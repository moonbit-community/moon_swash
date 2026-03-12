import {
  WASI,
  WASIProcExit,
  File as WasiFile,
  OpenFile,
  PreopenDirectory,
  ConsoleStdout,
} from "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.2/+esm";

const $ = (id) => document.getElementById(id);

const ui = {
  text: $("text"),
  size: $("size"),
  script: $("script"),
  direction: $("direction"),
  font: $("font"),
  render: $("render"),
  download: $("download"),
  status: $("status"),
  viewer: $("viewer"),
  raw: $("raw"),
  fontMeta: $("font-meta"),
};

const state = {
  wasmModule: null,
  defaultFont: null,
  customFont: null,
  customFontName: "",
  lastSvg: "",
};

function setStatus(text, isError = false) {
  ui.status.textContent = text;
  ui.status.style.color = isError ? "#b00020" : "#5a6b62";
}

function getTextBytes(text) {
  return new TextEncoder().encode(text);
}

function getBytesText(bytes) {
  return new TextDecoder().decode(bytes);
}

async function loadWasmModule() {
  if (state.wasmModule) {
    return state.wasmModule;
  }
  const resp = await fetch("./assets/moon_swash_svg_dump.wasm");
  if (!resp.ok) {
    throw new Error(`Failed to load wasm: HTTP ${resp.status}`);
  }
  const bytes = await resp.arrayBuffer();
  state.wasmModule = await WebAssembly.compile(bytes);
  return state.wasmModule;
}

async function loadDefaultFont() {
  if (state.defaultFont) {
    return state.defaultFont;
  }
  const resp = await fetch("./assets/NotoNaskhArabic-wght.ttf");
  if (!resp.ok) {
    throw new Error(`Failed to load default font: HTTP ${resp.status}`);
  }
  state.defaultFont = await resp.arrayBuffer();
  return state.defaultFont;
}

async function readCustomFont(file) {
  const bytes = await file.arrayBuffer();
  state.customFont = bytes;
  state.customFontName = file.name;
  ui.fontMeta.textContent = `Using custom font: ${file.name}`;
}

async function runSvgDump({ text, size, script, direction, fontBytes }) {
  const stdoutMemFile = new WasiFile([]);
  const stderrLines = [];
  const inputBytes = getTextBytes(text);

  const wasi = new WASI(
    [
      "moon_swash_svg_dump.wasm",
      "font.ttf",
      "@file:input.txt",
      String(size),
      script,
      direction,
    ],
    [],
    [
      new OpenFile(new WasiFile([])),
      new OpenFile(stdoutMemFile),
      ConsoleStdout.lineBuffered((line) => stderrLines.push(line)),
      new PreopenDirectory(
        ".",
        new Map([
          ["font.ttf", new WasiFile(fontBytes, { readonly: true })],
          ["input.txt", new WasiFile(inputBytes, { readonly: true })],
        ])
      ),
    ]
  );

  const instance = await WebAssembly.instantiate(await loadWasmModule(), {
    wasi_snapshot_preview1: wasi.wasiImport,
    spectest: {
      print_char: (_codePoint) => {
        // moon runtime may import this symbol; no output needed here.
      },
    },
  });

  let exitCode = 0;
  try {
    exitCode = wasi.start(instance);
  } catch (err) {
    if (err instanceof WASIProcExit) {
      exitCode = err.code;
    } else {
      throw err;
    }
  }

  if (exitCode !== 0) {
    const detail = stderrLines.join("\n").trim();
    throw new Error(detail || `WASM exited with code ${exitCode}`);
  }

  const svg = getBytesText(stdoutMemFile.data).trim();
  if (!svg.startsWith("<svg")) {
    throw new Error("moon_swash_svg_dump did not produce valid SVG output");
  }
  return svg;
}

function setBusy(busy) {
  ui.render.disabled = busy;
  ui.download.disabled = busy || !state.lastSvg;
}

function renderSvg(svg) {
  ui.viewer.innerHTML = svg;
  ui.raw.textContent = svg;
  state.lastSvg = svg;
  ui.download.disabled = false;
}

async function doRender() {
  const text = ui.text.value;
  if (!text.trim()) {
    setStatus("Please input some text.", true);
    return;
  }

  const size = Number(ui.size.value);
  if (!Number.isFinite(size) || size <= 0) {
    setStatus("Size must be a positive number.", true);
    return;
  }

  const script = ui.script.value;
  const direction = ui.direction.value;

  setBusy(true);
  setStatus("Rendering SVG with moon_swash...");

  try {
    const fontBytes = state.customFont || (await loadDefaultFont());
    const svg = await runSvgDump({ text, size, script, direction, fontBytes });
    renderSvg(svg);
    const fontName = state.customFontName || "NotoNaskhArabic-wght.ttf";
    setStatus(`Rendered successfully. size=${size}, script=${script}, direction=${direction}, font=${fontName}`);
  } catch (err) {
    console.error(err);
    setStatus(`Render failed: ${err instanceof Error ? err.message : String(err)}`, true);
  } finally {
    setBusy(false);
  }
}

function downloadSvg() {
  if (!state.lastSvg) {
    return;
  }
  const blob = new Blob([state.lastSvg], { type: "image/svg+xml" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "moon_swash_render.svg";
  a.click();
  URL.revokeObjectURL(url);
}

ui.render.addEventListener("click", () => {
  doRender();
});

ui.download.addEventListener("click", () => {
  downloadSvg();
});

ui.font.addEventListener("change", async (ev) => {
  const file = ev.target.files && ev.target.files[0];
  if (!file) {
    state.customFont = null;
    state.customFontName = "";
    ui.fontMeta.textContent = "Default font: Noto Naskh Arabic (OFL-1.1)";
    return;
  }
  try {
    await readCustomFont(file);
    setStatus(`Loaded custom font: ${file.name}`);
  } catch (err) {
    state.customFont = null;
    state.customFontName = "";
    setStatus(`Failed to read custom font: ${err instanceof Error ? err.message : String(err)}`, true);
  }
});

window.addEventListener("DOMContentLoaded", async () => {
  try {
    setStatus("Loading wasm and default font...");
    await Promise.all([loadWasmModule(), loadDefaultFont()]);
    setStatus("Ready. Click Render SVG.");
    await doRender();
  } catch (err) {
    setStatus(`Initialization failed: ${err instanceof Error ? err.message : String(err)}`, true);
  }
});

import {
  WASI,
  WASIProcExit,
  File as WasiFile,
  OpenFile,
  PreopenDirectory,
  ConsoleStdout,
} from "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.2/+esm";

const CUSTOM_FONT_ID = "custom";

const FONT_PRESETS = [
  {
    id: "noto-naskh-arabic",
    label: "Noto Naskh Arabic [TTF]",
    file: "NotoNaskhArabic-wght.ttf",
    licenseFile: "NotoNaskhArabic-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-sans-latin",
    label: "Noto Sans [TTF]",
    file: "NotoSans-Latin-wght.ttf",
    licenseFile: "NotoSans-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-serif-latin",
    label: "Noto Serif [TTF]",
    file: "NotoSerif-Latin-wght.ttf",
    licenseFile: "NotoSerif-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-sans-hebrew",
    label: "Noto Sans Hebrew [TTF]",
    file: "NotoSansHebrew-wght.ttf",
    licenseFile: "NotoSansHebrew-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-serif-hebrew",
    label: "Noto Serif Hebrew [TTF]",
    file: "NotoSerifHebrew-wght.ttf",
    licenseFile: "NotoSerifHebrew-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-sans-arabic",
    label: "Noto Sans Arabic [TTF]",
    file: "NotoSansArabic-wght.ttf",
    licenseFile: "NotoSansArabic-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-kufi-arabic",
    label: "Noto Kufi Arabic [TTF]",
    file: "NotoKufiArabic-wght.ttf",
    licenseFile: "NotoKufiArabic-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-sans-devanagari",
    label: "Noto Sans Devanagari [TTF]",
    file: "NotoSansDevanagari-wght.ttf",
    licenseFile: "NotoSansDevanagari-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-sans-thai",
    label: "Noto Sans Thai [TTF]",
    file: "NotoSansThai-wght.ttf",
    licenseFile: "NotoSansThai-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-sans-myanmar",
    label: "Noto Sans Myanmar [TTF]",
    file: "NotoSansMyanmar-wght.ttf",
    licenseFile: "NotoSansMyanmar-OFL.txt",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "source-sans-otf",
    label: "Source Sans 3 [OTF]",
    file: "SourceSans3-Regular.otf",
    licenseFile: "SourceSans-LICENSE.md",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "source-serif-otf",
    label: "Source Serif 4 [OTF]",
    file: "SourceSerif4-Regular.otf",
    licenseFile: "SourceSerif-LICENSE.md",
    licenseLabel: "OFL-1.1",
  },
  {
    id: "noto-latin-collection-ttc",
    label: "Noto Latin Collection [TTC]",
    file: "NotoLatinCollection.ttc",
    licenseFile: "NotoLatinCollection-NOTICE.txt",
    licenseLabel: "License Notes",
  },
  {
    id: "noto-arabic-collection-ttc",
    label: "Noto Arabic Collection [TTC]",
    file: "NotoArabicCollection.ttc",
    licenseFile: "NotoArabicCollection-NOTICE.txt",
    licenseLabel: "License Notes",
  },
];

const $ = (id) => document.getElementById(id);

const ui = {
  text: $("text"),
  size: $("size"),
  script: $("script"),
  direction: $("direction"),
  fontPreset: $("font-preset"),
  font: $("font"),
  render: $("render"),
  download: $("download"),
  status: $("status"),
  viewer: $("viewer"),
  raw: $("raw"),
  fontMeta: $("font-meta"),
  fontLicenseLink: $("font-license-link"),
};

const state = {
  wasmModule: null,
  presetFontBytes: new Map(),
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

function getPresetById(id) {
  return FONT_PRESETS.find((preset) => preset.id === id) || null;
}

function getSelectedPreset() {
  const preset = getPresetById(ui.fontPreset.value);
  if (!preset) {
    throw new Error(`Unknown font preset: ${ui.fontPreset.value}`);
  }
  return preset;
}

function initFontPresetOptions() {
  ui.fontPreset.innerHTML = "";
  for (const preset of FONT_PRESETS) {
    const option = document.createElement("option");
    option.value = preset.id;
    option.textContent = preset.label;
    ui.fontPreset.appendChild(option);
  }
  const custom = document.createElement("option");
  custom.value = CUSTOM_FONT_ID;
  custom.textContent = "Custom Upload";
  ui.fontPreset.appendChild(custom);
}

function updateFontUi() {
  const usingCustom = ui.fontPreset.value === CUSTOM_FONT_ID;
  ui.font.disabled = usingCustom ? false : true;

  if (usingCustom) {
    if (state.customFontName) {
      ui.fontMeta.textContent = `Current font: ${state.customFontName} (Custom Upload)`;
    } else {
      ui.fontMeta.textContent = "Current font: Custom Upload (pick a font file first)";
    }
    ui.fontLicenseLink.textContent = "User-provided";
    ui.fontLicenseLink.removeAttribute("href");
    return;
  }

  const preset = getSelectedPreset();
  ui.fontMeta.textContent = `Current font: ${preset.label}`;
  ui.fontLicenseLink.textContent = preset.licenseLabel;
  ui.fontLicenseLink.href = `./assets/${preset.licenseFile}`;
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

async function loadPresetFont(preset) {
  if (state.presetFontBytes.has(preset.id)) {
    return state.presetFontBytes.get(preset.id);
  }
  const resp = await fetch(`./assets/${preset.file}`);
  if (!resp.ok) {
    throw new Error(`Failed to load bundled font ${preset.file}: HTTP ${resp.status}`);
  }
  const bytes = await resp.arrayBuffer();
  state.presetFontBytes.set(preset.id, bytes);
  return bytes;
}

async function resolveActiveFont() {
  if (ui.fontPreset.value === CUSTOM_FONT_ID) {
    if (!state.customFont) {
      throw new Error("Custom Upload is selected, but no font file is loaded.");
    }
    return {
      bytes: state.customFont,
      displayName: state.customFontName || "custom-font.ttf",
    };
  }

  const preset = getSelectedPreset();
  return {
    bytes: await loadPresetFont(preset),
    displayName: preset.file,
  };
}

async function readCustomFont(file) {
  const bytes = await file.arrayBuffer();
  state.customFont = bytes;
  state.customFontName = file.name;
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
  ui.fontPreset.disabled = busy;
  if (busy) {
    ui.font.disabled = true;
  } else {
    updateFontUi();
  }
}

function renderSvg(svg) {
  ui.viewer.innerHTML = svg;
  const svgNode = ui.viewer.querySelector("svg");
  if (svgNode) {
    const viewBox = svgNode.getAttribute("viewBox");
    if (viewBox) {
      const nums = viewBox
        .trim()
        .split(/\s+/)
        .map((v) => Number(v));
      if (nums.length === 4 && Number.isFinite(nums[2]) && Number.isFinite(nums[3])) {
        if (nums[2] > 0 && nums[3] > 0) {
          svgNode.setAttribute("width", String(nums[2]));
          svgNode.setAttribute("height", String(nums[3]));
        }
      }
    }
  }
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
    const activeFont = await resolveActiveFont();
    const svg = await runSvgDump({
      text,
      size,
      script,
      direction,
      fontBytes: activeFont.bytes,
    });
    renderSvg(svg);
    setStatus(
      `Rendered successfully. size=${size}, script=${script}, direction=${direction}, font=${activeFont.displayName}`
    );
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

ui.fontPreset.addEventListener("change", async () => {
  updateFontUi();

  if (ui.fontPreset.value === CUSTOM_FONT_ID) {
    setStatus("Custom Upload selected. Pick a font file and render.");
    return;
  }

  try {
    const preset = getSelectedPreset();
    await loadPresetFont(preset);
    setStatus(`Ready. Active font: ${preset.label}`);
  } catch (err) {
    setStatus(`Failed to load bundled font: ${err instanceof Error ? err.message : String(err)}`, true);
  }
});

ui.font.addEventListener("change", async (ev) => {
  const file = ev.target.files && ev.target.files[0];
  if (!file) {
    state.customFont = null;
    state.customFontName = "";
    updateFontUi();
    return;
  }

  try {
    await readCustomFont(file);
    ui.fontPreset.value = CUSTOM_FONT_ID;
    updateFontUi();
    setStatus(`Loaded custom font: ${file.name}`);
  } catch (err) {
    state.customFont = null;
    state.customFontName = "";
    setStatus(`Failed to read custom font: ${err instanceof Error ? err.message : String(err)}`, true);
  }
});

window.addEventListener("DOMContentLoaded", async () => {
  try {
    const defaultPreset = FONT_PRESETS[0];
    initFontPresetOptions();
    ui.fontPreset.value = defaultPreset.id;
    updateFontUi();

    setStatus("Loading wasm and bundled fonts...");
    await Promise.all([loadWasmModule(), loadPresetFont(defaultPreset)]);
    setStatus("Ready. Click Render SVG.");
    await doRender();
  } catch (err) {
    setStatus(`Initialization failed: ${err instanceof Error ? err.message : String(err)}`, true);
  }
});

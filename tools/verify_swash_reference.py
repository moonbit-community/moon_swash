# Copyright 2025 International Digital Economy Academy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Tuple


ROOT = Path(__file__).resolve().parents[1]
SWASH_REFERENCE_DIR = ROOT / "swash-reference"

MOON_DUMP_DIR = ROOT / "tools" / "moon_swash_dump"
MOON_DUMP_WASM = MOON_DUMP_DIR / "target" / "wasm" / "release" / "build" / "moon_swash_dump.wasm"
SPECTEST_WASM = MOON_DUMP_DIR / "spectest.wasm"

TMP_DIR = ROOT / ".tmp"
TMP_FONTS_DIR = TMP_DIR / "fonts"


def _run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def _require_ok(p: subprocess.CompletedProcess[str], what: str) -> None:
    if p.returncode == 0:
        return
    sys.stderr.write(f"{what} failed (exit={p.returncode})\n")
    if p.stdout:
        sys.stderr.write("stdout:\n")
        sys.stderr.write(p.stdout)
        if not p.stdout.endswith("\n"):
            sys.stderr.write("\n")
    if p.stderr:
        sys.stderr.write("stderr:\n")
        sys.stderr.write(p.stderr)
        if not p.stderr.endswith("\n"):
            sys.stderr.write("\n")
    raise SystemExit(p.returncode)


def _pick_default_font() -> Path:
    candidates = [
        Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
        Path("/System/Library/Fonts/Supplemental/Times New Roman.ttf"),
        Path("/System/Library/Fonts/Geneva.ttf"),
    ]
    for p in candidates:
        if p.exists():
            return p
    raise SystemExit(
        "No default font found. Please pass --font /path/to/font.(ttf|otf|ttc)"
    )


def _prepare_font(font: Path) -> Path:
    TMP_FONTS_DIR.mkdir(parents=True, exist_ok=True)
    dst = TMP_FONTS_DIR / font.name
    if dst.exists():
        return dst
    # On macOS some system fonts carry flags/xattrs that can cause copy2/copyfile
    # to fail when attempting to preserve metadata. We only need the bytes.
    try:
        shutil.copy2(font, dst)
    except PermissionError:
        shutil.copyfile(font, dst)
    return dst


def _build_moon_dump() -> None:
    p = _run(
        ["moon", "build", "-C", str(MOON_DUMP_DIR), "--target", "wasm", "--release", "-d"],
        cwd=ROOT,
    )
    _require_ok(p, "moon build (tools/moon_swash_dump)")
    if not MOON_DUMP_WASM.exists():
        raise SystemExit(f"moon dump wasm not found at {MOON_DUMP_WASM}")
    if not SPECTEST_WASM.exists():
        raise SystemExit(f"spectest shim wasm not found at {SPECTEST_WASM}")


def _run_moon_dump(font_path: Path, text: str, size: float) -> str:
    # Run from repo root, and grant guest access to '.' so it can read `.tmp/...`.
    p = _run(
        [
            "wasmtime",
            "run",
            "--dir",
            ".",
            "--preload",
            f"spectest={SPECTEST_WASM}",
            str(MOON_DUMP_WASM),
            str(font_path),
            text,
            str(size),
        ],
        cwd=ROOT,
    )
    _require_ok(p, "wasmtime run (moon_swash_dump)")
    return p.stdout.strip()


def _run_rust_dump(font_path: Path, text: str, size: float) -> str:
    if not (SWASH_REFERENCE_DIR / "Cargo.toml").exists():
        raise SystemExit(
            "swash-reference not found at ./swash-reference.\n"
            "Place a checkout of the Rust reference implementation there to run this verifier."
        )
    p = _run(
        [
            "cargo",
            "run",
            "--quiet",
            "--manifest-path",
            str(SWASH_REFERENCE_DIR / "Cargo.toml"),
            "--bin",
            "dump_json",
            "--",
            str(font_path),
            text,
            str(size),
        ],
        cwd=ROOT,
    )
    _require_ok(p, "cargo run (swash-reference dump_json)")
    return p.stdout.strip()


def _cmp(a: Any, b: Any, *, tol: float, path: str) -> Tuple[bool, str]:
    if isinstance(a, dict) and isinstance(b, dict):
        ak = set(a.keys())
        bk = set(b.keys())
        if ak != bk:
            return False, f"{path}: key mismatch: ref={sorted(ak)} moon={sorted(bk)}"
        for k in sorted(ak):
            ok, msg = _cmp(a[k], b[k], tol=tol, path=f"{path}.{k}")
            if not ok:
                return False, msg
        return True, ""
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return False, f"{path}: length mismatch: ref={len(a)} moon={len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            ok, msg = _cmp(x, y, tol=tol, path=f"{path}[{i}]")
            if not ok:
                return False, msg
        return True, ""
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        af = float(a)
        bf = float(b)
        if abs(af - bf) <= tol:
            return True, ""
        return False, f"{path}: number mismatch: ref={a} moon={b} (tol={tol})"
    if a == b:
        return True, ""
    return False, f"{path}: value mismatch: ref={a!r} moon={b!r}"


def main() -> None:
    ap = argparse.ArgumentParser(description="Diff MoonBit swash vs Rust swash-reference.")
    ap.add_argument("--font", type=Path, help="Path to a font file (ttf/otf/ttc).")
    ap.add_argument("--text", action="append", help="Text to shape (repeatable).")
    ap.add_argument("--size", type=float, default=14.0, help="Font size (default: 14).")
    ap.add_argument("--tol", type=float, default=0.02, help="Numeric tolerance (default: 0.02).")
    ap.add_argument("--dump", action="store_true", help="Print both JSON blobs on mismatch.")
    args = ap.parse_args()

    font = args.font or _pick_default_font()
    if not font.exists():
        raise SystemExit(f"font not found: {font}")

    # Use a workspace-relative path for the WASI tool.
    font_local = _prepare_font(font)
    font_rel = font_local.relative_to(ROOT)

    texts = args.text or ["abc", "Hello, world!", "AV"]

    _build_moon_dump()

    for t in texts:
        rust_out = _run_rust_dump(font_rel, t, args.size)
        moon_out = _run_moon_dump(font_rel, t, args.size)
        try:
            rust_json = json.loads(rust_out)
        except Exception as e:
            raise SystemExit(f"failed to parse rust json: {e}\n{rust_out}")
        try:
            moon_json = json.loads(moon_out)
        except Exception as e:
            raise SystemExit(f"failed to parse moon json: {e}\n{moon_out}")

        ok, msg = _cmp(rust_json, moon_json, tol=args.tol, path="$")
        if not ok:
            sys.stderr.write(f"Mismatch for text={t!r} size={args.size} font={font}\n")
            sys.stderr.write(msg + "\n")
            if args.dump:
                sys.stderr.write("\nref:\n")
                sys.stderr.write(rust_out + "\n")
                sys.stderr.write("\nmoon:\n")
                sys.stderr.write(moon_out + "\n")
            raise SystemExit(1)
        sys.stdout.write(f"OK text={t!r}\n")


if __name__ == "__main__":
    main()

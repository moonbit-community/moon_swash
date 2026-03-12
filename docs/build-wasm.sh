#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/docs/wasm/moon_swash_svg_dump"
OUT="$ROOT/docs/assets/moon_swash_svg_dump.wasm"

(
  cd "$PKG"
  moon build --target wasm --release -d
)

cp "$PKG/_build/wasm/release/build/moon_swash_svg_dump.wasm" "$OUT"
echo "updated: $OUT"

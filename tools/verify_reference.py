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
import hashlib
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Tuple


ROOT = Path(__file__).resolve().parents[1]

MOON_DUMP_DIR = ROOT / "tools" / "moon_swash_dump"
MOON_DUMP_WASM = MOON_DUMP_DIR / "target" / "wasm" / "release" / "build" / "moon_swash_dump.wasm"
SPECTEST_WASM = MOON_DUMP_DIR / "spectest.wasm"

TMP_DIR = ROOT / ".tmp"
TMP_FONTS_DIR = TMP_DIR / "fonts"
DEFAULT_TEXTS = ["abc", "Hello, world!", "AV"]
DEFAULT_SIZES = [14.0]


@dataclass(frozen=True)
class VerifyCase:
    font_abs: Path
    font_rel: Path
    text: str
    size: float


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


def _normalize_path(p: Path) -> Path:
    p = p.expanduser()
    if p.is_absolute():
        return p.resolve()
    return (Path.cwd() / p).resolve()


def _stable_font_cache_name(font: Path) -> str:
    digest = hashlib.sha256(str(font).encode("utf-8")).hexdigest()[:12]
    return f"{font.stem}-{digest}{font.suffix}"


def _prepare_font(font: Path) -> Path:
    TMP_FONTS_DIR.mkdir(parents=True, exist_ok=True)
    dst = TMP_FONTS_DIR / _stable_font_cache_name(font)
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
        ["moon", "build", "--target", "wasm", "--release", "-d"],
        cwd=MOON_DUMP_DIR,
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


def _run_ref_dump(ref_cmd: list[str], font_path: Path, text: str, size: float) -> str:
    # The reference command must print JSON to stdout.
    p = _run(ref_cmd + [str(font_path), text, str(size)], cwd=ROOT)
    _require_ok(p, "reference command")
    return p.stdout.strip()


def _cmp(
    a: Any,
    b: Any,
    *,
    tol: float,
    path: str,
    allow_extra_moon_keys: bool,
) -> Tuple[bool, str]:
    if isinstance(a, dict) and isinstance(b, dict):
        ak = set(a.keys())
        bk = set(b.keys())
        if allow_extra_moon_keys:
            missing = ak - bk
            if missing:
                return (
                    False,
                    f"{path}: moon missing keys from ref: missing={sorted(missing)} "
                    f"ref={sorted(ak)} moon={sorted(bk)}",
                )
        elif ak != bk:
            return False, f"{path}: key mismatch: ref={sorted(ak)} moon={sorted(bk)}"
        for k in sorted(ak):
            ok, msg = _cmp(
                a[k],
                b[k],
                tol=tol,
                path=f"{path}.{k}",
                allow_extra_moon_keys=allow_extra_moon_keys,
            )
            if not ok:
                return False, msg
        return True, ""
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return False, f"{path}: length mismatch: ref={len(a)} moon={len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            ok, msg = _cmp(
                x,
                y,
                tol=tol,
                path=f"{path}[{i}]",
                allow_extra_moon_keys=allow_extra_moon_keys,
            )
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


def _load_case_records(case_file: Path) -> list[dict[str, Any]]:
    case_file = _normalize_path(case_file)
    if not case_file.exists():
        raise SystemExit(f"case file not found: {case_file}")
    raw = case_file.read_text(encoding="utf-8")

    if case_file.suffix in {".jsonl", ".ndjson"}:
        rows: list[dict[str, Any]] = []
        for i, line in enumerate(raw.splitlines(), start=1):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception as e:
                raise SystemExit(f"invalid JSONL at {case_file}:{i}: {e}") from e
            if not isinstance(rec, dict):
                raise SystemExit(f"case file row must be object: {case_file}:{i}")
            rows.append(rec)
        return rows

    try:
        obj = json.loads(raw)
    except Exception as e:
        raise SystemExit(f"invalid JSON case file: {case_file}: {e}") from e

    if isinstance(obj, dict):
        rows = obj.get("cases")
        if not isinstance(rows, list):
            raise SystemExit(f"JSON case file must contain a list under key 'cases': {case_file}")
    elif isinstance(obj, list):
        rows = obj
    else:
        raise SystemExit(f"JSON case file root must be list or object: {case_file}")

    for i, rec in enumerate(rows, start=1):
        if not isinstance(rec, dict):
            raise SystemExit(f"case file entry #{i} must be object: {case_file}")
    return rows


def _coerce_size(value: Any, *, where: str) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError as e:
            raise SystemExit(f"{where}: invalid size {value!r}") from e
    raise SystemExit(f"{where}: invalid size type {type(value).__name__}")


def _build_verify_cases(args: argparse.Namespace) -> list[VerifyCase]:
    cli_fonts = [_normalize_path(p) for p in (args.font or [])]
    cli_sizes = [float(s) for s in (args.size or DEFAULT_SIZES)]
    cli_texts = args.text or DEFAULT_TEXTS

    if not args.case_file and not cli_fonts:
        cli_fonts = [_pick_default_font()]

    raw_cases: list[tuple[Path, str, float]] = []
    if args.case_file:
        records = _load_case_records(args.case_file)
        for i, rec in enumerate(records, start=1):
            where = f"case #{i}"
            text = rec.get("text")
            if not isinstance(text, str):
                raise SystemExit(f"{where}: 'text' must be a string")

            if "size" in rec:
                size = _coerce_size(rec["size"], where=where)
            elif len(cli_sizes) == 1:
                size = cli_sizes[0]
            else:
                raise SystemExit(f"{where}: missing 'size' while multiple --size values are provided")

            rec_font = rec.get("font")
            if rec_font is None:
                if not cli_fonts:
                    cli_fonts = [_pick_default_font()]
                for font in cli_fonts:
                    raw_cases.append((font, text, size))
            else:
                raw_cases.append((_normalize_path(Path(str(rec_font))), text, size))
    else:
        for font in cli_fonts:
            for text in cli_texts:
                for size in cli_sizes:
                    raw_cases.append((font, text, size))

    if not raw_cases:
        raise SystemExit("no verify cases found")

    prepared: dict[Path, Path] = {}
    cases: list[VerifyCase] = []
    seen: set[tuple[str, str, float]] = set()
    for font_abs, text, size in raw_cases:
        if not font_abs.exists():
            raise SystemExit(f"font not found: {font_abs}")
        if font_abs not in prepared:
            prepared[font_abs] = _prepare_font(font_abs)
        font_rel = prepared[font_abs].relative_to(ROOT)
        key = (str(font_rel), text, size)
        if key in seen:
            continue
        seen.add(key)
        cases.append(
            VerifyCase(
                font_abs=font_abs,
                font_rel=font_rel,
                text=text,
                size=size,
            )
        )
    return cases


def main() -> None:
    ap = argparse.ArgumentParser(description="Diff MoonBit output vs an external reference dumper.")
    ap.add_argument(
        "--font",
        action="append",
        type=Path,
        help="Path to a font file (ttf/otf/ttc). Repeatable.",
    )
    ap.add_argument("--text", action="append", help="Text to shape (repeatable).")
    ap.add_argument(
        "--size",
        action="append",
        type=float,
        help="Font size. Repeatable. Default: 14.",
    )
    ap.add_argument(
        "--case-file",
        type=Path,
        help=(
            "Optional JSON/JSONL verify cases. Entry format: "
            '{"font":"...","text":"...","size":14.0}. '
            "If 'font' is omitted, all CLI fonts are used for that entry."
        ),
    )
    ap.add_argument("--tol", type=float, default=0.02, help="Numeric tolerance (default: 0.02).")
    ap.add_argument("--dump", action="store_true", help="Print both JSON blobs on mismatch.")
    ap.add_argument(
        "--strict-keys",
        action="store_true",
        help="Require exact key set match between ref and moon JSON (default: allow extra moon keys).",
    )
    ap.add_argument(
        "--fail-fast",
        action="store_true",
        help="Stop immediately on the first mismatch or parse error.",
    )
    ap.add_argument(
        "--max-report",
        type=int,
        default=20,
        help="Maximum number of mismatches to print in detail (default: 20).",
    )
    ap.add_argument(
        "--ref-cmd",
        nargs="+",
        required=True,
        help=(
            "Reference dumper command. It must accept arguments: <font_path> <text> <size> "
            "and print a single JSON object to stdout."
        ),
    )
    args = ap.parse_args()
    if args.max_report <= 0:
        raise SystemExit("--max-report must be > 0")

    _build_moon_dump()
    cases = _build_verify_cases(args)

    total = 0
    passed = 0
    mismatches: list[tuple[VerifyCase, str, str, str]] = []
    parse_errors: list[str] = []
    for case in cases:
        total = total + 1
        ref_out = _run_ref_dump(args.ref_cmd, case.font_rel, case.text, case.size)
        moon_out = _run_moon_dump(case.font_rel, case.text, case.size)
        try:
            ref_json = json.loads(ref_out)
        except Exception as e:
            msg = (
                f"failed to parse reference json for "
                f"text={case.text!r} size={case.size} font={case.font_abs}: {e}"
            )
            parse_errors.append(msg)
            if args.fail_fast:
                break
            continue
        try:
            moon_json = json.loads(moon_out)
        except Exception as e:
            msg = (
                f"failed to parse moon json for "
                f"text={case.text!r} size={case.size} font={case.font_abs}: {e}"
            )
            parse_errors.append(msg)
            if args.fail_fast:
                break
            continue

        ok, msg = _cmp(
            ref_json,
            moon_json,
            tol=args.tol,
            path="$",
            allow_extra_moon_keys=not args.strict_keys,
        )
        if not ok:
            mismatches.append((case, msg, ref_out, moon_out))
            if args.fail_fast:
                break
            continue
        passed = passed + 1
        sys.stdout.write(
            f"OK text={case.text!r} size={case.size} font={case.font_abs}\n"
        )

    if parse_errors:
        sys.stderr.write("Parse errors:\n")
        for msg in parse_errors[: args.max_report]:
            sys.stderr.write(f"- {msg}\n")
        if len(parse_errors) > args.max_report:
            sys.stderr.write(f"... and {len(parse_errors) - args.max_report} more parse errors\n")

    if mismatches:
        sys.stderr.write("Mismatches:\n")
        for case, msg, ref_out, moon_out in mismatches[: args.max_report]:
            sys.stderr.write(
                f"- text={case.text!r} size={case.size} font={case.font_abs}\n"
            )
            sys.stderr.write(f"  {msg}\n")
            if args.dump:
                sys.stderr.write("  ref:\n")
                sys.stderr.write(ref_out + "\n")
                sys.stderr.write("  moon:\n")
                sys.stderr.write(moon_out + "\n")
        if len(mismatches) > args.max_report:
            sys.stderr.write(f"... and {len(mismatches) - args.max_report} more mismatches\n")

    failed = len(mismatches) + len(parse_errors)
    sys.stdout.write(
        f"Summary: total={total} passed={passed} failed={failed} "
        f"(mismatch={len(mismatches)}, parse_error={len(parse_errors)})\n"
    )
    if failed > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

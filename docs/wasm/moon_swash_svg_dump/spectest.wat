;; Minimal import shim for MoonBit wasm output when running under Wasmtime.
;; Provides `spectest.print_char(i32)` which MoonBit may import.
(module
  (func (export "print_char") (param i32)
    nop)
)


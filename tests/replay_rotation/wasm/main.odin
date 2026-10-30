package wasm
import c "../shared"
@(export)
run :: proc "c" ()->u32 {context=runtime.default_context();return c.verify()}
import "base:runtime"

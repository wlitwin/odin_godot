package wasm
import "base:runtime"
import corpus "../shared"
value:u64
@(export)
run :: proc "c" ()->u32 {context=runtime.default_context();code,hash,_:=corpus.verify();value=hash;return code}
@(export)
hash :: proc "c" ()->u64 {return value}

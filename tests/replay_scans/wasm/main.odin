package wasm_scan_corpus
import "base:runtime"
import corpus "../shared"
value:u64
@(export)
run :: proc "c" ()->u32 {context=runtime.default_context();code,fingerprint:=corpus.verify();value=fingerprint;return code}
@(export)
hash :: proc "c" ()->u64 {return value}

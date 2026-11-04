package box3d_protocol_wasm
import c "../corpus"

@(export)
verify :: proc "c" () -> u32 {
    return c.verify()
}

@(export)
signature_byte :: proc "c" (index: u32) -> u32 {
    return c.signature_byte(index)
}

@(export)
trace_byte :: proc "c" (index: u32) -> u32 {
    return c.trace_byte(index)
}

@(export)
trace_size :: proc "c" () -> u32 {
    return c.trace_size()
}

@(export)
descriptor_byte :: proc "c" (index: u32) -> u32 {
    return c.descriptor_byte(index)
}

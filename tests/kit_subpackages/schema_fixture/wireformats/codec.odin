package schema_wireformats

import knet "godot:kit/net"

@(private)
SIGNED_V1 := knet.Wire_Codec{size = 4, encode = encode_signed, decode = decode_signed}

@(private)
encode_signed :: proc(wire, field: rawptr) {
    bytes := cast([^]u8)wire
    for i in 0 ..< SIGNED_V1.size {bytes[i] = 0}
    (cast(^i32)wire)^ = (cast(^i32)field)^
}
@(private)
decode_signed :: proc(field, wire: rawptr) { (cast(^i32)field)^ = (cast(^i32)wire)^ }

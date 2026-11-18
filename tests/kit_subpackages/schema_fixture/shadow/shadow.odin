package shadow_types
import knet "godot:kit/net"
Payload :: struct { wrong: [4]u64 }
SIGNED_V1 := knet.Wire_Codec{size = 2, encode = unused_encode, decode = unused_encode}
unused_encode :: proc(a, b: rawptr) {}

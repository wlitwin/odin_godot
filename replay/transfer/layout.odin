package replay_transfer
import sc "godot:replay/schema"

// Optional byte permutation for one typed section of a canonical archive.
// The caller owns the ready schema at a stable address and must not mutate it
// during use. Archive bytes, hashes and typed installation remain canonical.
Layout :: struct {schema:^sc.Schema,offset:int}

@(private)
layout_signature :: proc(layout:Layout,bytes:int)->u64 {
 s:=layout.schema
 if s==nil || !s.ready || len(s.arrays)==0 || s.wire_size<=0 || bytes>MAX_BYTES || layout.offset<sc.HEADER_BYTES || layout.offset>bytes || s.wire_size>bytes-layout.offset {return 0}
 // The schema signature includes shuffle version, canonical fingerprint and
 // every ordered array region. The archive offset/size are part of this plan.
 encoded:[24]u8
 for value,i in ([3]u64{s.shuffle_fingerprint,u64(layout.offset),u64(s.wire_size)}) {for j in 0..<8 {encoded[i*8+j]=u8(value>>uint(j*8))}}
 return sc.digest(encoded[:],0x7265706c61796c31)
}

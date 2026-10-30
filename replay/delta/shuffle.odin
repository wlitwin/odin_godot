package replay_delta

import sc "godot:replay/schema"

// Scratch contains two exact-size transformed values. It may change on failure;
// the caller's destination and both inputs remain unchanged on rejection.
shuffle_lz4_encode :: proc(schema:^sc.Schema,base,target,dst:[]u8,work:^Lz4_Workspace,scratch:[]u8)->(size:int,ok:bool) {
 if !schema.ready || len(base)!=schema.wire_size || len(target)!=len(base) || len(base)>65535 || len(scratch)<2*len(base) || work==nil {return}
 work_bytes:=(cast([^]u8)work)[:size_of(Lz4_Workspace)]
 if overlaps(scratch,base) || overlaps(scratch,target) || overlaps(scratch,dst) || overlaps(scratch,work_bytes) ||
    overlaps(dst,base) || overlaps(dst,target) || overlaps(work_bytes,base) || overlaps(work_bytes,target) || overlaps(work_bytes,dst) {return}
 a,b:=scratch[:len(base)],scratch[len(base):2*len(base)]
 // A permutation is linear over XOR. Transform the difference once instead
 // of transforming both values; the encoded LZ4 input is byte-identical.
 for &byte,i in a {byte=base[i]~target[i]}
 if !sc.shuffle(schema,a,b) {return}
 for &byte in a {byte=0}
 return lz4_xor_encode(a,b,dst,work)
}

shuffle_lz4_apply :: proc(schema:^sc.Schema,base,encoded,dst,scratch:[]u8)->bool {
 if !schema.ready || len(base)!=schema.wire_size || len(dst)!=len(base) || len(base)>65535 || len(scratch)<2*len(base) ||
    overlaps(scratch,base) || overlaps(scratch,encoded) || overlaps(scratch,dst) || overlaps(dst,base) || overlaps(dst,encoded) {return false}
 a,b:=scratch[:len(base)],scratch[len(base):2*len(base)]
 for &byte in a {byte=0}
 if !lz4_xor_apply(a,encoded,b) || !sc.unshuffle(schema,b,a) {return false}
 for &byte,i in dst {byte=base[i]~a[i]}
 return true
}

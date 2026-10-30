package replay_schema

// A byte permutation of large fixed arrays, compiled once with the schema.
// Canonical bytes stay the public representation. Both operations require
// disjoint exact-size buffers and change nothing on rejected arguments.
shuffle :: proc(s:^Schema,src,dst:[]u8)->bool {return shuffle_copy(s,src,dst,false)}
unshuffle :: proc(s:^Schema,src,dst:[]u8)->bool {return shuffle_copy(s,src,dst,true)}

@(private)
shuffle_copy :: proc(s:^Schema,src,dst:[]u8,$Inverse:bool)->bool {
 if !s.ready || len(src)!=s.wire_size || len(dst)!=s.wire_size {return false}
 if len(src)>0 {
  a,b:=uintptr(raw_data(src)),uintptr(raw_data(dst))
  if (a<=b && b-a<uintptr(len(src))) || (b<a && a-b<uintptr(len(dst))) {return false}
 }
 copy(dst,src)
 for region in s.arrays {
  for lane in 0..<region.stride {for element in 0..<region.count {
   canonical:=region.offset+element*region.stride+lane
   grouped:=region.offset+lane*region.count+element
   when Inverse {dst[canonical]=src[grouped]} else {dst[grouped]=src[canonical]}
  }}
 }
 return true
}

SHUFFLE_VERSION :: u64(1)

@(private)
shuffle_signature :: proc(s:^Schema)->u64 {
 hash:=u64(0xcbf29ce484222325)
 add :: proc(hash:^u64,value:u64) {for i in 0..<8 {hash^=(hash^~u64(u8(value>>uint(i*8))))*0x100000001b3}}
 for value in ([4]u64{SHUFFLE_VERSION,s.fingerprint,u64(s.wire_size),u64(len(s.arrays))}) {add(&hash,value)}
 for region in s.arrays {for value in ([3]u64{u64(region.offset),u64(region.stride),u64(region.count)}) {add(&hash,value)}}
 return hash
}

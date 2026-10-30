package shuffle_corpus
import "core:mem"
import sc "godot:replay/schema"
import d "godot:replay/delta"
import old "../reference"

Item :: struct {position:[2]f32,generation:u32,active:bool,secret:u64 `replay:"authority"`}
A :: struct {values:[64]u32}
B :: struct {bytes:[16]u8}
Choice :: union {A,B}
World :: struct {
 header:u16,
 records:[8][32]Item,
 choices:[8]Choice,
 standalone:Choice,
 private_values:[32]u64 `replay:"authority"`,
 bytes:[320]u8,
}
base,target,canonical,shuffled,restored,reference,encoded:[32768]u8
scratch:[65536]u8
work:d.Lz4_Workspace
make_world :: proc(tick:u32)->World {
 value:World;value.header=u16(tick)
 for &row,i in value.records {for &item,j in row {item={position={f32(tick*17+u32(i)),f32(j)-f32(tick)},generation=u32(i*32+j+1),active=(j+int(tick))%3==0,secret=0xdead0000+u64(j)}}}
 for &choice,i in value.choices {
  switch (i+int(tick))%3 {
  case 0:a:A;for &v,j in a.values {v=tick*137+u32(j)};choice=a
  case 1:b:B;for &v,j in b.bytes {v=u8(tick)+u8(j)};choice=b
  }
 }
 a:A;for &v,i in a.values {v=u32(i)+tick};value.standalone=a
 for &v,i in value.private_values {v=u64(tick)*991+u64(i)}
 for &v,i in value.bytes {v=u8(i)}
 return value
}
verify :: proc()->(code:u32,hash:u64,cases:u64) {
 hash=0xcbf29ce484222325
 for public in ([2]bool{false,true}) {
  schema:sc.Schema;legacy:old.Schema
  opts:=sc.DEFAULT_OPTIONS;prior:=old.DEFAULT_OPTIONS
  if public {opts.projection=.Public;prior.projection=.Public}
  if sc.init(&schema,World,opts).error!=.None || old.init(&legacy,World,prior).error!=.None {return 1,0,0}
  defer sc.destroy(&schema);defer old.destroy(&legacy)
  if schema.fingerprint!=legacy.fingerprint || schema.wire_size!=legacy.wire_size || len(schema.arrays)!=(public ? 2 : 3) {return 2,0,0}
  end:=0
  for region in schema.arrays {
   if region.offset<end || region.stride<2 || region.count<4 || region.stride*region.count<256 {return 3,0,0}
   end=region.offset+region.stride*region.count;if end>schema.wire_size {return 4,0,0}
  }
  for tick in u32(1)..=16 {for alignment in 0..<8 {
   size:=schema.wire_size
   b,t,out:=base[alignment:alignment+size],target[alignment:alignment+size],shuffled[alignment:alignment+size]
   value,previous:=make_world(tick),make_world(tick-1)
   if sc.encode(&schema,previous,b).error!=.None || sc.encode(&schema,value,t).error!=.None || old.encode(&legacy,value,reference[:size]).error!=.None {return 5,0,0}
   if mem.compare(t,reference[:size])!=0 {return 6,0,0}
   for &byte in shuffled {byte=0xcc}
   if !sc.shuffle(&schema,t,out) {return 7,0,0}
   copy(canonical[:size],t)
   for region in schema.arrays {for j in 0..<region.stride*region.count {canonical[region.offset+j]=t[region.offset+(j%region.count)*region.stride+j/region.count]}}
   if mem.compare(out,canonical[:size])!=0 {return 8,0,0}
   for byte in shuffled[:alignment] {if byte!=0xcc {return 9,0,0}}
   for byte in shuffled[alignment+size:] {if byte!=0xcc {return 10,0,0}}
   if !sc.unshuffle(&schema,out,restored[:size]) || mem.compare(restored[:size],t)!=0 {return 11,0,0}
   n,ok:=d.shuffle_lz4_encode(&schema,b,t,encoded[:],&work,scratch[:]);if !ok {return 12,0,0}
   if !sc.shuffle(&schema,b,canonical[:size]) {return 20,0,0}
   expected,valid:=d.lz4_xor_encode(canonical[:size],out,reference[:],&work)
   if !valid || expected!=n || mem.compare(encoded[:n],reference[:expected])!=0 {return 21,0,0}
   if !d.shuffle_lz4_apply(&schema,b,encoded[:n],restored[:size],scratch[:]) || mem.compare(restored[:size],t)!=0 {return 13,0,0}
   for cut in ([5]int{0,1,n/2,max(0,n-2),n-1}) {
    for &byte in restored {byte=0xcc}
    if d.shuffle_lz4_apply(&schema,b,encoded[:cut],restored[:size],scratch[:]) {return 14,0,0}
    for byte in restored {if byte!=0xcc {return 15,0,0}}
   }
   before:=encoded
   _,ok=d.shuffle_lz4_encode(&schema,b,t,encoded[:n-1],&work,scratch[:]);if ok || encoded!=before {return 16,0,0}
   if sc.shuffle(&schema,t,t) || sc.unshuffle(&schema,t,restored[:size-1]) {return 17,0,0}
   if _,ok:=d.shuffle_lz4_encode(&schema,b,t,b,&work,scratch[:]);ok {return 18,0,0}
   if d.shuffle_lz4_apply(&schema,b,encoded[:n],restored[:size],b) {return 19,0,0}
   hash=sc.digest(out,hash);hash=(hash~schema.shuffle_fingerprint)*0x100000001b3;cases+=1
  }}
 }
 return
}

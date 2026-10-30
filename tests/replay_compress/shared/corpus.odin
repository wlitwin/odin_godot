package compress_corpus
import c "godot:replay/compress"
import r "godot:replay"
import sc "godot:replay/schema"
input,output,scratch:[c.MAX_BYTES]u8
encoded:[c.MAX_BYTES+128]u8
work:c.Workspace
verify :: proc()->(code:u32,hash:u64) {
 hash=0xcbf29ce484222325;rng:=r.rng_make(991)
 for mode in 0..<4 {
  for &byte,i in input {byte=mode==0 ? 0 : mode==1 ? u8(i%251) : mode==2 ? u8(r.rng_next(&rng)) : u8(i/65535)}
  for size in ([8]int{1,1024,65534,65535,65536,131070,131071,c.MAX_BYTES}) {
   for &byte in work.zeros {byte=0xab} // Workspace is scratch, not an implicit dictionary.
   n,ok:=c.encode(input[:size],encoded[:],&work);if !ok {return 1,0}
   if !c.decode(encoded[:n],output[:size],scratch[:]) {return 2,0}
   for byte,i in input[:size] {if byte!=output[i] {return 3,0}}
   hash=sc.digest(encoded[:n],hash)
   for cut in ([3]int{0,n/2,n-1}) {
    for &byte in output[:size] {byte=0xcc}
    if c.decode(encoded[:cut],output[:size],scratch[:]) {return 4,0}
    for byte in output[:size] {if byte!=0xcc {return 5,0}}
   }
   if c.decode(encoded[:n+1],output[:size],scratch[:]) {return 6,0}
  }
 }
 return
}

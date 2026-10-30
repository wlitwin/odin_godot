package compress_test
import "core:testing"
import "core:mem"
import r "godot:replay"
import c "godot:replay/compress"
@(test)
block_compression_preserves_large_archives_and_atomic_malformed_failure :: proc(t:^testing.T) {
 input:=make([]u8,c.MAX_BYTES);defer delete(input)
 encoded:=make([]u8,c.MAX_BYTES+128);defer delete(encoded)
 output:=make([]u8,c.MAX_BYTES);defer delete(output)
 scratch:=make([]u8,c.MAX_BYTES);defer delete(scratch)
 work:=new(c.Workspace);defer free(work);rng:=r.rng_make(991)
 for mode in 0..<3 {
  for &byte,i in input {byte=mode==0 ? 0 : mode==1 ? u8(i%251) : u8(r.rng_next(&rng))}
  for size in ([6]int{1,1024,65534,65535,65536,c.MAX_BYTES}) {
   n,ok:=c.encode(input[:size],encoded,work);testing.expect(t,ok)
   testing.expect(t,c.decode(encoded[:n],output[:size],scratch) && mem.compare(input[:size],output[:size])==0)
   for cut in ([3]int{0,n/2,n-1}) {
    for &byte in output {byte=0xcc}
    testing.expect(t,!c.decode(encoded[:cut],output[:size],scratch))
    for byte in output {if byte!=0xcc {testing.expect(t,false);break}}
   }
   if mode==0 && size>65535 {testing.expect(t,n<size/100)}
  }
 }
}

@(test)
compression_rejects_aliases_and_invalid_block_lengths :: proc(t:^testing.T) {
 work:=new(c.Workspace);defer free(work)
 input:[1024]u8;encoded:[1100]u8;output:[1024]u8;scratch:[1024]u8
 n,ok:=c.encode(input[:],encoded[:],work);testing.expect(t,ok)
 _,ok=c.encode(input[:],input[:],work);testing.expect(t,!ok)
 workspace:=mem.slice_ptr(cast(^u8)work,size_of(c.Workspace))
 _,ok=c.encode(workspace[:1024],encoded[:],work);testing.expect(t,!ok)
 _,ok=c.encode(input[:],workspace,work);testing.expect(t,!ok)
 testing.expect(t,!c.decode(encoded[:n],output[:],output[:]))
 testing.expect(t,!c.decode(encoded[:n],encoded[:1024],scratch[:]))
 for mode in 0..<3 {
  encoded[4],encoded[5]=0,4 // encoded length equals decoded block, not canonical.
  if mode==1 {encoded[4],encoded[5]=255,255}
  if mode==2 {encoded[3]=2}
  for &byte in output {byte=0xcc}
  testing.expect(t,!c.decode(encoded[:n],output[:],scratch[:]))
  for byte in output {testing.expect_value(t,byte,u8(0xcc))}
 }
}

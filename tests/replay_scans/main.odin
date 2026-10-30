package main

import "core:fmt"
import "core:time"
import sc "godot:replay/schema"
import d "godot:replay/delta"
import r "godot:replay"
import game "godot:examples/replay_scrapyard/shared/game"
import corpus "shared"

hash_bench :: proc(label:string,bytes:[]u8,reference:bool,trial:int) {
 h:=u64(0xcbf29ce484222325);started:=time.tick_now()
 for _ in 0..<1000 {h=reference ? corpus.reference_digest(bytes,h) : sc.digest(bytes,h)}
 fmt.printf("SCAN_HASH case=%s reference=%v trial=%d ns=%d result=%d\n",label,reference,trial,i64(time.tick_since(started))/1000,h)
}
delta_bench :: proc(label:string,base,target,out:[]u8,reference:bool,trial:int) {
 saved:=target[0];defer target[0]=saved
 total,last:=0,0;algorithm:=reference ? corpus.reference_encode : d.encode;started:=time.tick_now()
 for i in 0..<1000 {
  target[0]=base[0]~u8(i) // vary a counter byte so repeated writes cannot be hoisted
  n,ok:=algorithm(base,target,out);assert(ok);total+=n;last=n
 }
 fmt.printf("SCAN_DELTA case=%s reference=%v trial=%d ns=%d total=%d hash=%d\n",label,reference,trial,i64(time.tick_since(started))/1000,total,sc.digest(out[:last]))
}
bench_base,bench_target:[65535]u8
bench_out:[327680]u8
main :: proc() {
 code,fingerprint:=corpus.verify();assert(code==0);fmt.printf("SCAN_CORPUS_OK hash=%d\n",fingerprint)
 codec:sc.Schema;assert(sc.init(&codec,game.World).error==.None);defer sc.destroy(&codec)
 canonical:=make([]u8,codec.wire_size);defer delete(canonical)
 assert(sc.encode(&codec,game.initial(),canonical).error==.None)
 base,target,out:=bench_base[:],bench_target[:],bench_out[:];rng:=r.rng_make(33)
 for mode in 0..<6 {
  size:=len(base);label:="zero"
  for &byte in base {byte=0}
  if mode==1 {label="canonical_world";size=len(canonical);copy(base[:],canonical)}
  if mode>=2 {label=mode==2 ? "equal_random" : mode==3 ? "dense_random" : mode==4 ? "alternating_changes" : "periodic_changes";for &byte in base {byte=u8(r.rng_next(&rng))}}
  copy(target,base)
  if mode==1 {for i:=0;i<size;i+=257 {target[i]~=1}}
  if mode==3 {for &byte in target {byte~=u8(r.rng_next(&rng)%255+1)}}
  if mode>=4 {stride:=mode==4 ? 2 : 8;for i:=0;i<size;i+=stride {target[i]~=1}}
  for trial in 0..<7 {
   for pass in 0..<2 {
    reference:=(trial+pass)%2==0
    hash_bench(label,base[:size],reference,trial)
    delta_bench(label,base[:size],target[:size],out[:],reference,trial)
   }
  }
 }
}

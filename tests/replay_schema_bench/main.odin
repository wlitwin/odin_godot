package main
import "core:fmt"
import "core:time"
import sc "godot:replay/schema"
import r "godot:replay"
import game "godot:examples/replay_scrapyard/shared/game"
Snapshot :: struct {snapshot_id,generation,serial,action_settled,input_newest:u64,frame:r.Frame(game.World),held:[game.SEATS]game.Control}
main :: proc() {
	codec:sc.Schema;options:=sc.DEFAULT_OPTIONS;options.projection=.Public;assert(sc.init(&codec,Snapshot,options).error==.None);defer sc.destroy(&codec)
	counts:[sc.Kind]int;for field in codec.fields {counts[field.kind]+=1}
	fmt.printf("SCHEMA_META bytes=%d fields=%d checks=%d spans=%d kinds=%v\n",codec.wire_size,len(codec.fields),len(codec.checks),len(codec.spans),counts)
	value:=Snapshot{snapshot_id=1,generation=1,serial=1,frame={state=game.initial()}}
	bytes:=make([]u8,codec.wire_size);defer delete(bytes)
	for _ in 0..<100 {assert(sc.encode(&codec,value,bytes).error==.None)}
	for trial in 0..<7 {
		started:=time.tick_now()
		for i in 0..<1000 {value.frame.tick=u64(i);assert(sc.encode(&codec,value,bytes).error==.None)}
		encode:=time.tick_since(started)
		decoded:Snapshot;started=time.tick_now()
		for i in 0..<1000 {bytes[0]=u8(i);assert(sc.decode(&codec,&decoded,bytes).error==.None)}
		decode:=time.tick_since(started)
		assert(decoded.frame.tick==999 && decoded.snapshot_id==231);bytes[0]=1
		fmt.printf("SCHEMA_TIMING trial=%d encode_ns_per_call=%d decode_ns_per_call=%d hash=%d\n",trial,i64(encode)/1000,i64(decode)/1000,sc.digest(bytes))
	}
	validation_cases()
}

Small :: enum u8 {Zero, One, Two}
Validation_Value :: struct {counter:u64,floats:[2048]f32,flags:[2048]bool,enums:[2048]Small}
validation_cases :: proc() {
 codec:sc.Schema;assert(sc.init(&codec,Validation_Value).error==.None);defer sc.destroy(&codec)
 bytes:=make([]u8,codec.wire_size);defer delete(bytes)
 for mode in 0..<4 {
  label:=mode==0 ? "zero" : mode==1 ? "dense" : mode==2 ? "sparse" : "alternating"
  value:Validation_Value
  for &f,i in value.floats {
   active:=mode==1 || mode==2 && i%257==0 || mode==3 && i%2==0
   f=active ? f32(i+1) : 0;value.flags[i]=active;value.enums[i]=active ? .Two : .Zero
  }
  fmt.printf("SCHEMA_CASE_META case=%s bytes=%d fields=%d checks=%d spans=%d\n",label,codec.wire_size,len(codec.fields),len(codec.checks),len(codec.spans))
  for trial in 0..<7 {
   started:=time.tick_now()
   for i in 0..<1000 {value.counter=u64(i);assert(sc.encode(&codec,value,bytes).error==.None)}
   encode:=time.tick_since(started)
   decoded:Validation_Value;started=time.tick_now()
   for i in 0..<1000 {bytes[0]=u8(i);assert(sc.decode(&codec,&decoded,bytes).error==.None)}
   decode:=time.tick_since(started)
   assert(decoded.counter==999);bytes[0]=231
   fmt.printf("SCHEMA_CASE_TIMING case=%s trial=%d encode_ns_per_call=%d decode_ns_per_call=%d hash=%d\n",label,trial,i64(encode)/1000,i64(decode)/1000,sc.digest(bytes))
  }
 }
}

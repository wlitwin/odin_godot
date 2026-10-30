package wasm_codec_bench
import "base:runtime"
import "core:mem"
import sc "godot:replay/schema"
import r "godot:replay"
import game "godot:examples/replay_scrapyard/shared/game"
Snapshot :: struct {snapshot_id,generation,serial,action_settled,input_newest:u64,frame:r.Frame(game.World),held:[game.SEATS]game.Control}
backing:[64*1024*1024]u8
last_hash:u64
last_bytes:u32
@(export)
run :: proc "c" ()->u32 {
	context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
	codec:sc.Schema;options:=sc.DEFAULT_OPTIONS;options.projection=.Public
	if sc.init(&codec,Snapshot,options).error!=.None {return 1}
	value:=Snapshot{snapshot_id=1,generation=1,serial=1,frame={tick=999,state=game.initial()}}
	bytes:=make([]u8,codec.wire_size)
	if sc.encode(&codec,value,bytes).error!=.None {return 2}
	last_hash=sc.digest(bytes);last_bytes=u32(len(bytes))
	decoded:Snapshot;if sc.decode(&codec,&decoded,bytes).error!=.None || decoded.frame.tick!=999 {return 3}
	// A late invalid float must reject without replacing the decoded frame.
	for i:=len(codec.fields)-1;i>=0;i-=1 {
		field:=codec.fields[i]
		if field.kind!=.Float || field.width!=4 {continue}
		bytes[field.wire_offset+0],bytes[field.wire_offset+1],bytes[field.wire_offset+2],bytes[field.wire_offset+3]=0,0,0x80,0x7f
		if sc.decode(&codec,&decoded,bytes).error!=.Invalid_Value || decoded.frame.tick!=999 {return 4}
		return 0
	}
	return 5
}
@(export)
hash :: proc "c" ()->u64 {return last_hash}
@(export)
size :: proc "c" ()->u32 {return last_bytes}

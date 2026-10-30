package cave_impact_wasm
import r "godot:replay"
import "base:runtime"
import "core:mem"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import base "godot:examples/replay_cavecrawl/shared/cave"
import owner "godot:examples/replay_cavecrawl/shared/owner_cave"
import upgrade "godot:examples/replay_cavecrawl/shared/upgrade"
import owned_upgrade "godot:examples/replay_cavecrawl/shared/owner_upgrade"

verify :: proc(bytes:[]u8,model:net.Model($W,$C,$A,base.Event,base.SEATS),content:u64) {
 model:=model
 archive:d.Recording(W,net.Batch(C,A,base.SEATS),net.Net_Event(base.Event));defer d.recording_destroy(&archive)
 identity:=d.Recording_Context{content,1,base.HZ}
 assert(d.recording_decode(&archive,bytes,identity)==.None)
 audit:r.Audit_Capture(W,net.Batch(C,A,base.SEATS),net.Net_Event(base.Event));defer r.audit_capture_destroy(&audit)
 assert(d.recording_verify(&archive,identity,net.recording_model(&model),&audit).error==.None)
}
@(require)
instantiate :: proc() {
 bytes,error:=upgrade.convert_archive(transmute([]u8)#load("../fixtures/c8.checkpoint"));assert(error==.None)
 resume(bytes,base.model(),base.CONTENT);delete(bytes)
 bytes,error=owned_upgrade.convert_archive(transmute([]u8)#load("../fixtures/o2.checkpoint"));assert(error==.None)
 resume(bytes,owner.model(),owner.CONTENT);delete(bytes)
 verify(transmute([]u8)#load("../fixtures/c8.rplrec"),upgrade.model8(),upgrade.CONTENT_8)
 verify(transmute([]u8)#load("../fixtures/o2.rplrec"),owned_upgrade.model_2(),owned_upgrade.CONTENT_2)
}
resume :: proc(bytes:[]u8,model:net.Model($W,$C,$A,base.Event,base.SEATS),content:u64) {
 cp:net.Checkpoint(W,C,A,base.SEATS);defer net.checkpoint_destroy(&cp)
 assert(net.checkpoint_decode(&cp,bytes,model,content)==.None)
 server:net.Server(W,C,A,base.Event,base.SEATS);defer net.server_destroy(&server)
 assert(net.server_restore(&server,&cp,model,{}, {epoch=2,local_seat=1,retain_membership=true,preserve_pending=true})==.None)
 assert(net.server_step(&server)==.None)
 frame,_:=r.current(&server.timeline);assert(frame.state.dwellers.values[0].hp==35)
 events:[net.WIRE_EVENTS]r.Occurrence(net.Net_Event(base.Event))
 count,error:=r.copy_events(&server.timeline,frame.tick,events[:]);assert(error==.None)
 hits:=0
 for e in events[:count] {if e.value.kind==.Gameplay && e.value.value.kind==.Hit && e.value.value.seat==0 {hits+=1;assert(e.id.key==u64(1)<<32|1)}}
 assert(hits==1)
}

backing:[96*1024*1024]u8
@(export)
run :: proc "c" ()->u32 {
 context=runtime.default_context()
 arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
 instantiate();return 1
}

//gd:extends Node
//gd:class CompleteOwnerProbe
package owner_probe

import "core:fmt"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ar "godot:box3d/authoring/runtime"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import gd "godot:godot"
import k "godot:kit/sim"
import kp "godot:kit/physics"
import kg "godot:kit/godot/physics"
import r "godot:replay"
import rn "godot:replay/net"
import rp "godot:replay/physics"
import rg "godot:replay/godot"
import rpg "godot:replay/godot/physics"

Game :: struct { tick: u64, body: b.Body_Key }
Control :: struct { pressed: bool }
Action :: struct { unused: bool }
Event :: struct { value: u32 }
Proxy :: struct { value: u64 }
User :: struct { control: rawptr, attempted: bool, result: k.World_Error }
Kit :: kg.Authored_World(Game,Control,Proxy,User)
Kit_Data :: kg.Authored_Data(Game,Control,Proxy,User)
Replay :: rpg.Authored_Session(Game,Control,Action,Event,2)
CompleteOwnerProbe :: struct {
    owner: gd.Node,
    kit: Kit,
    replay_a,replay_b: Replay,
    kit_saved: k.World_Checkpoint,
    replay_saved: r.Complete_Checkpoint(Game,rn.Net_Event(Event)),
}
initial :: proc(scene:^a.Baked_Scene,built:^ar.Built_Scene)->(Game,bool) {
    for body,i in scene.data.bodies { if body.stable_key=="player" { return {body=built.bodies[i].key},true } }
    return {},false
}
invalid_initial :: proc(_: ^a.Baked_Scene,_: ^ar.Built_Scene)->(Game,bool) { return {},false }
model :: proc()->rn.Model(Game,Control,Action,Event,2) {
    return {step=proc(game:^Game,_:[2]Control,_,_:u64,ctx:^r.Step(Event)){if rp.step(ctx.execution)!=.None {r.abort(ctx);return};game.tick=ctx.tick},
        action=proc(_: ^Game,_:u16,_:Action,_:^r.Step(Event))->bool{return false},
        control_valid=proc(_:Control)->bool{return true},action_valid=proc(_:Action)->bool{return false},
        state_valid=proc(game:Game)->bool{return game.body!=0},hold=proc(_:Control)->Control{return {}}}
}

@(gd_method)
complete_owner_probe_zero :: proc(self:^CompleteOwnerProbe)->bool {
    engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
    if es!=.Ok || ws!=.Ok || engine.live_bytes!=0 || wrapper.live_bytes!=0 {fmt.println("OWNER_NATIVE",engine.live_bytes,wrapper.live_bytes);return false}
    for category in u32(1)..=6 { stats,status:=meter.category_stats(category);if status!=bg.OK || stats.live_bytes!=0 || stats.contexts!=0 {fmt.println("OWNER_METER",category,stats);return false} }
    return true
}

@(gd_method = "owned_return")
complete_owner_probe_open_replay :: proc(self:^CompleteOwnerProbe,source:gd.Object)->gd.String {
    options:=rpg.authored_options(.Host);options.port=45931;options.network.epoch=7
    report:=rpg.authored_open(&self.replay_a,source,model(),initial,bd.hash_bytes(transmute([]u8)string("owner-test")),options)
    return gd.new_string_odin(fmt.tprintf("%v",report.error))
}

@(gd_method)
complete_owner_probe_replay_cases :: proc(self:^CompleteOwnerProbe,source:gd.Object)->bool {
    rules:=bd.hash_bytes(transmute([]u8)string("owner-test"))
    options:=rpg.authored_options(.Solo)
    report:=rpg.authored_open(&self.replay_a,source,model(),initial,rules,options)
    if report.error!=.None {fmt.println(rn.setup_describe(&report));return false}
    solo:=rpg.authored_session(&self.replay_a)
    if solo==nil || solo.connection!=nil || rg.session_frame(solo,1.0/60.0,Control{})!=.None {return false}
    if rpg.authored_close(&self.replay_a)!=.None || !complete_owner_probe_zero(self) {return false}
    options=rpg.authored_options(.Host);options.port=45931;options.network.epoch=7
    room_options:=rg.Room_Options{session=options,identity={1,1},room=1,coordinator="127.0.0.1",control_port=45939}
    room_options.key[0]=1
    report=rpg.authored_room_open(&self.replay_a,source,model(),initial,rules,room_options)
    if report.error!=.None {fmt.println("OWNER_ROOM_OPEN",rn.setup_describe(&report));return false}
    if !rpg.authored_data(&self.replay_a).room.ready || rpg.authored_close(&self.replay_a)!=.None || !complete_owner_probe_zero(self) {return false}
    report=rpg.authored_open(&self.replay_a,source,model(),invalid_initial,rules,options)
    if report.error!=.Invalid_Model || report.cleanup_error!=.None || self.replay_a.storage.memory!=nil {return false}
    if !complete_owner_probe_zero(self) {return false}
    report=rpg.authored_open(&self.replay_a,source,model(),initial,rules,options)
    if report.error!=.None {fmt.println(rn.setup_describe(&report));return false}
    options.port=45932
    report=rpg.authored_open(&self.replay_b,source,model(),initial,rules,options)
    if report.error!=.None || rpg.authored_session(&self.replay_a)==nil {return false}
    if rpg.authored_close(&self.replay_b)!=.None || rpg.authored_session(&self.replay_a)==nil {return false}
    checkpoint,ce:=rpg.authored_checkpoint(&self.replay_a,0)
    if ce!=.None || checkpoint.epoch!=7 {return false}
    var_error:r.Error
    self.replay_saved,var_error=r.complete_checkpoint_clone(checkpoint,rpg.authored_allocator(&self.replay_a))
    if var_error!=.None {return false}
    if rpg.authored_close(&self.replay_a)!=.None || rpg.authored_close(&self.replay_a)!=.None {return false}
    states:[8]b.Body_State
    count,be:=rp.body_states(&self.replay_saved,states[:])
    if be!=.None || count!=4 {return false}
    options.port=45932
    report=rpg.authored_open(&self.replay_b,source,model(),initial,rules,options)
    if report.error!=.None {fmt.println(rn.setup_describe(&report));return false}
    if r.complete_checkpoint_destroy(&self.replay_saved)!=.None {return false}
    checkpoint,ce=rpg.authored_checkpoint(&self.replay_b,0)
    if ce!=.None {return false}
    count,be=rp.body_states(checkpoint,states[:])
    if be!=.None || count!=4 {return false}
    if rpg.authored_close(&self.replay_b)!=.None {return false}
    return complete_owner_probe_zero(self)
}

kit_sample :: proc(_:rawptr,_:u64,out:rawptr){ (cast(^Control)out)^={} }
kit_step :: proc(user:rawptr,tick:u64) {
    data:=cast(^Kit_Data)user
    if !data.attempted {
        data.attempted=true
        data.result=kg.authored_close(cast(^Kit)data.control)
    }
    if side:=kp.state(&data.physics);side!=nil {side.tick=tick}
}

@(gd_method)
complete_owner_probe_kit_cases :: proc(self:^CompleteOwnerProbe,source:gd.Object)->bool {
    report:=kg.authored_open(&self.kit,source)
    if report.error!=.Ok {fmt.println(kg.describe(&report));return false}
    data:=kg.authored_data(&self.kit)
    data.control=&self.kit
    data.ses.is_host=true;data.ses.me=1
    if kg.authored_lane_init(data)!=.Ok {return false}
    k.lane_set_sim(&data.lane,data,kit_sample,kit_step)
    k.lane_class_set_type(&data.lane,0,Control)
    state,valid:=initial(&data.baked,&data.built)
    if !valid || kg.authored_attach(data,state,nil)!=.Ok {return false}
    checkpoint,ce:=kg.authored_checkpoint(&self.kit,0)
    if ce!=.Ok {return false}
    self.kit_saved,ce=k.world_checkpoint_clone(checkpoint)
    if ce!=.Ok {return false}
    _=k.lane_frame(&data.lane,1.0/f64(b.FIXED_HZ))
    if !data.attempted || data.result!=.Busy || self.kit.storage.data==nil {return false}
    if kg.authored_close(&self.kit)!=.Ok || kg.authored_close(&self.kit)!=.Ok {return false}
    states:[8]b.Body_State
    count,be:=kp.checkpoint_body_states(&self.kit_saved,states[:],Game)
    if be!=.Ok || count!=4 {return false}
    if k.world_checkpoint_destroy(&self.kit_saved)!=.Ok {return false}
    return complete_owner_probe_zero(self)
}

complete_owner_probe_finalize :: proc(self:^CompleteOwnerProbe) {
    _=k.world_checkpoint_destroy(&self.kit_saved)
    _=r.complete_checkpoint_destroy(&self.replay_saved)
    if kg.authored_close(&self.kit)!=.Ok && !self.kit.opening {gd.error("OWNER_KIT_CLOSE_RETAINED")}
    if rpg.authored_close(&self.replay_a)!=.None && !self.replay_a.opening {gd.error("OWNER_REPLAY_CLOSE_RETAINED")}
    if rpg.authored_close(&self.replay_b)!=.None && !self.replay_b.opening {gd.error("OWNER_REPLAY_B_CLOSE_RETAINED")}
}

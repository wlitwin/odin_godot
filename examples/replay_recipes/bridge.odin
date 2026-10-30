package replay_recipes

import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import view "godot:replay/view"
import rgd "godot:replay/godot"
import defs "godot:replay/definitions"
import hello "godot:examples/replay_hello/shared/hello"

// These additional recipes instantiate public convenience paths not exercised
// by the no-network scene fixture. Owners remain stable fields in a real script.
submit_room_button :: proc(room:^Hello_Room,button:^rgd.Signal_Action(hello.Action))->(u64,net.Error) {
    return rgd.room_bound_action(room,button)
}
observe_room_button :: proc(room:^Hello_Room,button:^rgd.Signal_Action(hello.Action),change:view.Change(net.Net_Event(hello.Event)))->bool {
    return rgd.bound_action_observe(button,&room.session,change)
}
Marker_Definition :: struct {spawn:[2]f32}
bake_marker_scene :: proc(scene:gd.Packed_Scene)->(value:Marker_Definition,ref:defs.Ref,report:defs.Report) {
    store:defs.Store(Marker_Definition)
    report=defs.init(&store,1);defer defs.destroy(&store)
    if report.error!=.None {return}
    ref,report=rgd.bake(&store,scene,1,proc(source:gd.Packed_Scene,ctx:^rgd.Bake_Context)->Marker_Definition {
        root:=rgd.bake_scene2(ctx,source,"$.scene")
        point,_:=rgd.bake_marker2(ctx,root,"Spawn")
        return {point}
    })
    if report.error!=.None {return}
    value,_=defs.get(&store,ref)
    // Embedded return value now owns its content; the temporary store can close.
    return
}
read_actor_display :: proc(timeline:^hello.Timeline)->(hello.Actor_Views,r.Error) {
    return r.project(timeline,timeline.head,hello.project_actor_views)
}

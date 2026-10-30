package replay_recipes

import gd "godot:godot"
import replay "godot:replay"
import net "godot:replay/net"
import view "godot:replay/view"
import replaygd "godot:replay/godot"
import defs "godot:replay/definitions"
import hello "godot:examples/replay_hello/shared/hello"

// These additional recipes instantiate public convenience paths not exercised
// by the no-network scene fixture. Owners remain stable fields in a real script.
submit_room_button :: proc(room: ^Hello_Room, button: ^replaygd.Signal_Action(hello.Action)) -> (u64, net.Error) {
	return replaygd.room_bound_action(room, button)
}

observe_room_button :: proc(room: ^Hello_Room, button: ^replaygd.Signal_Action(hello.Action), change: view.Change(net.Net_Event(hello.Event))) -> bool {
	return replaygd.bound_action_observe(button, &room.session, change)
}

Marker_Definition :: struct {
	spawn: [2]f32,
}

bake_marker_scene :: proc(scene: gd.Packed_Scene) -> (value: Marker_Definition, report: defs.Report) {
	store: defs.Store(Marker_Definition)
	report = defs.init(&store, 1)
	defer defs.destroy(&store)
	if report.error != .None {
		return
	}

	ref: defs.Ref
	ref, report = replaygd.bake(&store, scene, 1, proc(source: gd.Packed_Scene, ctx: ^replaygd.Bake_Context) -> Marker_Definition {
		root := replaygd.bake_scene2(ctx, source, "$.scene")
		point, _ := replaygd.bake_marker2(ctx, root, "Spawn")
		return {spawn = point}
	})
	if report.error != .None {
		return
	}

	found: bool
	value, found = defs.get(&store, ref)
	assert(found)
	// Return the copied value; the store-scoped reference expires at destroy.
	return value, report
}

read_actor_display :: proc(timeline: ^hello.Timeline) -> (hello.Actor_Views, replay.Error) {
	return replay.project(timeline, timeline.head, hello.project_actor_views)
}

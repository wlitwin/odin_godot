package nodes_probe
import gd "godot:godot"
import v "godot:replay/view"
import scenegd "godot:replay/godot/scene"

when !LEGACY {
    Routed_Event :: struct {
        x:     f32,
        value: i32,
    }

    effects_check :: proc(self: ^ReplayNodesProbe) {
        effect: scenegd.Effect_Route2(Routed_Event, i32, gd.Node2d)
        binding := scenegd.Effect_Binding(Routed_Event, i32, gd.Node2d) {
            project = proc(event: Routed_Event) -> (v.Entity_View(i32), bool) {
                return {pose = {position = {event.x, 0}}, scale = {1, 1}, color = {1, 1, 1, 1}, value = event.value},
                    true
            },
            view = {attach = proc(_: rawptr, node: gd.Node2d) -> (gd.Node2d, bool) {
                    return node, true
                }, paint = proc(_: rawptr, node: ^gd.Node2d, state: scenegd.Effect_State(i32)) {}},
        }
        assert(
            scenegd.effect_route_load(
                &effect,
                self.owner,
                "res://view.tscn",
                1,
                .5,
                binding,
                capacity = 1,
                history = 8,
            ),
        )
        defer scenegd.effect_route_destroy(&effect)
        change := v.Change(Routed_Event) {
            kind = .Begin,
            occurrence = {id = {1, 1, 1, 1}, value = {x = 10, value = 7}},
        }
        assert(scenegd.effect_route_change(&effect, change))
        assert(scenegd.effect_route_frame(&effect, 0) == .None)
        first := effect.views.entries[0].node
        assert(gd.node2d_get_position(first).x == 10)
        assert(scenegd.effect_route_frame(&effect, .1) == .None)
        change.kind = .Update
        change.occurrence.value.x = 20
        scenegd.effect_route_change(&effect, change)
        change.kind = .Confirm
        scenegd.effect_route_change(&effect, change)
        assert(scenegd.effect_route_frame(&effect, 0) == .None)
        assert(
            effect.views.entries[0].node == first &&
            effect.route.cues.slots[0].age == .1 &&
            effect.route.cues.slots[0].confirmed,
        )
        assert(gd.node2d_get_position(first).x == 20)
        change.kind = .Cancel
        scenegd.effect_route_change(&effect, change)
        assert(scenegd.effect_route_frame(&effect, 0) == .None && effect.views.nodes.count == 0)
        change.kind = .Begin
        assert(!scenegd.effect_route_change(&effect, change))
        change.occurrence.id.tick = 2
        assert(scenegd.effect_route_change(&effect, change))
        assert(scenegd.effect_route_frame(&effect, 0) == .None)
        assert(effect.views.entries[0].node != first && effect.generations[0] == 2)
        assert(scenegd.effect_route_frame(&effect, 1) == .None && effect.views.nodes.count == 0)
        assert(scenegd.effect_route_epoch(&effect, 2, 2))
        assert(!scenegd.effect_route_change(&effect, change))

        stream := cast(gd.Audio_Stream)gd.load("res://tone.wav")
        assert(stream != nil)
        defer gd.release_ref(stream)
        audio: scenegd.Audio_Route(Routed_Event)
        assert(
            scenegd.audio_route_init(
                &audio,
                self.owner,
                1,
                proc(raw: rawptr, event: Routed_Event) -> (scenegd.Audio_Cue, bool) {
                    return {stream = (cast(^gd.Audio_Stream)raw)^, position = {event.x, 0}, pitch = 1, spatial = true},
                        true
                },
                &stream,
                .Confirmed,
                world_voices = 1,
                screen_voices = 1,
                history = 8,
            ),
        )
        defer scenegd.audio_route_destroy(&audio)
        change.occurrence.id = {1, 1, 1, 1}
        change.kind = .Begin
        assert(!scenegd.audio_route_change(&audio, change))
        change.kind = .Confirm
        assert(scenegd.audio_route_change(&audio, change))
        assert(!scenegd.audio_route_change(&audio, change) && audio.pool.played == 1)
        change.kind = .Update
        change.confirmed = true
        change.occurrence.value.x = 30
        scenegd.audio_route_change(&audio, change)
        assert(gd.node2d_get_position(audio.pool.world[0].world).x == 30 && audio.pool.played == 1)
        old := change
        change.kind = .Begin
        change.occurrence.id.key = 2
        assert(scenegd.audio_route_change(&audio, change))
        old.kind = .Cancel
        scenegd.audio_route_change(&audio, old)
        assert(audio.pool.world[0].tagged && audio.pool.stopped == 0)
        change.kind = .Cancel
        scenegd.audio_route_change(&audio, change)
        assert(!audio.pool.world[0].tagged && audio.pool.stopped == 1)
        change.kind = .Confirm
        assert(!scenegd.audio_route_change(&audio, change))
        assert(scenegd.audio_route_epoch(&audio, 2, 2))
        assert(!scenegd.audio_route_change(&audio, change))
        contextual: scenegd.Audio_Route(Routed_Event)
        assert(
            scenegd.audio_route_init_change(
                &contextual,
                self.owner,
                1,
                proc(raw: rawptr, event: v.Change(Routed_Event)) -> (scenegd.Audio_Cue, bool) {
                    assert(event.occurrence.id.tick == 77 && event.occurrence.id.key == 19 && event.kind == .Begin)
                    return {
                            stream = (cast(^gd.Audio_Stream)raw)^,
                            position = {f32(event.occurrence.id.tick), event.occurrence.value.x},
                            pitch = 1,
                            spatial = true,
                        },
                        true
                },
                &stream,
                world_voices = 1,
                screen_voices = 1,
                history = 8,
            ),
        )
        defer scenegd.audio_route_destroy(&contextual)
        change.kind = .Begin
        change.occurrence.id = {1, 77, 1, 19}
        assert(scenegd.audio_route_change(&contextual, change))
        assert(gd.node2d_get_position(contextual.pool.world[0].world).x == 77)
        change.kind = .Cancel
        scenegd.audio_route_change(&contextual, change)
        assert(contextual.pool.stopped == 1)
        gd.print_str(
            "REPLAY_EFFECT_ROUTES_OK update_confirm_no_restart=true cancel=true lifetime_reuse=true audio_epoch=true",
        )
    }
}

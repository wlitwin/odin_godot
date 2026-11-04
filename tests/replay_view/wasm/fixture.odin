package replay_view_wasm

import r "godot:replay"
import v "godot:replay/view"
import engine "godot:godot"
import game "../../../examples/replay_hello/shared/hello"
import scenegd "godot:replay/godot/scene"

@(require) instantiate :: proc() {
    projection: v.Projection(game.Actor, u8)
    v.projection_init(&projection, game.CAPACITY)
    world := game.initial()
    v.project_pool(
        &projection,
        world.actors,
        {1, 0},
        0,
        .Predicted,
        proc(actor: game.Actor) -> (v.Entity_View(u8), bool) {
            return {
                    pose = {position = actor.body.position},
                    scale = {1, 1},
                    color = {1, 1, 1, 1},
                    value = actor.owner,
                },
                true
        },
    )
    typed: scenegd.View_Pool2(game.Actor, u8, u32)
    scenegd.view_pool_load(&typed, nil, "", game.CAPACITY, scenegd.View_Binding(u8, u32) {
        attach = proc(_: rawptr, node: engine.Node2d) -> (u32, bool) {
            return 0, true
        },
        paint = proc(_: rawptr, rig: ^u32, value: u8) {},
    })
    scenegd.view_pool_present(&typed, projection.scope, v.projection_values(&projection))
    scenegd.view_pool_invalidate(&typed)
    scenegd.view_pool_destroy(&typed)
    v.projection_destroy(&projection)
    phase: v.Tick_Phase
    v.tick_phase(&phase, 1, 0, 1, .5, .025, 20)
    v.linear_preview2({1, 2}, {12, 0}, phase.fraction)
    cues: v.Cues([2]f32)
    v.cues_init(&cues, 1)
    v.cues_change(&cues, v.Change([2]f32){kind = .Begin, occurrence = {id = {1, 1, 1, 1}, value = {1, 2}}}, .4)
    v.cues_advance(&cues, .1)
    v.cues_epoch(&cues, 2, 1)
    v.cues_destroy(&cues)
    tl: game.Timeline
    r.init(&tl, r.Frame(game.World){state = game.initial()}, game.step)
    r.advance(&tl, game.Input{})
    r.confirm_through(&tl, 1)
    r.audit(&tl, 1)
    v.frames_at(&tl, 0, 0.5)
    r.destroy(&tl)
    j: v.Journal(game.Event)
    v.journal_init(&j)
    batch := [1]r.Occurrence(game.Event){{id = {epoch = 1, tick = 1}}}
    v.sync_tick(&j, 1, batch[:])
    v.advance_time(&j, 1, 1)
    out: [4]v.Change(game.Event)
    v.drain(&j, out[:])
    v.journal_rebase_check(&j, 2)
    v.journal_rebase(&j, 2)
    v.journal_destroy(&j)
    c: r.Clock
    r.clock_init(&c)
    r.clock_add(&c, 1.0 / 60)
    r.clock_consume(&c)
    s: v.Smoother2
    v.smooth_rebase(&s, {})
    v.smooth_present(&s, {}, 0.01)
    v.pose_blend({}, {}, 0.5)
    nodes: scenegd.Nodes2
    scenegd.nodes_load(&nodes, nil, "", 32)
    scenegd.nodes_present(&nodes, nil)
    scenegd.nodes_destroy(&nodes)
}

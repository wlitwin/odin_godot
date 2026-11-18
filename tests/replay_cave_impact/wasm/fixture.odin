package cave_impact_wasm
import r "godot:replay"
import "base:runtime"
import "core:mem"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import base "godot:examples/replay_cavecrawl/shared/cave"
import owner "godot:examples/replay_cavecrawl/shared/owner_cave"

verify :: proc(bytes: []u8, model: net.Model($W, $C, $A, base.Event, base.SEATS), content: u64) {
    model := model
    archive: d.Recording(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer d.recording_destroy(&archive)
    identity := d.Recording_Context{content, 1, base.HZ}
    assert(d.recording_decode(&archive, bytes, identity) == .None)
    audit: r.Audit_Capture(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer r.audit_capture_destroy(&audit)
    assert(d.recording_verify(&archive, identity, net.recording_model(&model), &audit).error == .None)
    r.audit_capture_destroy(&audit)
    changed := false
    for &event in archive.events {
        if event.value.kind == .Gameplay && event.value.value.kind == .Hit && event.value.value.seat == 0 {
            event.value.value.amount += 1
            changed = true
            break
        }
    }
    assert(changed)
    result := d.recording_verify(&archive, identity, net.recording_model(&model), &audit)
    assert(result.error == .Replay && result.replay.error == .Diverged_Event && result.replay.tick == 2)
}

@(require) instantiate :: proc() {
    resume(#load("../fixtures/current/server.checkpoint", []u8), base.model(), base.CONTENT)
    resume(#load("../fixtures/current/owner.checkpoint", []u8), owner.model(), owner.CONTENT)
    verify(#load("../fixtures/current/server.rplrec", []u8), base.model(), base.CONTENT)
    verify(#load("../fixtures/current/owner.rplrec", []u8), owner.model(), owner.CONTENT)
}

resume :: proc(bytes: []u8, model: net.Model($W, $C, $A, base.Event, base.SEATS), content: u64) {
    cp: net.Checkpoint(W, C, A, base.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, bytes, model, content) == .None)
    server: net.Server(W, C, A, base.Event, base.SEATS)
    defer net.server_destroy(&server)
    assert(
        net.server_restore(
            &server,
            &cp,
            model,
            {},
            {epoch = 2, local_seat = 1, retain_membership = true, preserve_pending = true},
        ) ==
        .None,
    )
    assert(net.server_step(&server) == .None)
    frame, _ := r.current(&server.timeline)
    assert(frame.state.dwellers.values[0].hp == 35)
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(base.Event))
    count, error := r.copy_events(&server.timeline, frame.tick, events[:])
    assert(error == .None)
    hits := 0

    for e in events[:count] {
        if e.value.kind == .Gameplay && e.value.value.kind == .Hit && e.value.value.seat == 0 {
            hits += 1
            assert(e.id.key == u64(1) << 32 | 1)
        }
    }

    assert(hits == 1)
}

backing: [96 * 1024 * 1024]u8

@(export)
run :: proc "c" () -> u32 {
    context = runtime.default_context()
    arena: mem.Arena
    mem.arena_init(&arena, backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = context.allocator
    instantiate()
    return 1
}

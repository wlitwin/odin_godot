package replay_net_test

import "core:testing"
import "core:reflect"
import net "godot:replay/net"
import sc "godot:replay/schema"

Expanded_World :: struct {
    original:   World,
    definition: u32,
}

expanded_model :: proc() -> net.Model(Expanded_World, Control, Action, Event, 2) {
    return {control_valid = control_valid, state_valid = proc(w: Expanded_World) -> bool {
            return w.definition == 7 && state_valid(w.original)
        }}
}

@(test)
world_schema_conversion_preserves_session_sections_and_rejects_invalid_mapping :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    bytes, encoded := net.checkpoint_encode(&cp, model())
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    before := sc.digest(bytes)

    mapper := proc(w: World) -> (Expanded_World, bool) {
        return {w, 7}, true
    }

    out, err := net.checkpoint_convert_state(bytes, model(), f.server.cfg.content, expanded_model(), 99, mapper)
    defer delete(out)
    testing.expect_value(t, err, net.Error.None)

    if err != .None {
        return
    }

    decoded: net.Checkpoint(Expanded_World, Control, Action, 2)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_decode(&decoded, out, expanded_model(), 99), net.Error.None)
    testing.expect(t, reflect.equal(decoded.frame.state.original, cp.frame.state))
    testing.expect_value(t, decoded.frame.state.definition, u32(7))
    testing.expect(
        t,
        reflect.equal(decoded.peers[:], cp.peers[:], true) && reflect.equal(decoded.inputs[:], cp.inputs[:], true),
    )
    testing.expect_value(t, decoded.header.epoch, cp.header.epoch)
    testing.expect_value(t, sc.digest(bytes), before)

    for bad in 0 ..< 2 {
        map_value := bad == 0 ? proc(w: World) -> (Expanded_World, bool) {
                return {}, false
            } : proc(w: World) -> (Expanded_World, bool) {
                return {w, 9}, true
            }
        invalid, result := net.checkpoint_convert_state(
            bytes,
            model(),
            f.server.cfg.content,
            expanded_model(),
            99,
            map_value,
        )
        defer delete(invalid)
        testing.expect(t, result != .None && len(invalid) == 0)
        testing.expect_value(t, sc.digest(bytes), before)
    }
}

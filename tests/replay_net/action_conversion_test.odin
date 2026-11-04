package replay_net_test

import "core:testing"
import "core:reflect"
import net "godot:replay/net"
import r "godot:replay"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

Action_V2 :: struct {
    amount: u16,
    slot:   u8,
}

action_v2_model :: proc() -> net.Model(World, Control, Action_V2, Event, 2) {
    return {
        step = model_step,
        control_valid = control_valid,
        state_valid = state_valid,
        hold = hold,
        action_valid = proc(a: Action_V2) -> bool {
            return a.amount == 1 && a.slot == 7
        },
        action = proc(w: ^World, seat: u16, a: Action_V2, ctx: ^r.Step(Event)) -> bool {
            return model_action(w, seat, Action{take = true}, ctx)
        },
    }
}

@(test)
action_schema_conversion_maps_pending_work_and_preserves_common_sections :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 40 {
        fixture_step(&f)
    }

    net.client_issue(&f.clients[0], Action{take = true})
    tr.memory_advance(&f.network, f.clock)
    net.server_pump(&f.server, f.clock * 1000 / 60)
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    testing.expect(t, len(cp.actions) > 0 && len(cp.inputs) > 0)
    bytes, _ := net.checkpoint_encode(&cp, model())
    defer delete(bytes)
    before := sc.digest(bytes)

    mapper := proc(a: Action) -> (Action_V2, bool) {
        return {1, 7}, a.take
    }

    out, err := net.checkpoint_convert_actions(bytes, model(), f.server.cfg.content, action_v2_model(), 77, mapper)
    defer delete(out)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, sc.digest(bytes), before)

    if err != .None {
        return
    }

    decoded: net.Checkpoint(World, Control, Action_V2, 2)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_decode(&decoded, out, action_v2_model(), 77), net.Error.None)
    testing.expect_value(t, decoded.header.content, u64(77))
    testing.expect_value(t, decoded.header.epoch, cp.header.epoch)
    testing.expect(
        t,
        reflect.equal(decoded.frame, cp.frame) &&
        reflect.equal(decoded.peers[:], cp.peers[:], true) &&
        reflect.equal(decoded.inputs[:], cp.inputs[:], true),
    )

    for saved, i in cp.actions {
        testing.expect_value(t, decoded.actions[i].tick, saved.tick)
        testing.expect_value(t, decoded.actions[i].sequence, saved.sequence)
        testing.expect_value(t, decoded.actions[i].value, Action_V2{1, 7})
    }

    invalid_model := action_v2_model()
    invalid_model.control_valid = nil
    invalid_bytes, invalid_error := net.checkpoint_convert_actions(
        bytes,
        model(),
        f.server.cfg.content,
        invalid_model,
        77,
        mapper,
    )
    defer delete(invalid_bytes)
    testing.expect_value(t, invalid_error, net.Error.Invalid_Model)
    testing.expect(t, len(invalid_bytes) == 0)

    for mode in 0 ..< 3 {
        candidate := make([]u8, len(bytes))
        copy(candidate, bytes)
        defer delete(candidate)

        if mode == 0 {
            candidate[len(candidate) - 1] ~= 1
        }

        map_value := mapper

        if mode == 1 {
            map_value = proc(_: Action) -> (Action_V2, bool) {
                return {}, false
            }
        }

        if mode == 2 {
            map_value = proc(_: Action) -> (Action_V2, bool) {
                return {99, 7}, true
            }
        }

        hash := sc.digest(candidate)
        bad, rejected := net.checkpoint_convert_actions(
            candidate,
            model(),
            f.server.cfg.content,
            action_v2_model(),
            77,
            map_value,
        )
        defer delete(bad)
        testing.expect(t, rejected != .None && len(bad) == 0)
        testing.expect_value(t, sc.digest(candidate), hash)
    }
}

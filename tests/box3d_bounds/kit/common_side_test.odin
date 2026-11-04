package kit_bounds_test

import "core:fmt"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import common "godot:examples/box3d_common"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"
import wp "godot:tests/kit_world_protocol"

// The production Kit model's Side value shape, including the REAL common.Game
// type whose retired[:retired_count] accesses require retired_count<=8. No
// proposed-control validator is an authority for this application Side invariant.
Common_Receipt :: struct {
    tick:    u64,
    kind:    common.Action_Kind,
    applied: bool,
}

Common_Side :: struct {
    game:     common.Game,
    players:  [2]u16,
    receipts: [2]Common_Receipt,
}

Common_Box :: struct {
    transport: f.Box, // unchanged actual Session send/pump implementation
    physics:   p.Instance(Common_Side),
    network:   p.Network(Common_Side),
    control:   p.Typed_Codec(common.Control),
    action:    p.Typed_Codec(common.Action),
    axis:      i16,
    effects:   u32,
}

common_control :: proc(user: rawptr, _: u64, out: rawptr) {
    box := cast(^Common_Box)user
    (cast(^common.Control)out)^ = {
        x = box.axis,
    }
}

common_action :: proc(_: rawptr, _: u64, out: rawptr) {
    (cast(^common.Action)out)^ = {}
}

common_control_valid :: proc(_: rawptr, value: rawptr) -> bool {
    return common.control_valid((cast(^common.Control)value)^)
}

common_side_valid :: proc(value: Common_Side) -> bool {
    return common.game_valid(value.game)
}

common_effect :: proc(user: rawptr, _: u64, _: u64, _: []u8) {
    (cast(^Common_Box)user).effects += 1
}

common_step :: proc(user: rawptr, tick: u64) {
    box := cast(^Common_Box)user
    side := p.state(&box.physics)
    side.game.tick = tick
    world, we := p.world(&box.physics)
    assert(we == .Ok)

    for player in ([]n.Player_Id{1, 2}) {
        control, _ := k.lane_input_of(&box.transport.lane, player, common.Control)

        if control.x != 0 {
            body, be := b.body_resolve(world, side.game.bodies[int(player) - 1])
            assert(be == .Ok)

            if !p.require(&box.physics, b.body_apply_impulse(body, {f32(control.x) * .001, 0, 0})) {
                return
            }
        }
    }

    if tick % 3 == 0 {
        assert(k.lane_world_emit(&box.transport.lane, 1, common_effect, box) == .Ok)
    }
}

common_attach :: proc(t: ^testing.T, box: ^Common_Box, catalog: ^b.Recovery_Catalog, retired_count: u32) -> bool {
    // Deliberately malicious authoritative INITIAL data is supplied through the
    // public trusted constructor, never by mutating a published image or decoding
    // a private recovery envelope. Both instances use the identical real world.
    world, game, be := common.world(4, 42)
    testing.expect_value(t, be, b.Status.Ok)

    if be != .Ok {
        return false
    }

    defer if world != 0 {
        b.world_destroy(&world)
    }

    game.retired_count = retired_count
    lane := &box.transport.lane
    k.lane_init(lane, &box.transport.ses, size_of(common.Control), cfg = {slots = 128, snap_every = 3})
    k.lane_set_sim(lane, box, common_control, common_step)
    k.lane_class_set_type(lane, 0, common.Control)
    k.lane_class_set_validate(lane, 0, common_control_valid)
    k.lane_add_input_class(lane, 1, size_of(common.Action), common_action)
    k.lane_class_set_type(lane, 1, common.Action)
    e := p.attach(
        &box.physics,
        lane,
        &world,
        Common_Side{game = game, players = {1, 2}},
        nil,
        {asset_id = common.ASSET_DECLARATION},
    )
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    e = p.codec_init(&box.control)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    e = p.codec_init(&box.action)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    inputs := []k.World_Wire_Input{{0, box.control.value, .Hold}, {1, box.action.value, .Neutral}}
    drivers := []k.World_Driver{{1, 0}, {1, 1}, {2, 0}, {2, 1}}
    effects := []k.World_Effect_Def{{1, common_effect, box, p.empty_codec()}}
    box.network.side_valid = common_side_valid
    e = p.network_attach(&box.network, &box.physics, catalog, nil, inputs, drivers, effects, common.game_rules())
    testing.expect_value(t, e, k.World_Error.Ok)
    return e == .Ok
}

common_detach :: proc(t: ^testing.T, box: ^Common_Box) -> bool {
    e := p.network_destroy(&box.network)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    e = p.detach(&box.physics)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    e = p.codec_destroy(&box.control)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    e = p.codec_destroy(&box.action)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    k.lane_destroy(&box.transport.lane)
    packets := wp.take_packets(&box.transport)
    wp.destroy_packets(&packets)
    return true
}

common_pump :: proc(host, client: ^Common_Box) {
    f.pump({&host.transport, &client.transport})
}

common_reset_response :: proc(t: ^testing.T, host, client: ^Common_Box) -> bool {
    e := k.lane_world_request_reset(&client.transport.lane)
    testing.expect_value(t, e, k.World_Error.Ok)

    if e != .Ok {
        return false
    }

    // The test controls delivery, not packet contents. Drop the real request so
    // that ONLY the following explicitly sent real Host responses are delivered.
    request := wp.take_packets(&client.transport)
    wp.destroy_packets(&request)

    // Re-created Host starts its public sequence at zero. Send twice normally:
    // first serial1 is obsolete, second serial2 is newer than initial Welcome1.
    // No Session identity, network sequence, head, ready or scope is assigned.
    for _ in 0 ..< 2 {
        e = k.lane_world_send_checkpoint(&host.transport.lane, client.transport.peer, .Reset)
        testing.expect_value(t, e, k.World_Error.Ok)

        if e != .Ok {
            return false
        }
    }

    packets := wp.take_packets(&host.transport)
    testing.expect(t, wp.count_kind(packets[:], k.SIM_WORLD_CHUNK) >= 2)
    wp.deliver_all(&client.transport, host.transport.peer, packets[:])
    wp.destroy_packets(&packets)
    _ = k.lane_frame(&client.transport.lane, 0)
    return true
}

@(test)
authoritative_common_retired_count9_requires_side_semantic_rejection :: proc(t: ^testing.T) {
    baseline := wp.usage(t)
    config := b.recovery_config_default()
    config.profile = common.PROFILE
    assets := common.assets()
    catalog, ce := b.recovery_catalog_create(config, assets[:])
    testing.expect_value(t, ce, b.Status.Ok)

    if ce != .Ok {
        return
    }

    host, client: Common_Box
    f.start_pair(&host.transport, &client.transport)

    defer {
        _ = common_detach(t, &client)
        _ = common_detach(t, &host)
        s.session_destroy(&client.transport.ses)
        s.session_destroy(&host.transport.ses)
        testing.expect_value(t, b.recovery_catalog_destroy(&catalog), b.Status.Ok)
        testing.expect_value(t, wp.usage(t), baseline)
    }

    if !common_attach(t, &host, &catalog, 0) || !common_attach(t, &client, &catalog, 0) {
        return
    }

    testing.expect_value(
        t,
        k.lane_world_send_checkpoint(&host.transport.lane, client.transport.peer, .Welcome),
        k.World_Error.Ok,
    )
    common_pump(&host, &client)
    _ = k.lane_frame(&client.transport.lane, 0)
    testing.expect(t, k.lane_world_network_status(&client.transport.lane).ready)
    before: k.World_Diagnostic_Frame

    if !saved_frame(t, &client.transport, 0, &before) {
        return
    }

    defer k.world_diagnostic_frame_destroy(&before)
    old_scope := k.lane_world_protocol_status(&client.transport.lane).bootstrap_sequence
    testing.expect_value(t, old_scope, u64(1))

    // Session/peer/player remain live and unchanged while only the PUBLIC Host
    // producer is rebuilt. This is an untrusted sender, not normal Game behavior.
    if !common_detach(t, &host) || !common_attach(t, &host, &catalog, 9) {
        return
    }

    malicious: k.World_Diagnostic_Frame

    if !saved_frame(t, &host.transport, 0, &malicious) {
        return
    }

    defer k.world_diagnostic_frame_destroy(&malicious)

    for part in bd.Part {
        if part != .Side {
            testing.expect_value(t, mem.compare(before.view.parts[part], malicious.view.parts[part]), 0)
        }
    }

    testing.expect_value(t, bd.compare(before.signature, malicious.signature), bd.Difference.Side)
    recomputed, sign_error := bd.sign(malicious.view)
    testing.expect_value(t, sign_error, bd.Error.None)
    testing.expect_value(t, bd.compare(recomputed, malicious.signature), bd.Difference.Match)
    source, source_ok := p.read(&host.physics)
    testing.expect(t, source_ok && source.game.retired_count == 9)
    old_status := k.lane_world_network_status(&client.transport.lane)

    if !common_reset_response(t, &host, &client) {
        return
    }

    actual, observed := p.read(&client.physics)
    after: k.World_Diagnostic_Frame

    if !saved_frame(t, &client.transport, 0, &after) {
        return
    }

    defer k.world_diagnostic_frame_destroy(&after)
    preserved := bd.compare(before.signature, after.signature) == .Match

    for part in bd.Part {
        preserved = preserved && mem.compare(before.view.parts[part], after.view.parts[part]) == 0
    }

    status := k.lane_world_network_status(&client.transport.lane)
    rejected := status.rejected > old_status.rejected && !status.ready
    criterion :=
        observed &&
        actual.game.retired_count == 0 &&
        rejected &&
        preserved &&
        k.lane_world_protocol_status(&client.transport.lane).bootstrap_sequence == old_scope &&
        k.lane_world_confirmed(&client.transport.lane) == 0 &&
        client.effects == 0
    fmt.printf(
        "KIT_COMMON_SIDE count=%d observed=%v rejected=%v preserved_full5=%v ready=%v scope=%d\n",
        actual.game.retired_count,
        observed,
        rejected,
        preserved,
        status.ready,
        k.lane_world_protocol_status(&client.transport.lane).bootstrap_sequence,
    )
    // ONE prospective RED. Never step the accepted unsafe value or call the
    // actual unsafe slice to turn a meaningful assertion into a process panic.
    testing.expect(
        t,
        criterion,
        "complete authenticated Reset must reject common.Game.retired_count=9 before publication",
    )

    if !criterion {
        return
    }

    // Once the missing rule exists, the identical test also requires genuine
    // valid recovery, nonzero submitted/executed work, full5, FX and cleanup.
    if !common_detach(t, &host) || !common_attach(t, &host, &catalog, 0) {
        return
    }

    if !common_reset_response(t, &host, &client) {
        return
    }

    testing.expect(t, k.lane_world_network_status(&client.transport.lane).ready)
    client.axis = 1

    for _ in 0 ..< 3 {
        if !wp.advance_one(t, &client.transport) {
            return
        }

        common_pump(&host, &client)

        if !wp.advance_one(t, &host.transport) {
            return
        }

        common_pump(&host, &client)
        _ = k.lane_frame(&client.transport.lane, 0)
    }

    authority, replica: k.World_Diagnostic_Frame

    if !saved_frame(t, &host.transport, 3, &authority) {
        return
    }

    defer k.world_diagnostic_frame_destroy(&authority)

    if !saved_frame(t, &client.transport, 3, &replica) {
        return
    }

    defer k.world_diagnostic_frame_destroy(&replica)

    for part in bd.Part {
        testing.expect_value(t, mem.compare(authority.view.parts[part], replica.view.parts[part]), 0)
    }

    testing.expect_value(t, bd.compare(authority.signature, replica.signature), bd.Difference.Match)
    value, origin, sequence, ve := k.lane_world_accepted_input(&host.transport.lane, 3, 2, 0)
    testing.expect_value(t, ve, k.World_Error.Ok)

    if ve == .Ok {
        testing.expect_value(t, origin, k.World_Input_Origin.Submitted)
        testing.expect_value(t, sequence, u64(3))
        testing.expect_value(t, (cast(^common.Control)raw_data(value)).x, i16(1))
    }

    testing.expect_value(t, host.effects, u32(1))
    testing.expect_value(t, client.effects, u32(1))
}

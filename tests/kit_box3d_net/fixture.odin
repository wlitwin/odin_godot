package kit_box3d_net_test

import "core:fmt"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"
import pf "godot:tests/replay_physics_net/fixture"

Control :: struct {
    axis: i32,
}

Action :: struct {
    kind, serial: u32,
}

Proxy :: struct {
    pose: b.Pose,
    tick: u64,
}

Side :: struct {
    tick:                         u64,
    rng:                          u32,
    initial:                      u32,
    keys:                         [33]b.Body_Key,
    alive:                        [33]bool,
    generation:                   [33]u32,
    hinge:                        b.Joint_Key,
    last_action:                  [2]u32,
    births, deaths, begins, ends: u32,
    pending_destroy:              bool,
}

Parcel :: struct {
    to:      s.Peer_Id,
    bytes:   []u8,
    channel: s.Channel,
}

Box :: struct {
    peer:               s.Peer_Id,
    ses:                s.Session,
    lane:               k.Lane,
    physics:            p.Instance(Side),
    network:            p.Network(Side),
    control:            p.Typed_Codec(Control),
    action:             p.Typed_Codec(Action),
    proxy:              p.Typed_Codec(Proxy),
    desc:               n.Entity_Desc,
    proxies:            [32]Proxy,
    fields:             [32]k.World_Wire_Field,
    out:                [dynamic]Parcel,
    axis:               i32,
    action_at:          u64,
    action_kind:        u32,
    effects:            int,
    count:              int,
    fail:               bool,
    initial_gravity:    bool,
    initial_side_delta: bool,
}

check :: proc(status: b.Status) {
    assert(status == .Ok)
}

send :: proc(user: rawptr, to: s.Peer_Id, bytes: []u8, channel: s.Channel) {
    box := cast(^Box)user
    clone := make([]u8, len(bytes))
    copy(clone, bytes)
    append(&box.out, Parcel{to, clone, channel})
}

pump :: proc(boxes: []^Box) {
    for progress := true; progress; {
        progress = false

        for box in boxes {
            for len(box.out) > 0 {
                parcel := box.out[0]
                ordered_remove(&box.out, 0)

                for dest in boxes {
                    if dest.peer != box.peer && (parcel.to == s.BROADCAST_PEER || parcel.to == dest.peer) {
                        r := n.reader_make(parcel.bytes)
                        s.session_handle_packet(&dest.ses, box.peer, &r)
                    }
                }

                delete(parcel.bytes)
                progress = true
            }
        }
    }
}

start_pair :: proc(host, client: ^Box) {
    host.peer = s.HOST_PEER
    client.peer = 100

    for box in ([]^Box{host, client}) {
        box.ses.send = send
        box.ses.send_user = box
    }

    s.session_host_start(&host.ses, "authority")
    s.session_client_start(&client.ses, 0x1234, "client")
    s.session_client_join(&client.ses)
    pump({host, client})
    assert(host.ses.me == 1 && client.ses.me == 2)
}

world :: proc(count: int) -> (b.World, Side) {
    w, source, status := pf.world(u32(count))
    check(status)
    game := Side {
        rng     = source.rng,
        initial = u32(count),
        hinge   = source.joint,
    }

    for i in 0 ..< count {
        game.keys[i] = source.bodies[i]
        game.alive[i] = source.alive[i]
        game.generation[i] = source.generation[i]
    }

    return w, game
}

catalog :: proc() -> b.Recovery_Catalog {
    config := b.recovery_config_default()
    config.profile = pf.PROFILE
    source := pf.assets()
    assets: [4]b.Recovery_Asset

    for a, i in source {
        assets[i] = {
            id     = a.id,
            kind   = b.Recovery_Asset_Kind(a.kind),
            a      = a.a,
            b      = a.b,
            radius = a.radius,
        }
    }

    result, status := b.recovery_catalog_create(config, assets[:])
    check(status)
    return result
}

game_rules :: proc() -> bd.Digest {
    digest, status := bd.hash_descriptors(
        "kit-physics-network-test-rules-v1",
        []bd.Descriptor {
            {"kit", transmute([]u8)#load("fixture.odin")},
            {"shared-world", transmute([]u8)#load("../replay_physics_net/fixture/fixture.odin")},
        },
    )
    assert(status == .None)
    return digest
}

sample_control :: proc(user: rawptr, tick: u64, dst: rawptr) {
    box := cast(^Box)user
    (cast(^Control)dst)^ = {box.axis}
}

sample_action :: proc(user: rawptr, tick: u64, dst: rawptr) {
    box := cast(^Box)user
    (cast(^Action)dst)^ = {}

    if tick == box.action_at {
        (cast(^Action)dst)^ = {box.action_kind, u32(tick)}
    }
}

validate_control :: proc(_: rawptr, value: rawptr) -> bool {
    return abs((cast(^Control)value).axis) <= 2
}

validate_action :: proc(_: rawptr, value: rawptr) -> bool {
    return (cast(^Action)value).kind <= 2
}

effect :: proc(user: rawptr, tick, key: u64, args: []u8) {
    box := cast(^Box)user
    assert(box.lane.world.presenting)
    box.effects += 1
}

step :: proc(user: rawptr, tick: u64) {
    box := cast(^Box)user
    game := p.state(&box.physics)
    w, error := p.world(&box.physics)
    assert(error == .Ok)
    game.tick = tick
    game.rng = game.rng * 1664525 + 1013904223

    for player in ([]n.Player_Id{1, 2}) {
        input, _ := k.lane_input_of(&box.lane, player, Control)
        action, _ := k.lane_input_of(&box.lane, player, Action)
        body, status := b.body_resolve(w, game.keys[0])
        check(status)

        if input.axis != 0 {
            if !p.require(&box.physics, b.body_apply_impulse(body, {f32(input.axis) * .002, 0, 0})) {
                return
            }
        }

        if action.kind != 0 && action.serial > game.last_action[int(player) - 1] {
            game.last_action[int(player) - 1] = action.serial

            if action.kind == 1 && !game.alive[game.initial] {
                def := b.body_def_default()
                def.type = .Dynamic
                def.pose.position = box.count == 32 ? b.Vec3{.1, 7, .1} : b.Vec3{0, 1, 0}
                born, status := b.body_create(w, def)

                if !p.require(&box.physics, status) {
                    return
                }

                shape := b.shape_def_default()
                shape.enable_sensor_events = 1
                _, status = b.shape_sphere(born, shape, .25)

                if !p.require(&box.physics, status) {
                    return
                }

                game.keys[game.initial], status = b.body_key(born)
                check(status)
                game.alive[game.initial] = true
                game.generation[game.initial] += 1
                game.births += 1
            }

            if action.kind == 2 && game.alive[game.initial] {
                game.pending_destroy = true
            }

            assert(k.lane_world_emit(&box.lane, 100 + u64(player), effect, box) == .Ok)
        }
    }

    if tick % 5 == 0 {
        assert(k.lane_world_emit(&box.lane, 1, effect, box) == .Ok)
    }

    if box.fail {
        assert(p.network_destroy(&box.network) == .Busy)
        k.lane_world_fail(&box.lane, .Step_Failed)
    }
}

settle :: proc(user: rawptr, tick: u64) {
    box := cast(^Box)user
    game := p.state(&box.physics)
    w, error := p.world(&box.physics)
    assert(error == .Ok)
    obs, oe := p.sensor_observations(&box.physics)
    assert(oe == .Ok)

    for event in obs.events[:obs.count] {
        if event.began != 0 {
            game.begins += 1
        } else {
            game.ends += 1
        }
    }

    if game.pending_destroy {
        body, status := b.body_resolve(w, game.keys[game.initial])
        check(status)

        if !p.require(&box.physics, b.body_destroy(&body)) {
            return
        }

        game.alive[game.initial] = false
        game.keys[game.initial] = 0
        game.pending_destroy = false
        game.deaths += 1
    }

    for &proxy, i in box.proxies[:box.count] {
        body, status := b.body_resolve(w, game.keys[i])
        check(status)
        proxy.pose, status = b.body_get_pose(body)
        check(status)
        proxy.tick = tick
    }
}

setup :: proc(box: ^Box, count: int, cat: ^b.Recovery_Catalog) {
    box.count = count
    @(static) fields := []n.Field_Desc {
        {offset = offset_of(Proxy, pose), size = size_of(b.Pose), name = "pose", flags = {.Predicted}},
        {offset = offset_of(Proxy, tick), size = size_of(u64), name = "tick", flags = {.Predicted}},
    }
    box.desc = {
        fields = fields,
    }
    k.lane_init(&box.lane, &box.ses, size_of(Control), cfg = {slots = 128, snap_every = 3})
    k.lane_set_sim(&box.lane, box, sample_control, step)
    k.lane_class_set_type(&box.lane, 0, Control)
    k.lane_class_set_validate(&box.lane, 0, validate_control)
    k.lane_add_input_class(&box.lane, 1, size_of(Action), sample_action)
    k.lane_class_set_type(&box.lane, 1, Action)
    k.lane_class_set_validate(&box.lane, 1, validate_action)
    types := make([]k.World_Field_Type, count, context.temp_allocator)

    for i in 0 ..< count {
        k.lane_track(&box.lane, n.Net_Id(i + 1), &box.proxies[i], &box.desc, box.ses.me)
        types[i] = k.world_field_type(n.Net_Id(i + 1), Proxy)
    }

    w, game := world(count)

    if box.initial_gravity {
        check(b.world_set_gravity(w, {0, -2, 0}))
    }

    if box.initial_side_delta {
        game.rng ~= 1
    }

    probe, probe_status := b.snapshot_capture(w)
    check(probe_status)
    _, write_status, diagnostic := b.recovery_write_diagnostic(cat, &probe, nil)

    if write_status != .Ok {
        fmt.eprintf(
            "KIT_NATIVE_WRITE status=%v section=%d record=%d field=%d reason=%d offset=%d\n",
            write_status,
            diagnostic.section,
            diagnostic.record,
            diagnostic.field,
            diagnostic.reason,
            diagnostic.offset,
        )
    }

    check(b.snapshot_destroy(&probe))
    assert(p.attach(&box.physics, &box.lane, &w, game, types, {asset_id = pf.ASSET_DECLARATION}, settle) == .Ok)
    assert(p.codec_init(&box.control) == .Ok)
    assert(p.codec_init(&box.action) == .Ok)
    assert(p.codec_init(&box.proxy, &box.desc) == .Ok)

    for i in 0 ..< count {
        box.fields[i] = {n.Net_Id(i + 1), box.proxy.value}
    }

    inputs := []k.World_Wire_Input{{0, box.control.value, .Hold}, {1, box.action.value, .Neutral}}
    drivers := []k.World_Driver{{1, 0}, {1, 1}, {2, 0}, {2, 1}}
    effects := []k.World_Effect_Def{{1, effect, box, p.empty_codec()}}
    error := p.network_attach(
        &box.network,
        &box.physics,
        cat,
        box.fields[:count],
        inputs,
        drivers,
        effects,
        game_rules(),
    )

    if error != .Ok {
        fmt.eprintf("KIT_NETWORK_ATTACH error=%v count=%d\n", error, count)
    }

    assert(error == .Ok)
}

destroy :: proc(box: ^Box) {
    assert(p.network_destroy(&box.network) == .Ok)
    assert(p.detach(&box.physics) == .Ok)
    p.codec_destroy(&box.control)
    p.codec_destroy(&box.action)
    p.codec_destroy(&box.proxy)
    k.lane_destroy(&box.lane)

    for parcel in box.out {
        delete(parcel.bytes)
    }

    delete(box.out)
    s.session_destroy(&box.ses)
}

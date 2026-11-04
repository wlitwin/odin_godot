// TEST ONLY: real Core/SDK caller, public Session/Lane CPU fixture, no transport.
package kit_gate_b_fixture

import "core:mem"
import "core:os"
import "core:fmt"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import dense "godot:tests/replay_physics_net/fixture"
import common "godot:examples/box3d_common"

MAX_SAVED_BYTES :: 4 * 1024 * 1024
MAX_SAVED_PACKETS :: 128
REPAIR_BASE :: u64(154)
REPAIR_HEAD :: u64(162)

Profile :: enum {
    Dense,
    Common,
}

Packet :: struct {
    bytes:   []u8,
    channel: s.Channel,
    tick:    u64,
}

Proxy :: struct {
    pose:           b.Pose,
    tick, lifetime: u64,
    alive:          bool,
}

Event :: struct {
    epoch, tick, serial, lifetime, key: u64,
    kind, source:                       u16,
}

Sink :: struct {
    calls, duplicates: u64,
    keys:              [512]u64,
    ticks:             [512]u64,
    count:             int,
}

Endpoint :: struct($G, $C, $A: typeid) {
    lane:          k.Lane,
    ses:           s.Session,
    physics:       p.Instance(G),
    network:       p.Network(G),
    control:       p.Typed_Codec(C),
    action:        p.Typed_Codec(A),
    proxy:         p.Typed_Codec(Proxy),
    event:         p.Typed_Codec(Event),
    proxies:       [33]Proxy,
    desc:          n.Entity_Desc,
    fields:        [33]k.World_Wire_Field,
    sink:          Sink,
    actions:       [2]A,
    steps:         u64,
    root:          ^State,
    host, diverge: bool,
    owners:        [8]p.SDK_User_Owner,
    sdk:           p.SDK_Context,
    allocator:     mem.Allocator,
}

Dense :: Endpoint(dense.Game, dense.Control, dense.Action)
Common :: Endpoint(common.Game, common.Control, common.Action)

Send_Context :: struct {
    state: ^State,
    host:  bool,
}

State :: struct {
    sdk:                                                                                                     p.SDK_Context,
    allocator:                                                                                               mem.Allocator,
    owner:                                                                                                   p.SDK_User_Owner,
    endpoint_sdk:                                                                                            p.SDK_Context,
    profile:                                                                                                 Profile,
    source_dense,
    ghost_dense,
    receiver_dense:                                                               ^Dense,
    source_common,
    ghost_common,
    receiver_common:                                                            ^Common,
    source_send,
    ghost_send,
    receiver_send:                                                                  Send_Context,
    packets:                                                                                                 [MAX_SAVED_PACKETS]Packet,
    packet_count:                                                                                            int,
    saved_bytes:                                                                                             u64,
    session_welcome:                                                                                         []u8,
    expected:                                                                                                [bd.Part][]u8,
    expected_signature:                                                                                      bd.Signature,
    capture_tick:                                                                                            u64,
    capture,
    source_phase:                                                                                   bool,
    peak:                                                                                                    b.World_Counters,
    source_ledger_peak:                                                                                      u64,
    source_freed:                                                                                            bool,
    before_steps,
    after_steps,
    head_before,
    head_after,
    confirmed_before,
    confirmed_after:                   u64,
    operations:                                                                                              u64,
    last_error:                                                                                              k.World_Error,
    fx_before,
    fx_after:                                                                                     u64,
    actual_signature:                                                                                        bd.Signature,
    equal,
    cleanup_ok:                                                                                       bool,
    stage:                                                                                                   u32,
    progress_tick:                                                                                           u64,
    accepted_trace:                                                                                          bd.Digest,
    accepted_rows:                                                                                           u64,
    current_expected:                                                                                        [bd.Part][]u8,
    current_expected_signature:                                                                              bd.Signature,
    publication_atomic:                                                                                      bool,
    bootstrap_tick,
    target_tick:                                                                             u64,
    matched_before,
    matched_after,
    full_before,
    full_after:                                                  u64,
    received_accepted,
    received_signatures,
    outgoing_calls,
    outgoing_copies,
    outgoing_freed,
    outgoing_bytes: u64,
    accepted_first,
    accepted_last,
    signature_tick:                                                           u64,
    accepted_window_count:                                                                                   int,
}

status :: proc(value: b.Status) -> k.World_Error {
    return value == .Ok ? .Ok : .Step_Failed
}

profile_id :: proc(which: Profile) -> u64 {
    return which == .Dense ? dense.PROFILE : common.PROFILE
}

rules :: proc(which: Profile) -> bd.Digest {
    model := bd.hash_bytes(transmute([]u8)#load("fixture.odin"))
    world := which == .Dense ? dense.game_rules() : common.game_rules()
    result, e := bd.hash_descriptors("kit-gate-b-cpu-v2", []bd.Descriptor{{"model", model[:]}, {"world", world[:]}})
    assert(e == .None)
    return result
}

catalog :: proc(which: Profile) -> (b.Recovery_Catalog, b.Status) {
    cfg := b.recovery_config_default()
    cfg.profile = profile_id(which)
    assets: [5]b.Recovery_Asset
    count := 0

    if which == .Common {
        assets = common.assets()
        count = 5
    } else {
        for a, i in dense.assets() {
            assets[i] = {
                id     = a.id,
                kind   = b.Recovery_Asset_Kind(a.kind),
                a      = a.a,
                b      = a.b,
                radius = a.radius,
            }
        }

        count = 4
    }

    return b.recovery_catalog_create(cfg, assets[:count])
}

body_world :: proc(ep: ^Endpoint($G, $C, $A)) -> b.World {
    world, e := p.world(&ep.physics)
    assert(e == .Ok)
    return world
}

require :: proc(ep: ^Endpoint($G, $C, $A), value: b.Status) -> bool {
    return p.require(&ep.physics, value)
}

common_ops :: proc(ep: ^Endpoint(common.Game, common.Control, common.Action)) -> common.Operations {
    return {user = ep, impulse = proc(user: rawptr, key: b.Body_Key, v: b.Vec3) -> bool {
            e := cast(^Common)user
            w := body_world(e)
            body, s := b.body_resolve(w, key)
            return require(e, s) && require(e, b.body_apply_impulse(body, v))
        }, spawn = proc(user: rawptr, asset: u32, def: b.Body_Def) -> (b.Body_Key, b.Shape_Key, bool) {
            e := cast(^Common)user
            w := body_world(e)
            body, s := b.body_create(w, def)

            if !require(e, s) {
                return 0, 0, false
            }

            shape := b.shape_def_default()
            shape.enable_sensor_events = 1

            if asset != common.SPAWN_ASSET {
                return 0, 0, false
            }

            h, ss := b.shape_capsule(body, shape, {0, -.2, 0}, {0, .2, 0}, .2)

            if !require(e, ss) {
                return 0, 0, false
            }

            key, ks := b.body_key(body)
            sk, sks := b.shape_key(h)
            return key, sk, require(e, ks) && require(e, sks)
        }, remove = proc(user: rawptr, key: b.Body_Key) -> bool {
            e := cast(^Common)user
            body, s := b.body_resolve(body_world(e), key)
            return require(e, s) && require(e, b.body_destroy(&body))
        }, motor = proc(user: rawptr, key: b.Joint_Key, speed: f32) -> bool {
            e := cast(^Common)user
            j, s := b.joint_resolve(body_world(e), key)
            return require(e, s) && require(e, b.joint_hinge_set_motor(j, true, speed, 2))
        }, awake = proc(user: rawptr, key: b.Body_Key, value: bool) -> bool {
            e := cast(^Common)user
            body, s := b.body_resolve(body_world(e), key)
            return require(e, s) && require(e, b.body_set_awake(body, value))
        }, query = proc(user: rawptr, key: b.Body_Key) -> (u32, bool) {
            e := cast(^Common)user
            w := body_world(e)
            body, s := b.body_resolve(w, key)

            if !require(e, s) {
                return 0, false
            }

            pose, ps := b.body_get_pose(body)

            if !require(e, ps) {
                return 0, false
            }

            hits: [35]b.Ray_Hit
            count, qs := b.query_ray(
                w,
                {pose.position.x, pose.position.y + .5, pose.position.z},
                {0, -2, 0},
                b.QUERY_FILTER_ALL,
                hits[:],
            )
            return count, require(e, qs)
        }}
}

dense_ops :: proc(ep: ^Dense) -> dense.Operations {
    return {execution = ep, impulse = proc(user: rawptr, key: b.Body_Key, v: b.Vec3) -> bool {
            e := cast(^Dense)user
            body, s := b.body_resolve(body_world(e), key)
            return require(e, s) && require(e, b.body_apply_impulse(body, v))
        }, spawn = proc(user: rawptr, pos: b.Vec3) -> (b.Body_Key, bool) {
            e := cast(^Dense)user
            w := body_world(e)
            def := b.body_def_default()
            def.type = .Dynamic
            def.pose.position = pos
            body, s := b.body_create(w, def)

            if !require(e, s) {
                return 0, false
            }

            shape := b.shape_def_default()
            shape.enable_sensor_events = 1
            _, ss := b.shape_sphere(body, shape, .25)
            key, ks := b.body_key(body)
            return key, require(e, ss) && require(e, ks)
        }, remove = proc(user: rawptr, key: b.Body_Key) -> bool {
            e := cast(^Dense)user
            body, s := b.body_resolve(body_world(e), key)
            return require(e, s) && require(e, b.body_destroy(&body))
        }, motor = proc(user: rawptr, key: b.Joint_Key, speed: f32) -> bool {
            e := cast(^Dense)user
            j, s := b.joint_resolve(body_world(e), key)
            return require(e, s) && require(e, b.joint_hinge_set_motor(j, true, speed, 2))
        }}
}

effect :: proc(user: rawptr, tick, key: u64, args: []u8) {
    sink := cast(^Sink)user

    for i in 0 ..< sink.count {
        if sink.keys[i] == key && sink.ticks[i] == tick {
            sink.duplicates += 1
        }
    }

    assert(sink.count < len(sink.keys))
    sink.keys[sink.count] = key
    sink.ticks[sink.count] = tick
    sink.count += 1
    sink.calls += 1
}

emit :: proc(ep: ^Endpoint($G, $C, $A), tick, key: u64, event: Event) {
    copy := event
    assert(k.lane_world_emit(&ep.lane, key, effect, &ep.sink, (cast([^]u8)&copy)[:size_of(copy)]) == .Ok)
}

sample_control :: proc(user: rawptr, tick: u64, out: rawptr, $G, $C, $A: typeid) {
    ep := cast(^Endpoint(G, C, A))user

    when G == dense.Game {
        v := dense.Control{}

        if ep.host {
            v.x = tick % 2 == 0 ? 10 : -10
        }

        if ep.diverge {
            v.x = 1
        }

        (cast(^C)out)^ = v
    } else {
        v := common.scripted_control(tick, ep.host ? 1 : 2)

        if ep.diverge {
            v.x = 1
        }

        (cast(^C)out)^ = v
    }
}

sample_action :: proc(user: rawptr, tick: u64, out: rawptr, $G, $C, $A: typeid) {
    ep := cast(^Endpoint(G, C, A))user

    when G == dense.Game {
        v := dense.Action{}

        if ep.host {
            switch tick {
            case 40, 41:
                v.kind = .Spawn
            case 95:
                v.kind = .Remove
            case 115:
                v.kind = .Motor
            }
        }

        (cast(^A)out)^ = v
    } else {
        (cast(^A)out)^ = common.scripted_action(tick, ep.host ? 1 : 2)
    }
}

step :: proc(user: rawptr, tick: u64, $G, $C, $A: typeid) {
    ep := cast(^Endpoint(G, C, A))user
    ep.steps += 1
    ep.actions = {}
    g := p.state(&ep.physics)
    controls: [2]C

    for player, i in ([]n.Player_Id{1, 2}) {
        controls[i], _ = k.lane_input_of(&ep.lane, player, C)
        ep.actions[i], _ = k.lane_input_of(&ep.lane, player, A)
    }

    when G == dense.Game {
        g.tick += 1
        x := g.rng
        x ~= x << 13
        x ~= x >> 17
        x ~= x << 5
        g.rng = x
        ops := dense_ops(ep)

        for c, i in controls {
            if c.x != 0 || c.z != 0 {
                if !ops.impulse(ep, g.bodies[i], {f32(c.x) * .001, 0, f32(c.z) * .001}) {
                    k.lane_world_fail(&ep.lane, .Step_Failed)
                }
            }
        }
    } else {
        if !common.pre_step(g, controls, common_ops(ep)) {
            k.lane_world_fail(&ep.lane, .Step_Failed)
        }
    }

    assert(g.tick == tick)
}

settle :: proc(user: rawptr, tick: u64, $G, $C, $A: typeid) {
    ep := cast(^Endpoint(G, C, A))user
    g := p.state(&ep.physics)
    obs, oe := p.sensor_observations(&ep.physics)
    assert(oe == .Ok)
    actions := ep.actions
    ep.actions = {}

    when G == dense.Game {
        for event in obs.events[:obs.count] {
            began := event.began != 0

            if began {
                g.begins += 1
            } else {
                g.ends += 1
            }

            source := u16(began ? 1 : 2)
            emit(
                ep,
                tick,
                (u64(source) << 56) | u64(event.visitor),
                {
                    epoch = k.lane_world_epoch(&ep.lane),
                    tick = tick,
                    key = u64(event.visitor),
                    source = source,
                    kind = source,
                },
            )
        }

        for action, i in actions {
            if action.kind != .None {
                applied := dense.apply_action(g, u16(i + 1), action, dense_ops(ep))
                assert(applied || action.kind == .Spawn)
            }
        }
    } else {
        observed: [70]common.Observation

        for event, i in obs.events[:obs.count] {
            observed[i] = {event.sensor, event.visitor, event.began != 0}
        }

        events: [32]common.Event
        count, ok := common.post_step(g, observed[:obs.count], events[:])
        assert(ok)

        for event in events[:count] {
            emit(
                ep,
                tick,
                (event.serial << 32) | (event.lifetime << 8) | (u64(event.seat) << 4) | u64(event.kind),
                {
                    epoch = k.lane_world_epoch(&ep.lane),
                    tick = tick,
                    serial = event.serial,
                    lifetime = event.lifetime,
                    key = event.serial,
                    kind = u16(event.kind),
                    source = event.seat,
                },
            )
        }

        for action, i in actions {
            event, applied := common.apply_action(g, u16(i + 1), action, common_ops(ep))

            if applied && event.serial != 0 {
                emit(
                    ep,
                    tick,
                    (event.serial << 32) | (event.lifetime << 8) | (u64(event.seat) << 4) | u64(event.kind),
                    {
                        epoch = k.lane_world_epoch(&ep.lane),
                        tick = tick,
                        serial = event.serial,
                        lifetime = event.lifetime,
                        key = event.serial,
                        kind = u16(event.kind),
                        source = event.seat,
                    },
                )
            }
        }
    }

    w := body_world(ep)

    for &proxy, i in ep.proxies {
        key: b.Body_Key
        alive: bool
        life: u64

        when G == dense.Game {
            key = g.bodies[i]
            alive = g.alive[i]
            life = u64(g.generation[i])
        } else {
            key = g.bodies[i]
            alive = g.alive[i]
            life = g.lifetimes[i]
        }

        proxy = {
            tick     = tick,
            lifetime = life,
            alive    = alive,
        }

        if alive {
            body, s := b.body_resolve(w, key)
            assert(s == .Ok)
            proxy.pose, s = b.body_get_pose(body)
            assert(s == .Ok)
        }
    }
}

own :: proc(ep: ^Endpoint($G, $C, $A), index: int, user: rawptr, bytes: u64) -> bool {
    owner, e := p.sdk_user_owner_create(ep.sdk.memory, ep, u64(size_of(ep^)), user, bytes)

    if e != .Ok {
        ep.root.last_error = e
        ep.root.stage = u32(100 + index)
        return false
    }

    ep.owners[index] = owner
    return true
}

setup :: proc(root: ^State, ep: ^Endpoint($G, $C, $A), host: bool) -> bool {
    ep.sdk = root.endpoint_sdk
    ep.allocator = bm.allocator(ep.sdk.memory)
    context.allocator = ep.allocator
    ep.root = root
    ep.host = host

    if !own(ep, 0, ep, u64(size_of(ep^))) ||
       !own(ep, 1, &ep.physics, u64(size_of(ep.physics))) ||
       !own(ep, 2, &ep.network, u64(size_of(ep.network))) ||
       !own(ep, 3, &ep.control, u64(size_of(ep.control))) ||
       !own(ep, 4, &ep.action, u64(size_of(ep.action))) ||
       !own(ep, 5, &ep.proxy, u64(size_of(ep.proxy))) ||
       !own(ep, 6, &ep.event, u64(size_of(ep.event))) ||
       !own(ep, 7, &ep.sink, u64(size_of(ep.sink))) {
        return false
    }

    k.lane_init(&ep.lane, &ep.ses, size_of(C), cfg = {slots = 128, snap_every = 3}, allocator = ep.allocator)
    k.lane_set_sim(&ep.lane, ep, proc(user: rawptr, tick: u64, out: rawptr) {
        sample_control(user, tick, out, G, C, A)
    }, proc(user: rawptr, tick: u64) {
        step(user, tick, G, C, A)
    })
    k.lane_class_set_type(&ep.lane, 0, C)
    k.lane_class_set_validate(&ep.lane, 0, proc(_: rawptr, v: rawptr) -> bool {
        when G == dense.Game {
            return dense.control_valid((cast(^C)v)^)
        } else {
            return common.control_valid((cast(^C)v)^)
        }
    })
    k.lane_add_input_class(&ep.lane, 1, size_of(A), proc(user: rawptr, tick: u64, out: rawptr) {
        sample_action(user, tick, out, G, C, A)
    })
    k.lane_class_set_type(&ep.lane, 1, A)
    k.lane_class_set_validate(&ep.lane, 1, proc(_: rawptr, v: rawptr) -> bool {
        when G == dense.Game {
            return dense.action_valid((cast(^A)v)^)
        } else {
            return common.action_valid((cast(^A)v)^)
        }
    })
    @(static) fields := []n.Field_Desc {
        {offset = offset_of(Proxy, pose), size = size_of(b.Pose), name = "pose", flags = {.Predicted}},
        {offset = offset_of(Proxy, tick), size = 8, name = "tick", flags = {.Predicted}},
        {offset = offset_of(Proxy, lifetime), size = 8, name = "lifetime", flags = {.Predicted}},
        {offset = offset_of(Proxy, alive), size = 1, name = "alive", flags = {.Predicted}},
    }
    ep.desc = {
        fields = fields,
    }
    types: [33]k.World_Field_Type

    for &proxy, i in ep.proxies {
        k.lane_track(&ep.lane, n.Net_Id(i + 1), &proxy, &ep.desc, ep.ses.me)
        types[i] = k.world_field_type(n.Net_Id(i + 1), Proxy)
    }

    w: b.World
    initial: G
    ws: b.Status
    asset: u64

    when G == dense.Game {
        w, initial, ws = dense.world(32)
        asset = dense.ASSET_DECLARATION
    } else {
        w, initial, ws = common.world(32, 1)
        asset = common.ASSET_DECLARATION
    }

    if ws != .Ok {
        root.last_error = .Step_Failed
        return false
    }

    cfg := p.sdk_context_config(ep.sdk, asset, provider = ep.owners[1], author = ep.owners[0], effects = ep.owners[7])
    e := p.attach(&ep.physics, &ep.lane, &w, initial, types[:], cfg, proc(user: rawptr, tick: u64) {
        settle(user, tick, G, C, A)
    })

    if e != .Ok {
        b.world_destroy(&w)
        root.last_error = e
        return false
    }

    if p.codec_init(&ep.control, allocator = ep.allocator, ownership = ep.owners[3]) != .Ok ||
       p.codec_init(&ep.action, allocator = ep.allocator, ownership = ep.owners[4]) != .Ok ||
       p.codec_init(&ep.proxy, &ep.desc, ep.allocator, ownership = ep.owners[5]) != .Ok ||
       p.codec_init(&ep.event, allocator = ep.allocator, ownership = ep.owners[6]) != .Ok {
        root.last_error = .Allocation_Failed
        return false
    }

    for &field, i in ep.fields {
        field = {n.Net_Id(i + 1), ep.proxy.value}
    }

    cat, cs := catalog(root.profile)

    if cs != .Ok {
        root.last_error = .Step_Failed
        return false
    }

    defer b.recovery_catalog_destroy(&cat)
    inputs := []k.World_Wire_Input{{0, ep.control.value, .Hold}, {1, ep.action.value, .Neutral}}
    drivers := []k.World_Driver{{1, 0}, {1, 1}, {2, 0}, {2, 1}}
    fx := []k.World_Effect_Def{{1, effect, &ep.sink, ep.event.value}}
    root.last_error = p.network_attach(
        &ep.network,
        &ep.physics,
        &cat,
        ep.fields[:],
        inputs,
        drivers,
        fx,
        rules(root.profile),
        ownership = ep.owners[2],
    )
    return root.last_error == .Ok
}

close_endpoint :: proc(ep: ^Endpoint($G, $C, $A)) -> bool {
    if ep == nil {
        return true
    }

    owners := ep.owners
    alloc := ep.allocator

    if alloc.procedure == nil {
        alloc = bm.allocator(ep.root.endpoint_sdk.memory)
    }

    ok := true

    if p.network_destroy(&ep.network) != .Ok {
        ok = false
    }

    if p.codec_destroy(&ep.control) != .Ok {
        ok = false
    }

    if p.codec_destroy(&ep.action) != .Ok {
        ok = false
    }

    if p.codec_destroy(&ep.proxy) != .Ok {
        ok = false
    }

    if p.codec_destroy(&ep.event) != .Ok {
        ok = false
    }

    if p.detach(&ep.physics) != .Ok {
        ok = false
    }

    k.lane_destroy(&ep.lane)
    s.session_destroy(&ep.ses)
    free(ep, alloc)

    for &owner in owners {
        if p.sdk_user_owner_destroy(&owner) != .Ok {
            ok = false
        }
    }

    return ok
}

source_session :: proc(root: ^State) -> ^s.Session {
    if root.profile == .Dense {
        return &root.source_dense.ses
    }

    return &root.source_common.ses
}

ghost_session :: proc(root: ^State) -> ^s.Session {
    if root.profile == .Dense {
        return &root.ghost_dense.ses
    }

    return &root.ghost_common.ses
}

save_bytes :: proc(root: ^State, bytes: []u8) -> []u8 {
    if root.saved_bytes + u64(len(bytes)) > MAX_SAVED_BYTES {
        root.last_error = .Capacity
        return nil
    }

    result, e := make([]u8, len(bytes), root.allocator)

    if e != nil || len(result) != len(bytes) {
        root.last_error = .Allocation_Failed
        return nil
    }

    copy(result, bytes)
    root.saved_bytes += u64(len(result))
    return result
}

send :: proc(user: rawptr, to: s.Peer_Id, bytes: []u8, channel: s.Channel) {
    ctx := cast(^Send_Context)user
    root := ctx.state

    if !root.source_phase {
        // Actual local serialized output remains bounded/countable even though the
        // source endpoint has been destroyed. Copy/free, never a no-op transport.
        root.outgoing_calls += 1

        if len(bytes) > k.WORLD_NETWORK_BYTES {
            root.last_error = .Capacity
            return
        }

        clone, e := make([]u8, len(bytes), root.allocator)

        if e != nil {
            root.last_error = .Allocation_Failed
            return
        }

        copy(clone, bytes)
        root.outgoing_copies += 1
        root.outgoing_bytes += u64(len(clone))
        delete(clone, root.allocator)
        root.outgoing_freed += 1
        return
    }

    if !ctx.host {
        r := n.reader_make(bytes)
        s.session_handle_packet(source_session(root), 100, &r, channel)

        if r.err {
            root.last_error = .Invalid
        }

        return
    }

    if len(bytes) > 0 && to == 100 && len(root.session_welcome) == 0 {
        root.session_welcome = save_bytes(root, bytes)
    }

    tick := u64(0)
    capture := false

    if len(bytes) > 2 && bytes[0] == s.SES_APP {
        r := n.reader_make(bytes[3:])
        revision := n.read_u32(&r)

        if revision == k.WORLD_NETWORK_REV {
            switch bytes[2] {
            case k.SIM_WORLD_CHUNK:
                mode := k.World_Transfer_Mode(n.read_u8(&r))
                _ = n.read_u64(&r)
                _ = n.read_u64(&r)
                tick = n.read_u64(&r)
                capture = !r.err && tick == root.bootstrap_tick && mode == .Reset
            case k.SIM_WORLD_ACCEPTED:
                _ = n.reader_view(&r, 32)
                _ = n.read_u64(&r)
                tick = n.read_u64(&r)
                first := n.read_u64(&r)
                count := int(n.read_u8(&r))
                _ = n.read_u8(&r)
                capture = !r.err && tick == root.target_tick

                if capture {
                    root.accepted_first = first
                    root.accepted_window_count = count
                    root.accepted_last = first + u64(count) - 1
                }
            case k.SIM_WORLD_SIGNATURE:
                signature, e := bd.signature_decode(n.reader_remaining(&r))
                tick = signature.tick
                capture = e == .None && tick == root.target_tick

                if capture {
                    root.signature_tick = tick
                }
            }
        }
    }

    if capture {
        if root.packet_count == MAX_SAVED_PACKETS {
            root.last_error = .Capacity
            return
        }

        owned := save_bytes(root, bytes)

        if len(owned) == len(bytes) {
            root.packets[root.packet_count] = {
                bytes   = owned,
                channel = channel,
                tick    = tick,
            }
            root.packet_count += 1
        }
    }

    if to == s.BROADCAST_PEER || to == 100 {
        r := n.reader_make(bytes)
        s.session_handle_packet(ghost_session(root), s.HOST_PEER, &r, channel)

        if r.err {
            root.last_error = .Invalid
        }
    }
}

sample_counts :: proc(root: ^State, ep: ^Endpoint($G, $C, $A)) {
    observation, e := p.observe(&ep.physics)

    if e != .Ok {
        root.last_error = e
        return
    }

    c := observation.counts
    root.peak.body_count = max(root.peak.body_count, c.body_count)
    root.peak.shape_count = max(root.peak.shape_count, c.shape_count)
    root.peak.contact_count = max(root.peak.contact_count, c.contact_count)
    root.peak.joint_count = max(root.peak.joint_count, c.joint_count)
    contract, cs := b.domain_contract_get()

    if cs == .Ok {
        ledger, ls := b.host_ledger_get(contract.cookie)

        if ls == .Ok {
            root.source_ledger_peak = max(root.source_ledger_peak, ledger.committed_peak_bytes)
        }
    }
}

trace_accepted :: proc(root: ^State, ep: ^Endpoint($G, $C, $A), tick: u64) -> bool {
    writer := n.writer_make(256, root.allocator)
    defer n.writer_destroy(&writer)
    n.write_u64(&writer, tick)

    for player in ([]n.Player_Id{1, 2}) {
        for class in 0 ..< 2 {
            local, origin, sequence, e := k.lane_world_accepted_input(&ep.lane, tick, player, u16(class))

            if e != .Ok {
                root.last_error = e
                return false
            }

            codec := class == 0 ? ep.control.value : ep.action.value
            wire: [256]u8

            if codec.wire_bytes > len(wire) || codec.encode(codec.user, local, wire[:codec.wire_bytes]) != .Ok {
                root.last_error = .Invalid
                return false
            }

            n.write_u16(&writer, u16(player))
            n.write_u16(&writer, u16(class))
            n.write_u8(&writer, u8(origin))
            n.write_u64(&writer, sequence)
            n.write_u16(&writer, u16(codec.wire_bytes))

            for byte in wire[:codec.wire_bytes] {
                n.write_u8(&writer, byte)
            }
        }
    }

    row := bd.hash_bytes(n.writer_bytes(&writer))
    previous := root.accepted_trace
    digest, e := bd.hash_descriptors(
        "kit-gate-b-accepted-trajectory-v1",
        []bd.Descriptor{{"previous", previous[:]}, {"row", row[:]}},
    )

    if e != .None {
        root.last_error = .Invalid
        return false
    }

    root.accepted_trace = digest
    root.accepted_rows += 1
    return true
}

prepare_typed :: proc(root: ^State, source, ghost: ^Endpoint($G, $C, $A), target_tick: u64 = REPAIR_HEAD) -> bool {
    root.stage = 1
    root.source_phase = true
    root.source_send = {root, true}
    root.ghost_send = {root, false}
    source.root = root
    ghost.root = root
    source.ses.allocator = bm.allocator(root.endpoint_sdk.memory)
    ghost.ses.allocator = source.ses.allocator
    source.ses.send = send
    source.ses.send_user = &root.source_send
    ghost.ses.send = send
    ghost.ses.send_user = &root.ghost_send
    s.session_host_start(&source.ses, "authority", 101)
    s.session_client_start(&ghost.ses, 202, "input-producer")
    s.session_client_join(&ghost.ses)

    if source.ses.me != 1 || ghost.ses.me != 2 {
        root.last_error = .Incompatible
        return false
    }

    root.stage = 2

    if !setup(root, source, true) || !setup(root, ghost, false) {
        return false
    }

    if k.lane_world_send_checkpoint(&source.lane, 100, .Welcome) != .Ok {
        return false
    }

    if k.lane_frame(&ghost.lane, 0) != 0 {
        return false
    }

    // Preparation-only public resets bound auxiliary history. Actual source
    // authority trajectory/inputs remain unchanged; final operation uses NO CHUNK.
    for block in 0 ..< 22 {
        if source.lane.ticker.tick == target_tick {
            break
        }

        next := min(target_tick, source.lane.ticker.tick + 8)

        if source.lane.ticker.tick < root.bootstrap_tick && next > root.bootstrap_tick {
            next = root.bootstrap_tick
        }

        ticks := next - source.lane.ticker.tick
        root.stage = 3

        for _ in 0 ..< ticks {
            root.progress_tick = ghost.lane.ticker.tick + 1

            if ghost.lane.ticker.scale != 1 || k.lane_frame(&ghost.lane, 1.0 / 60) != 1 {
                root.last_error = k.lane_world_status(&ghost.lane)
                return false
            }
        }

        root.stage = 4

        for _ in 0 ..< ticks {
            root.progress_tick = source.lane.ticker.tick + 1

            if k.lane_frame(&source.lane, 1.0 / 60) != 1 {
                root.last_error = k.lane_world_status(&source.lane)
                return false
            }

            sample_counts(root, source)

            if !trace_accepted(root, source, source.lane.ticker.tick) {
                return false
            }
        }

        root.stage = 6

        if k.lane_world_request_reset(&ghost.lane) != .Ok {
            return false
        }

        _ = k.lane_frame(&source.lane, 0)
        _ = k.lane_frame(&ghost.lane, 0)

        if k.lane_world_confirmed(&ghost.lane) != next {
            root.last_error = k.lane_world_status(&ghost.lane)
            return false
        }
    }

    if source.lane.ticker.tick != target_tick {
        return false
    }

    root.stage = 7
    fact: k.World_Diagnostic_Frame

    if k.lane_world_diagnostic_frame(&source.lane, target_tick, &fact) != .Ok {
        return false
    }

    root.expected_signature = fact.signature
    root.current_expected_signature = fact.signature

    for part in bd.Part {
        root.expected[part] = save_bytes(root, fact.view.parts[part])
    }

    if k.world_diagnostic_frame_destroy(&fact) != .Ok {
        root.last_error = .Rejected
        return false
    }

    return root.last_error == .Ok
}

// v2 default is one fresh154->162 repair suffix; normal A requests bootstrap152,
// and authority B retains real source161 for its due-signature step162.
create :: proc(
    which: Profile,
    live_authority_tick: u64 = 0,
    bootstrap_tick: u64 = REPAIR_BASE,
) -> (
    ^State,
    k.World_Error,
) {
    if live_authority_tick != 0 && live_authority_tick != 161 {
        return nil, .Unsupported
    }

    if bootstrap_tick != 152 && bootstrap_tick != REPAIR_BASE {
        return nil, .Unsupported
    }

    target_tick := live_authority_tick == 0 ? REPAIR_HEAD : live_authority_tick
    sdk, e := p.sdk_context_create()

    if e != .Ok {
        return nil, e
    }

    alloc := bm.allocator(sdk.memory)
    root, ae := new(State, alloc)

    if ae != nil || root == nil {
        p.sdk_context_destroy(&sdk)
        return nil, .Allocation_Failed
    }

    root.sdk = sdk
    root.allocator = alloc
    root.profile = which
    root.cleanup_ok = true
    root.bootstrap_tick = bootstrap_tick
    root.target_tick = target_tick
    owner, oe := p.sdk_user_owner_create(sdk.memory, root, u64(size_of(root^)), root, u64(size_of(root^)))

    if oe != .Ok {
        return root, oe
    }

    root.owner = owner
    context.allocator = alloc
    endpoint_sdk, ee := p.sdk_context_create()

    if ee != .Ok {
        return root, ee
    }

    root.endpoint_sdk = endpoint_sdk
    endpoint_alloc := bm.allocator(endpoint_sdk.memory)

    if which == .Dense {
        root.source_dense = new(Dense, endpoint_alloc)
        root.ghost_dense = new(Dense, endpoint_alloc)

        if !prepare_typed(root, root.source_dense, root.ghost_dense, target_tick) {
            return root, root.last_error == .Ok ? .Step_Failed : root.last_error
        }

        if live_authority_tick != 0 {
            return root, .Ok
        }

        ghost_ok := close_endpoint(root.ghost_dense)
        source_ok := close_endpoint(root.source_dense)
        root.cleanup_ok = ghost_ok && source_ok
        root.source_dense = nil
        root.ghost_dense = nil
    } else {
        root.source_common = new(Common, endpoint_alloc)
        root.ghost_common = new(Common, endpoint_alloc)

        if !prepare_typed(root, root.source_common, root.ghost_common, target_tick) {
            return root, root.last_error == .Ok ? .Step_Failed : root.last_error
        }

        if live_authority_tick != 0 {
            return root, .Ok
        }

        ghost_ok := close_endpoint(root.ghost_common)
        source_ok := close_endpoint(root.source_common)
        root.cleanup_ok = ghost_ok && source_ok
        root.source_common = nil
        root.ghost_common = nil
    }

    if p.sdk_context_destroy(&root.endpoint_sdk) != .Ok {
        root.cleanup_ok = false
    }

    root.source_phase = false
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    root.source_freed = root.cleanup_ok && es == .Ok && ws == .Ok && engine.live_bytes == 0 && wrapper.live_bytes == 0
    return root, root.source_freed ? .Ok : .Busy
}

receiver_start_typed :: proc(root: ^State, ep: ^Endpoint($G, $C, $A)) -> bool {
    root.stage = 20
    ep.root = root
    ep.ses.allocator = bm.allocator(root.endpoint_sdk.memory)
    root.receiver_send = {root, false}
    ep.ses.send = send
    ep.ses.send_user = &root.receiver_send
    s.session_client_start(&ep.ses, 202, "receiver")
    r := n.reader_make(root.session_welcome)
    s.session_handle_packet(&ep.ses, s.HOST_PEER, &r, .Reliable)

    if r.err || !ep.ses.joined || ep.ses.me != 2 {
        root.last_error = .Incompatible
        return false
    }

    if !setup(root, ep, false) {
        return false
    }

    for packet in root.packets[:root.packet_count] {
        if packet.tick == root.bootstrap_tick && len(packet.bytes) > 2 && packet.bytes[2] == k.SIM_WORLD_CHUNK {
            r = n.reader_make(packet.bytes)
            s.session_handle_packet(&ep.ses, s.HOST_PEER, &r, packet.channel)

            if r.err {
                return false
            }
        }
    }

    _ = k.lane_frame(&ep.lane, 0)
    return(
        k.lane_world_network_status(&ep.lane).ready &&
        k.lane_world_confirmed(&ep.lane) == root.bootstrap_tick &&
        ep.lane.ticker.tick == root.bootstrap_tick \
    )
}

receiver_start :: proc(root: ^State) -> bool {
    if !root.source_freed {
        return false
    }

    sdk, e := p.sdk_context_create()

    if e != .Ok {
        root.last_error = e
        return false
    }

    root.endpoint_sdk = sdk
    alloc := bm.allocator(sdk.memory)

    if root.profile == .Dense {
        root.receiver_dense = new(Dense, alloc)
        return receiver_start_typed(root, root.receiver_dense)
    }

    root.receiver_common = new(Common, alloc)
    return receiver_start_typed(root, root.receiver_common)
}

receiver_restart :: proc(root: ^State) -> bool {
    if root.receiver_dense != nil {
        if !close_endpoint(root.receiver_dense) {
            root.cleanup_ok = false
            return false
        }

        root.receiver_dense = nil
    }

    if root.receiver_common != nil {
        if !close_endpoint(root.receiver_common) {
            root.cleanup_ok = false
            return false
        }

        root.receiver_common = nil
    }

    if p.sdk_context_destroy(&root.endpoint_sdk) != .Ok {
        root.cleanup_ok = false
        return false
    }

    return receiver_start(root)
}

prepare_operation_typed :: proc(root: ^State, ep: ^Endpoint($G, $C, $A)) -> bool {
    ep.diverge = true

    for _ in 0 ..< 8 {
        if ep.lane.ticker.scale != 1 || k.lane_frame(&ep.lane, 1.0 / 60) != 1 {
            root.last_error = k.lane_world_status(&ep.lane)
            return false
        }
    }

    root.before_steps = ep.steps
    root.head_before = ep.lane.ticker.tick
    root.confirmed_before = k.lane_world_confirmed(&ep.lane)
    root.fx_before = ep.sink.calls
    state := k.lane_world_protocol_status(&ep.lane)
    root.matched_before = state.signatures_matched
    root.full_before = state.full_states_received
    root.current_expected_signature = root.expected_signature
    return(
        root.bootstrap_tick == REPAIR_BASE &&
        root.head_before == REPAIR_HEAD &&
        root.confirmed_before == REPAIR_BASE &&
        root.head_before - root.confirmed_before == 8 &&
        root.outgoing_calls == root.outgoing_copies &&
        root.outgoing_copies == root.outgoing_freed \
    )
}

prepare_operation :: proc(root: ^State) -> bool {
    if root.operations > 0 && !receiver_restart(root) {
        return false
    }

    if root.profile == .Dense {
        return prepare_operation_typed(root, root.receiver_dense)
    }

    return prepare_operation_typed(root, root.receiver_common)
}

// WHOLE v2 ENTRY: genuine reliable ACCEPTED162 (155..162) + SIGNATURE162.
// Ingress/copies/typed validation/8 real steps/signing+complete compare/commit/
// effects/required packet cleanup all finish before this returns through Core.
apply_operation_typed :: proc(root: ^State, ep: ^Endpoint($G, $C, $A)) -> bool {
    accepted, signatures := 0, 0

    for packet in root.packets[:root.packet_count] {
        if packet.tick == REPAIR_HEAD && len(packet.bytes) > 2 {
            if packet.bytes[2] != k.SIM_WORLD_ACCEPTED && packet.bytes[2] != k.SIM_WORLD_SIGNATURE {
                root.last_error = .Invalid
                return false
            }

            if packet.channel != .Reliable {
                root.last_error = .Invalid
                return false
            }

            clone, e := make([]u8, len(packet.bytes), root.allocator)

            if e != nil {
                root.last_error = .Allocation_Failed
                return false
            }

            copy(clone, packet.bytes)
            r := n.reader_make(clone)
            s.session_handle_packet(&ep.ses, s.HOST_PEER, &r, packet.channel)
            delete(clone, root.allocator)

            if r.err {
                root.last_error = .Invalid
                return false
            }

            if packet.bytes[2] == k.SIM_WORLD_ACCEPTED {
                accepted += 1
            } else {
                signatures += 1
            }
        }
    }

    root.received_accepted = u64(accepted)
    root.received_signatures = u64(signatures)

    if accepted != 1 ||
       signatures != 1 ||
       root.accepted_first != 155 ||
       root.accepted_last != REPAIR_HEAD ||
       root.accepted_window_count != 8 ||
       root.signature_tick != REPAIR_HEAD {
        root.last_error = .History_Missing
        return false
    }

    root.publication_atomic =
        ep.steps == root.before_steps &&
        ep.lane.ticker.tick == root.head_before &&
        k.lane_world_confirmed(&ep.lane) == root.confirmed_before
    _ = k.lane_frame(&ep.lane, 0)
    root.after_steps = ep.steps
    root.head_after = ep.lane.ticker.tick
    root.confirmed_after = k.lane_world_confirmed(&ep.lane)
    root.fx_after = ep.sink.calls
    root.last_error = k.lane_world_status(&ep.lane)
    root.operations += 1
    protocol := k.lane_world_protocol_status(&ep.lane)
    root.matched_after = protocol.signatures_matched
    root.full_after = protocol.full_states_received
    return(
        root.publication_atomic &&
        root.last_error == .Ok &&
        root.head_before == REPAIR_HEAD &&
        root.head_after == REPAIR_HEAD &&
        root.confirmed_before == REPAIR_BASE &&
        root.confirmed_after == REPAIR_HEAD &&
        root.after_steps - root.before_steps == 8 &&
        root.matched_after == root.matched_before + 1 &&
        root.full_after == root.full_before &&
        protocol.matched_signature_tick == REPAIR_HEAD &&
        ep.sink.duplicates == 0 \
    )
}

apply_operation :: proc(root: ^State) -> bool {
    if root.profile == .Dense {
        return apply_operation_typed(root, root.receiver_dense)
    }

    return apply_operation_typed(root, root.receiver_common)
}

proof_typed :: proc(root: ^State, ep: ^Endpoint($G, $C, $A)) -> bool {
    frame: k.World_Diagnostic_Frame
    e := k.lane_world_diagnostic_frame(&ep.lane, REPAIR_HEAD, &frame)

    if e != .Ok {
        root.last_error = e
        return false
    }

    root.actual_signature = frame.signature
    root.equal = bd.compare(frame.signature, root.expected_signature) == .Match

    for part in bd.Part {
        root.equal = root.equal && mem.compare(frame.view.parts[part], root.expected[part]) == 0
    }

    if k.world_diagnostic_frame_destroy(&frame) != .Ok {
        return false
    }

    base, be := k.lane_world_checkpoint(&ep.lane, REPAIR_BASE)

    if be != .Ok {
        return false
    }

    if k.world_checkpoint_destroy(&base) != .Ok {
        return false
    }

    return root.equal && ep.sink.duplicates == 0
}

proof :: proc(root: ^State) -> bool {
    if root.profile == .Dense {
        return proof_typed(root, root.receiver_dense)
    }

    return proof_typed(root, root.receiver_common)
}

observe_typed :: proc(ep: ^Endpoint($G, $C, $A)) -> b.World_Counters {
    observation, e := p.observe(&ep.physics)
    assert(e == .Ok)
    return observation.counts
}

observe :: proc(root: ^State) -> b.World_Counters {
    if root.profile == .Dense {
        return observe_typed(root.receiver_dense)
    }

    return observe_typed(root.receiver_common)
}

Cleanup :: struct {
    native_live, snapshot_live, meter_live, ledger_live, ledger_reserved, ledger_peak: u64,
    ok, stats_ok:                                                                      bool,
}

destroy :: proc(root: ^^State) -> Cleanup {
    if root^ == nil {
        return {ok = true, stats_ok = true}
    }

    r := root^
    sdk, alloc, owner := r.sdk, r.allocator, r.owner
    ok := r.cleanup_ok

    if r.receiver_dense != nil {
        ok = close_endpoint(r.receiver_dense) && ok
    }

    if r.receiver_common != nil {
        ok = close_endpoint(r.receiver_common) && ok
    }

    if r.source_dense != nil {
        ok = close_endpoint(r.source_dense) && ok
    }

    if r.ghost_dense != nil {
        ok = close_endpoint(r.ghost_dense) && ok
    }

    if r.source_common != nil {
        ok = close_endpoint(r.source_common) && ok
    }

    if r.ghost_common != nil {
        ok = close_endpoint(r.ghost_common) && ok
    }

    for packet in r.packets[:r.packet_count] {
        delete(packet.bytes, alloc)
    }

    delete(r.session_welcome, alloc)

    for part in bd.Part {
        delete(r.expected[part], alloc)
    }

    for part in bd.Part {
        delete(r.current_expected[part], alloc)
    }

    if p.sdk_context_destroy(&r.endpoint_sdk) != .Ok {
        ok = false
    }

    free(r, alloc)

    if p.sdk_user_owner_destroy(&owner) != .Ok {
        ok = false
    }

    if p.sdk_context_destroy(&sdk) != .Ok {
        ok = false
    }

    root^ = nil
    a, ae := b.engine_allocation_stats()
    z, ze := b.snapshot_allocation_stats()
    m, me := bm.category_stats(bg.CATEGORY_KIT_CORE)
    contract, ce := b.domain_contract_get()
    ledger, le := b.host_ledger_get(contract.cookie)
    return {
        a.live_bytes,
        z.live_bytes,
        m.live_bytes,
        ledger.live_bytes,
        ledger.host_reserved_bytes,
        ledger.committed_peak_bytes,
        ok,
        ae == .Ok && ze == .Ok && me == bg.OK && ce == .Ok && le == .Ok,
    }
}

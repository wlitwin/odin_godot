package kit_module_fixture_test

import "core:fmt"
import "core:testing"
import "core:time"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import bm "godot:box3d/godot/meter"
import net "godot:kit/net"
import p "godot:kit/physics"
import session "godot:kit/session"
import sim "godot:kit/sim"
import f "godot:tests/replay_physics_net/fixture"

Envelope_Side :: struct {
    keys:  [33]b.Body_Key,
    joint: b.Joint_Key,
    tick:  u64,
    rng:   u32,
}

Envelope_Proxy :: struct {
    pose: b.Pose,
    tick: u64,
}

Envelope_Fx :: struct {
    count: u64,
}

Envelope_Source :: struct {
    lane:                                            sim.Lane,
    ses:                                             session.Session,
    provider:                                        p.Instance(Envelope_Side),
    network:                                         p.Network(Envelope_Side),
    codec:                                           p.Typed_Codec(Envelope_Proxy),
    proxies:                                         [32]Envelope_Proxy,
    desc:                                            net.Entity_Desc,
    sink:                                            ^Envelope_Fx,
    fail, reject_fx:                                 bool,
    cookie, live_peak, admitted_peak, reserved_peak: u64,
}

envelope_sample :: proc(s: ^Envelope_Source) {
    values, status := b.host_ledger_get(s.cookie)
    assert(status == .Ok)
    s.live_peak = max(s.live_peak, values.live_bytes)
    s.admitted_peak = max(s.admitted_peak, values.admitted_bytes)
    s.reserved_peak = max(s.reserved_peak, values.host_reserved_bytes)
}

envelope_fx :: proc(user: rawptr, tick, key: u64, args: []u8) {
    (cast(^Envelope_Fx)user).count += 1
}

envelope_step :: proc(user: rawptr, tick: u64) {
    s := cast(^Envelope_Source)user
    state := p.state(&s.provider)
    assert(state != nil)
    state.tick = tick
    state.rng = state.rng * 1664525 + 1013904223
    envelope_sample(s)

    if s.reject_fx {
        assert(sim.lane_world_emit(&s.lane, 777, envelope_fx, s) == .Unsupported)
        return
    }

    world, error := p.world(&s.provider)
    assert(error == .Ok)

    if tick == 129 {
        def := b.body_def_default()
        def.type = .Dynamic
        def.pose.position = {.1, 7, .1}
        body, status := b.body_create(world, def)
        assert(status == .Ok)
        shape := b.shape_def_default()
        shape.enable_sensor_events = 1
        _, status = b.shape_sphere(body, shape, .25)
        assert(status == .Ok)
        state.keys[32], status = b.body_key(body)
        assert(status == .Ok)
    }

    if tick % 5 == 0 {
        assert(sim.lane_world_emit(&s.lane, 1, envelope_fx, s.sink) == .Ok)
    }
}

envelope_settle :: proc(user: rawptr, tick: u64) {
    s := cast(^Envelope_Source)user
    state := p.state(&s.provider)
    world, error := p.world(&s.provider)
    assert(error == .Ok)

    for &proxy, i in s.proxies {
        body, status := b.body_resolve(world, state.keys[i])
        assert(status == .Ok)
        proxy.pose, status = b.body_get_pose(body)
        assert(status == .Ok)
        proxy.tick = tick
    }

    if s.fail {
        sim.lane_world_fail(&s.lane, .Step_Failed)
    }

    envelope_sample(s)
}

envelope :: proc(t: ^testing.T, service: bg.Service) {
    owned, oe := p.sdk_context_create()
    testing.expect_value(t, oe, sim.World_Error.Ok)
    alloc := bm.allocator(owned.memory)
    source := new(Envelope_Source, alloc)
    source.cookie = service.domain.cookie
    author, ae := p.sdk_user_owner_create(owned.memory, source, u64(size_of(source^)), source, u64(size_of(source^)))
    testing.expect_value(t, ae, sim.World_Error.Ok)
    provider, pe := p.sdk_user_owner_create(
        owned.memory,
        source,
        u64(size_of(source^)),
        &source.provider,
        u64(size_of(source.provider)),
    )
    testing.expect_value(t, pe, sim.World_Error.Ok)
    source.sink = new(Envelope_Fx, alloc)
    sink_owner, se := p.sdk_user_owner_create(
        owned.memory,
        source.sink,
        u64(size_of(Envelope_Fx)),
        source.sink,
        u64(size_of(Envelope_Fx)),
    )
    testing.expect_value(t, se, sim.World_Error.Ok)
    source.ses.is_host = true
    source.ses.me = 1
    sim.lane_init(&source.lane, &source.ses, 0, allocator = alloc)
    sim.lane_set_sim(&source.lane, source, nil, envelope_step)
    @(static) fields := []net.Field_Desc {
        {offset = offset_of(Envelope_Proxy, pose), size = size_of(b.Pose), flags = {.Predicted}},
        {offset = offset_of(Envelope_Proxy, tick), size = size_of(u64), flags = {.Predicted}},
    }
    source.desc = {
        fields = fields,
    }
    types: [32]sim.World_Field_Type

    for &proxy, i in source.proxies {
        sim.lane_track(&source.lane, net.Net_Id(i + 1), &proxy, &source.desc, 1)
        types[i] = sim.world_field_type(net.Net_Id(i + 1), Envelope_Proxy)
    }

    world, game, ws := f.world(32)
    testing.expect_value(t, ws, b.Status.Ok)
    initial := Envelope_Side {
        joint = game.joint,
        rng   = game.rng,
    }

    for key, i in game.bodies[:32] {
        initial.keys[i] = key
    }

    cfg := p.sdk_context_config(owned, f.ASSET_DECLARATION, provider = provider, author = author, effects = sink_owner)

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        before_requests: bg.Request_Totals
        after_requests: bg.Request_Totals
        testing.expect_value(t, service.request_totals(service.user, &before_requests), bg.OK)
        bad := cfg
        bad.provider_owner = {}
        testing.expect_value(
            t,
            p.attach(&source.provider, &source.lane, &world, initial, types[:], bad, envelope_settle),
            sim.World_Error.Unsupported,
        )
        bad = cfg
        bad.allocator_context = nil
        testing.expect_value(
            t,
            p.attach(&source.provider, &source.lane, &world, initial, types[:], bad, envelope_settle),
            sim.World_Error.Unsupported,
        )
        testing.expect_value(t, service.request_totals(service.user, &after_requests), bg.OK)
        testing.expect_value(t, after_requests, before_requests)
        testing.expect(t, world != 0 && source.lane.world == nil && source.provider.lane == nil)
    }

    testing.expect_value(
        t,
        p.attach(&source.provider, &source.lane, &world, initial, types[:], cfg, envelope_settle),
        sim.World_Error.Ok,
    )
    codec_owner, coe := p.sdk_user_owner_create(
        owned.memory,
        source,
        u64(size_of(source^)),
        &source.codec,
        u64(size_of(source.codec)),
    )
    testing.expect_value(t, coe, sim.World_Error.Ok)
    testing.expect_value(
        t,
        p.codec_init(&source.codec, &source.desc, alloc, ownership = codec_owner),
        sim.World_Error.Ok,
    )
    network_owner, noe := p.sdk_user_owner_create(
        owned.memory,
        source,
        u64(size_of(source^)),
        &source.network,
        u64(size_of(source.network)),
    )
    testing.expect_value(t, noe, sim.World_Error.Ok)
    catalog_config := b.recovery_config_default()
    catalog_config.profile = f.PROFILE
    assets: [4]b.Recovery_Asset
    source_assets := f.assets()

    for asset, i in source_assets {
        assets[i] = {
            id     = asset.id,
            kind   = b.Recovery_Asset_Kind(asset.kind),
            a      = asset.a,
            b      = asset.b,
            radius = asset.radius,
        }
    }

    catalog, cat_status := b.recovery_catalog_create(catalog_config, assets[:])
    testing.expect_value(t, cat_status, b.Status.Ok)
    wire_fields: [32]sim.World_Wire_Field

    for &field, i in wire_fields {
        field = {net.Net_Id(i + 1), source.codec.value}
    }

    fx := []sim.World_Effect_Def{{1, envelope_fx, source.sink, p.empty_codec()}}
    testing.expect_value(
        t,
        p.network_attach(
            &source.network,
            &source.provider,
            &catalog,
            wire_fields[:],
            nil,
            nil,
            fx,
            bd.hash_bytes(transmute([]u8)#load("envelope_test.odin")),
            ownership = network_owner,
        ),
        sim.World_Error.Ok,
    )
    testing.expect_value(t, b.recovery_catalog_destroy(&catalog), b.Status.Ok)
    encoded, wire_error := sim.lane_world_export(&source.lane, 0)
    testing.expect_value(t, wire_error, sim.World_Error.Ok)
    wire_reader := net.reader_make(encoded[bd.SIGNATURE_BYTES:])
    recovery_size := int(net.read_u32(&wire_reader))
    recovery := net.reader_view(&wire_reader, recovery_size)
    diagnostic: sim.World_Diagnostic_Frame
    testing.expect_value(t, sim.lane_world_diagnostic_frame(&source.lane, 0, &diagnostic), sim.World_Error.Ok)
    reconstructed, read_error := source.lane.world.network.config.codec.decode(
        source.lane.world.network.config.codec.user,
        recovery,
        diagnostic.view.parts[.Side],
        diagnostic.view.parts[.Observations],
    )
    testing.expect_value(t, read_error, sim.World_Error.Ok)
    complete_equal, equal_error := source.lane.world.provider.equal(source.lane.world.frames[0].image, reconstructed)
    testing.expect_value(t, equal_error, sim.World_Error.Ok)
    testing.expect(t, complete_equal)
    source.lane.world.provider.release(reconstructed)
    testing.expect_value(t, sim.world_diagnostic_frame_destroy(&diagnostic), sim.World_Error.Ok)
    delete(encoded, alloc)
    testing.expect_value(t, p.network_destroy(&source.network), sim.World_Error.Ok)
    testing.expect_value(t, p.codec_destroy(&source.codec), sim.World_Error.Ok)
    testing.expect_value(t, p.sdk_user_owner_destroy(&network_owner), sim.World_Error.Ok)
    testing.expect_value(t, p.sdk_user_owner_destroy(&codec_owner), sim.World_Error.Ok)
    normal_samples: [140]i64

    for i in 0 ..< 132 {
        started := time.tick_now()
        testing.expect_value(t, sim.lane_frame(&source.lane, 1.0 / 60), 1)
        normal_samples[i] = i64(time.tick_since(started))
        testing.expect_value(t, bh.registry_stats().marks, u32(0))
    }

    cp132, e132 := sim.lane_world_checkpoint(&source.lane, 132)
    testing.expect_value(t, e132, sim.World_Error.Ok)

    for i in 132 ..< 140 {
        started := time.tick_now()
        testing.expect_value(t, sim.lane_frame(&source.lane, 1.0 / 60), 1)
        normal_samples[i] = i64(time.tick_since(started))
    }

    before, be := sim.lane_world_checkpoint(&source.lane, 140)
    testing.expect_value(t, be, sim.World_Error.Ok)
    _, missing := sim.lane_world_checkpoint(&source.lane, 0)
    testing.expect_value(t, missing, sim.World_Error.History_Missing)
    effects := source.sink.count
    // Exact additional producer allocation leaves insufficient room for the
    // deterministic eight-tick parent promise. No synthetic LIVE estimates.
    other_code: Code
    other: bg.Service
    testing.expect_value(t, bh.producer_create(&other_code, &other), bg.OK)
    previous, os := bh.origin_enter(other.user)
    testing.expect_value(t, os, bg.OK)
    extra_context, ec := bm.create(other, bg.CATEGORY_KIT_PROVIDER)
    testing.expect_value(t, ec, bg.OK)
    extra_alloc := bm.allocator(extra_context)
    extra, error := make([]u8, 16 * 1024 * 1024, extra_alloc)
    testing.expect(t, error == nil && len(extra) == 16 * 1024 * 1024)
    bh.origin_leave(previous)
    rejected := sim.lane_world_reconcile(&source.lane, &cp132)
    testing.expect_value(t, rejected.error, sim.World_Error.Budget)
    unchanged, ue := sim.lane_world_checkpoint(&source.lane, 140)
    testing.expect_value(t, ue, sim.World_Error.Ok)
    equal, ee := sim.world_checkpoint_equal(&before, &unchanged)
    testing.expect_value(t, ee, sim.World_Error.Ok)
    testing.expect(t, equal)
    testing.expect_value(t, source.sink.count, effects)
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    testing.expect_value(t, sim.world_checkpoint_destroy(&unchanged), sim.World_Error.Ok)
    previous, os = bh.origin_enter(other.user)
    testing.expect_value(t, os, bg.OK)
    delete(extra, extra_alloc)
    testing.expect_value(t, bm.destroy(&extra_context), bg.OK)
    testing.expect_value(t, bh.producer_destroy(other.user), bg.OK)
    bh.origin_leave(previous)
    started := time.tick_now()
    corrected := sim.lane_world_reconcile(&source.lane, &cp132)
    whole_ns := i64(time.tick_since(started))
    testing.expect_value(t, corrected.error, sim.World_Error.Ok)
    testing.expect_value(t, corrected.steps, 8)
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    testing.expect_value(t, source.sink.count, effects)
    after, fe := sim.lane_world_checkpoint(&source.lane, 140)
    testing.expect_value(t, fe, sim.World_Error.Ok)
    equal, ee = sim.world_checkpoint_equal(&before, &after)
    testing.expect_value(t, ee, sim.World_Error.Ok)
    testing.expect(t, equal)
    cp133, e133 := sim.lane_world_checkpoint(&source.lane, 133)
    testing.expect_value(t, e133, sim.World_Error.Ok)
    source.fail = true
    failed := sim.lane_world_reconcile(&source.lane, &cp133)
    testing.expect_value(t, failed.error, sim.World_Error.Step_Failed)
    source.fail = false
    failed_after, fae := sim.lane_world_checkpoint(&source.lane, 140)
    testing.expect_value(t, fae, sim.World_Error.Ok)
    equal, ee = sim.world_checkpoint_equal(&before, &failed_after)
    testing.expect_value(t, ee, sim.World_Error.Ok)
    testing.expect(t, equal)
    testing.expect_value(t, source.sink.count, effects)
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    source.reject_fx = true
    testing.expect_value(t, sim.lane_frame(&source.lane, 1.0 / 60), 0)
    testing.expect_value(t, sim.lane_world_status(&source.lane), sim.World_Error.Unsupported)
    blocked, blocked_error := sim.lane_world_checkpoint(&source.lane, 140)
    testing.expect_value(t, blocked_error, sim.World_Error.Ok)
    equal, ee = sim.world_checkpoint_equal(&before, &blocked)
    testing.expect_value(t, ee, sim.World_Error.Ok)
    testing.expect(t, equal)
    testing.expect_value(t, source.sink.count, effects)
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    testing.expect_value(t, sim.world_checkpoint_destroy(&blocked), sim.World_Error.Ok)
    source.reject_fx = false
    observation, obse := p.observe(&source.provider)
    testing.expect_value(t, obse, sim.World_Error.Ok)
    envelope_sample(source)
    ledger, ledger_status := b.host_ledger_get(source.cookie)
    testing.expect_value(t, ledger_status, b.Status.Ok)
    fmt.printf(
        "KIT_SDK_ENVELOPE initial=32 history=128 tick=140 repair=8 local_repair_whole_ns=%d live_now=%d sampled_live_peak=%d sampled_admitted_peak=%d sampled_reserved_peak=%d committed_admitted_peak=%d admission_observation_peak=%d declared_repair_ticket=%d bodies=%d shapes=%d contacts=%d joints=%d normal_raw_ns=%v\n",
        whole_ns,
        ledger.live_bytes,
        source.live_peak,
        source.admitted_peak,
        source.reserved_peak,
        ledger.committed_peak_bytes,
        p.allocation_stats().observed_live_peak,
        u64(22 * 1024 * 1024),
        observation.counts.body_count,
        observation.counts.shape_count,
        observation.counts.contact_count,
        observation.counts.joint_count,
        normal_samples,
    )
    testing.expect_value(t, sim.world_checkpoint_destroy(&failed_after), sim.World_Error.Ok)
    testing.expect_value(t, sim.world_checkpoint_destroy(&cp133), sim.World_Error.Ok)
    testing.expect_value(t, sim.world_checkpoint_destroy(&after), sim.World_Error.Ok)
    testing.expect_value(t, sim.world_checkpoint_destroy(&before), sim.World_Error.Ok)
    testing.expect_value(t, p.detach(&source.provider), sim.World_Error.Ok)
    sim.lane_destroy(&source.lane)
    sink := source.sink
    source_pointer := rawptr(source)
    free(source, alloc) // pending only while the exact author/provider owners live
    testing.expect_value(t, p.sdk_user_owner_destroy(&provider), sim.World_Error.Ok)
    testing.expect_value(t, p.sdk_user_owner_destroy(&author), sim.World_Error.Ok)
    testing.expect(t, !bm.owns(owned.memory, source_pointer, u64(size_of(Envelope_Source))))
    free(sink, alloc)
    testing.expect_value(t, p.sdk_user_owner_destroy(&sink_owner), sim.World_Error.Ok)
    // Detached complete owner still retains the real independent FX sink.
    clone, ce := sim.world_checkpoint_clone(&cp132)
    testing.expect_value(t, ce, sim.World_Error.Ok)
    testing.expect_value(t, sim.world_checkpoint_destroy(&cp132), sim.World_Error.Ok)
    testing.expect_value(t, sim.world_checkpoint_destroy(&clone), sim.World_Error.Ok)
    testing.expect(t, !bm.owns(owned.memory, sink, u64(size_of(Envelope_Fx))))
    testing.expect_value(t, p.sdk_context_destroy(&owned), sim.World_Error.Ok)
}

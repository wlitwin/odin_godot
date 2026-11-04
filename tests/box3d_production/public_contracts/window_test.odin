package box3d_production_public_test

import "core:mem"
import "core:fmt"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"
import ksess "godot:kit/session"
import r "godot:replay"
import rn "godot:replay/net"
import ph "godot:replay/physics"
import tr "godot:replay/transport"
import v "godot:replay/view"
import pf "godot:tests/replay_physics_net/fixture"
import kf "godot:tests/kit_box3d_net"
import ar "godot:tests/box3d_soak/replay/action_retire"

@(test)
kit_natural128_edge_and_expired_read_then_real_source_free_reset :: proc(t: ^testing.T) {
    defer cleanup(t)
    host, client: kf.Box
    kf.start_pair(&host, &client)
    cat := kf.catalog()
    defer b.recovery_catalog_destroy(&cat)
    kf.setup(&host, 4, &cat)
    kf.setup(&client, 4, &cat)
    host_closed := false

    defer if !host_closed {
        kf.destroy(&host)
    }

    defer kf.destroy(&client)
    kf.bootstrap(t, &host, &client)

    for _ in 0 ..< 160 {
        testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1)
        discard(&host)
    }

    edge, ee := k.lane_world_checkpoint(&host.lane, 33)
    testing.expect_value(t, ee, k.World_Error.Ok)

    if ee != .Ok {
        return
    }

    defer k.world_checkpoint_destroy(&edge)
    before, be := k.lane_world_checkpoint(&host.lane, 160)
    testing.expect_value(t, be, k.World_Error.Ok)

    if be != .Ok {
        return
    }

    defer k.world_checkpoint_destroy(&before)
    expired, error := k.lane_world_checkpoint(&host.lane, 32)
    testing.expect_value(t, error, k.World_Error.History_Missing)
    _ = k.world_checkpoint_destroy(&expired)
    after, ae := k.lane_world_checkpoint(&host.lane, 160)
    testing.expect_value(t, ae, k.World_Error.Ok)

    if ae != .Ok {
        return
    }

    defer k.world_checkpoint_destroy(&after)
    kit_same(t, &before, &after)
    authority: k.World_Diagnostic_Frame
    defer k.world_diagnostic_frame_destroy(&authority)
    testing.expect_value(t, k.lane_world_diagnostic_frame(&host.lane, 160, &authority), k.World_Error.Ok)
    // The client really requests Reset through its Session; no recovery flag,
    // baseline, Native row or head is assigned by this test.
    testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
    _ = k.lane_frame(&client.lane, 0)
    kf.pump({&host, &client})
    // Session receive queues the Request. The authority's existing Lane frame
    // must ingest it before any Reset can be exported; a Session pump alone is
    // not the World transaction/publication boundary.
    _ = k.lane_frame(&host.lane, 0)
    reset_chunks := 0

    for parcel in host.out {
        if len(parcel.bytes) > 2 && parcel.bytes[0] == ksess.SES_APP && parcel.bytes[2] == k.SIM_WORLD_CHUNK {
            reset_chunks += 1
        }
    }

    testing.expect(t, reset_chunks > 0, "actual authority Reset chunks sent before source teardown")
    fmt.printf(
        "PUBLIC_KIT_WINDOW stage=reset_sent target160 chunks=%d before_confirmed=%d host_status=%v client_status=%v\n",
        reset_chunks,
        k.lane_world_confirmed(&client.lane),
        k.lane_world_status(&host.lane),
        k.lane_world_status(&client.lane),
    )
    kf.pump({&host, &client})
    // The received public chunks own their bytes before the source is destroyed.
    kf.destroy(&host)
    host_closed = true
    _ = k.lane_frame(&client.lane, 0)
    fmt.printf(
        "PUBLIC_KIT_WINDOW stage=after_import confirmed=%d status=%v ready=%v\n",
        k.lane_world_confirmed(&client.lane),
        k.lane_world_status(&client.lane),
        k.lane_world_network_status(&client.lane).ready,
    )
    testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(160))
    replica: k.World_Diagnostic_Frame
    defer k.world_diagnostic_frame_destroy(&replica)
    testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 160, &replica), k.World_Error.Ok)
    testing.expect_value(t, bd.compare(authority.signature, replica.signature), bd.Difference.Match)

    for part in bd.Part {
        testing.expect(
            t,
            mem.compare(authority.view.parts[part], replica.view.parts[part]) == 0,
            "source-free actual Reset preserves complete five-part state",
        )
    }

    testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 1)
}

@(test)
replay_natural128_edge_expired_refusal_and_source_free_complete_reset :: proc(t: ^testing.T) {
    defer cleanup(t)
    cat := catalog(t)
    config := ph.config_default(pf.ASSET_DECLARATION, b.build_fingerprint())
    config.initial_dynamic_bodies = 4
    config.assets[0].id = 3
    config.assets[1].id = 4
    world, game, ws := pf.world(4)
    testing.expect_value(t, ws, b.Status.Ok)

    if ws != .Ok {
        b.recovery_catalog_destroy(&cat)
        return
    }

    initial, ie := ph.checkpoint_make(
        r.Frame(pf.Game){state = game},
        rn.Net_Event(pf.Event),
        world,
        config,
        catalog = &cat,
    )
    testing.expect_value(t, ie, r.Error.None)
    b.world_destroy(&world)

    if ie != .None {
        b.recovery_catalog_destroy(&cat)
        return
    }

    defer r.complete_checkpoint_destroy(&initial)
    codec := new(ph.Network_Codec(pf.Game, pf.Control, pf.Action, pf.Event, 2))
    defer free(codec)
    ce := ph.network_codec_init(codec, &cat, config, ar.rules())
    testing.expect_value(t, ce, rn.Error.None)
    b.recovery_catalog_destroy(&cat)

    if ce != .None {
        return
    }

    defer ph.network_codec_destroy(codec)
    model := rn.Model(pf.Game, pf.Control, pf.Action, pf.Event, 2) {
        complete_state = true,
        step = ar.step,
        action = ar.action,
        control_valid = pf.control_valid,
        action_valid = pf.action_valid,
        hold = pf.hold,
        state_valid = proc(value: pf.Game) -> bool {
            return value.initial == 4
        },
    }
    timeline: r.Timeline(pf.Game, rn.Batch(pf.Control, pf.Action, 2), rn.Net_Event(pf.Event))
    defer r.destroy(&timeline)
    testing.expect_value(
        t,
        r.init_complete(
            &timeline,
            &initial,
            rn.model_callback(pf.Game, pf.Control, pf.Action, pf.Event, 2),
            {128, 70},
            user = &model,
        ),
        r.Error.None,
    )

    for tick in u64(1) ..= 160 {
        testing.expect_value(t, r.advance(&timeline, rn.Batch(pf.Control, pf.Action, 2){}).error, r.Error.None)
        testing.expect_value(t, r.confirm_through(&timeline, tick), r.Error.None)
    }

    edge, ee := r.capture_complete(&timeline, 33)
    testing.expect_value(t, ee, r.Error.None)

    if ee != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&edge)
    final, fe := r.capture_complete(&timeline, 160)
    testing.expect_value(t, fe, r.Error.None)

    if fe != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&final)
    expired, error := r.capture_complete(&timeline, 32)
    testing.expect_value(t, error, r.Error.History_Missing)
    r.complete_checkpoint_destroy(&expired)
    current, ok := r.current_values(&timeline)
    testing.expect(t, ok && current == final.frame, "expired capture cannot change committed state")
    // Both original Native world and catalog creator are already gone. A new
    // complete Timeline starts from the still-owned source-free checkpoint.
    branch: r.Timeline(pf.Game, rn.Batch(pf.Control, pf.Action, 2), rn.Net_Event(pf.Event))
    defer r.destroy(&branch)
    testing.expect_value(
        t,
        r.init_complete(
            &branch,
            &final,
            rn.model_callback(pf.Game, pf.Control, pf.Action, pf.Event, 2),
            {128, 70},
            user = &model,
        ),
        r.Error.None,
    )
    testing.expect_value(t, r.advance(&timeline, rn.Batch(pf.Control, pf.Action, 2){}).error, r.Error.None)
    testing.expect_value(t, r.advance(&branch, rn.Batch(pf.Control, pf.Action, 2){}).error, r.Error.None)
    left, le := r.capture_complete(&timeline, 161)
    right, re := r.capture_complete(&branch, 161)
    testing.expect(t, le == .None && re == .None)
    defer r.complete_checkpoint_destroy(&left)
    defer r.complete_checkpoint_destroy(&right)
    a, ad := rn.complete_view(codec.value, &left, &codec.state, &codec.occurrence)
    testing.expect_value(t, ad, rn.Error.None)

    if ad != .None {
        return
    }

    defer rn.complete_view_destroy(&a)
    z, zd := rn.complete_view(codec.value, &right, &codec.state, &codec.occurrence)
    testing.expect_value(t, zd, rn.Error.None)

    if zd != .None {
        return
    }

    defer rn.complete_view_destroy(&z)

    for part in bd.Part {
        testing.expect(
            t,
            mem.compare(a.frame.parts[part], z.frame.parts[part]) == 0,
            "source-free resumed canonical all5 agree",
        )
    }
}

@(test)
replay_actual_delivery_gap_beyond128_recovers_from_public_canonical_welcome :: proc(t: ^testing.T) {
    defer cleanup(t)
    pair := new(ar.Pair)
    defer free(pair)
    defer ar.close(t, pair)

    if !ar.open(t, pair) {
        return
    }

    generation, serial, baseline := pair.client.generation, pair.client.serial, pair.client.baseline
    testing.expect(t, pair.client.cfg.history == 128 && pair.client.cfg.max_prediction == 8)
    // Signed facts are reliable, so Memory's unreliable-loss setting cannot
    // create this missing-prefix condition. Explicitly consume/discard real
    // receiver packets for authority steps2..129 through the PUBLIC Transport.
    // receive copies into caller storage and releases its Memory packet; there
    // is no extra borrowed packet/lease to destroy and no ACK is fabricated.
    // This is receiver discard, not ENet/reliable-network loss or SIGSTOP.
    receiver := tr.memory_transport(&pair.endpoints[1])
    scratch: [tr.MAX_PACKET_BYTES]u8
    discarded_packets, discarded_bytes: u64

    for pair.server.timeline.head < 160 {
        now := (pair.server.timeline.head + 1) * 17
        testing.expect(t, tr.memory_advance(&pair.memory, now))
        testing.expect_value(t, rn.server_pump(&pair.server, now), rn.Error.None)
        testing.expect_value(t, rn.server_local(&pair.server, pf.Control{}), rn.Error.None)
        testing.expect_value(t, rn.server_step(&pair.server), rn.Error.None)
        testing.expect(t, tr.memory_advance(&pair.memory, now))

        if pair.server.timeline.head <= 129 {
            drained := false

            for _ in 0 ..< 65 {     // existing fixture capacity64 +one Empty observation
                packet := tr.receive(&receiver, scratch[:])

                if packet.state == .Empty {
                    drained = true
                    break
                }

                testing.expect_value(t, packet.state, tr.Receive_State.Received)

                if packet.state != .Received {
                    return
                }

                discarded_packets += 1
                discarded_bytes += u64(packet.count)
            }

            testing.expect(t, drained, "bounded public receive consumed the pending real packet queue")
        }
    }

    testing.expect(
        t,
        pair.server.timeline.head - pair.client.timeline.confirmed > 128,
        "actual confirmed delivery gap exceeds H128",
    )
    testing.expect(
        t,
        discarded_packets > 0 && discarded_bytes > 0,
        "actual receiver-discard evidence, never a fake missing-history flag",
    )
    fmt.printf(
        "PUBLIC_REPLAY_WINDOW stage=gap control=explicit_receiver_discard authority=%d head=%d confirmed=%d baseline=%d generation=%d serial=%d resyncs=%d discarded_packets=%d discarded_bytes=%d\n",
        pair.server.timeline.head,
        pair.client.timeline.head,
        pair.client.timeline.confirmed,
        pair.client.baseline,
        pair.client.generation,
        pair.client.serial,
        pair.client.stats.resyncs,
        discarded_packets,
        discarded_bytes,
    )
    changes: [320]v.Change(rn.Net_Event(pf.Event))

    for pump in 0 ..< 64 {
        now := u64(3000 + pump * 25)
        tr.memory_advance(&pair.memory, now)
        testing.expect_value(t, rn.client_pump(&pair.client, now), rn.Error.None)
        _ = v.drain(&pair.client.journal, changes[:])
        tr.memory_advance(&pair.memory, now)
        testing.expect_value(t, rn.server_pump(&pair.server, now), rn.Error.None)

        if pair.client.phase == .Running && pair.client.timeline.confirmed >= 160 {
            break
        }
    }

    fmt.printf(
        "PUBLIC_REPLAY_WINDOW stage=after_pumps authority=%d head=%d confirmed=%d phase=%v baseline=%d generation=%d serial=%d resyncs=%d notice=%v\n",
        pair.server.timeline.head,
        pair.client.timeline.head,
        pair.client.timeline.confirmed,
        pair.client.phase,
        pair.client.baseline,
        pair.client.generation,
        pair.client.serial,
        pair.client.stats.resyncs,
        pair.client.resync_notice,
    )
    testing.expect(
        t,
        pair.client.phase == .Running && pair.client.timeline.confirmed >= 160 && pair.client.baseline > baseline,
        "actual beyond-window exhaustion installs complete recovery",
    )
    testing.expect(
        t,
        pair.client.generation > generation || pair.client.serial > serial,
        "new actual validated Welcome scope",
    )
    testing.expect(
        t,
        pair.client.stats.resyncs > 0 && pair.client.resync_notice.serial != 0,
        "public recovery notice, never inferred from a head jump",
    )
    testing.expect(t, ar.full_pair(t, pair, 160), "actual canonical all5 after public recovery")
    testing.expect_value(t, rn.server_step(&pair.server), rn.Error.None)
}

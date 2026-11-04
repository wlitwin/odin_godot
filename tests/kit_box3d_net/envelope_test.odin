package kit_box3d_net_test

import "core:fmt"
import "core:mem"
import "core:testing"
import "core:time"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"

Saved :: struct {
    tick:    u64,
    parcels: [dynamic]Parcel,
    bytes:   u64,
}

discard :: proc(box: ^Box) {
    for parcel in box.out {
        delete(parcel.bytes)
    }

    clear(&box.out)
}

take :: proc(box: ^Box, tick: u64, kind: u8) -> Saved {
    result := Saved {
        tick = tick,
    }

    for parcel in box.out {
        if len(parcel.bytes) > 2 && parcel.bytes[0] == s.SES_APP && parcel.bytes[2] == kind {
            append(&result.parcels, parcel)
            result.bytes += u64(len(parcel.bytes))
        } else {
            delete(parcel.bytes)
        }
    }

    clear(&box.out)
    return result
}

deliver :: proc(client: ^Box, saved: ^Saved) {
    for parcel in saved.parcels {
        r := n.reader_make(parcel.bytes)
        s.session_handle_packet(&client.ses, s.HOST_PEER, &r)
        delete(parcel.bytes)
    }

    delete(saved.parcels)
    saved.parcels = nil
    saved.bytes = 0
}

@(test)
primitive32_history128_real_eight_tick_transaction_and_teardown :: proc(t: ^testing.T) {
    host, client: Box
    start_pair(&host, &client)
    cat := catalog()
    setup(&host, 32, &cat)
    saved: [21]Saved
    testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Welcome), k.World_Error.Ok)
    saved[0] = take(&host, 0, k.SIM_WORLD_CHUNK)
    stored := saved[0].bytes
    host.lane.world.config.additional_owned_bytes = stored
    var_final: k.World_Checkpoint
    e: k.World_Error
    accepted, signature: Saved
    peak_counts: b.World_Counters
    host.action_at = 5
    host.action_kind = 1

    for tick := 1; tick <= 160; tick += 1 {
        if tick == 18 {
            host.action_at = 18
            host.action_kind = 2
        }

        if !advance_one(t, &host) {
            return
        }

        expect_ordinary(t, &host)
        observed, oe := p.observe(&host.physics)
        testing.expect_value(t, oe, k.World_Error.Ok)
        peak_counts.body_count = max(peak_counts.body_count, observed.counts.body_count)
        peak_counts.shape_count = max(peak_counts.shape_count, observed.counts.shape_count)
        peak_counts.contact_count = max(peak_counts.contact_count, observed.counts.contact_count)
        peak_counts.joint_count = max(peak_counts.joint_count, observed.counts.joint_count)

        if tick == 159 {
            signature = take(&host, 159, k.SIM_WORLD_SIGNATURE)
            stored += signature.bytes
            testing.expect_value(t, len(signature.parcels), 1)
        } else if tick == 160 {
            accepted = take(&host, u64(tick), k.SIM_WORLD_ACCEPTED)
            stored += accepted.bytes
        } else {
            discard(&host)
        }

        if tick % 8 == 0 {
            testing.expect_value(
                t,
                k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction),
                k.World_Error.Ok,
            )
            saved[tick / 8] = take(&host, u64(tick), k.SIM_WORLD_CHUNK)
            stored += saved[tick / 8].bytes
        }

        host.lane.world.config.additional_owned_bytes = stored
    }

    var_final, e = k.lane_world_checkpoint(&host.lane, 160)
    testing.expect_value(t, e, k.World_Error.Ok)
    final_view: k.World_Diagnostic_Frame
    testing.expect_value(t, k.lane_world_diagnostic_frame(&host.lane, 160, &final_view), k.World_Error.Ok)
    source_effects := host.effects
    destroy(&host) // replay imports only canonical packets after source teardown
    setup(&client, 32, &cat)
    b.recovery_catalog_destroy(&cat)
    client.lane.world.config.additional_owned_bytes = stored
    deliver(&client, &saved[0])
    _ = k.lane_frame(&client.lane, 0)
    normal_max, correction_max: u64

    for tick := 1; tick <= 160; tick += 1 {
        if tick == 153 {
            client.axis = 1
        } // local guesses that authority explicitly held0

        started := time.tick_now()

        if !advance_one(t, &client) {
            return
        }

        call_ns := u64(time.tick_since(started))
        work := k.lane_world_work_stats(&client.lane)
        normal_max = max(normal_max, work.normal_latest_ns)
        fmt.printf(
            "KIT_NETWORK_SAMPLE metric=normal tick=%d core_ns=%d call_ns=%d\n",
            tick,
            work.normal_latest_ns,
            call_ns,
        )
        discard(&client)

        if tick % 8 == 0 && tick <= 152 {
            bytes := saved[tick / 8].bytes
            deliver(&client, &saved[tick / 8])
            stored -= bytes
            client.lane.world.config.additional_owned_bytes = stored
            started = time.tick_now()
            _ = k.lane_frame(&client.lane, 0)
            call_ns = u64(time.tick_since(started))
            work = k.lane_world_work_stats(&client.lane)
            testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(tick))
            correction_max = max(correction_max, work.correction_latest_ns)
            fmt.printf(
                "KIT_NETWORK_SAMPLE metric=complete_correction tick=%d depth=8 core_ns=%d call_ns=%d\n",
                tick,
                work.correction_latest_ns,
                call_ns,
            )
        }
    }

    testing.expect(t, client.lane.world.frames[0].tick >= 128)
    _, missing := k.lane_world_checkpoint(&client.lane, 0)
    testing.expect_value(t, missing, k.World_Error.History_Missing)
    effects := client.effects
    resims := client.lane.stat_resims
    bytes := accepted.bytes
    deliver(&client, &accepted)
    stored -= bytes
    client.lane.world.config.additional_owned_bytes = stored
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, client.lane.stat_resims, resims)
    testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(152))
    // ACCEPTED160 alone cannot publish. The real cadence SIGNATURE159 verifies
    // its prefix while replaying the COMPLETE152->160 eight-tick suffix.
    bytes = signature.bytes
    deliver(&client, &signature)
    stored -= bytes
    client.lane.world.config.additional_owned_bytes = stored
    started := time.tick_now()
    _ = k.lane_frame(&client.lane, 0)
    call_ns := u64(time.tick_since(started))
    work := k.lane_world_work_stats(&client.lane)
    testing.expect_value(t, client.lane.stat_resims - resims, 8)
    testing.expect_value(t, client.effects, effects)
    testing.expect_value(t, k.lane_world_protocol_status(&client.lane).matched_signature_tick, u64(159))
    testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(159))
    fmt.printf(
        "KIT_NETWORK_SAMPLE metric=accepted_repair tick=160 depth=8 core_ns=%d call_ns=%d\n",
        work.correction_latest_ns,
        call_ns,
    )
    actual, ae := k.lane_world_checkpoint(&client.lane, 160)
    testing.expect_value(t, ae, k.World_Error.Ok)
    same, ee := k.world_checkpoint_equal(&var_final, &actual)
    testing.expect_value(t, ee, k.World_Error.Ok)
    testing.expect(t, same)
    k.world_checkpoint_destroy(&actual)
    deliver(&client, &saved[20])
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(160))
    testing.expect_value(t, client.effects, source_effects)
    settled: k.World_Diagnostic_Frame
    testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 160, &settled), k.World_Error.Ok)

    for part in bd.Part {
        testing.expect_value(t, mem.compare(final_view.view.parts[part], settled.view.parts[part]), 0)
    }

    settled_signature, signature_error := k.lane_world_confirmed_signature(&client.lane, 160)
    testing.expect_value(t, signature_error, k.World_Error.Ok)
    testing.expect_value(t, bd.compare(settled.signature, settled_signature), bd.Difference.Match)
    k.world_diagnostic_frame_destroy(&settled)
    observed, oe := p.observe(&client.physics)
    testing.expect_value(t, oe, k.World_Error.Ok)
    profile := p.allocation_stats()
    fmt.printf(
        "KIT_NETWORK_ENVELOPE initial=32 history=128 repair=8 peak_bodies=%d peak_shapes=%d peak_contacts=%d peak_joints=%d staged_live_peak=%d observed_live_peak=%d live_at_end=%d engine_high=%d wrapper_high=%d external_high=%d component_upper_bound=%d max_operation_requests=%d reservation=%d recovery_write_reserve=%d reservation_failures=%d normal_max_ns=%d complete_correction_max_ns=%d accepted_repair_ns=%d\n",
        peak_counts.body_count,
        peak_counts.shape_count,
        peak_counts.contact_count,
        peak_counts.joint_count,
        profile.staged_live_peak,
        profile.observed_live_peak,
        observed.live_bytes,
        observed.engine.high_water_bytes,
        observed.wrapper.high_water_bytes,
        profile.external_peak,
        observed.engine.high_water_bytes + observed.wrapper.high_water_bytes + profile.external_peak,
        profile.largest_operation_requests,
        client.physics.config.reservation_bytes,
        b.RECOVERY_WRITE_RESERVE_BYTES,
        profile.reservation_failures,
        normal_max,
        correction_max,
        work.correction_latest_ns,
    )
    testing.expect(t, profile.staged_live_peak <= b.ALPHA_RESOURCE_BYTES && profile.reservation_failures == 0)
    k.world_checkpoint_destroy(&var_final)
    k.world_diagnostic_frame_destroy(&final_view)
    destroy(&client)

    for &item in saved {
        for parcel in item.parcels {
            delete(parcel.bytes)
        }

        delete(item.parcels)
    }

    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    fmt.printf(
        "KIT_NETWORK_TEARDOWN engine=%d wrapper=%d provider=%d checkpoints=%d\n",
        engine.live_bytes,
        wrapper.live_bytes,
        p.owned_bytes(),
        k.world_checkpoint_owned_bytes(),
    )
    testing.expect(
        t,
        es == .Ok &&
        ws == .Ok &&
        engine.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        p.owned_bytes() == 0 &&
        k.world_checkpoint_owned_bytes() == 0 &&
        k.world_diagnostic_frame_owned_bytes() == 0,
    )
}

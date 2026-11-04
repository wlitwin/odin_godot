package known_skip_reset_test

// Public generic4/static OFFddff/nilOwner V2 reset + FIRST46 admission.
// Reuses the real actual-app fixture; no Runtime_frame/Godot/SDK/ENet/timing.
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import common "godot:examples/box3d_common"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import p "godot:kit/physics"
import f "godot:tests/box3d_soak/kit/input_admission/fresh_intent"

Packet :: struct {
    id:       u32,
    from, to: s.Peer_Id,
    channel:  s.Channel,
    kind:     u8,
    bytes:    int,
    digest:   bd.Digest,
}

Tap :: struct {
    host, client: ^f.Endpoint,
    count:        u32,
    bytes:        u64,
    failed:       bool,
    packets:      [2048]Packet,
}

tap: ^Tap

Observation :: struct {
    scope,
    stage:                                                                                                                     string,
    setup_complete,
    known_reached,
    skip_reached,
    step40_reached,
    reset_requested,
    reset_applied,
    recovered_reached,
    cleanup_observed: bool,
    client_before_head,
    client_before_confirmed,
    client_after_head,
    client_after_confirmed,
    authority_head,
    epoch:                    u64,
    known_status:                                                                                                                     k.World_Error,
    known_origin:                                                                                                                     k.World_Input_Origin,
    known_sequence:                                                                                                                   u64,
    known_value:                                                                                                                      common.Action,
    before,
    after_skip,
    after_reset:                                                                                                  app.Intent_Plan,
    returned:                                                                                                                         common.Action,
    recovering_before,
    recovering_after_request,
    recovering_after_observe,
    observe_return:                                            bool,
    request_head,
    request_confirmed,
    request_watermark,
    received_watermark,
    reset_baseline:                                           u64,
    request_packets,
    held_prefix_packets,
    reset_packets:                                                                              int,
    full5_preserved_confirmed39,
    full5_after45,
    reset_signature_match,
    identity_preserved,
    packet_provenance_ok:                      bool,
    expected_due,
    actual_due:                                                                                                         u64,
    proposed_criterion_pass:                                                                                                          bool,
    first46_reached,
    first46_packet_observed,
    first46_full5,
    first46_fx_equal,
    first46_identity_pinned:                               bool,
    first46_unknown_status:                                                                                                           k.World_Error,
    first46_source_sequence:                                                                                                          u64,
    first46_value:                                                                                                                    common.Action,
    first46_digest:                                                                                                                   bd.Digest,
    first46_receipt:                                                                                                                  app.Receipt,
    first46_plan:                                                                                                                     app.Intent_Plan,
    first46_host_fx,
    first46_client_fx:                                                                                               int,
    packets_count:                                                                                                                    u32,
    packet_bytes:                                                                                                                     u64,
    packets:                                                                                                                          [2048]Packet,
    native_live,
    wrapper_live,
    provider_live,
    checkpoint_live,
    diagnostic_live,
    odin_live:                                            u64,
}

write_json :: proc(name: string, value: $T) {
    bytes, error := json.marshal(value)
    assert(error == nil)
    defer delete(bytes)
    assert(os.write_entire_file(name, bytes) == nil)
}

record_send :: proc(user: rawptr, to: s.Peer_Id, bytes: []u8, channel: s.Channel) {
    // Existing fixture owns the actual transport copy. Archive every packet
    // after the reused Welcome handshake; no capture failure drops transport.
    f.send(user, to, bytes, channel)
    endpoint := cast(^f.Endpoint)user

    if tap == nil {
        return
    }

    if tap.count >= len(tap.packets) || tap.bytes + u64(len(bytes)) > 8 * 1024 * 1024 {
        tap.failed = true
        return
    }

    id := tap.count
    kind: u8

    if len(bytes) > 2 && bytes[0] == s.SES_APP {
        kind = bytes[2]
    }

    tap.packets[id] = {
        id      = id,
        from    = endpoint.peer,
        to      = to,
        channel = channel,
        kind    = kind,
        bytes   = len(bytes),
        digest  = bd.hash_bytes(bytes),
    }
    tap.count += 1
    tap.bytes += u64(len(bytes))
    name := fmt.aprintf("packet-%03d-from-%d.bin", id, endpoint.peer)
    defer delete(name)

    if os.write_entire_file(name, bytes) != nil {
        tap.failed = true
    }
}

deliver :: proc(t: ^testing.T, from, to: ^f.Endpoint, packet: f.Parcel) {
    before := bd.hash_bytes(packet.bytes)
    reader := n.reader_make(packet.bytes)
    s.session_handle_packet(&to.runtime.ses, from.peer, &reader, packet.channel)
    testing.expect(t, !reader.err && bd.hash_bytes(packet.bytes) == before)
}

gate :: proc(t: ^testing.T, ok: bool, observation: ^Observation, stage: string) -> bool {
    observation.stage = stage
    testing.expect(t, ok, stage)
    return ok
}

input46 :: proc(
    t: ^testing.T,
    endpoint: ^f.Endpoint,
) -> (
    found: bool,
    value: common.Action,
    sequence: u64,
    digest: bd.Digest,
) {
    for packet in endpoint.out {
        if len(packet.bytes) < 3 || packet.bytes[2] != k.SIM_WORLD_INPUT {
            continue
        }

        reader := n.reader_make(packet.bytes)
        _ = n.read_u8(&reader)
        _ = n.read_u8(&reader)
        _ = n.read_u8(&reader)
        testing.expect_value(t, n.read_u32(&reader), k.WORLD_NETWORK_REV)
        _ = n.reader_view(&reader, 32)
        testing.expect_value(t, n.read_u64(&reader), k.lane_world_epoch(&endpoint.runtime.lane))
        testing.expect_value(t, n.read_u64(&reader), u64(46))
        first := n.read_u64(&reader)
        count := int(n.read_u8(&reader))
        entries := int(n.read_u8(&reader))

        for j in 0 ..< count {
            for _ in 0 ..< entries {
                driver := int(n.read_u8(&reader))
                origin := k.World_Input_Origin(n.read_u8(&reader))
                source := n.read_u64(&reader)
                declared := endpoint.runtime.lane.world.network.drivers[driver]
                codec := declared.class == 0 ? endpoint.runtime.controls.value : endpoint.runtime.action_codec.value
                blob := n.reader_view(&reader, codec.wire_bytes)

                if first + u64(j) == 46 && declared.player == endpoint.runtime.ses.me && declared.class == 1 {
                    testing.expect(t, !found)
                    found = true
                    sequence = source
                    digest = bd.hash_bytes(packet.bytes)
                    testing.expect_value(t, origin, k.World_Input_Origin.Submitted)
                    testing.expect_value(
                        t,
                        codec.decode(codec.user, blob, (cast([^]u8)&value)[:size_of(value)]),
                        k.World_Error.Ok,
                    )
                    testing.expect(t, os.write_entire_file("actual-first46.stream.bin", packet.bytes) == nil)
                }
            }
        }

        testing.expect(t, !reader.err && len(n.reader_remaining(&reader)) == 0)
    }

    return
}

spawn46 :: proc(rt: ^app.Runtime) -> (count: int, event: app.Stamped_Event) {
    for candidate in rt.sink.observed[:rt.sink.count] {
        if candidate.tick == 46 && candidate.value.kind == .Spawn {
            count += 1
            event = candidate
        }
    }

    return
}

@(test)
known_skip_then_actual_validated_reset_due46_and_first_admission :: proc(t: ^testing.T) {
    backing := context.allocator
    tracking: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking, backing, backing)
    context.allocator = mem.tracking_allocator(&tracking)
    observation := Observation {
        scope        = "ONE_generic4_static_OFFddff_nilOwner_actual_app_public_Session_Lane_memory_NOT_SDK32_ENet_or_oldcause",
        stage        = "handshake",
        expected_due = 46,
    }
    host, client := new(f.Endpoint), new(f.Endpoint)
    f.handshake(t, host, client)
    capture := new(Tap)
    capture.host = host
    capture.client = client
    tap = capture
    host.runtime.ses.send = record_send
    client.runtime.ses.send = record_send

    defer {
        observation.packets_count = capture.count
        observation.packet_bytes = capture.bytes
        observation.packets = capture.packets
        observation.packet_provenance_ok = !capture.failed
        f.destroy(t, client)
        f.destroy(t, host)
        tap = nil
        free(capture)
        engine, es := b.engine_allocation_stats()
        wrapper, ws := b.snapshot_allocation_stats()
        observation.native_live = engine.live_bytes
        observation.wrapper_live = wrapper.live_bytes
        observation.provider_live = p.owned_bytes()
        observation.checkpoint_live = k.world_checkpoint_owned_bytes()
        observation.diagnostic_live = k.world_diagnostic_frame_owned_bytes()
        observation.odin_live = u64(tracking.current_memory_allocated)
        observation.cleanup_observed =
            es == .Ok &&
            ws == .Ok &&
            observation.native_live == 0 &&
            observation.wrapper_live == 0 &&
            observation.provider_live == 0 &&
            observation.checkpoint_live == 0 &&
            observation.diagnostic_live == 0 &&
            observation.odin_live == 0
        testing.expect(t, observation.packet_provenance_ok && observation.cleanup_observed)
        context.allocator = backing
        mem.tracking_allocator_destroy(&tracking)
        write_json("observation.json", observation)
    }

    rt := &client.runtime

    if !gate(
        t,
        rt.model_ready && host.runtime.model_ready && k.lane_world_network_status(&rt.lane).ready,
        &observation,
        "real_model_ready",
    ) {
        return
    }

    for _ in 0 ..< 39 {
        if !gate(t, k.lane_frame(&rt.lane, 1.0 / 60) == 1, &observation, "public_client_before39") {
            return
        }

        f.drain(t, client, host)

        if !gate(t, k.lane_frame(&host.runtime.lane, 1.0 / 60) == 1, &observation, "public_authority_before39") {
            return
        }

        f.drain(t, host, client)

        if !gate(t, k.lane_frame(&rt.lane, 0) == 0, &observation, "public_confirm_before39") {
            return
        }
    }

    observation.client_before_head = rt.lane.ticker.tick
    observation.client_before_confirmed = k.lane_world_confirmed(&rt.lane)

    if !gate(
        t,
        observation.client_before_head == 39 && observation.client_before_confirmed == 39,
        &observation,
        "head39_confirmed39",
    ) {
        return
    }

    if !gate(t, k.lane_frame(&host.runtime.lane, 1.0 / 60) == 1, &observation, "authority_step40") {
        return
    }

    f.drain(t, host, client)

    if !gate(t, k.lane_frame(&rt.lane, 0) == 0, &observation, "receive_known40") {
        return
    }

    known, origin, sequence, status := k.lane_world_accepted_input(&rt.lane, 40, rt.ses.me, 1)
    observation.known_status = status
    observation.known_origin = origin
    observation.known_sequence = sequence
    observation.known_reached = true

    if !gate(t, status == .Ok && len(known) == size_of(common.Action), &observation, "actual_known40_row") {
        return
    }

    copy((cast([^]u8)&observation.known_value)[:size_of(common.Action)], known)

    if !gate(t, observation.known_value == common.Action{}, &observation, "actual_known_none40") {
        return
    }

    observation.known_reached = true
    rt.scripted = true
    app.intent_prepare(rt)

    if !gate(t, rt.intents.armed, &observation, "actual_intent_prepared") {
        return
    }

    observation.before = rt.intents.plans[rt.intents.active]
    observation.returned = app.intent_sample(rt, 40)
    observation.after_skip = rt.intents.plans[rt.intents.active]

    if !gate(
        t,
        observation.before.original == 40 &&
        observation.before.due == 40 &&
        observation.returned.kind == .None &&
        observation.after_skip == observation.before &&
        !observation.after_skip.attempted &&
        !observation.after_skip.published &&
        !observation.after_skip.transported,
        &observation,
        "actual_known_skip_unsampled",
    ) {
        return
    }

    observation.skip_reached = true

    if !gate(t, k.lane_frame(&rt.lane, 1.0 / 60) == 1, &observation, "public_client_step40") {
        return
    }

    observation.client_after_head = rt.lane.ticker.tick
    observation.client_after_confirmed = k.lane_world_confirmed(&rt.lane)

    if !gate(
        t,
        observation.client_after_head == 40 && rt.intents.plans[rt.intents.active] == observation.before,
        &observation,
        "public40_preserves_unsampled_identity",
    ) {
        return
    }

    observation.step40_reached = true
    observation.full5_preserved_confirmed39 = f.pair(t, "preserved-confirmed39", host, client, 39)

    if !gate(t, observation.full5_preserved_confirmed39, &observation, "full5_preserved_confirmed39") {
        return
    }

    f.drain(t, client, host)

    if !gate(t, k.lane_frame(&host.runtime.lane, 0) == 0, &observation, "deliver_real_client40") {
        return
    }

    // Do not deliver ordinary accepted/canonical output41..45. Keep every owned
    // prefix parcel in its original queue/order/bytes until final teardown.
    for _ in 0 ..< 5 {
        if !gate(t, k.lane_frame(&host.runtime.lane, 1.0 / 60) == 1, &observation, "public_authority_to45") {
            return
        }
    }

    observation.authority_head = host.runtime.lane.ticker.tick
    observation.held_prefix_packets = len(host.out)

    if !gate(t, observation.authority_head == 45, &observation, "authority_actual45") {
        return
    }

    observation.recovering_before = rt.recovering
    node := app.KitSlice {
        rt = rt,
    }
    app.kit_slice_on_reset(&node) // Actual method accesses only this real Runtime.
    observation.recovering_after_request = rt.recovering
    observation.request_head = rt.recovery_head
    observation.request_confirmed = rt.recovery_confirmed
    observation.request_watermark = rt.recovery_sequence
    observation.request_packets = len(client.out)

    if !gate(
        t,
        !observation.recovering_before &&
        observation.recovering_after_request &&
        observation.request_head == 40 &&
        observation.request_packets > 0,
        &observation,
        "actual_UI_public_reset_request",
    ) {
        return
    }

    observation.reset_requested = true

    for packet in client.out {
        if !gate(
            t,
            len(packet.bytes) > 2 && packet.bytes[2] == k.SIM_WORLD_REQUEST,
            &observation,
            "genuine_request_packet_kind",
        ) {
            return
        }
    }

    f.drain(t, client, host)

    if !gate(t, k.lane_frame(&host.runtime.lane, 0) == 0, &observation, "authority_public_request_pump") {
        return
    }

    observation.reset_packets = len(host.out) - observation.held_prefix_packets

    if !gate(t, observation.reset_packets > 0, &observation, "actual_reset_suffix_exists") {
        return
    }

    // Only the newly emitted actual Reset suffix is delivered. The older prefix
    // stays owned/gated; this controlled memory delivery is NOT ENet ordering.
    for index in observation.held_prefix_packets ..< len(host.out) {
        packet := host.out[index]

        if !gate(
            t,
            len(packet.bytes) > 2 && packet.bytes[2] == k.SIM_WORLD_CHUNK && packet.channel == .Reliable,
            &observation,
            "actual_reset_chunk_suffix",
        ) {
            return
        }

        deliver(t, host, client, packet)
        delete(packet.bytes)
        host.out[index].bytes = nil
    }

    if !gate(t, k.lane_frame(&rt.lane, 0) == 0, &observation, "client_public_reset_ingest") {
        return
    }

    observation.reset_baseline = rt.lane.world.network.last_signature.tick
    observation.received_watermark = rt.lane.world.network.received_sequence
    observation.epoch = k.lane_world_epoch(&rt.lane)

    if !gate(
        t,
        rt.lane.ticker.tick == 45 &&
        k.lane_world_confirmed(&rt.lane) == 45 &&
        observation.reset_baseline == 45 &&
        observation.received_watermark > observation.request_watermark,
        &observation,
        "actual_reset45_watermark",
    ) {
        return
    }

    observation.reset_applied = true
    signature, signature_error := k.lane_world_confirmed_signature(&rt.lane, 45)
    observation.reset_signature_match =
        signature_error == .Ok && bd.compare(signature, rt.lane.world.network.last_signature) == .Match

    if !gate(t, observation.reset_signature_match, &observation, "actual_reset_signature_match") {
        return
    }

    signature_bytes: [bd.SIGNATURE_BYTES]u8
    _, encoding_error := bd.signature_encode(signature, signature_bytes[:])

    if !gate(
        t,
        encoding_error == .None && os.write_entire_file("actual-reset45.sig", signature_bytes[:]) == nil,
        &observation,
        "actual_signature_bytes_saved",
    ) {
        return
    }

    observation.observe_return = app.observe_recovered(rt)
    observation.recovering_after_observe = rt.recovering

    if !gate(
        t,
        observation.observe_return && !observation.recovering_after_observe && !rt.failed,
        &observation,
        "actual_observe_recovered_success",
    ) {
        return
    }

    observation.recovered_reached = true
    observation.after_reset = rt.intents.plans[rt.intents.active]
    observation.identity_preserved =
        observation.after_reset.original == 40 &&
        !observation.after_reset.attempted &&
        !observation.after_reset.published &&
        !observation.after_reset.transported &&
        observation.after_reset.attempt_tick == 0 &&
        observation.after_reset.attempt_head == 0

    if !gate(t, observation.identity_preserved, &observation, "unsampled_logical_identity_preserved") {
        return
    }

    observation.full5_after45 = f.pair(t, "after-reset45", host, client, 45)

    if !gate(t, observation.full5_after45 && !capture.failed, &observation, "fullfive45_and_packet_provenance") {
        return
    }

    observation.setup_complete = true
    observation.stage = "V2_DUE46_ASSERTION"
    observation.actual_due = observation.after_reset.due
    observation.proposed_criterion_pass = observation.actual_due == observation.expected_due

    if !gate(t, observation.proposed_criterion_pass, &observation, "V2_due46_after_real_Reset45") {
        return
    }

    _, _, _, observation.first46_unknown_status = k.lane_world_accepted_input(&rt.lane, 46, rt.ses.me, 1)

    if !gate(
        t,
        observation.first46_unknown_status == .History_Missing,
        &observation,
        "actual_unknown46_before_first_sample",
    ) {
        return
    }

    if !gate(t, k.lane_frame(&rt.lane, 1.0 / 60) == 1 && !rt.failed, &observation, "public_FIRST_client46") {
        return
    }

    observation.first46_packet_observed, observation.first46_value, observation.first46_source_sequence, observation.first46_digest =
        input46(t, client)

    if !gate(
        t,
        observation.first46_packet_observed &&
        observation.first46_value == common.Action{.Spawn} &&
        observation.first46_source_sequence == 46,
        &observation,
        "actual_FIRST_input46_bytes",
    ) {
        return
    }

    app.intent_published(rt)
    observation.first46_plan = rt.intents.plans[rt.intents.active]
    // This fixture uses actual Memory Session send, not app Wire's packet hook.
    // Preserve transported=false; prove real delivery from the packet itself.
    observation.first46_identity_pinned =
        observation.first46_plan.original == 40 &&
        observation.first46_plan.due == 46 &&
        observation.first46_plan.attempted &&
        observation.first46_plan.attempt_tick == 46 &&
        observation.first46_plan.attempt_head == 45 &&
        observation.first46_plan.published &&
        !observation.first46_plan.transported

    if !gate(t, observation.first46_identity_pinned, &observation, "actual_FIRST46_identity_no_fabricated_wire_flag") {
        return
    }

    start := len(host.out)
    f.drain(t, client, host)

    if !gate(
        t,
        k.lane_frame(&host.runtime.lane, 0) == 0 && k.lane_frame(&host.runtime.lane, 1.0 / 60) == 1,
        &observation,
        "public_FIRST_authority46",
    ) {
        return
    }

    accepted, accepted_origin, accepted_sequence, accepted_status := k.lane_world_accepted_input(
        &host.runtime.lane,
        46,
        rt.ses.me,
        1,
    )

    if !gate(
        t,
        accepted_status == .Ok &&
        len(accepted) == size_of(common.Action) &&
        accepted_origin == .Submitted &&
        accepted_sequence == 46,
        &observation,
        "actual_authority_admitted46",
    ) {
        return
    }

    accepted_action: common.Action
    copy((cast([^]u8)&accepted_action)[:size_of(accepted_action)], accepted)

    if !gate(t, accepted_action == common.Action{.Spawn}, &observation, "actual_authority_action46") {
        return
    }

    checkpoint, checkpoint_error := k.lane_world_checkpoint(&host.runtime.lane, 46)

    if !gate(t, checkpoint_error == .Ok, &observation, "actual_authority_checkpoint46") {
        return
    }

    side, side_error := p.checkpoint_side(&checkpoint, app.Side)

    if side_error == .Ok {
        observation.first46_receipt = side.receipts[1]
    }

    k.world_checkpoint_destroy(&checkpoint)

    if !gate(
        t,
        side_error == .Ok &&
        observation.first46_receipt.tick == 46 &&
        observation.first46_receipt.kind == .Spawn &&
        observation.first46_receipt.applied,
        &observation,
        "actual_authority_receipt46",
    ) {
        return
    }

    if !gate(
        t,
        k.lane_world_send_checkpoint(&host.runtime.lane, client.peer, .Correction) == .Ok,
        &observation,
        "actual_confirmation46",
    ) {
        return
    }

    for index in start ..< len(host.out) {
        packet := host.out[index]
        deliver(t, host, client, packet)
        delete(packet.bytes)
        host.out[index].bytes = nil
    }

    if !gate(
        t,
        k.lane_frame(&rt.lane, 0) == 0 && k.lane_world_confirmed(&rt.lane) == 46,
        &observation,
        "actual_client_confirmed46",
    ) {
        return
    }

    observation.first46_full5 = f.pair(t, "first-admission46", host, client, 46)
    host_fx, host_event := spawn46(&host.runtime)
    client_fx, client_event := spawn46(rt)
    observation.first46_host_fx = host_fx
    observation.first46_client_fx = client_fx
    observation.first46_fx_equal = host_fx == 1 && client_fx == 1 && host_event == client_event

    if !gate(
        t,
        observation.first46_full5 && observation.first46_fx_equal && !capture.failed,
        &observation,
        "FIRST46_fullfive_onceFX_provenance",
    ) {
        return
    }

    observation.first46_reached = true
    observation.stage = "V2_PUBLIC_RESET_AND_FIRST46_COMPLETE"
}

package kit_box3d

// Process-local observations only. These values never enter Side, input,
// network identity, simulation decisions, or admission configuration.
import b "godot:box3d"
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import ng "godot:kit/netgd"
import gd "godot:godot"
import "core:fmt"

Published_Observations :: struct {
    calls, epoch, tick: u64,
    logged:             bool,
    current, peak:      b.World_Counters,
}

// Bounded diagnostic cadence only: no simulation/admission decision reads it.
telemetry_pump :: proc(rt: ^Runtime) {
    if rt.initial != 32 || !rt.model_ready {
        return
    }

    rt.diagnostic_pumps += 1
    now := n.now_s()

    if rt.diagnostic_next > now {
        return
    }

    rt.diagnostic_next = now + 1
    net := rt.lane.world.network

    if net == nil {
        return
    }

    first := max(u64)
    last, source: u64
    rows := 0

    for row in net.accepted {
        if row.valid {
            first = min(first, row.tick)
            last = max(last, row.tick)
            rows += 1

            for sequence in row.sequence {
                source = max(source, sequence)
            }
        }
    }

    if rows == 0 {
        first = 0
    }

    wire := ng.wire_status(&rt.wire)
    rates := ng.wire_rates(&rt.wire)
    runtime_log(
        rt,
        "{\"event\":\"PUMP\",\"framework\":\"kit\",\"role\":\"%s\",\"pumps\":%d,\"epoch\":%d,\"head\":%d,\"confirmed\":%d,\"target\":%d,\"last_requested_dt\":%f,\"ticker_acc\":%f,\"ready\":%v,\"world_status\":%d,\"net_status\":%d,\"resync\":%v,\"recovering\":%v,\"accepted_rows\":%d,\"accepted_first\":%d,\"accepted_head\":%d,\"accepted_source_sequence_max\":%d,\"last_signature\":%d,\"received_sequence\":%d,\"sent_sequence\":%d,\"transfer_sequence\":%d,\"transfer_tick\":%d,\"transfer_mode\":%d,\"transfer_received\":%d,\"transfer_chunks\":%d,\"transfer_bytes\":%d,\"queue_count\":%d,\"queue_bytes\":%d}\n",
        role_name(rt.role),
        rt.diagnostic_pumps,
        k.lane_world_epoch(&rt.lane),
        rt.lane.ticker.tick,
        k.lane_world_confirmed(&rt.lane),
        rt.target,
        rt.diagnostic_dt,
        rt.lane.ticker.acc,
        net.ready,
        k.lane_world_status(&rt.lane),
        net.status,
        k.lane_world_needs_resync(&rt.lane),
        rt.recovering,
        rows,
        first,
        last,
        source,
        net.last_signature.tick,
        net.received_sequence,
        net.sequence,
        net.transfer_sequence,
        net.transfer_tick,
        net.transfer_mode,
        net.transfer_received,
        net.transfer_chunks,
        len(net.transfer),
        net.queue_count,
        net.queue_bytes,
    )
    telemetry_protocol(rt)
    peer_state := -1
    peer_id, remote_count: int
    mp := gd.node_get_multiplayer(rt.node)

    if mp != nil {
        peers := gd.multiplayer_api_get_peers(mp)
        remote_count = int(gd.packed_int32_array_size(&peers))
        transport := gd.multiplayer_api_get_multiplayer_peer(mp)

        if remote_count > 0 &&
           transport != nil &&
           gd.object_is_class(cast(gd.Object)transport, gd.e_net_multiplayer_peer_name()) {
            peer_id = int(gd.packed_int32_array_get(&peers, 0))
            endpoint := gd.e_net_multiplayer_peer_get_peer(cast(gd.E_Net_Multiplayer_Peer)transport, gd.Int(peer_id))

            if endpoint != nil {
                peer_state = int(gd.e_net_packet_peer_get_state(endpoint))
            }

            gd.release_ref(endpoint)
        }

        gd.release_ref(transport)
        gd.free_packed_int32_array(peers)
        gd.release_ref(mp)
    }

    runtime_log(
        rt,
        "{\"event\":\"FLOW\",\"framework\":\"kit\",\"role\":\"%s\",\"head\":%d,\"confirmed\":%d,\"remote_count\":%d,\"peer\":%d,\"peer_state\":%d,\"enet_in_bandwidth\":0,\"enet_out_bandwidth\":0,\"wire_bandwidth_bytes_s\":%d,\"wire_latency_s\":%f,\"wire_loss_fraction\":%f,\"snapshot_every\":%d,\"wire_status\":%d,\"queued_packets\":%d,\"queued_bytes\":%d,\"reliable_refusals\":%d,\"stream_drops\":%d,\"unavailable_recipients\":%d,\"session_traffic_dropped\":%d,\"reliable_bytes_s_limit\":%d,\"stream_bytes_s_limit\":%d,\"bytes_in\":%d,\"bytes_out\":%d,\"packets_in\":%d,\"packets_out\":%d,\"rate_scope\":\"last_completed_wire_window_framed_bytes\",\"rate_window\":%f,\"observed_at\":%f}\n",
        role_name(rt.role),
        rt.lane.ticker.tick,
        k.lane_world_confirmed(&rt.lane),
        remote_count,
        peer_id,
        peer_state,
        rt.wire.bandwidth,
        rt.wire.latency,
        rt.wire.loss,
        rt.lane.snap_every,
        wire.error,
        wire.queued_packets,
        wire.queued_bytes,
        wire.reliable_refusals,
        wire.stream_drops,
        wire.unavailable_recipients,
        s.session_traffic_dropped(&rt.ses),
        rt.ses.cfg.traffic.reliable.bytes_per_second,
        rt.ses.cfg.traffic.stream.bytes_per_second,
        rates.bytes_in,
        rates.bytes_out,
        rates.packets_in,
        rates.packets_out,
        rt.wire.gauge.window,
        now,
    )
}

telemetry_protocol :: proc(rt: ^Runtime) {
    protocol := k.lane_world_protocol_status(&rt.lane)
    fmt.print("{")
    fmt.printf(
        "\"event\":\"STATUS\",\"framework\":\"kit\",\"stage\":\"world_protocol_v2\",\"session_generation\":%d,\"role\":\"%s\",\"wire_revision\":%d,\"status\":%d,\"bootstrap_sequence\":%d,\"matched_signature_tick\":%d,\"pending_signature_tick\":%d,\"accepted_through\":%d,\"signatures_sent\":%d,\"signatures_matched\":%d,\"full_states_sent\":%d,\"full_states_received\":%d,\"full_state_counter_scope\":\"emitted_or_validated_publication_NOT_delivery_certificate\",\"scale_bits\":\"%x\",\"receipt_available\":%v,\"receipt_scope\":\"fully_validated_class0_proposal_NOT_admission_or_action_ACK\",\"receipt\":",
        rt.generation,
        role_name(rt.role),
        protocol.wire_revision,
        protocol.error,
        protocol.bootstrap_sequence,
        protocol.matched_signature_tick,
        protocol.pending_signature_tick,
        protocol.accepted_through,
        protocol.signatures_sent,
        protocol.signatures_matched,
        protocol.full_states_sent,
        protocol.full_states_received,
        transmute(u64)protocol.scale,
        protocol.receipt_available,
    )

    if protocol.receipt_available {
        fmt.print("{")
        fmt.printf(
            "\"player\":%d,\"proposal_tick\":%d,\"authority_tick\":%d",
            protocol.receipt_player,
            protocol.receipt_proposal_tick,
            protocol.receipt_authority_tick,
        )
        fmt.print("}")
    } else {
        fmt.print("null")
    }

    fmt.print("}\n")
}

telemetry_ledger :: proc(generation: u32, role: Role, stage: string) {
    contract, cs := b.domain_contract_get()

    if cs != .Ok {
        generation_log(
            generation,
            "{\"event\":\"LEDGER_ERROR\",\"framework\":\"kit\",\"stage\":\"%s\",\"status\":%d}\n",
            stage,
            cs,
        )
        return
    }

    ledger, status := b.host_ledger_get(contract.cookie)
    generation_log(
        generation,
        "{\"event\":\"LEDGER\",\"framework\":\"kit\",\"role\":\"%s\",\"stage\":\"%s\",\"status\":%d,\"engine_live_bytes\":%d,\"snapshot_live_bytes\":%d,\"host_live_bytes\":%d,\"host_reserved_bytes\":%d,\"live_bytes\":%d,\"admitted_bytes\":%d,\"limit_bytes\":%d,\"committed_peak_bytes\":%d,\"ledger_storage_bytes\":%d}\n",
        role_name(role),
        stage,
        status,
        ledger.engine_live_bytes,
        ledger.snapshot_live_bytes,
        ledger.host_live_bytes,
        ledger.host_reserved_bytes,
        ledger.live_bytes,
        ledger.admitted_bytes,
        ledger.limit_bytes,
        ledger.committed_peak_bytes,
        ledger.ledger_storage_bytes,
    )
}

// The caller already checked Side and obtained these samples from this SAME
// owned current-head checkpoint. No capture, world creation, step or private
// Image access occurs here. Kit's public observe reads its published world.
telemetry_frame :: proc(rt: ^Runtime, cp: ^k.World_Checkpoint, states: []b.Body_State) {
    if rt.initial != 32 {
        return
    }

    epoch := k.lane_world_epoch(&rt.lane)
    d := &rt.observations

    if d.logged && d.epoch == epoch && d.tick == cp.tick {
        return
    }

    observation, error := p.observe(&rt.physics)
    d.calls += 1

    if error != .Ok || cp.tick != rt.lane.ticker.tick || int(observation.counts.body_count) != len(states) {
        runtime_log(
            rt,
            "{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"published_envelope_observation\",\"status\":%d,\"cached_body_count\":%d,\"native_body_count\":%d}\n",
            error,
            len(states),
            observation.counts.body_count,
        )
        rt.failed = true
        return
    }

    dynamic_count := u32(0)

    for state in states {
        if state.type == .Dynamic {
            dynamic_count += 1
        }
    }

    if !d.logged {
        runtime_log(
            rt,
            "{\"event\":\"LIMITS\",\"framework\":\"kit\",\"role\":\"%s\",\"initial_cached_dynamic_bodies\":%d,\"initial_cached_body_count\":%d,\"history\":128,\"hz\":60,\"substeps\":4,\"max_prediction\":8,\"max_repair\":8,\"process_limit_bytes\":67108864}\n",
            role_name(rt.role),
            dynamic_count,
            len(states),
        )
    }

    d.current = observation.counts
    d.peak.body_count = max(d.peak.body_count, d.current.body_count)
    d.peak.shape_count = max(d.peak.shape_count, d.current.shape_count)
    d.peak.contact_count = max(d.peak.contact_count, d.current.contact_count)
    d.peak.joint_count = max(d.peak.joint_count, d.current.joint_count)
    runtime_log(
        rt,
        "{\"event\":\"ENVELOPE\",\"framework\":\"kit\",\"role\":\"%s\",\"epoch\":%d,\"tick\":%d,\"phase\":\"published_cache_and_world_observation\",\"native_scope\":\"published_world_only\",\"cached_body_count\":%d,\"cached_dynamic_bodies\":%d,\"native_body_count\":%d,\"native_shape_count\":%d,\"native_contact_count\":%d,\"native_joint_count\":%d,\"peak_body_count\":%d,\"peak_shape_count\":%d,\"peak_contact_count\":%d,\"peak_joint_count\":%d,\"observe_calls\":%d,\"observe_error\":\"None\",\"observe_error_code\":0}\n",
        role_name(rt.role),
        epoch,
        cp.tick,
        len(states),
        dynamic_count,
        d.current.body_count,
        d.current.shape_count,
        d.current.contact_count,
        d.current.joint_count,
        d.peak.body_count,
        d.peak.shape_count,
        d.peak.contact_count,
        d.peak.joint_count,
        d.calls,
    )
    telemetry_ledger(rt.generation, rt.role, "published_frame")
    d.logged = true
    d.epoch = epoch
    d.tick = cp.tick
}

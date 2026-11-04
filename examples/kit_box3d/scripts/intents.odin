package kit_box3d

// External device/scenario intent, not solver/Side state. The existing class1
// callback and transactional input ring remain the only input publication path.
import common "godot:examples/box3d_common"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import ng "godot:kit/netgd"
import p "godot:kit/physics"

Intent_Plan :: struct {
    original, due, attempt_tick, attempt_head, packet_head, row_sequence, recovery_serial: u64,
    attempted, published, transported, rebased:                                            bool,
}

Intent_Catalog :: struct {
    initialized, armed: bool,
    active:             int,
    plans:              [6]Intent_Plan,
}

INTENT_PHASES :: [6]u64{40, 56, 80, 120, 136, 160}

intent_fail :: proc(rt: ^Runtime, plan: Intent_Plan, reason: string) {
    runtime_log(
        rt,
        "{\"event\":\"INTENT_UNEXERCISED\",\"framework\":\"kit\",\"epoch\":%d,\"seat\":%d,\"original_requested_tick\":%d,\"requested_tick\":%d,\"sampled_tick\":%d,\"target\":%d,\"reason\":\"%s\"}\n",
        k.lane_world_epoch(&rt.lane),
        rt.seat,
        plan.original,
        plan.due,
        plan.attempt_tick,
        rt.target,
        reason,
    )
    rt.failed = true
}

intent_prepare :: proc(rt: ^Runtime) {
    if !rt.scripted || rt.seat == 0 {
        return
    }

    c := &rt.intents

    if !c.initialized {
        for phase, i in INTENT_PHASES {
            due := (rt.baseline / 240) * 240 + phase

            if due <= rt.baseline {
                due += 240
            }

            c.plans[i] = {
                original = due,
                due      = due,
            }
        }

        c.initialized = true
    }

    if c.armed {
        return
    }

    head := rt.lane.ticker.tick
    chosen := -1

    for plan, i in c.plans {
        if common.scripted_action(plan.original, rt.seat).kind == .None {
            continue
        }

        if plan.due <= head + 8 && (chosen < 0 || plan.due < c.plans[chosen].due) {
            chosen = i
        }
    }

    if chosen < 0 {
        return
    }

    plan := c.plans[chosen]

    if (rt.target != 0 && plan.due > rt.target) || head >= plan.due + 8 {
        intent_fail(rt, plan, "no_eligible_fresh_tick")
        return
    }

    c.active = chosen
    c.armed = true
}

intent_sample :: proc(rt: ^Runtime, tick: u64) -> common.Action {
    c := &rt.intents

    if !c.armed {
        return {}
    }

    plan := &c.plans[c.active]

    // Only the actual live post-start Client defers NEW samples during recovery.
    // An existing candidate/issued tuple retains its original sampling behavior.
    if !plan.attempted && caller_client(rt) && rt.started && rt.reanchor_bootstrap != 0 {
        return {}
    }

    if tick < plan.due || (plan.attempted && tick != plan.attempt_tick) {
        return {}
    }

    if tick > plan.due + 8 {
        intent_fail(rt, plan^, "sample_window_exceeded")
        return {}
    }

    if !plan.attempted {
        // Only a first client sample needs a fresh authority slot. An existing
        // attempt keeps its identity, including after an aborted candidate.
        if !rt.ses.is_host && rt.lane.world != nil && rt.lane.world.network != nil {
            _, _, _, error := k.lane_world_accepted_input(&rt.lane, tick, rt.ses.me, 1)

            if error == .Ok {
                return {}
            }

            if error != .History_Missing {
                intent_fail(rt, plan^, "accepted_slot_unavailable")
                return {}
            }
        }

        plan.attempted = true
        plan.attempt_tick = tick
        plan.attempt_head = rt.lane.ticker.tick
        runtime_log(
            rt,
            "{\"event\":\"INTENT_ATTEMPT\",\"framework\":\"kit\",\"epoch\":%d,\"seat\":%d,\"original_requested_tick\":%d,\"requested_tick\":%d,\"sampled_head\":%d,\"sampled_tick\":%d,\"candidate_only\":true}\n",
            k.lane_world_epoch(&rt.lane),
            rt.seat,
            plan.original,
            plan.due,
            plan.attempt_head,
            tick,
        )
    }

    return common.scripted_action(plan.original, rt.seat)
}

intent_send :: proc(user: rawptr, peer: s.Peer_Id, bytes: []u8, channel: s.Channel) {
    rt := cast(^Runtime)user
    before := ng.wire_status(&rt.wire)
    rt.raw_send(rt.raw_send_user, peer, bytes, channel)
    after := ng.wire_status(&rt.wire)
    intent_note_send(rt, bytes, channel, before, after)
}

intent_note_send :: proc(rt: ^Runtime, bytes: []u8, channel: s.Channel, before, after: ng.Wire_Status) {
    if !rt.intents.armed ||
       !rt.intents.plans[rt.intents.active].attempted ||
       after.error != .Ok ||
       after.unavailable_recipients != before.unavailable_recipients ||
       channel != (rt.ses.is_host ? s.Channel.Reliable : s.Channel.Stream) {
        return
    }

    r := n.reader_make(bytes)

    if n.read_u8(&r) != s.SES_APP || n.read_u8(&r) != rt.lane.tag {
        return
    }

    kind := n.read_u8(&r)

    if kind != (rt.ses.is_host ? k.SIM_WORLD_ACCEPTED : k.SIM_WORLD_INPUT) {
        return
    }

    // Ordinary World v2: inspect the original public bytes; transport is NOT an
    // authority admission/outcome acknowledgement and never permits a retry.
    rev := n.read_u32(&r)
    schema := n.reader_view(&r, 32)
    epoch := n.read_u64(&r)
    bootstrap := u64(0)

    if kind == k.SIM_WORLD_INPUT {
        bootstrap = n.read_u64(&r)
    }

    head := n.read_u64(&r)
    first := n.read_u64(&r)
    count := int(n.read_u8(&r))
    entries := int(n.read_u8(&r))
    net := rt.lane.world.network

    if r.err ||
       rev != k.WORLD_NETWORK_REV ||
       epoch != k.lane_world_epoch(&rt.lane) ||
       count < 1 ||
       count > 8 ||
       entries < 1 ||
       entries > len(net.drivers) ||
       first == 0 ||
       first > head ||
       u64(count - 1) != head - first {
        return
    }

    expected_entries := 0

    for driver in net.drivers {
        if rt.ses.is_host || driver.player == rt.ses.me {
            expected_entries += 1
        }
    }

    if entries != expected_entries {
        return
    }

    if kind == k.SIM_WORLD_INPUT {
        protocol := k.lane_world_protocol_status(&rt.lane)

        if protocol.error != .Ok ||
           protocol.wire_revision != rev ||
           bootstrap == 0 ||
           bootstrap != protocol.bootstrap_sequence {
            return
        }
    }

    for byte, i in schema {
        if byte != net.config.identity.input_schema[i] {
            return
        }
    }

    active := rt.intents.active
    prior := rt.intents.plans[active]
    matched := false
    matched_sequence: u64

    for j in 0 ..< count {
        seen: u32

        for _ in 0 ..< entries {
            driver := int(n.read_u8(&r))
            origin := k.World_Input_Origin(n.read_u8(&r))
            sequence := n.read_u64(&r)

            if r.err || driver >= len(net.drivers) || driver >= 32 || seen & (u32(1) << u32(driver)) != 0 {
                return
            }

            seen |= u32(1) << u32(driver)
            declared := net.drivers[driver]

            if origin != .Submitted && origin != .Held && origin != .Authority {
                return
            }

            if !rt.ses.is_host &&
               (declared.player != rt.ses.me || origin != .Submitted || sequence != first + u64(j)) {
                return
            }

            codec: ^k.World_Value_Codec

            for &input in net.config.codec.inputs {
                if input.class == declared.class {
                    codec = &input.codec
                    break
                }
            }

            if codec == nil {
                return
            }

            blob := n.reader_view(&r, codec.wire_bytes)

            if r.err {
                return
            }

            if declared.class == 0 {
                value: common.Control

                if codec.local_bytes != size_of(value) ||
                   codec.decode(codec.user, blob, (cast([^]u8)&value)[:size_of(value)]) != .Ok {
                    return
                }
            } else if declared.class == 1 {
                value: common.Action

                if codec.local_bytes != size_of(value) ||
                   codec.decode(codec.user, blob, (cast([^]u8)&value)[:size_of(value)]) != .Ok {
                    return
                }

                if declared.player == rt.ses.me &&
                   first + u64(j) == prior.attempt_tick &&
                   sequence == prior.attempt_tick &&
                   origin == (rt.ses.is_host ? k.World_Input_Origin.Authority : k.World_Input_Origin.Submitted) &&
                   value == common.scripted_action(prior.original, rt.seat) {
                    if matched {
                        return
                    }

                    matched = true
                    matched_sequence = sequence
                }
            } else {
                return
            }
        }
    }

    if kind == k.SIM_WORLD_ACCEPTED {
        receipt_count := int(n.read_u8(&r))
        expected_receipts := 0

        for driver in net.drivers {
            if driver.class == 0 {
                expected_receipts += 1
            }
        }

        if receipt_count != expected_receipts {
            return
        }

        receipt_index := 0

        for driver in net.drivers {
            if driver.class == 0 {
                player := n.read_u64(&r)
                _ = n.read_u64(&r)
                available := n.read_u8(&r)
                _ = n.read_u64(&r)

                if r.err || player != u64(driver.player) || available > 1 {
                    return
                }

                receipt_index += 1
            }
        }

        if receipt_index != receipt_count {
            return
        }
    }

    if r.err || len(n.reader_remaining(&r)) != 0 || rt.intents.active != active || rt.intents.plans[active] != prior {
        return
    }

    if matched && !prior.transported {
        plan := &rt.intents.plans[active]
        plan.transported = true
        plan.packet_head = head
        plan.row_sequence = matched_sequence
    }
}

intent_published :: proc(rt: ^Runtime) {
    c := &rt.intents

    if !rt.scripted || !c.armed {
        return
    }

    plan := &c.plans[c.active]

    if !plan.attempted || rt.lane.ticker.tick < plan.attempt_tick {
        return
    }

    local: []u8
    have := false

    for &input in rt.lane.inputs {
        if input.id == 1 {
            local, have = k.input_read(&input.ring, plan.attempt_tick)
            break
        }
    }

    if !have || len(local) != size_of(common.Action) {
        return
    }

    value: common.Action
    copy((cast([^]u8)&value)[:size_of(value)], local)

    if value != common.scripted_action(plan.original, rt.seat) {
        intent_fail(rt, plan^, "published_input_changed")
        return
    }

    plan.published = true

    if !plan.transported {
        return
    }

    cp, error := k.lane_world_checkpoint(&rt.lane, plan.attempt_tick)

    if error != .Ok {
        intent_fail(rt, plan^, "published_checkpoint_unavailable")
        return
    }

    defer k.world_checkpoint_destroy(&cp)
    side, se := p.checkpoint_side(&cp, Side)

    if se != .Ok {
        intent_fail(rt, plan^, "published_side_unavailable")
        return
    }

    receipt := side.receipts[rt.seat - 1]
    runtime_log(
        rt,
        "{\"event\":\"ISSUED\",\"framework\":\"kit\",\"epoch\":%d,\"seat\":%d,\"kind\":%d,\"original_requested_tick\":%d,\"requested_tick\":%d,\"sampled_head\":%d,\"sampled_tick\":%d,\"submitted_tick\":%d,\"sequence\":%d,\"packet_head\":%d,\"published\":true,\"rebased_before_sampling\":%v,\"recovery_serial\":%d,\"action_timing\":\"Scheduled\",\"transport\":\"existing_class1_input_stream\",\"local_receipt_kind\":%d,\"local_receipt_applied\":%v,\"query_total\":%d}\n",
        k.lane_world_epoch(&rt.lane),
        rt.seat,
        value.kind,
        plan.original,
        plan.due,
        plan.attempt_head,
        plan.attempt_tick,
        plan.attempt_tick,
        plan.row_sequence,
        plan.packet_head,
        plan.rebased,
        plan.recovery_serial,
        receipt.kind,
        receipt.applied,
        side.game.queries,
    )

    if plan.original > max(u64) - 240 {
        intent_fail(rt, plan^, "scenario_tick_exhausted")
        return
    }

    next := plan.original + 240
    plan^ = {
        original = next,
        due      = next,
    }
    c.armed = false
}

intent_rebase :: proc(rt: ^Runtime, old_head, new_head, old_serial, new_serial: u64) {
    if !rt.scripted || !rt.intents.initialized {
        return
    }

    for &plan in rt.intents.plans {
        if common.scripted_action(plan.original, rt.seat).kind == .None {
            continue
        }

        if plan.published {
            if plan.attempt_tick <= new_head {
                intent_fail(rt, plan, "published_sample_lacked_packet_evidence")
            }

            continue
        }

        if plan.attempted ||
           plan.published ||
           plan.transported ||
           plan.attempt_tick != 0 ||
           plan.attempt_head != 0 ||
           plan.packet_head != 0 ||
           plan.row_sequence != 0 {
            continue
        }

        if plan.due <= new_head {
            if new_head == max(u64) {
                intent_fail(rt, plan, "fresh_tick_overflow")
                return
            }

            prior := plan
            plan.due = new_head + 1
            plan.rebased = true
            plan.recovery_serial = new_serial
            runtime_log(
                rt,
                "{\"event\":\"INTENT_REBASE\",\"framework\":\"kit\",\"intent_contract_version\":2,\"epoch\":%d,\"seat\":%d,\"player\":%d,\"class\":1,\"original_requested_tick\":%d,\"old_current_due\":%d,\"new_current_due\":%d,\"old_head\":%d,\"new_head\":%d,\"old_serial\":%d,\"new_serial\":%d,\"cause\":\"validated_reset\",\"committed\":false,\"pre_attempted\":%v,\"pre_published\":%v,\"pre_transported\":%v,\"pre_attempt_tick\":%d,\"pre_attempt_head\":%d,\"pre_packet_head\":%d,\"pre_row_sequence\":%d,\"pre_recovery_serial\":%d}\n",
                k.lane_world_epoch(&rt.lane),
                rt.seat,
                rt.ses.me,
                plan.original,
                prior.due,
                plan.due,
                old_head,
                new_head,
                old_serial,
                new_serial,
                prior.attempted,
                prior.published,
                prior.transported,
                prior.attempt_tick,
                prior.attempt_head,
                prior.packet_head,
                prior.row_sequence,
                prior.recovery_serial,
            )

            if rt.target != 0 && plan.due > rt.target {
                intent_fail(rt, plan, "fresh_tick_after_end")
            }
        }
    }
}

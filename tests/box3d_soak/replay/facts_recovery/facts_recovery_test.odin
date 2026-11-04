// Public complete-physics regression: real signed facts are sufficient to
// bridge an ordinary Snapshot ahead by >8 but less than the retained history.
package replay_facts_recovery_test

import "core:encoding/json"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import a "godot:tests/box3d_soak/replay/action_scope_case_a"

TARGET :: u64(20)
NOW :: u64(340)
MAX_FINAL_PUMPS :: 4

Observation :: struct {
    scope, stage:                                                                         string,
    setup_complete, within_existing_history, facts_ready:                                 bool,
    old_snapshot_captured, old_ack_matches, target_snapshot_captured:                     bool,
    old_header, target_header:                                                            net.Physics_Chunk_Header,
    old_ack:                                                                              net.Physics_Ack,
    initial_head, initial_confirmed, generation, serial, authority_head:                  u64,
    initial_gap, history, prediction, facts_contiguous, authority_seen:                   u64,
    head_after_facts, confirmed_after_facts, head_before_target, confirmed_before_target: u64,
    final_head, final_confirmed, final_generation, final_serial:                          u64,
    final_phase:                                                                          net.Phase,
    resyncs_before, resyncs_after, catchups_before, catchups_after:                       u64,
    final_notice:                                                                         net.Resync_Notice,
    final_pumps:                                                                          int,
    full5_available, full5_equal, final_ACK_pumped, same_server_scope:                    bool,
    prospective_criterion:                                                                bool,
    raw_capture_count:                                                                    int,
    all_saved_bytes_intact, all_drops_ok, cleanup_observed:                               bool,
    native_live, wrapper_live, provider_live, odin_live:                                  u64,
}

header :: proc(c: ^a.Case, tick: u64) -> (net.Physics_Chunk_Header, bool) {
    for saved in c.gates[1].saved[:c.gates[1].count] {
        if !saved.snapshot || saved.tick != tick {
            continue
        }

        meta, fingerprint, ie := sc.inspect(saved.data.bytes)

        if ie.error != .None || fingerprint != c.pair.client.physics.schemas.chunk.fingerprint {
            continue
        }

        _, body, ue := sc.unpack_bytes(fingerprint, saved.data.bytes, meta)

        if ue.error != .None || len(body) < c.pair.client.physics.schemas.chunk.wire_size {
            continue
        }

        value: net.Physics_Chunk_Header

        if sc.decode(&c.pair.client.physics.schemas.chunk, &value, body[:c.pair.client.physics.schemas.chunk.wire_size]).error ==
           .None {
            return value, true
        }
    }

    return {}, false
}

old_ack_matches :: proc(c: ^a.Case, expected: net.Physics_Chunk_Header) -> (net.Physics_Ack, bool) {
    for saved in c.gates[0].saved[:c.gates[0].count] {
        meta, fingerprint, ie := sc.inspect(saved.data.bytes)

        if ie.error != .None || fingerprint != c.pair.client.physics.schemas.ack.fingerprint {
            continue
        }

        ack: net.Physics_Ack
        _, de := sc.unpack(&c.pair.client.physics.schemas.ack, &ack, saved.data.bytes, meta)

        if de.error == .None &&
           saved.packet.channel == .Reliable &&
           ack.id == expected.id &&
           ack.generation == expected.generation &&
           ack.serial == expected.serial &&
           ack.digest == expected.digest {
            return ack, true
        }
    }

    return {}, false
}

exercise :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) -> bool {
    o.stage = "existing_public_pair"

    if !a.open(t, c) {
        return false
    }

    p := &c.pair
    o.initial_head = p.client.timeline.head
    o.initial_confirmed = p.client.timeline.confirmed
    o.generation = p.client.generation
    o.serial = p.client.serial
    o.history = u64(p.client.cfg.history)
    o.prediction = u64(p.client.cfg.max_prediction)
    o.initial_gap = TARGET - o.initial_head
    o.within_existing_history =
        o.history == 128 &&
        o.prediction == 8 &&
        TARGET > o.initial_head &&
        o.initial_gap > o.prediction &&
        o.initial_gap < o.history

    if !a.check(t, o.within_existing_history, "real target ahead>8 and retained gap<history128") {
        return false
    }

    o.resyncs_before = p.client.stats.resyncs
    o.catchups_before = p.client.stats.snapshot_catchups
    c.gates[1].hold_snapshots = true
    o.stage = "ordinary_authority_steps_while_snapshot_held"

    for p.server.timeline.head < TARGET {
        now := (p.server.timeline.head + 1) * 17

        if !a.server_pump(t, c, now) || !a.none(t, net.server_step(&p.server), "real ordinary authority step") {
            return false
        }
    }

    o.authority_head = p.server.timeline.head

    if !a.client_pump(t, c, NOW) {
        return false
    }

    o.facts_contiguous = p.client.facts_contiguous
    o.authority_seen = p.client.authority_tick_seen
    o.head_after_facts = p.client.timeline.head
    o.confirmed_after_facts = p.client.timeline.confirmed
    o.facts_ready = o.facts_contiguous >= TARGET

    if !a.check(t, o.facts_ready, "actual validated contiguous facts reach target20") {
        return false
    }

    o.old_header, o.old_snapshot_captured = header(c, 2)

    if !a.check(t, o.old_snapshot_captured, "genuine held ordinary Snapshot2") {
        return false
    }

    // Release the actual old Snapshot. Its real ACK unlocks the authority's
    // current Snapshot; no synthetic ACK or manual transmission state is used.
    o.stage = "old_snapshot_actual_ACK"
    c.gates[1].hold_snapshots = false
    c.gates[1].release_snapshots = true

    if !a.client_pump(t, c, NOW) {
        return false
    }

    c.gates[1].hold_snapshots = true
    c.gates[1].release_snapshots = false

    if !a.server_pump(t, c, NOW) {
        return false
    }

    o.old_ack, o.old_ack_matches = old_ack_matches(c, o.old_header)

    if !a.check(t, o.old_ack_matches, "actual Snapshot2 ACK id/digest/generation/serial") {
        return false
    }

    o.stage = "deliver_actual_target_and_bounded_public_pumps"
    c.gates[1].hold_snapshots = false
    c.gates[1].release_snapshots = true
    // No capture-only client pump: the next public pump receives Snapshot20
    // while it is genuinely more than8 ahead of the actual confirmed frontier.
    o.head_before_target = p.client.timeline.head
    o.confirmed_before_target = p.client.timeline.confirmed

    if !a.check(
        t,
        TARGET > o.confirmed_before_target &&
        TARGET - o.confirmed_before_target > o.prediction &&
        TARGET - o.confirmed_before_target < o.history,
        "immediate pre-delivery Snapshot20 gap>8 and<history128",
    ) {
        return false
    }

    for _ in 0 ..< MAX_FINAL_PUMPS {
        if !a.client_pump(t, c, NOW) {
            return false
        }

        o.final_pumps += 1

        if p.client.phase != .Running || p.client.timeline.confirmed >= TARGET {
            break
        }
    }

    // The ordinary receive gate already copied the real packet. Inspect it
    // afterward, without inserting a client pump to capture/hold it first.
    o.target_header, o.target_snapshot_captured = header(c, TARGET)

    if !a.check(
        t,
        o.target_snapshot_captured && o.target_header.generation == o.generation && o.target_header.serial == o.serial,
        "actual delivered current-scope signed ordinary Snapshot20",
    ) {
        return false
    }

    o.setup_complete = true
    o.final_phase = p.client.phase
    o.final_head = p.client.timeline.head
    o.final_confirmed = p.client.timeline.confirmed
    o.final_generation = p.client.generation
    o.final_serial = p.client.serial
    o.resyncs_after = p.client.stats.resyncs
    o.catchups_after = p.client.stats.snapshot_catchups
    o.final_notice = p.client.resync_notice

    if o.final_phase == .Running && o.final_head >= TARGET && o.final_confirmed >= TARGET {
        authority, ae := r.capture_complete(&p.server.timeline, TARGET)

        if ae == .None {
            defer r.complete_checkpoint_destroy(&authority)
            replica, ce := r.capture_complete(&p.client.timeline, TARGET)

            if ce == .None {
                defer r.complete_checkpoint_destroy(&replica)
                o.full5_available = true
                o.full5_equal = a.complete_same(c, &authority, &replica)
            }
        }

        if !a.server_pump(t, c, NOW) {
            return false
        }

        o.final_ACK_pumped = true

        for peer in p.server.peers {
            if !peer.local && peer.seat == p.client.seat {
                o.same_server_scope = peer.serial == o.serial && peer.generation == o.generation
            }
        }
    }

    o.prospective_criterion =
        o.final_phase == .Running &&
        o.final_head >= TARGET &&
        o.final_confirmed >= TARGET &&
        o.final_generation == o.generation &&
        o.final_serial == o.serial &&
        o.resyncs_after == o.resyncs_before &&
        o.catchups_after == o.catchups_before &&
        o.full5_available &&
        o.full5_equal &&
        o.final_ACK_pumped &&
        o.same_server_scope
    return true
}

cleanup :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) {
    p := &c.pair
    drops := true
    intact := true

    if p.client.initialized {
        drops = net.client_destroy(&p.client) == .None && drops
    }

    if p.server.initialized {
        drops = net.server_destroy(&p.server) == .None && drops
    }

    for &link in c.links {
        if link.ready {
            drops = rec.link_destroy(&link) == .None && drops
        }
    }

    for &gate in c.gates {
        for &saved in gate.saved[:gate.count] {
            o.raw_capture_count += 1
            intact = bd.hash_bytes(saved.data.bytes) == saved.hash && intact
            net.complete_data_destroy(&saved.data)
        }
    }

    if p.codec.ready {
        drops = ph.network_codec_destroy(&p.codec) == .None && drops
    }

    if p.catalog._handle != nil {
        drops = b.recovery_catalog_destroy(&p.catalog) == .Ok && drops
    }

    if len(p.memory.packets) > 0 {
        tr.memory_destroy(&p.memory)
    }

    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    o.native_live = engine.live_bytes
    o.wrapper_live = wrapper.live_bytes
    o.provider_live = ph.allocation_stats().live_bytes
    o.all_saved_bytes_intact = intact
    o.all_drops_ok = drops && es == .Ok && ws == .Ok
    o.cleanup_observed =
        o.all_saved_bytes_intact && o.all_drops_ok && o.native_live == 0 && o.wrapper_live == 0 && o.provider_live == 0
    testing.expect(t, o.cleanup_observed, "all actual captured bytes intact and complete Native/provider cleanup")
}

@(test)
contiguous_signed_facts_recover_ahead_snapshot_without_resync :: proc(t: ^testing.T) {
    backing := context.allocator
    tracking: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking, backing, backing)
    context.allocator = mem.tracking_allocator(&tracking)
    c := new(a.Case)
    o := Observation {
        scope = "generic4_actualCompleteCodec_publicSessionMemory_nilOwner_static_NOT_SDK32_ENet_CPU_or_liveCause",
    }
    reached := exercise(t, c, &o)
    cleanup(t, c, &o)
    free(c)
    o.odin_live = u64(tracking.current_memory_allocated)
    testing.expect_value(t, o.odin_live, u64(0))
    context.allocator = backing
    mem.tracking_allocator_destroy(&tracking)

    if reached && o.setup_complete && o.cleanup_observed && o.odin_live == 0 {
        o.stage = "ONLY_PROSPECTIVE_FACT_RECOVERY_CRITERION"
        testing.expect(
            t,
            o.prospective_criterion,
            "EXPECTED baseline RED: retained signed contiguous facts must permit bounded complete-physics catchup through20 without Resync/newWelcome",
        )
    }

    bytes, error := json.marshal(o)
    testing.expect(t, error == nil)

    if error == nil {
        defer delete(bytes)
        testing.expect(t, os.write_entire_file("facts-recovery-observation.json", bytes) == nil)
    }
}

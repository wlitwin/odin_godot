package kit_chunk_batch_test

import "core:fmt"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import p "godot:kit/physics"
import k "godot:kit/sim"
import s "godot:kit/session"
import n "godot:kit/net"
import f "godot:tests/kit_box3d_net"

Header :: struct {
    sequence, tick: u64,
    index, count:   int,
}

header :: proc(parcel: f.Parcel) -> Header {
    r := n.reader_make(parcel.bytes)
    assert(n.read_u8(&r) == s.SES_APP)
    _ = n.read_u8(&r)
    assert(n.read_u8(&r) == k.SIM_WORLD_CHUNK)
    assert(n.read_u32(&r) == k.WORLD_NETWORK_REV)
    _ = n.read_u8(&r)
    sequence := n.read_u64(&r)
    _ = n.read_u64(&r)
    tick := n.read_u64(&r)
    _ = n.read_u32(&r)
    index := int(n.read_u16(&r))
    count := int(n.read_u16(&r))
    assert(!r.err)
    return {sequence, tick, index, count}
}

deliver :: proc(client: ^f.Box, parcel: f.Parcel) {
    r := n.reader_make(parcel.bytes)
    s.session_handle_packet(&client.ses, s.HOST_PEER, &r, parcel.channel)
}

expect_pair :: proc(t: ^testing.T, host, client: ^f.Box, tick: u64) {
    a, c: k.World_Diagnostic_Frame
    ae := k.lane_world_diagnostic_frame(&host.lane, tick, &a)
    ce := k.lane_world_diagnostic_frame(&client.lane, tick, &c)
    testing.expect_value(t, ae, k.World_Error.Ok)
    testing.expect_value(t, ce, k.World_Error.Ok)

    if ae == .Ok && ce == .Ok {
        for part in bd.Part {
            testing.expect_value(t, mem.compare(a.view.parts[part], c.view.parts[part]), 0)
        }
    }

    k.world_diagnostic_frame_destroy(&a)
    k.world_diagnostic_frame_destroy(&c)
}

// No wire bytes are changed or lost. A and B come from the REAL public sender.
// We deliver complete A and first B in one receive batch, then let the normal
// frame phase apply A, then deliver every remaining B byte and all of newer C.
@(test)
completed_assembly_must_not_consume_next_transfers_first_chunk :: proc(t: ^testing.T) {
    host, client: f.Box
    f.start_pair(&host, &client)
    cat := f.catalog()
    f.setup(&host, 32, &cat)
    f.setup(&client, 32, &cat)
    f.bootstrap(t, &host, &client)

    for _ in 0 ..< 6 {
        testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 1)
    }

    for parcel in client.out {
        delete(parcel.bytes)
    }

    clear(&client.out)

    for _ in 0 ..< 6 {
        testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1)
    }

    a, batch: [dynamic]f.Parcel

    for parcel in host.out {
        if parcel.channel == .Reliable && len(parcel.bytes) > 2 && parcel.bytes[2] == k.SIM_WORLD_CHUNK {
            h := header(parcel)

            if h.tick == 3 {
                append(&a, parcel)
            } else {
                assert(h.tick == 6)
                append(&batch, parcel)
            }
        } else {
            deliver(&client, parcel)
            delete(parcel.bytes)
        }
    }

    clear(&host.out)
    testing.expect(t, len(a) >= 2 && len(batch) >= 2)
    assert(len(a) > 0 && len(batch) > 1)
    ah, bh := header(a[0]), header(batch[0])
    assert(bh.sequence > ah.sequence)
    before, be := k.lane_world_checkpoint(&client.lane, 6)
    testing.expect_value(t, be, k.World_Error.Ok)
    fields, effects := client.proxies, client.effects

    for parcel in a {
        testing.expect_value(t, parcel.channel, s.Channel.Reliable)
        deliver(&client, parcel)
    }

    deliver(&client, batch[0]) // B's first chunk is rejected while complete A is pending.
    net := client.lane.world.network
    fmt.printf(
        "KIT_BATCH_BEFORE_APPLY A_seq=%d A_chunks=%d B_seq=%d B_chunks=%d held_seq=%d received=%d chunks=%d status=%v ready=%t resync=%t\n",
        ah.sequence,
        len(a),
        bh.sequence,
        len(batch),
        net.transfer_sequence,
        net.transfer_received,
        net.transfer_chunks,
        net.status,
        net.ready,
        k.lane_world_needs_resync(&client.lane),
    )
    after, ae := k.lane_world_checkpoint(&client.lane, 6)
    testing.expect_value(t, ae, k.World_Error.Ok)
    same, ee := k.world_checkpoint_equal(&before, &after)
    testing.expect_value(t, ee, k.World_Error.Ok)
    testing.expect(t, same)
    testing.expect_value(t, client.proxies, fields)
    testing.expect_value(t, client.effects, effects)
    k.world_checkpoint_destroy(&before)
    k.world_checkpoint_destroy(&after)
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(3))
    expect_pair(t, &host, &client, 3)
    after_a, ape := k.lane_world_checkpoint(&client.lane, 6)
    testing.expect_value(t, ape, k.World_Error.Ok)
    after_a_fields, after_a_effects := client.proxies, client.effects

    for parcel in batch[1:] {
        deliver(&client, parcel)
    }

    testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction), k.World_Error.Ok)
    c_count := 0

    for parcel in host.out {
        testing.expect_value(t, parcel.channel, s.Channel.Reliable)
        deliver(&client, parcel)
        c_count += 1
        delete(parcel.bytes)
    }

    clear(&host.out)
    partial, pte := k.lane_world_checkpoint(&client.lane, 6)
    testing.expect_value(t, pte, k.World_Error.Ok)
    held, he := k.world_checkpoint_equal(&after_a, &partial)
    testing.expect_value(t, he, k.World_Error.Ok)
    testing.expect(t, held)
    testing.expect_value(t, client.proxies, after_a_fields)
    testing.expect_value(t, client.effects, after_a_effects)
    k.world_checkpoint_destroy(&after_a)
    k.world_checkpoint_destroy(&partial)
    _ = k.lane_frame(&client.lane, 0)
    status := k.lane_world_network_status(&client.lane)
    fmt.printf(
        "KIT_BATCH_ALL_DELIVERED A=%d/%d B=%d/%d C=%d held_seq=%d held_tick=%d received=%d/%d seen0=%t status=%v ready=%t resync=%t head=%d confirmed=%d effects=%d authority_effects=%d\n",
        len(a),
        ah.count,
        len(batch),
        bh.count,
        c_count,
        net.transfer_sequence,
        net.transfer_tick,
        net.transfer_received,
        net.transfer_chunks,
        net.transfer_seen[0],
        status.error,
        status.ready,
        status.needs_resync,
        status.head,
        status.confirmed,
        client.effects,
        host.effects,
    )
    // Desired regression outcome: all real Reliable B bytes were delivered and
    // ordinary frame pumping must reach B. This fails on the stranded partial B.
    testing.expect_value(t, status.confirmed, u64(6))

    if status.confirmed == 6 {
        expect_pair(t, &host, &client, 6)
        testing.expect_value(t, client.effects, host.effects)
    }

    for parcel in a {
        delete(parcel.bytes)
    }

    delete(a)

    for parcel in batch {
        delete(parcel.bytes)
    }

    delete(batch)
    f.destroy(&client)
    f.destroy(&host)
    b.recovery_catalog_destroy(&cat)
    engine, _ := b.engine_allocation_stats()
    wrapper, _ := b.snapshot_allocation_stats()
    fmt.printf(
        "KIT_BATCH_TEARDOWN native=%d wrapper=%d provider=%d checkpoints=%d diagnostics=%d\n",
        engine.live_bytes,
        wrapper.live_bytes,
        p.owned_bytes(),
        k.world_checkpoint_owned_bytes(),
        k.world_diagnostic_frame_owned_bytes(),
    )
    testing.expect(
        t,
        engine.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        p.owned_bytes() == 0 &&
        k.world_checkpoint_owned_bytes() == 0 &&
        k.world_diagnostic_frame_owned_bytes() == 0,
    )
}

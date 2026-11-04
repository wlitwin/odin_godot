package replay_physics_native_net_test

import "core:testing"
import "core:mem"
import r "godot:replay"
import b "godot:box3d"
import ph "godot:replay/physics"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import f "../fixture"

@(test)
actual_recovery_transfer_imports_complete_archive_then_resumes_native_authority :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    archive: net.Checkpoint(f.Game, f.Control, f.Action, 2)
    testing.expect_value(t, net.checkpoint_capture(&pair.server, &archive), net.Error.None)
    defer net.checkpoint_destroy(&archive)
    memory: tr.Memory
    testing.expect(t, tr.memory_init(&memory, cfg = {2, 128, 1200, 4096}))
    defer tr.memory_destroy(&memory)
    ends: [2]tr.Memory_Endpoint

    for &endpoint, index in ends {
        tr.memory_open(&memory, &endpoint, tr.Peer_Id(index + 1))
    }

    sender: rec.Sender
    receiver: rec.Receiver(f.Game, f.Control, f.Action, f.Event, 2)
    scope := rec.Scope {
        room    = 7,
        epoch   = pair.server.cfg.epoch,
        binding = 9,
        content = pair.server.cfg.content,
    }
    testing.expect_value(t, rec.sender_init(&sender, scope, 2, tr.memory_transport(&ends[0])), rec.Error.None)
    defer rec.sender_destroy(&sender)
    testing.expect_value(
        t,
        rec.receiver_init(&receiver, scope, 1, tr.memory_transport(&ends[1]), pair.server.model),
        rec.Error.None,
    )
    defer rec.receiver_destroy(&receiver)
    sender.compress = true
    sender.shuffle = true
    testing.expect_value(t, rec.sender_publish(&sender, &archive, pair.server.model, 0), rec.Error.None)
    testing.expect(t, sender.layout.schema == nil && receiver.transfer.layout.schema == nil)
    testing.expect(t, sender.budget.attached && receiver.transfer.budget.attached)
    buffer: [1200]u8

    for tick in 1 ..= 300 {
        now := u64(tick * 10)
        tr.memory_advance(&memory, now)

        for &endpoint, index in ends {
            wire := tr.memory_transport(&endpoint)

            for _ in 0 ..< 128 {
                packet := tr.receive(&wire, buffer[:])

                if packet.state != .Received {
                    break
                }

                if index == 0 {
                    rec.sender_receive(&sender, packet.from, buffer[:packet.count], now)
                } else {
                    rec.receiver_receive(&receiver, packet.from, buffer[:packet.count], now, packet.channel)
                }
            }
        }

        rec.sender_update(&sender, now)
        rec.receiver_update(&receiver, now)

        if sender.phase == .Complete {
            break
        }
    }

    testing.expect_value(t, sender.phase, rec.Phase.Complete)
    receipt, ready := rec.receiver_latest(&receiver)
    testing.expect(t, ready)
    decoded, found := rec.receiver_checkpoint(&receiver, receipt.archive)
    testing.expect(t, found)

    if !found {
        return
    }

    resumed: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            decoded,
            pair.server.model,
            {},
            {epoch = 2, local_seat = 1, retain_membership = true, preserve_pending = true},
        ),
        net.Error.None,
    )
    left, le := r.capture_complete(&pair.server.timeline, pair.server.timeline.head)
    right, re := r.capture_complete(&resumed.timeline, resumed.timeline.head)
    testing.expect(t, le == .None && re == .None)
    defer r.complete_checkpoint_destroy(&left)
    defer r.complete_checkpoint_destroy(&right)
    n, _ := ph.dump(&left, nil)
    a, z := make([]u8, int(n)), make([]u8, int(n))
    defer delete(a)
    defer delete(z)
    ph.dump(&left, a)
    ph.dump(&right, z)
    testing.expect_value(t, mem.compare(a, z), 0)
    testing.expect_value(t, left.frame.state, right.frame.state)
}

@(test)
actual_old_authority_rejoin_seeds_owned_complete_state_after_old_runtime_destruction :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    model, cfg := pair.server.model, pair.server.cfg
    owner, error := net.server_departing_complete(&pair.server)
    testing.expect_value(t, error, net.Error.None)
    defer net.complete_departing_destroy(&owner)
    net.server_destroy(&pair.server)
    net.client_destroy(&pair.client)
    client: net.Client(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, net.client_init(&client, model, {}, net.Token{0 = 1}, cfg = cfg), net.Error.None)
    defer net.client_destroy(&client)
    testing.expect_value(t, net.client_seed_departing(&client, owner.metadata), net.Error.Incomplete_State)
    testing.expect_value(t, net.client_seed_departing_complete(&client, &owner), net.Error.None)
    before, be := r.capture_complete(&client.timeline, owner.checkpoint.frame.tick)
    testing.expect_value(t, be, r.Error.None)
    defer r.complete_checkpoint_destroy(&before)
    n, _ := ph.dump(&owner.checkpoint, nil)
    a, z := make([]u8, int(n)), make([]u8, int(n))
    defer delete(a)
    defer delete(z)
    ph.dump(&owner.checkpoint, a)
    ph.dump(&before, z)
    testing.expect_value(t, mem.compare(a, z), 0)
    testing.expect_value(t, net.client_authority(&client, 2, {}), net.Error.None)
    testing.expect_value(t, client.phase, net.Phase.Joining)
    testing.expect(t, client.recovering && client.has_world)
    // The embedding still owns its immutable codec until the new client closes.
    net.client_destroy(&client)
    tr.memory_destroy(&pair.memory)
    testing.expect_value(t, ph.network_codec_destroy(&pair.codec), net.Error.None)
    b.recovery_catalog_destroy(&pair.catalog)
}

package main
import "core:fmt"
import "core:os"
import "core:mem"
import "core:strconv"
import r "godot:replay"
import sc "godot:replay/schema"
import net "godot:replay/net"
import c "godot:replay/compress"
import game "sample:game"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

main :: proc() {
    assert(len(os.args) == 4)
    wire, read := os.read_entire_file(os.args[1], context.allocator)
    assert(read == nil)
    defer delete(wire)
    size, parsed := strconv.parse_int(os.args[2])
    assert(parsed && size > 0 && size <= c.MAX_BYTES)
    raw := make([]u8, size)
    defer delete(raw)
    scratch := make([]u8, size)
    defer delete(scratch)
    assert(c.decode(wire, raw, scratch))
    cp := new(net.Checkpoint(game.World, game.Control, game.Action, game.SEATS))
    defer free(cp)
    defer net.checkpoint_destroy(cp)
    assert(net.checkpoint_decode(cp, raw, game.model(), game.CONTENT) == .None)
    assert(os.write_entire_file(os.args[3], raw) == nil)
    // Exercise the actual typed recovery sender/receiver with this captured world.
    network: tr.Memory
    assert(
        tr.memory_init(
            &network,
            771,
            {2, 256, 1200, 131072},
            {
                latency_ticks = 30,
                jitter_ticks = 20,
                loss_permyriad = 1000,
                duplicate_permyriad = 1000,
                retry_ticks = 3,
            },
        ),
    )
    defer tr.memory_destroy(&network)
    ends: [2]tr.Memory_Endpoint

    for &end, i in ends {
        assert(tr.memory_open(&network, &end, tr.Peer_Id(i + 1)))
    }

    sender: rec.Sender
    receiver := new(rec.Receiver(game.World, game.Control, game.Action, game.Event, game.SEATS))
    defer free(receiver)
    codec: net.Checkpoint_Codec
    assert(net.checkpoint_codec_init(&codec, game.World, game.Control, game.Action, game.Event, game.SEATS) == .None)
    defer net.checkpoint_codec_destroy(&codec)
    scope := rec.Scope{7, cp.header.epoch, 3, game.CONTENT}
    assert(rec.sender_init(&sender, scope, 2, tr.memory_transport(&ends[0])) == .None)
    defer rec.sender_destroy(&sender)
    assert(rec.receiver_init(receiver, scope, 1, tr.memory_transport(&ends[1]), game.model()) == .None)
    defer rec.receiver_destroy(receiver)
    sender.compress, sender.shuffle = true, true
    assert(rec.sender_publish(&sender, cp, game.model(), 0, &codec) == .None && sender.wire_layout != 0)
    assert(mem.compare(sender.bytes, raw) == 0)
    tx, rx := tr.memory_transport(&ends[0]), tr.memory_transport(&ends[1])
    packet: [1200]u8

    for now := u64(10); now < 15000; now += 10 {
        tr.memory_advance(&network, now)

        for {
            p := tr.receive(&tx, packet[:])

            if p.state != .Received {
                break
            }

            rec.sender_receive(&sender, p.from, packet[:p.count], now)
        }

        for {
            p := tr.receive(&rx, packet[:])

            if p.state != .Received {
                break
            }

            rec.receiver_receive(receiver, p.from, packet[:p.count], now)
        }

        rec.sender_update(&sender, now)
        rec.receiver_update(receiver, now)

        if sender.phase == .Complete {
            break
        }
    }

    assert(sender.phase == .Complete && receiver.stats.shuffled_archives == 1)
    installed, found := rec.receiver_checkpoint(receiver, sender.archive)
    assert(found)
    installed_bytes, encoded_error := net.checkpoint_encode(installed, game.model(), codec = &codec)
    defer delete(installed_bytes)
    assert(encoded_error == .None && mem.compare(installed_bytes, raw) == 0)
    fmt.printf(
        "CHECKPOINT_LAYOUT_RECOVERY_OK raw=%d wire=%d saved=%d retries=%d\n",
        len(raw),
        len(sender.wire_bytes),
        sender.stats.shuffle_bytes_saved,
        sender.stats.retries,
    )
    // Offline layout diagnostic only. No new transfer format is implied.
    header, settings, frame: sc.Schema
    assert(sc.init(&header, net.Checkpoint_Header).error == .None)
    defer sc.destroy(&header)
    assert(sc.init(&settings, net.Checkpoint_Settings).error == .None)
    defer sc.destroy(&settings)
    assert(sc.init(&frame, r.Frame(game.World)).error == .None)
    defer sc.destroy(&frame)
    offset := sc.HEADER_BYTES + header.wire_size + settings.wire_size
    shuffled := make([]u8, size)
    defer delete(shuffled)
    copy(shuffled, raw)
    assert(sc.shuffle(&frame, raw[offset:offset + frame.wire_size], shuffled[offset:offset + frame.wire_size]))
    encoded := make([]u8, size)
    defer delete(encoded)
    work := new(c.Workspace)
    defer free(work)
    plain, ok := c.encode(raw, encoded, work)
    assert(ok)
    grouped, better := c.encode(shuffled, encoded, work)
    assert(better)
    roundtrip := make([]u8, size)
    defer delete(roundtrip)
    assert(c.decode(encoded[:grouped], roundtrip, scratch))
    assert(sc.unshuffle(&frame, roundtrip[offset:offset + frame.wire_size], scratch[:frame.wire_size]))
    copy(roundtrip[offset:offset + frame.wire_size], scratch[:frame.wire_size])
    assert(mem.compare(raw, roundtrip) == 0)
    fmt.println("CHECKPOINT_FRAME_GROUPED_ROUNDTRIP_OK")

    for stride in ([5]int{2, 4, 8, 16, 32}) {
        copy(shuffled, raw)
        rows := len(raw) / stride

        for lane in 0 ..< stride {
            for row in 0 ..< rows {
                shuffled[lane * rows + row] = raw[row * stride + lane]
            }
        }

        count, valid := c.encode(shuffled, encoded, work)
        assert(valid)
        fmt.printf("CHECKPOINT_BYTE_PLANES stride=%d encoded=%d\n", stride, count)
    }

    living := 0

    for alive, i in cp.frame.state.mobs.alive {
        if alive && cp.frame.state.mobs.values[i].hp > 0 {
            living += 1
        }
    }

    fmt.printf(
        "CHECKPOINT_CAPTURE_VALID tick=%d living=%d raw=%d captured_wire=%d plain=%d frame_grouped=%d frame_offset=%d frame_bytes=%d\n",
        cp.frame.tick,
        living,
        size,
        len(wire),
        plain,
        grouped,
        offset,
        frame.wire_size,
    )
}

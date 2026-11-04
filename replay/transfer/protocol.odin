package replay_transfer

import "core:crypto/sha2"
import "core:mem"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

@(private)
codecs_init :: proc(c: ^Codecs, allocator: mem.Allocator) -> bool {
    types := [?]typeid{Offer, Chunk, Progress, Ready, Failed, Compressed_Offer, Shuffled_Offer}
    parts := [?]^sc.Schema {
        &c.offer,
        &c.chunk,
        &c.progress,
        &c.ready,
        &c.failure,
        &c.compressed_offer,
        &c.shuffled_offer,
    }

    for part, i in parts {
        if sc.init(part, types[i], allocator = allocator).error != .None {
            return false
        }
    }

    return true
}

@(private)
codecs_destroy :: proc(c: ^Codecs) {
    parts := [?]^sc.Schema {
        &c.offer,
        &c.chunk,
        &c.progress,
        &c.ready,
        &c.failure,
        &c.compressed_offer,
        &c.shuffled_offer,
    }

    for part in parts {
        sc.destroy(part)
    }

    c^ = {}
}

hash :: proc(bytes: []u8) -> [32]u8 {
    ctx: sha2.Context_256
    sha2.init_256(&ctx)
    sha2.update(&ctx, bytes)
    result: [32]u8
    sha2.final(&ctx, result[:])
    return result
}

@(private)
send :: proc(
    wire: ^tr.Transport,
    to: tr.Peer_Id,
    bytes: []u8,
    clock: ^Clock,
    remaining: ^int,
    stats: ^Stats,
    channel: tr.Channel = .Unreliable,
) -> bool {
    if len(bytes) > remaining^ || f64(len(bytes)) > clock.budget {
        stats.deferred += 1
        return false
    }

    if tr.send(wire, to, channel, bytes) != .Sent {
        stats.deferred += 1
        return false
    }

    remaining^ -= len(bytes)
    clock.budget -= f64(len(bytes))
    stats.tx_packets += 1
    stats.tx_bytes += u64(len(bytes))
    return true
}

@(private)
send_value :: proc(
    wire: ^tr.Transport,
    to: tr.Peer_Id,
    schema: ^sc.Schema,
    value: $T,
    scope: Scope,
    kind: u16,
    tick: u64,
    txb: []u8,
    clock: ^Clock,
    remaining: ^int,
    stats: ^Stats,
    channel: tr.Channel = .Unreliable,
) -> bool {
    if sc.pack(schema, value, {kind = u16(kind), epoch = scope.epoch, tick = tick, content = scope.content}, txb).error !=
       .None {
        return false
    }

    return send(wire, to, txb[:sc.HEADER_BYTES + schema.wire_size], clock, remaining, stats, channel)
}

@(private)
expected :: proc(scope: Scope, kind: u16) -> sc.Envelope_Meta {
    return {kind = kind, epoch = scope.epoch, content = scope.content}
}

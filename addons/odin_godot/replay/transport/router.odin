package replay_transport

import "core:mem"

// Independently buffered packet consumers on one connection. Lane 0 is
// gameplay/control; other lanes share background capacity. Classification is routing only;
// each consumer still authenticates and validates its own protocol.
Router_Config :: struct {
    packets_per_lane, bytes_per_lane:                                 int,
    ingress_packets, ingress_bytes:                                   int,
    egress_per_second, egress_per_pump, burst_bytes, primary_reserve: int,
}

DEFAULT_ROUTER_CONFIG :: Router_Config{128, 256 * 1024, 256, 512 * 1024, 512 * 1024, 256 * 1024, 256 * 1024, 65536}
MAX_ROUTER_LANES :: 8

Router_Stats :: struct {
    received, rejected, tx_bytes, deferred, retired: u64,
    dropped:                                         [MAX_ROUTER_LANES]u64,
}

Router :: struct {
    allocator:                mem.Allocator,
    ready, time_set, pending: bool,
    wire:                     Transport, // borrowed; router_destroy does not close the underlying owner
    cfg:                      Router_Config,
    classify_user:            rawptr,
    classify:                 proc(user: rawptr, from: Peer_Id, channel: Channel, bytes: []u8) -> int,
    lanes:                    []Router_Lane,
    rxb:                      []u8,
    packet:                   Received,
    pending_lane:             int,
    now:                      u64,
    budget:                   f64,
    remaining:                int,
    stats:                    Router_Stats,
}

@(private)
Router_Lane :: struct {
    owner:                              ^Router,
    index:                              int,
    open:                               bool,
    packets:                            []Received,
    bytes:                              []u8,
    head, count, byte_head, byte_count: int,
}

router_init :: proc(
    r: ^Router,
    wire: Transport,
    classify: proc(user: rawptr, from: Peer_Id, channel: Channel, bytes: []u8) -> int,
    cfg := DEFAULT_ROUTER_CONFIG,
    user: rawptr = nil,
    allocator := context.allocator,
    lane_count: int = 2,
) -> bool {
    if r.ready ||
       classify == nil ||
       lane_count < 1 ||
       lane_count > MAX_ROUTER_LANES ||
       cfg.packets_per_lane < 1 ||
       cfg.packets_per_lane > 1024 ||
       cfg.bytes_per_lane < MAX_PACKET_BYTES ||
       cfg.bytes_per_lane > 4 * 1024 * 1024 ||
       cfg.ingress_packets < 1 ||
       cfg.ingress_packets > 4096 ||
       cfg.ingress_bytes < MAX_PACKET_BYTES ||
       cfg.ingress_bytes > 8 * 1024 * 1024 ||
       cfg.egress_per_second < 8192 ||
       cfg.egress_per_second > 64 * 1024 * 1024 ||
       cfg.egress_per_pump < MAX_PACKET_BYTES ||
       cfg.egress_per_pump > 8 * 1024 * 1024 ||
       cfg.burst_bytes < MAX_PACKET_BYTES ||
       cfg.burst_bytes > 8 * 1024 * 1024 ||
       cfg.primary_reserve < 0 ||
       cfg.primary_reserve + 1200 > min(cfg.burst_bytes, cfg.egress_per_pump) {
        return false
    }

    r.allocator, r.wire, r.cfg, r.classify, r.classify_user = allocator, wire, cfg, classify, user
    r.rxb = make([]u8, MAX_PACKET_BYTES, allocator)
    r.lanes = make([]Router_Lane, lane_count, allocator)

    for &lane, i in r.lanes {
        lane.owner, lane.index, lane.open = r, i, true
        lane.packets = make([]Received, cfg.packets_per_lane, allocator)
        lane.bytes = make([]u8, cfg.bytes_per_lane, allocator)
    }

    r.ready = true
    return true
}

router_destroy :: proc(r: ^Router) {
    for &lane in r.lanes {
        delete(lane.packets, r.allocator)
        delete(lane.bytes, r.allocator)
    }

    delete(r.lanes, r.allocator)
    delete(r.rxb, r.allocator)
    r^ = {}
}

router_transport :: proc(r: ^Router, lane: int) -> Transport {
    if !r.ready || lane < 0 || lane >= len(r.lanes) {
        return {}
    }

    return {
        user = &r.lanes[lane],
        send = router_send,
        receive = router_receive,
        poll = router_lane_poll,
        status = router_status,
        connected = router_connected,
        generation = router_generation,
        close = router_close,
    }
}

// Call once per outer pump before either consumer. Consumer Transport.poll calls
// deliberately do not poll again, so two runners cannot multiply ingress budgets.
router_pump :: proc(r: ^Router, now_ms: u64) -> bool {
    if !r.ready || (r.time_set && now_ms < r.now) {
        return false
    }

    if !r.time_set {
        r.budget = f64(r.cfg.burst_bytes)
    } else {
        r.budget = min(r.budget + f64(now_ms - r.now) * f64(r.cfg.egress_per_second) / 1000, f64(r.cfg.burst_bytes))
    }

    r.time_set, r.now, r.remaining = true, now_ms, r.cfg.egress_per_pump
    poll(&r.wire)

    if r.pending && r.packet.generation != peer_generation(&r.wire, r.packet.from) {
        r.pending = false
        r.stats.retired += 1
    }

    if r.pending {
        if !router_enqueue(r, r.pending_lane, r.packet) {
            return true
        }

        r.pending = false
    }

    bytes := 0

    for _ in 0 ..< r.cfg.ingress_packets {
        packet := receive(&r.wire, r.rxb)

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            r.stats.rejected += 1
            continue
        }

        r.stats.received += 1
        lane := r.classify(r.classify_user, packet.from, packet.channel, r.rxb[:packet.count])

        if lane < 0 || lane >= len(r.lanes) {
            r.stats.rejected += 1
            continue
        }

        bytes += packet.count

        if !router_enqueue(r, lane, packet) {
            // A reliable packet is retained until its consumer has room. Background
            // replication uses unreliable packets, so a full background queue does
            // not block gameplay or turn a promised reliable delivery into a drop.
            r.pending, r.pending_lane, r.packet = true, lane, packet
            break
        }

        if bytes >= r.cfg.ingress_bytes {
            break
        }
    }

    return true
}

@(private)
router_enqueue :: proc(r: ^Router, index: int, packet: Received) -> bool {
    lane := &r.lanes[index]

    if !lane.open {
        return true
    }

    router_prune(lane)

    if lane.count == len(lane.packets) || packet.count > len(lane.bytes) - lane.byte_count {
        if packet.channel == .Reliable {
            return false
        }

        r.stats.dropped[index] += 1
        return true
    }

    start := (lane.byte_head + lane.byte_count) % len(lane.bytes)
    first := min(packet.count, len(lane.bytes) - start)
    copy(lane.bytes[start:start + first], r.rxb[:first])
    copy(lane.bytes[:packet.count - first], r.rxb[first:packet.count])
    lane.packets[(lane.head + lane.count) % len(lane.packets)] = packet
    lane.count += 1
    lane.byte_count += packet.count
    return true
}

@(private)
router_receive :: proc(user: rawptr, dst: []u8) -> Received {
    lane := cast(^Router_Lane)user

    if !lane.owner.ready || !lane.open {
        return {state = .Disconnected}
    }

    router_prune(lane)

    if lane.count == 0 {
        return {state = router_status(user) == .Disconnected ? .Disconnected : .Empty}
    }

    packet := lane.packets[lane.head]

    if len(dst) < packet.count {
        packet.state = .Buffer_Too_Small
        return packet
    }

    first := min(packet.count, len(lane.bytes) - lane.byte_head)
    copy(dst[:first], lane.bytes[lane.byte_head:lane.byte_head + first])
    copy(dst[first:packet.count], lane.bytes[:packet.count - first])
    lane.byte_head = (lane.byte_head + packet.count) % len(lane.bytes)
    lane.byte_count -= packet.count
    lane.head = (lane.head + 1) % len(lane.packets)
    lane.count -= 1
    return packet
}

@(private)
router_send :: proc(user: rawptr, to: Peer_Id, channel: Channel, bytes: []u8) -> Send_Result {
    lane := cast(^Router_Lane)user
    r := lane.owner

    if !r.ready || !lane.open {
        return .Disconnected
    }

    reserve := lane.index == 0 ? 0 : r.cfg.primary_reserve

    if !r.time_set || len(bytes) + reserve > r.remaining || f64(len(bytes) + reserve) > r.budget {
        r.stats.deferred += 1
        return .Backpressure
    }

    result := send(&r.wire, to, channel, bytes)

    if result == .Sent {
        r.remaining -= len(bytes)
        r.budget -= f64(len(bytes))
        r.stats.tx_bytes += u64(len(bytes))
    }

    return result
}

@(private)
router_lane_poll :: proc(user: rawptr) {}

@(private)
router_status :: proc(user: rawptr) -> Status {
    lane := cast(^Router_Lane)user
    return lane.owner.ready && lane.open ? status(&lane.owner.wire) : .Disconnected
}

@(private)
router_connected :: proc(user: rawptr, peer: Peer_Id) -> bool {
    lane := cast(^Router_Lane)user
    return lane.owner.ready && lane.open && peer_connected(&lane.owner.wire, peer)
}

@(private)
router_close :: proc(user: rawptr) {
    lane := cast(^Router_Lane)user
    lane.open, lane.head, lane.count, lane.byte_head, lane.byte_count = false, 0, 0, 0, 0
}

@(private)
router_generation :: proc(user: rawptr, peer: Peer_Id) -> u64 {
    lane := cast(^Router_Lane)user
    return lane.owner.ready && lane.open ? peer_generation(&lane.owner.wire, peer) : 0
}

@(private)
router_prune :: proc(lane: ^Router_Lane) {
    for lane.count > 0 {
        packet := lane.packets[lane.head]

        if packet.generation == peer_generation(&lane.owner.wire, packet.from) {
            break
        }

        lane.byte_head = (lane.byte_head + packet.count) % len(lane.bytes)
        lane.byte_count -= packet.count
        lane.head = (lane.head + 1) % len(lane.packets)
        lane.count -= 1
        lane.owner.stats.retired += 1
    }
}

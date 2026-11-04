package replay_net_parts_reference

import tr "godot:replay/transport"

// Drain traffic that a fenced authority cannot admit. This keeps a shared
// transport's primary queue from blocking checkpoint replies behind reliable
// gameplay packets. It never applies input/actions or advances session state.
server_drain_fenced :: proc(s: ^Server($S, $C, $A, $E, $N)) -> Error {
    if !s.initialized {
        return .Not_Initialized
    }

    if !s.cfg.require_permit || permitted(true, s.permit, s.cfg.epoch) {
        return .Wrong_Phase
    }

    bytes := 0

    for _ in 0 ..< s.cfg.packets_per_pump {
        packet := tr.receive(&s.wire, s.rxb)

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            break
        }

        s.stats.fenced_packets += 1
        bytes += packet.count

        if bytes >= s.cfg.bytes_per_pump {
            break
        }
    }

    return .None
}

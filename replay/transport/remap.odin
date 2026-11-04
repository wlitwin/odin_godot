package replay_transport

Peer_Mapping :: struct {
    logical, physical: Peer_Id,
}

// Explicit trusted bindings for a fresh transport instance. Stable logical
// identities can survive ENet connection-ID changes; this is not authentication.
// Closing remap_transport forwards close to base, then clears the mapping.
Remap :: struct {
    ready:    bool,
    base:     Transport,
    mappings: [16]Peer_Mapping,
    count:    int,
}

remap_init :: proc(m: ^Remap, base: Transport, bindings: []Peer_Mapping) -> bool {
    if m.ready || len(bindings) == 0 || len(bindings) > len(m.mappings) {
        return false
    }

    for binding, i in bindings {
        if binding.logical == 0 || binding.physical == 0 {
            return false
        }

        for previous in bindings[:i] {
            if previous.logical == binding.logical || previous.physical == binding.physical {
                return false
            }
        }
    }

    m.base, m.count, m.ready = base, len(bindings), true
    copy(m.mappings[:], bindings)
    return true
}

remap_transport :: proc(m: ^Remap) -> Transport {
    return {
        user = m,
        send = remap_send,
        receive = remap_receive,
        poll = remap_poll,
        status = remap_status,
        close = remap_close,
        connected = remap_connected,
        generation = remap_generation,
    }
}

@(private)
remap_send :: proc(user: rawptr, to: Peer_Id, channel: Channel, bytes: []u8) -> Send_Result {
    m := cast(^Remap)user

    for binding in m.mappings[:m.count] {
        if binding.logical == to {
            return send(&m.base, binding.physical, channel, bytes)
        }
    }

    return .Invalid
}

@(private)
remap_receive :: proc(user: rawptr, bytes: []u8) -> Received {
    m := cast(^Remap)user
    packet := receive(&m.base, bytes)

    if packet.state != .Received {
        return packet
    }

    for binding in m.mappings[:m.count] {
        if binding.physical == packet.from {
            packet.from = binding.logical
            return packet
        }
    }

    // Consume unknown senders; logical zero cannot be in an admitted roster.
    packet.from = 0
    return packet
}

@(private)
remap_poll :: proc(user: rawptr) {
    poll(&(cast(^Remap)user).base)
}

@(private)
remap_status :: proc(user: rawptr) -> Status {
    return status(&(cast(^Remap)user).base)
}

@(private)
remap_connected :: proc(user: rawptr, peer: Peer_Id) -> bool {
    m := cast(^Remap)user

    for binding in m.mappings[:m.count] {
        if binding.logical == peer {
            return peer_connected(&m.base, binding.physical)
        }
    }

    return false
}

@(private)
remap_close :: proc(user: rawptr) {
    m := cast(^Remap)user
    close(&m.base)
    m^ = {}
}

@(private)
remap_generation :: proc(user: rawptr, peer: Peer_Id) -> u64 {
    m := cast(^Remap)user

    for binding in m.mappings[:m.count] {
        if binding.logical == peer {
            return peer_generation(&m.base, binding.physical)
        }
    }

    return 0
}

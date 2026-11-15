package replay_transport

Peer_Id :: distinct u64

Channel :: enum u8 {
    Reliable,
    Unreliable,
}

Status :: enum u8 {
    Disconnected,
    Connecting,
    Connected,
}

Send_Result :: enum u8 {
    Sent,
    Backpressure,
    Disconnected,
    Too_Large,
    Invalid,
}

Receive_State :: enum u8 {
    Empty,
    Received,
    Buffer_Too_Small,
    Too_Large,
    Disconnected,
}

MAX_PACKET_BYTES :: 65536

Received :: struct {
    state:      Receive_State,
    from:       Peer_Id,
    channel:    Channel,
    count:      int,
    generation: u64, // local adapter metadata; never trusted from gameplay payloads
}

// Borrowed interface; the concrete adapter owns its lifetime. send copies accepted
// bytes before returning. receive copies into caller storage and retains a packet
// on Buffer_Too_Small. Peer identity comes from the adapter, never a wire field.
Transport :: struct {
    user:       rawptr,
    send:       proc(user: rawptr, to: Peer_Id, channel: Channel, bytes: []u8) -> Send_Result,
    receive:    proc(user: rawptr, dst: []u8) -> Received,
    poll:       proc(user: rawptr),
    status:     proc(user: rawptr) -> Status,
    close:      proc(user: rawptr),
    connected:  proc(user: rawptr, peer: Peer_Id) -> bool,
    generation: proc(user: rawptr, peer: Peer_Id) -> u64,
}

send :: proc(t: ^Transport, to: Peer_Id, channel: Channel, bytes: []u8) -> Send_Result {
    if t.send == nil {
        return .Disconnected
    }

    if len(bytes) > MAX_PACKET_BYTES {
        return .Too_Large
    }

    if to == 0 || len(bytes) == 0 || channel > .Unreliable {
        return .Invalid
    }

    return t.send(t.user, to, channel, bytes)
}

receive :: proc(t: ^Transport, dst: []u8) -> Received {
    if t.receive == nil {
        return {state = .Disconnected}
    }

    packet := t.receive(t.user, dst)

    if t.generation == nil {
        packet.generation = 0
    } else if (packet.state == .Received || packet.state == .Buffer_Too_Small) && packet.generation == 0 {
        packet.generation = peer_generation(t, packet.from)
    }

    return packet
}

poll :: proc(t: ^Transport) {
    if t.poll != nil {
        t.poll(t.user)
    }
}

status :: proc(t: ^Transport) -> Status {
    return t.status != nil ? t.status(t.user) : .Disconnected
}

close :: proc(t: ^Transport) {
    if t.close != nil {
        t.close(t.user)
    }

    t^ = {}
}

peer_connected :: proc(t: ^Transport, peer: Peer_Id) -> bool {
    return t.connected != nil ? t.connected(t.user, peer) : status(t) == .Connected
}

// Zero means the adapter does not supply connection generations. Versioned
// adapters return a nonzero generation and never reuse it for a replacement
// connection within one open transport lifetime. Closing ends borrowed handles.
// Wrappers must forward the callback to preserve this local metadata.
peer_generation :: proc(t: ^Transport, peer: Peer_Id) -> u64 {
    return t.generation != nil ? t.generation(t.user, peer) : 0
}

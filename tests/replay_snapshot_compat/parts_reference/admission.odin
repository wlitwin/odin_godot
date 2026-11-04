package replay_net_parts_reference

import sc "godot:replay/schema"

// These are authority-side session operations, not speculative game actions.
// Custom admission data must be restored/reinstalled by the hosting application.
server_set_locked :: proc(s: ^Server($S, $C, $A, $E, $N), locked: bool) {
    s.locked = locked
}

server_set_admission :: proc(
    s: ^Server($S, $C, $A, $E, $N),
    user: rawptr,
    allow: proc(user: rawptr, token_hash: [32]u8, spectator: bool) -> bool,
) {
    s.admission_user, s.admission = user, allow
}

server_ban :: proc(s: ^Server($S, $C, $A, $E, $N), token: Token) -> Error {
    if !s.initialized || !token_valid(token) {
        return .Invalid_Input
    }

    return ban_hash(s, token_digest(token))
}

server_unban :: proc(s: ^Server($S, $C, $A, $E, $N), token: Token) -> bool {
    hash := token_digest(token)

    for banned, i in s.banned[:s.banned_count] {
        if banned != hash {
            continue
        }

        for j in i ..< s.banned_count - 1 {
            s.banned[j] = s.banned[j + 1]
        }

        s.banned_count -= 1
        s.banned[s.banned_count] = {}
        return true
    }

    return false
}

server_kick :: proc(s: ^Server($S, $C, $A, $E, $N), seat: u16, ban: bool = false) -> Error {
    if !s.initialized || seat == 0 {
        return .Invalid_Input
    }

    for &peer in s.peers {
        if peer.seat != seat || peer.phase == .Vacant {
            continue
        }

        if peer.local {
            return .Wrong_Phase
        }

        if ban {
            return ban_hash(s, peer.token_hash)
        }

        return remove_peer(s, &peer, .Removed)
    }

    return .Invalid_Input
}

// Explicitly release a disconnected reservation. The model must define how a
// fresh occupant's data is initialized; reset_player runs inside the joining tick.
// Old connection generations remain invalid, and bans survive reservation release.
server_release_seat :: proc(s: ^Server($S, $C, $A, $E, $N), seat: u16) -> Error {
    if !s.initialized || seat == 0 || s.model.reset_player == nil {
        return .Invalid_Model
    }

    for &peer, i in s.peers {
        if peer.phase == .Vacant || peer.seat != seat {
            continue
        }

        if peer.local || peer.phase != .Disconnected || peer.action_count != 0 {
            return .Wrong_Phase
        }

        peer = {}

        for &slot in s.inputs[i * s.cfg.history:(i + 1) * s.cfg.history] {
            slot = {}
        }

        snapshot_tx_reset(&s.snapshot_tx[i])
        s.checkpoints[i] = {}
        return .None
    }

    return .Invalid_Input
}

@(private)
ban_hash :: proc(s: ^Server($S, $C, $A, $E, $N), hash: [32]u8) -> Error {
    found := false

    for banned in s.banned[:s.banned_count] {
        if banned == hash {
            found = true
        }
    }

    if !found {
        if s.banned_count == len(s.banned) {
            return .Capacity
        }

        s.banned[s.banned_count] = hash
        s.banned_count += 1
    }

    for &peer in s.peers {
        if peer.local || peer.phase == .Vacant || peer.token_hash != hash {
            continue
        }

        if err := remove_peer(s, &peer, .Banned); err != .None {
            return err
        }
    }

    return .None
}

@(private)
remove_peer :: proc(s: ^Server($S, $C, $A, $E, $N), peer: ^Peer(A), reason: Reject) -> Error {
    if peer.phase == .Disconnected {
        return .None
    }

    meta := sc.Envelope_Meta {
        kind    = u16(Kind.Removed),
        epoch   = s.cfg.epoch,
        tick    = s.timeline.head,
        content = s.cfg.content,
    }
    packet := Removed_Packet{peer.generation, peer.serial, reason}

    if sc.pack(&s.codecs.removed, packet, meta, s.txb).error != .None {
        return .Invalid_Model
    }

    // Notify before retiring the binding. Authority removal still takes effect if
    // notification is congested; Transport reports that notification limitation.
    sent := server_send(s, peer.connection, .Reliable, s.txb[:sc.HEADER_BYTES + s.codecs.removed.wire_size]) == .Sent
    server_drop(s, peer)
    return sent ? .None : .Transport
}

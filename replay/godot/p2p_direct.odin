package replay_godot

import "core:crypto"
import "core:strings"
import gd "godot:godot"
import auth "godot:replay/authority"
import lk "godot:replay/p2p/link"
import tr "godot:replay/transport"
import transportgd "godot:replay/godot/transport"

P2P_Direct_Error :: enum {
    None,
    Configuration,
    Transport,
    Provision,
    Entropy,
    Clock,
    Capacity,
}

P2P_Direct_Options :: struct {
    // Empty uses the advertised endpoint. An explicit endpoint affects only the
    // local listener; peers still receive the service's advertised endpoint.
    listen: auth.Endpoint,
}

p2p_direct_listen_endpoint :: proc(
    advertised: auth.Endpoint,
    options: P2P_Direct_Options = {},
) -> (
    auth.Endpoint,
    bool,
) {
    endpoint := options.listen

    if endpoint == (auth.Endpoint{}) {
        endpoint = advertised
    }

    for candidate in ([2]auth.Endpoint{advertised, endpoint}) {
        probe := auth.record_make(1, 1, {1, 1})
        probe.members[0] = {
            identity = {1, 1},
            endpoint = candidate,
        }

        if !auth.record_valid(probe) || p2p_direct_address(candidate) == "" {
            return {}, false
        }
    }

    return endpoint, true
}

// Two-participant ENet owner. Party is borrowed and must be pumped once/frame
// before this transport. This owner handles endpoint discovery and replacement;
// it exposes stable member IDs only after pair-key authentication succeeds.
P2P_Direct :: struct {
    ready, hosting, waiting, admitted:    bool,
    error:                                P2P_Direct_Error,
    party:                                ^P2P_Party,
    socket:                               transportgd.Enet,
    link:                                 lk.Link,
    peer:                                 tr.Peer_Id,
    remote:                               u64,
    serial, now, retry_at, connecting_at: u64,
    endpoint, listen_endpoint:            auth.Endpoint,
}

p2p_direct_open :: proc(d: ^P2P_Direct, party: ^P2P_Party, options: P2P_Direct_Options = {}) -> bool {
    when gd.IS_WEB {
        return false
    } else {
        if d.ready || party == nil || !party.ready || party.failed || party.players != 2 {
            return false
        }

        listen, valid := p2p_direct_listen_endpoint(party.party.config.endpoint, options)

        if !valid {
            d.error = .Configuration
            return false
        }

        d.party, d.listen_endpoint = party, listen
        d.hosting = party.authorization.identity.member == party.authorization.match.members[0]
        d.remote = party.authorization.match.members[d.hosting ? 1 : 0]
        now, ok := party.control.client.clock.read(party.control.client.clock.user)

        if !ok {
            d.error = .Clock
            return false
        }

        d.now = now

        if d.hosting {
            ep := d.listen_endpoint
            host := p2p_direct_address(ep)

            if host == "" {
                d.error = .Configuration
                return false
            }

            name := strings.clone_to_cstring(host)
            defer delete(name)

            if !transportgd.enet_host(&d.socket, ep.port, 8, bind_ip = name) {
                d.error = .Transport
                return false
            }
        }

        d.ready = true
        return true
    }
}

p2p_direct_close :: proc(d: ^P2P_Direct) {
    lk.close(&d.link)
    wire := transportgd.enet_transport(&d.socket)
    tr.close(&wire)
    crypto.zero_explicit(d, size_of(P2P_Direct))
}

p2p_direct_transport :: proc(d: ^P2P_Direct) -> tr.Transport {
    return {
        user = d,
        send = p2p_direct_send,
        receive = p2p_direct_receive,
        poll = p2p_direct_poll,
        status = p2p_direct_status,
        connected = p2p_direct_connected,
        generation = p2p_direct_generation,
        close = p2p_direct_destroy,
    }
}

p2p_direct_identity :: proc(d: ^P2P_Direct) -> (auth.Identity, bool) {
    if !d.ready || d.error != .None || !d.admitted {
        return {}, false
    }

    return lk.identity(&d.link)
}

p2p_direct_frame :: proc(d: ^P2P_Direct) {
    if !d.ready || d.error != .None {
        return
    }

    now, ok := d.party.control.client.clock.read(d.party.control.client.clock.user)

    if !ok || now < d.now {
        d.error = .Clock
        return
    }

    d.now = now

    if d.party.registration.phase == .Failed &&
       (d.party.registration.error == .Denied || d.party.registration.error == .Invalid) {
        lk.close(&d.link)
        d.admitted = false
        d.error = .Provision
        return
    }

    base := transportgd.enet_transport(&d.socket)
    tr.poll(&base)

    if d.link.phase != .Closed {
        lk.pump(&d.link)
        // A newer signed roster read retires an old incarnation. A pair reply
        // can be newer than the last periodic roster, so older reads do not undo it.
        remote := d.link.config.grant.scope.members[1 - d.link.local_index]

        for member in d.party.registration.members {
            if member.identity.member == d.remote &&
               (!member.enabled || member.identity.incarnation > remote.incarnation) {
                p2p_direct_retire(d)
                return
            }
        }

        if d.link.phase == .Failed {
            p2p_direct_retire(d)
            return
        }

        if d.link.phase == .Ready && !d.admitted {
            if d.serial == max(u64) {
                d.error = .Capacity
                return
            }

            d.serial += 1
            d.admitted = true
        }

        return
    }

    if d.waiting {
        pairs := &d.party.pairs

        if pairs.error != .None {
            d.error = .Provision
            return
        }

        if !pairs.complete {
            return
        }

        reply := pairs.reply
        pairs.complete = false
        d.waiting = false
        defer crypto.zero_explicit(&reply, size_of(reply))

        if reply.result == .Not_Ready || reply.result == .Rate_Limited {
            d.retry_at = now + 500
            return
        }

        if reply.result != .None {
            d.error = .Provision
            return
        }

        if !d.hosting && (d.socket.peer == nil || d.endpoint != reply.endpoint) {
            tr.close(&base)
            d.peer = 0
            d.endpoint = reply.endpoint
            host := p2p_direct_address(d.endpoint)

            if host == "" {
                d.error = .Configuration
                return
            }

            name := strings.clone_to_cstring(host)
            defer delete(name)

            if !transportgd.enet_join(&d.socket, name, d.endpoint.port) {
                d.error = .Transport
                return
            }

            d.connecting_at = now
            return
        }

        if d.peer == 0 || !tr.peer_connected(&base, d.peer) {
            d.retry_at = now + 250
            return
        }

        secret, _, valid := party_random(d.party.party.config.entropy)
        defer crypto.zero_explicit(&secret, size_of(secret))

        if !valid {
            d.error = .Entropy
            return
        }

        cfg := lk.Config {
            grant      = reply.grant,
            local      = d.party.authorization.identity,
            peer       = d.peer,
            nonce      = secret,
            timeout_ms = 5000,
        }

        if !lk.open(&d.link, base, d.party.control.client.clock, cfg) {
            d.error = .Transport
            return
        }

        return
    }

    if now < d.retry_at {
        return
    }

    if d.socket.peer != nil {
        if len(d.socket.remotes) > 0 {
            d.peer = d.socket.remotes[0]
        } else {
            if d.hosting {
                return
            }

            if now - d.connecting_at < 5000 && tr.status(&base) != .Disconnected {
                return
            }

            tr.close(&base)
            d.peer = 0
        }
    }

    if d.party.ready && !d.party.failed {
        if !p2p_party_pair_begin(d.party, d.remote) {
            d.error = .Provision
            return
        }

        d.waiting = true
    }
}

@(private)
p2p_direct_retire :: proc(d: ^P2P_Direct) {
    lk.close(&d.link)
    d.admitted = false
    base := transportgd.enet_transport(&d.socket)

    if d.hosting && d.socket.peer != nil && d.peer != 0 && tr.peer_connected(&base, d.peer) {
        gd.multiplayer_peer_disconnect_peer(d.socket.peer, gd.Int(d.peer), true)
    }

    if !d.hosting {
        base := transportgd.enet_transport(&d.socket)
        tr.close(&base)
    }

    d.peer = 0
    d.retry_at = d.now + 500
}

@(private)
p2p_direct_address :: proc(endpoint: auth.Endpoint) -> string {
    // Return an owned string; a value parameter's byte array cannot be borrowed.
    e := endpoint
    count := 0

    for byte in e.host {
        if byte == 0 {
            break
        }

        count += 1
    }

    if count == 0 || e.port == 0 || string(e.host[:count]) == "rtc" {
        return ""
    }

    return strings.clone(string(e.host[:count]), context.temp_allocator)
}

@(private)
p2p_direct_send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
    d := cast(^P2P_Direct)user

    if to != tr.Peer_Id(d.remote) || !d.admitted {
        return .Disconnected
    }

    wire := lk.transport(&d.link)
    return tr.send(&wire, d.peer, channel, bytes)
}

@(private)
p2p_direct_receive :: proc(user: rawptr, bytes: []u8) -> tr.Received {
    d := cast(^P2P_Direct)user

    if !d.admitted {
        return {state = .Empty}
    }

    wire := lk.transport(&d.link)
    packet := tr.receive(&wire, bytes)

    if packet.state == .Received || packet.state == .Buffer_Too_Small {
        packet.from, packet.generation = tr.Peer_Id(d.remote), d.serial
    }

    return packet
}

@(private)
p2p_direct_poll :: proc(user: rawptr) {
    p2p_direct_frame(cast(^P2P_Direct)user)
}

@(private)
p2p_direct_status :: proc(user: rawptr) -> tr.Status {
    d := cast(^P2P_Direct)user

    if !d.ready || d.error != .None {
        return .Disconnected
    }

    _, ok := p2p_direct_identity(d)
    return ok ? .Connected : .Connecting
}

@(private)
p2p_direct_connected :: proc(user: rawptr, peer: tr.Peer_Id) -> bool {
    d := cast(^P2P_Direct)user
    return peer == tr.Peer_Id(d.remote) && p2p_direct_status(user) == .Connected
}

@(private)
p2p_direct_generation :: proc(user: rawptr, peer: tr.Peer_Id) -> u64 {
    d := cast(^P2P_Direct)user
    return p2p_direct_connected(user, peer) ? d.serial : 0
}

@(private)
p2p_direct_destroy :: proc(user: rawptr) {
    p2p_direct_close(cast(^P2P_Direct)user)
}

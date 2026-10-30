package replay_p2p_provision

import "core:crypto"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import p "godot:replay/provision"
import tr "godot:replay/transport"

Client_Phase :: enum {Closed, Registering, Rebinding, Waiting, Ready, Failed}
Client :: struct {
    phase: Client_Phase,
    error: p.Error,
    control_error: auth.Error,
    players: u8,
    grant: p.Grant,
    registration: auth.Identity,
    lease: auth.Lease,
    rpc: auth.Rpc_Client,
    match: adm.Match,
    members: [adm.MAX_PLAYERS]auth.Member,
    endpoint: auth.Endpoint,
    next_query: u64,
}

// Stable-address owner. The grant is the durable enrollment credential; each
// process must still register a new incarnation with a fresh nonce. No simulation
// authority permit is produced. The driver owns/polls the connected transport.
client_open :: proc(c: ^Client, grant: p.Grant, players: u8, nonce: auth.Nonce,
                    clock: auth.Clock_Source, wire: tr.Transport, allocator := context.allocator, endpoint: auth.Endpoint = {}) -> bool {
    if c.phase != .Closed || players < 2 || players > adm.MAX_PLAYERS || grant.identity.member > u64(players) ||
       grant.can_host || grant.trusted_authority || grant.infrastructure {return false}
    if auth.lease_init(&c.lease, grant.identity, grant.room, grant.content, clock, false) != .None {return false}
    if !auth.rpc_client_init(&c.rpc, &c.lease, grant.key, nonce, wire, timeout_ms = 10000, allocator = allocator) {client_close(c); return false}
    c.grant, c.players, c.phase, c.endpoint = grant, players, .Registering, endpoint
    if auth.rpc_begin(&c.rpc, {verb = .Challenge, endpoint = endpoint}) != .None {client_close(c); return false}
    return true
}
client_close :: proc(c: ^Client) {auth.rpc_client_destroy(&c.rpc); crypto.zero_explicit(c, size_of(Client))}

client_frame :: proc(c: ^Client) {
    if c.phase == .Closed || c.phase == .Failed {return}
    if error := auth.rpc_client_pump(&c.rpc); error != .None {client_fail(c, .Not_Ready, error); return}
    reply, complete := auth.rpc_completed(&c.rpc)
    if complete {
        // Consume each response once. A later query retains the same nonce and
        // monotone sequence, so regular roster reads also keep registration live.
        c.rpc.reply = {}
        if reply.result != .None {client_fail(c, .Denied, reply.result); return}
        switch c.phase {
        case .Registering:
            if reply.registration_identity.member != c.grant.identity.member ||
               reply.registration_identity.incarnation <= c.grant.identity.incarnation || reply.challenge == ([32]u8{}) {
                client_fail(c, .Invalid, .Invalid); return
            }
            c.registration = reply.registration_identity
            if error := auth.rpc_begin(&c.rpc, {verb = .Rebind, challenge = reply.challenge, incarnation = c.registration.incarnation, endpoint = c.endpoint}); error != .None {
                client_fail(c, .Invalid, error); return
            }
            c.phase = .Rebinding
        case .Rebinding:
            if c.lease.identity != c.registration {client_fail(c, .Invalid, .Invalid); return}
            c.phase, c.next_query = .Waiting, 0
        case .Waiting, .Ready:
            if c.lease.now > max(u64)-500 {client_fail(c, .Clock, .Clock); return}
            match, error := match_from_reply(reply, c.grant.room, c.grant.content, c.players, c.lease.identity)
            if error == .Not_Ready && c.phase == .Waiting {
                c.next_query = c.lease.now + 500
            } else if error != .None {client_fail(c, error, .Invalid); return} else {
                if c.phase == .Ready && c.match != match {client_fail(c, .Invalid, .Invalid); return}
                c.match, c.phase, c.next_query = match, .Ready, c.lease.now + 500
                copy(c.members[:],reply.members[:int(c.players)])
            }
        case .Closed, .Failed: return
        }
    }
    if (c.phase == .Waiting || c.phase == .Ready) && !c.rpc.pending && c.lease.now >= c.next_query {
        if error := auth.rpc_begin(&c.rpc, {verb = .Query}); error != .None {client_fail(c, .Not_Ready, error)}
    }
}
client_admission :: proc(c: ^Client) -> (adm.Match, auth.Credential, bool) {
    if c.phase != .Ready {return {}, {}, false}
    return c.match, {c.lease.identity, c.grant.key}, true
}
@(private)
client_fail :: proc(c: ^Client, error: p.Error, control_error: auth.Error) {c.phase, c.error, c.control_error = .Failed, error, control_error}

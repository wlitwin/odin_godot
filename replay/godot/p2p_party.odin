package replay_godot

import "core:crypto"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import pp "godot:replay/p2p/provision"
import p "godot:replay/provision"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

// Composes persistent enrollment with fixed-roster registration. This owns no
// gameplay runner or transport. Close it before its borrowed native Party_Storage.
P2P_Party :: struct {
    party: Party,
    control: Provision_Connection,
    registration: pp.Client,
    router: tr.Router,
    pairs: pp.Pair_Client,
    authorization: Rtc_P2P_Auth,
    players: u8,
    started, failed, ready: bool,
    connecting_at: u64,
}
p2p_party_open :: proc(o: ^P2P_Party, cfg: Party_Config, players: u8) -> bool {
    if o.players != 0 || players < 2 || players > adm.MAX_PLAYERS || cfg.invite_role != .Player ||
       cfg.invite_uses != players-1 || cfg.checkpoint_interval_ms != 0 {return false}
    if !party_open(&o.party, cfg) {return false}
    o.players = players; return true
}
p2p_party_begin :: proc(o: ^P2P_Party, action: Party_Action, ticket: p.Ticket = {}) -> bool {
    if o.players == 0 || o.started {return false}
    if !party_begin(&o.party, action, ticket) {return false}
    o.started = true; return true
}
p2p_party_frame :: proc(o: ^P2P_Party) {
    if o.players == 0 || o.failed {return}
    party_frame(&o.party)
    if o.party.failed {o.failed, o.ready = true, false; return}
    grant, enrolled := party_grant(&o.party)
    if !enrolled {return}
    if !o.control.ready {
        if provision_connect(&o.control, o.party.config.service, o.party.config.tls, o.party.config.local_development) != .None {
            o.failed = true; return
        }
        now, valid := o.control.client.clock.read(o.control.client.clock.user)
        if !valid {o.failed = true; return}
        o.connecting_at = now
    }
    wire := o.control.client.wire
    if o.registration.phase == .Closed {
        tr.poll(&wire)
        if tr.status(&wire) != .Connected {
            now, valid := o.control.client.clock.read(o.control.client.clock.user)
            if !valid || now < o.connecting_at || now-o.connecting_at >= 10000 {o.failed = true; return}
            // Use the standard connection timeout/reconnect driver only before
            // RPC starts; it must not consume authenticated replies afterwards.
            if provision_frame(&o.control) != .None {o.failed = true}
            return
        }
        // Godot Crypto works in both native and browser builds.
        secret, _, ok := party_random(o.party.config.entropy)
        nonce: auth.Nonce; copy(nonce[:], secret[:len(nonce)])
        crypto.zero_explicit(&secret, size_of(secret))
        if !ok || !tr.router_init(&o.router,wire,proc(_:rawptr,_:tr.Peer_Id,_:tr.Channel,bytes:[]u8)->int {
            if len(bytes)<sc.HEADER_BYTES+32 {return -1}
            meta,_,report:=sc.inspect(bytes[:len(bytes)-32]);if report.error!=.None {return -1}
            if meta.kind==auth.RPC_REPLY {return 0};if meta.kind==pp.PAIR_REPLY {return 1};return -1
        }) {o.failed=true;return}
        if !pp.client_open(&o.registration, grant, o.players, nonce, o.control.client.clock,tr.router_transport(&o.router,0),endpoint=o.party.config.endpoint) {o.failed = true; return}
    }
    now,valid:=o.control.client.clock.read(o.control.client.clock.user)
    if !valid || !tr.router_pump(&o.router,now) {o.failed,o.ready=true,false;return}
    pp.client_frame(&o.registration)
    if o.registration.phase == .Failed {o.failed, o.ready = true, false; return}
    match, credential, ready := pp.client_admission(&o.registration)
    if ready {o.authorization = {match, credential.identity, credential.key}; o.ready = true}
    if o.pairs.ready {pp.pair_client_pump(&o.pairs)}
}
p2p_party_pair_begin :: proc(o:^P2P_Party,remote:u64)->bool {
    if !o.ready || o.failed || o.pairs.pending {return false}
    if !o.pairs.ready && !pp.pair_client_open(&o.pairs,&o.registration,tr.router_transport(&o.router,1)) {return false}
    secret,_,ok:=party_random(o.party.config.entropy);defer crypto.zero_explicit(&secret,size_of(secret))
    nonce:auth.Nonce;copy(nonce[:],secret[:len(nonce)])
    return ok && pp.pair_client_begin(&o.pairs,remote,nonce)
}
p2p_party_rtc :: proc(o: ^P2P_Party) -> (Rtc_Config, bool) {
    if !o.ready || o.failed {return {}, false}
    cfg := rtc_p2p_config(&o.authorization, o.party.config.service, o.authorization.identity.member == o.authorization.match.members[0])
    cfg.wait_for_host = !cfg.host
    cfg.ice_json = o.party.config.ice_json
    if o.party.config.relay_credentials {cfg.ice_user, cfg.ice_source = &o.party.relay, relay_ice_source}
    return cfg, true
}
p2p_party_close :: proc(o: ^P2P_Party) {
    pp.pair_client_close(&o.pairs);pp.client_close(&o.registration);tr.router_destroy(&o.router)
    provision_disconnect(&o.control); party_close(&o.party)
    crypto.zero_explicit(o, size_of(P2P_Party))
}
p2p_party_message :: proc(o: ^P2P_Party) -> string {
    if o.party.failed {return party_message(&o.party)}
    if o.failed {return "Match registration could not be completed. Rejoin to retry."}
    if o.ready {return "Ready to connect to the match."}
    if o.registration.phase == .Waiting {return "Waiting for the other players to join…"}
    return "Connecting to the match…"
}

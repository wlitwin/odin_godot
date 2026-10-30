package replay_p2p

import tr "godot:replay/transport"

// Rebind a retained runner after the provider has authenticated the same ordered
// identities and excluded all packets from retired connections. This does not
// authenticate peers or close either borrowed transport. Every affected survivor
// must restart its handshake so a restored peer can advertise its durable frontier.
// No simulation, captured input, ACK frontier or checksum history is discarded.
reconnect :: proc(p:^Runner($S,$I,$E,$N),wire:tr.Transport,now_ms:u64)->Error {
 if !p.ready || p.timeline.busy || p.dirty!=0 || p.phase==.Failed || p.phase==.Diverged {return .Not_Ready}
 if p.time_set && now_ms<p.now {return .Time}
 if wire.send==nil || wire.receive==nil || wire.status==nil {return .Transport}
 p.wire=wire;p.now,p.time_set=now_ms,true
 p.hello_seen={};p.hello_seen[p.local]=true
 p.sent_once={};p.sent_at={}
 for &seen in p.last_seen {seen=now_ms}
 p.phase,p.error=.Connecting,.None
 return .None
}

package replay_net

import tr "godot:replay/transport"

// Validated live connection metadata for session services. Seat identity and
// generation originate in the authority's admission ledger, never caller packets.
Connection :: struct {peer: tr.Peer_Id, generation: u64, seat: u16, spectator: bool, incarnation: u64, token_hash: [32]u8}

server_connection :: proc(s: ^Server($S, $C, $A, $E, $N), id: tr.Peer_Id) -> (Connection, bool) {
	if !s.initialized || id == 0 || !tr.peer_connected(&s.wire, id) {return {}, false}
	for peer in s.peers {
		if !peer.local && peer.phase == .Running && peer.connection == id {
			return {peer.connection, peer.generation, peer.seat, peer.spectator, peer.incarnation, peer.token_hash}, true
		}
	}
	return {}, false
}

token_hash :: proc(token: Token) -> [32]u8 {return token_digest(token)}

// Returns the number available, writing at most len(dst). Session services use
// this admitted roster rather than raw transport peers, including spectators.
server_connections :: proc(s: ^Server($S, $C, $A, $E, $N), dst: []Connection) -> int {
	if !s.initialized {return 0}
	count := 0
	for peer in s.peers {
		if peer.local || peer.phase != .Running {continue}
		if connection, live := server_connection(s, peer.connection); live {
			if count < len(dst) {dst[count] = connection}
			count += 1
		}
	}
	return count
}

server_seat_connection :: proc(s: ^Server($S, $C, $A, $E, $N), seat: u16) -> (Connection, bool) {
	if seat == 0 || int(seat) > N {return {}, false}
	for peer in s.peers {if peer.seat == seat && !peer.local {return server_connection(s, peer.connection)}}
	return {}, false
}

// Capability belongs to the current admitted connection; reconnect resets it.
server_checkpoint_compression :: proc(s:^Server($S,$C,$A,$E,$N),id:tr.Peer_Id)->bool {
 if _,live:=server_connection(s,id);!live {return false}
 for peer,i in s.peers {if !peer.local && peer.phase==.Running && peer.connection==id {return s.snapshot_tx[i].checkpoint_compression}}
 return false
}

server_checkpoint_shuffle :: proc(s:^Server($S,$C,$A,$E,$N),id:tr.Peer_Id)->bool {
 if _,live:=server_connection(s,id);!live {return false}
 for peer,i in s.peers {if !peer.local && peer.phase==.Running && peer.connection==id {return s.snapshot_tx[i].checkpoint_shuffle}}
 return false
}

server_checkpoint_reliable :: proc(s:^Server($S,$C,$A,$E,$N),id:tr.Peer_Id)->bool {
 if _,live:=server_connection(s,id);!live {return false}
 for peer,i in s.peers {if !peer.local && peer.phase==.Running && peer.connection==id {return s.snapshot_tx[i].checkpoint_reliable}}
 return false
}

server_observer_names :: proc(s:^Server($S,$C,$A,$E,$N),id:tr.Peer_Id)->bool {
 if _,live:=server_connection(s,id);!live {return false}
 for peer,i in s.peers {if !peer.local && peer.phase==.Running && peer.connection==id {return s.snapshot_tx[i].observer_names}}
 return false
}

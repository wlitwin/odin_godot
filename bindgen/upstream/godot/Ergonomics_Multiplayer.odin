package godot

// Ergonomic helpers for ENet-based multiplayer / RPC — hand-written (like the other
// Ergonomics_*.odin), and mirrored in bindgen/upstream/godot/ so they survive binding
// regeneration.
//
// These collapse the host/join + peer-id + sender-id dance into a few readable lines so P2P
// co-op netcode reads like:
//
//     if is_host { gd.host(self.owner, 7777) } else { gd.join(self.owner, "127.0.0.1", 7777) }
//     ...
//     gd.connect_to(gd.multiplayer(self.owner), "peer_connected", self.owner, "on_peer")
//     ...
//     // inside an @(gd_rpc) proc, read who sent it:
//     sender := gd.rpc_sender_id(self.owner)
//
// All helpers take a `Node` and reach its MultiplayerAPI via Node.get_multiplayer(), so they
// work from a script's `self.owner` with no extra plumbing.
//
// WEB/WASM: Godot's web export does NOT ship ENetMultiplayerPeer (it uses WebRTC/WebSocket
// instead — a later milestone). `host`/`join` therefore compile on wasm32 but return false
// at runtime there (the `when ODIN_ARCH` guard below), so web builds stay link-clean and
// callers can branch on the bool. The pure-query helpers (is_server / my_peer_id /
// rpc_sender_id / connected_peers / multiplayer) are platform-independent.

import gdext "godot:gdext"

// multiplayer returns the MultiplayerAPI for `node`'s scene tree (nil before the node is in a
// tree). Use it as the signal emitter for peer_connected / peer_disconnected:
//
//     gd.connect_to(gd.multiplayer(self.owner), "peer_connected", self.owner, "on_peer_joined")
multiplayer :: proc "contextless" (node: Node) -> Multiplayer_Api {
	return node_get_multiplayer(node)
}

// host creates an ENet SERVER on `port` and installs it as `node`'s multiplayer peer. Returns
// false if ENet is unavailable (web) or the bind/listen failed (e.g. port in use). `max_peers`
// is the client cap (default 32).
//
//     if !gd.host(self.owner, 7777) { gd.error("could not host on 7777") }
host :: proc "contextless" (node: Node, port: int, max_peers := 32) -> bool {
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		return false // ENet is not in the web export; WebRTC comes later.
	} else {
		peer := new_e_net_multiplayer_peer()
		if cast(rawptr)peer == nil {return false}
		err := e_net_multiplayer_peer_create_server(peer, Int(port), Int(max_peers), 0, 0, 0)
		if err != .Ok {return false}
		mp := node_get_multiplayer(node)
		if cast(rawptr)mp == nil {return false}
		multiplayer_api_set_multiplayer_peer(mp, cast(Multiplayer_Peer)peer)
		return true
	}
}

// join creates an ENet CLIENT connecting to `address:port` and installs it as `node`'s
// multiplayer peer. Returns false if ENet is unavailable (web) or the client could not be
// created. A successful return only means the connection ATTEMPT started — wait for the
// MultiplayerAPI `connected_to_server` / `connection_failed` signal for the outcome.
//
//     if !gd.join(self.owner, "127.0.0.1", 7777) { gd.error("could not start client") }
join :: proc "contextless" (node: Node, address: cstring, port: int) -> bool {
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		return false // ENet is not in the web export; WebRTC comes later.
	} else {
		peer := new_e_net_multiplayer_peer()
		if cast(rawptr)peer == nil {return false}
		addr := new_string_cstring(address)
		err := e_net_multiplayer_peer_create_client(peer, addr, Int(port), 0, 0, 0, 0)
		if err != .Ok {return false}
		mp := node_get_multiplayer(node)
		if cast(rawptr)mp == nil {return false}
		multiplayer_api_set_multiplayer_peer(mp, cast(Multiplayer_Peer)peer)
		return true
	}
}

// multiplayer_clear_peer detaches `node`'s multiplayer peer (sets it to nil, returning the
// MultiplayerAPI to OFFLINE) so a fresh host/join can install a new one. Use it when tearing
// down a failed or finished connection — e.g. recovering a lobby after a connect failure so the
// next host/join starts from a clean MultiplayerAPI. No-op before a peer is in a tree.
multiplayer_clear_peer :: proc "contextless" (node: Node) {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return}
	none: Multiplayer_Peer
	multiplayer_api_set_multiplayer_peer(mp, none)
}

// is_server reports whether this peer is the multiplayer authority (the server / host). On an
// offline (single-player) peer this is also true. False before a peer is assigned.
is_server :: proc "contextless" (node: Node) -> bool {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return false}
	return bool(multiplayer_api_is_server(mp))
}

// my_peer_id returns this peer's unique network id (server is always 1; clients get a random
// positive id; 0 means no peer is assigned).
my_peer_id :: proc "contextless" (node: Node) -> int {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return 0}
	return int(multiplayer_api_get_unique_id(mp))
}

// rpc_sender_id returns the peer id of the sender of the RPC currently executing — call it
// from INSIDE an `@(gd_rpc)` proc. Returns 0 when not in an RPC (or a call_local dispatch).
rpc_sender_id :: proc "contextless" (node: Node) -> int {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return 0}
	return int(multiplayer_api_get_remote_sender_id(mp))
}

// connected_peers returns the ids of all peers connected to this one (NOT including self).
// The slice is temp-allocated (valid until the next `free_all(context.temp_allocator)`), so
// this is a regular `proc` (needs an Odin context — script methods already have one).
connected_peers :: proc(node: Node) -> []int {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return nil}
	arr := multiplayer_api_get_peers(mp)
	n := int(packed_int32_array_size(&arr))
	if n <= 0 {return nil}
	out := make([]int, n, context.temp_allocator)
	for i in 0 ..< n {
		out[i] = int(packed_int32_array_get(&arr, Int(i)))
	}
	return out
}

// on_peer_connected connects `node`'s MultiplayerAPI `peer_connected(id)` signal to `node`'s
// own `method` (an `@(gd_method)` taking one Int — the joining peer's id). Returns the connect
// Error. Thin sugar over connect_to(gd.multiplayer(node), ...):
//
//     gd.on_peer_connected(self.owner, "on_peer_joined")  // -> net_node_on_peer_joined(self, id)
on_peer_connected :: proc "contextless" (node: Node, method: cstring) -> Error {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return .Failed}
	return connect_to(cast(Object)mp, "peer_connected", cast(Object)node, method)
}

// on_peer_disconnected — `on_peer_connected` for the `peer_disconnected(id)` signal.
on_peer_disconnected :: proc "contextless" (node: Node, method: cstring) -> Error {
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return .Failed}
	return connect_to(cast(Object)mp, "peer_disconnected", cast(Object)node, method)
}

// rpc calls `method` (an `@(gd_rpc)` proc) on `node` across the network per the method's RPC
// config (broadcast to the configured peers; with `call_local` it also runs locally). Thin
// sugar over node_rpc that interns the method name for you — pass the payload as Variants:
//
//     v := i64(7); fv := gd.variant_from(&v)
//     gd.rpc(self.owner, "take_damage", fv)
rpc :: proc "contextless" (node: Node, method: cstring, args: ..Variant) -> Error {
	name := new_string_name_cstring(method, true)
	return node_rpc(node, name, ..args)
}

// rpc_id is `rpc` targeted at a single peer (`peer_id`; the server is always 1). Used for
// client->server requests (e.g. `gd.rpc_id(self.owner, 1, "request_damage", ...)`):
rpc_id :: proc "contextless" (node: Node, peer_id: int, method: cstring, args: ..Variant) -> Error {
	name := new_string_name_cstring(method, true)
	return node_rpc_id(node, Int(peer_id), name, ..args)
}

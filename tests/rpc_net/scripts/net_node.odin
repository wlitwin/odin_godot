//gd:extends Node
//gd:class NetNode
package rpc_net_scripts

// ----------------------------------------------------------------------------
// NetNode — the SUBJECT of the two-peer ENet RPC test (tests/rpc_net). It declares several
// `@(gd_rpc)` methods. Two independent headless Godot processes (a server + a client) each
// load this script onto a node at the SAME tree path (/root/Net). When one peer calls an
// RPC targeted at the other, the engine ships an ENet packet to the remote peer and dispatches
// it BY NAME into the matching Odin proc on THAT peer.
//
// Every RPC proc prints a stdout sentinel naming the method, the peer it RAN ON
// (gd.my_peer_id) and the SENDER (gd.rpc_sender_id) plus the payload, so the harness can
// assert — from each process's captured stdout — that the call crossed the wire and executed
// remotely with the correct sender id. This is the genuine remote path the single-process
// tests/rpc could not exercise.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:fmt"

NetNode :: struct {
	owner: gd.Node,
}

// Print "<tag> on=<local peer id> from=<rpc sender id> value=<payload>". `on` is which peer
// executed the proc; `from` is who sent the RPC (0 for a local call_local dispatch).
@(private = "file")
_log :: proc(self: ^NetNode, tag: string, value: gd.Int) {
	on := gd.my_peer_id(self.owner)
	from := gd.rpc_sender_id(self.owner)
	gd.print_str(fmt.tprintf("RPC_RECV %s on=%d from=%d value=%d", tag, on, from, i64(value)))
}

// any_peer, reliable, NO call_local — exercised BOTH directions (server->client, client->server)
// and ALSO broadcast from the server to prove a non-call_local RPC does NOT run on the sender.
@(gd_method, gd_rpc = "any_peer,reliable")
net_node_ping :: proc(self: ^NetNode, value: gd.Int) {
	_log(self, "ping", value)
}

// authority, reliable — only the node's authority (peer 1 = the server) may send it; it runs
// on the receiver (the client). Covers the second rpc_mode.
@(gd_method, gd_rpc = "authority,reliable")
net_node_auth :: proc(self: ^NetNode, value: gd.Int) {
	_log(self, "auth", value)
}

// any_peer, reliable, call_local ON — the positive control for call_local: when the server
// broadcasts this it runs LOCALLY on the server too (and on the client).
@(gd_method, gd_rpc = "any_peer,reliable,call_local")
net_node_echo :: proc(self: ^NetNode, value: gd.Int) {
	_log(self, "echo", value)
}

// peer_connected handler — wired from Odin via gd.on_peer_connected (exercising that helper);
// prints when a peer joins so the harness can observe the join from the Odin side too.
@(gd_method)
net_node_on_peer :: proc(self: ^NetNode, id: gd.Int) {
	gd.print_str(fmt.tprintf("PEER_JOIN on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
}

// start_host hosts an ENet server on `port` using the gd.host ergonomic helper, wires the
// peer_connected signal to net_node_on_peer via gd.on_peer_connected, and reports its id.
@(gd_method)
net_node_start_host :: proc(self: ^NetNode, port: gd.Int) {
	if gd.host(self.owner, int(port)) {
		gd.on_peer_connected(self.owner, "on_peer")
		gd.print_str(fmt.tprintf("HOST_OK MY_ID=%d is_server=%v", gd.my_peer_id(self.owner), gd.is_server(self.owner)))
	} else {
		gd.print("HOST_FAIL")
	}
}

// start_client joins 127.0.0.1:`port` using the gd.join ergonomic helper.
@(gd_method)
net_node_start_client :: proc(self: ^NetNode, port: gd.Int) {
	if gd.join(self.owner, "127.0.0.1", int(port)) {
		gd.print("CLIENT_STARTED")
	} else {
		gd.print("CLIENT_FAIL")
	}
}

// report prints the live network state via the query helpers (exercises is_server /
// my_peer_id / connected_peers).
@(gd_method)
net_node_report :: proc(self: ^NetNode) {
	peers := gd.connected_peers(self.owner)
	gd.print_str(
		fmt.tprintf(
			"REPORT my_id=%d is_server=%v peers=%v",
			gd.my_peer_id(self.owner),
			gd.is_server(self.owner),
			peers,
		),
	)
}

//gd:extends Node
//gd:class NetNode
package rpc_scripts

// ----------------------------------------------------------------------------
// NetNode — a Node script that exposes RPC methods via `@(gd_rpc)`. It is the subject
// of the RPC test (tests/rpc): a GDScript driver asserts the engine sees these methods
// as RPCs with the right per-method config (Script.get_rpc_config()), and that a
// `call_local` RPC actually dispatches into the Odin method in a single process.
//
// Each `@(gd_rpc)` proc is ALSO a `@(gd_method)` (gd_rpc implies gd_method), so it is a
// registered, name-dispatchable method — which is exactly what the engine invokes when an
// RPC arrives. Side effects on the exported counters make the dispatch observable from
// GDScript.
// ----------------------------------------------------------------------------

import gd "godot:godot"

NetNode :: struct {
	owner:      gd.Node,
	ping_count: gd.Int `gd:"export"`,
	last_value: gd.Int `gd:"export"`,
}

// Bare `@(gd_rpc)`: all defaults — authority mode, reliable transfer, NO call_local, channel 0.
@(gd_method, gd_rpc)
net_node_ping :: proc(self: ^NetNode) {
	self.ping_count += 1
}

// Explicit config: any_peer mode, unreliable transfer, call_local ON, channel 2. Because
// call_local is on, `node.rpc("set_value", n)` runs THIS proc on the calling peer too, so a
// single-process test can observe `last_value` change.
@(gd_method, gd_rpc = "any_peer,unreliable,call_local,channel=2")
net_node_set_value :: proc(self: ^NetNode, value: gd.Int) {
	self.last_value = value
	self.ping_count += 1
}

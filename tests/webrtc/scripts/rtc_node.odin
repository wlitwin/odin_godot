//gd:extends Node
//gd:class RtcNode
package webrtc_scripts

// ----------------------------------------------------------------------------
// RtcNode — the SUBJECT of the two-BROWSER WebRTC RPC test (tests/webrtc). It is the WebRTC
// analogue of tests/rpc_net's NetNode: two independent headless-Chrome instances each load
// this script onto a node at the SAME tree path (/root/Net — required for RPC routing). One
// browser hosts, the other joins, over a REAL browser-native WebRTC data channel established
// via the WebSocket signaling server. Once connected, the SAME `@(gd_rpc)` methods + `gd.rpc`
// used over ENet carry packets across the WebRTC link.
//
// `start_host`/`start_join` kick off the WebRTC session via the gd.webrtc_host/join helpers;
// the `process` lifecycle pumps the signaling socket every frame via gd.webrtc_poll. Each RPC
// proc prints an "RPC_RECV <tag> on=<peer> from=<sender> value=<n>" sentinel so the browser
// driver (driver.gd) — and through it drive.mjs reading the JS console — can prove a call
// crossed the WebRTC wire and executed on the OTHER browser with the correct sender id.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import gdext "godot:gdext"
import "core:fmt"

RtcNode :: struct {
	owner: gd.Node,
}

// Per-frame: pump the WebRTC signaling socket. Once connected this is a cheap no-op; the
// engine polls the installed WebRTCMultiplayerPeer itself.
rtc_node_process :: proc(self: ^RtcNode, _delta: f64) {
	gd.webrtc_poll(self.owner)
}

// Print "<tag> on=<local peer id> from=<rpc sender id> value=<payload>".
@(private = "file")
_log :: proc(self: ^RtcNode, tag: string, value: gd.Int) {
	on := gd.my_peer_id(self.owner)
	from := gd.rpc_sender_id(self.owner)
	gd.print_str(fmt.tprintf("RPC_RECV %s on=%d from=%d value=%d", tag, on, from, i64(value)))
}

// any_peer, reliable, NO call_local — fired BOTH directions (host->client, client->host) to
// prove the WebRTC link carries RPCs with the correct remote sender id each way.
@(gd_method, gd_rpc = "any_peer,reliable")
rtc_node_ping :: proc(self: ^RtcNode, value: gd.Int) {
	_log(self, "ping", value)
}

// any_peer, reliable, call_local — positive control: when broadcast it runs locally too.
@(gd_method, gd_rpc = "any_peer,reliable,call_local")
rtc_node_echo :: proc(self: ^RtcNode, value: gd.Int) {
	_log(self, "echo", value)
}

// start_host hosts the WebRTC lobby (becomes peer id 1), connecting to the signaling URL.
@(gd_method)
rtc_node_start_host :: proc(self: ^RtcNode, url: gd.String) {
	if gd.webrtc_host(self.owner, _to_cstr(url)) {
		gd.print("RTC_HOST_OK")
	} else {
		gd.print("RTC_HOST_FAIL")
	}
}

// start_join joins the WebRTC lobby (room CODE) as a client, connecting to the signaling URL.
@(gd_method)
rtc_node_start_join :: proc(self: ^RtcNode, url: gd.String, room: gd.String) {
	if gd.webrtc_join(self.owner, _to_cstr(url), _to_cstr2(room)) {
		gd.print("RTC_JOIN_OK")
	} else {
		gd.print("RTC_JOIN_FAIL")
	}
}

// room_code returns the host's assigned room CODE (empty until the signaling server replies).
@(gd_method)
rtc_node_room_code :: proc(self: ^RtcNode) -> gd.String {
	return gd.new_string_odin(gd.webrtc_room_code(self.owner))
}

// report prints the live network state (id / is_server / peers) — exercises the query helpers
// over a WebRTCMultiplayerPeer just as rpc_net does over ENet.
@(gd_method)
rtc_node_report :: proc(self: ^RtcNode) {
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

// _to_cstr copies a Godot String's UTF-8 into a package-local buffer and null-terminates it,
// so the URL String the driver passes can feed the cstring-based webrtc_host/join helpers.
@(private = "file")
_urlbuf: [512]u8

@(private = "file")
_to_cstr :: proc(s: gd.String) -> cstring {
	return _copy_cstr(s, _urlbuf[:])
}

// Separate buffer so start_join can convert BOTH url and room without one clobbering the other.
@(private = "file")
_roombuf: [64]u8

@(private = "file")
_to_cstr2 :: proc(s: gd.String) -> cstring {
	return _copy_cstr(s, _roombuf[:])
}

@(private = "file")
_copy_cstr :: proc(s: gd.String, buf: []u8) -> cstring {
	s := s
	need := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if need < 0 {need = 0}
	n := min(int(need), len(buf) - 1)
	if n > 0 {
		gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), i64(n))
	}
	buf[n] = 0
	return cstring(raw_data(buf))
}

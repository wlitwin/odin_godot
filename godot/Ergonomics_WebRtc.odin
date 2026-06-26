package godot

// ----------------------------------------------------------------------------
// Ergonomic helpers for WebRTC multiplayer — the WEB / browser co-op transport.
// Hand-written (like the other Ergonomics_*.odin), and mirrored in
// bindgen/upstream/godot/ so it survives binding regeneration.
//
// WHY: Godot's web export does NOT ship ENetMultiplayerPeer, so `gd.host`/`gd.join`
// (Ergonomics_Multiplayer.odin) return false in the browser. The browser DOES have native
// WebRTC, exposed through Godot's `WebRTCMultiplayerPeer` / `WebRTCPeerConnection`. Setting
// one up by hand is a big async dance: open a signaling channel, create a peer connection,
// trade an SDP offer/answer + trickle ICE candidates, build the data channels, and only
// THEN install it as `multiplayer.multiplayer_peer`. These helpers collapse that into:
//
//     // host (becomes peer id 1), gets a ROOM CODE to share:
//     gd.webrtc_host(self.owner, "wss://relay.example.com/rtc")
//     code := gd.webrtc_room_code(self.owner)   // "" until the server replies `created`
//     // client joins that room code:
//     gd.webrtc_join(self.owner, "wss://relay.example.com/rtc", "ABCD")
//     // ...then EVERY frame, pump the signaling socket until connected:
//     gd.webrtc_poll(self.owner)
//
// Once connected, the SAME `@(gd_rpc)` methods + `gd.rpc` / `gd.rpc_id` used over ENet just
// work — a WebRTCMultiplayerPeer is a MultiplayerPeer like any other, and the high-level
// multiplayer RPC layer is transport-agnostic. So the ENet co-op code is reused verbatim;
// only the transport setup differs.
//
// SIGNALING PROTOCOL (raw WebSocket, JSON text frames; server path `/rtc`). This matches the
// production Elixir relay spec EXACTLY — adhere to field names / message types / id semantics:
//   client -> server:
//     {"type":"create"}                                // make a room, become host (id 1)
//     {"type":"join","room":"<CODE>"}                  // join a room
//     {"type":"signal","to":<peerId>,"data":<opaque>}  // relay SDP/ICE to a peer
//     {"type":"leave"}
//   server -> client:
//     {"type":"created","room":"<CODE>","id":1}
//     {"type":"joined","room":"<CODE>","id":<n>}
//     {"type":"peer","id":<peerId>}                    // both sides get it once 2 are in
//     {"type":"signal","from":<peerId>,"data":<opaque>}
//     {"type":"peer_left","id":<peerId>}
//     {"type":"error","reason":"no_room"|"full"|"bad_msg"}
// The server relays `data` VERBATIM (it never parses it). We carry the WebRTC SDP/ICE that the
// connection emits as a nested JSON object under `data` — both client sides agree on its shape:
//     SDP : {"kind":"sdp","sdp_type":"offer"|"answer","sdp":"<text>"}
//     ICE : {"kind":"ice","media":"<m>","index":<i>,"name":"<candidate>"}
// The host (is_host) initiates with an offer; the client answers when it set_remote_description's
// the offer. Godot's JSON class does all the escaping/parsing (SDP is full of CRLF + ':' chars).
//
// STUN/TURN: _ICE_CONFIG_JSON below is parsed into the WebRTCPeerConnection config so real
// cross-NAT deploys can gather server-reflexive candidates. A public Google STUN server is
// configured; add a TURN entry (with credentials) for SYMMETRIC-NAT pairs that STUN can't punch.
// Localhost needs neither (host candidates resolve directly), so the headless tests don't rely
// on STUN — but it must be present for real internet co-op.
//
// NATIVE CAVEAT: desktop/native Godot has NO bundled WebRTC implementation ("No default WebRTC
// extension configured" — `WebRTCPeerConnection` is an abstract extension point the separate
// `godot-webrtc` GDExtension fills). So these helpers are a WEB-target path: on a native build
// they compile + run, but `WebRTCPeerConnection.initialize` fails unless godot-webrtc is
// installed (out of scope). Prove + use them in the browser export.
//
// 2-PEER scope: this implements a host + one client lobby (exactly what the signaling server
// brokers), so each side has a SINGLE remote peer connection — which is why no per-callable
// peer disambiguation is needed. The structure generalizes, but the helpers target 2 peers.
// ----------------------------------------------------------------------------

import gdext "godot:gdext"

// ICE server configuration parsed into WebRTCPeerConnection.initialize. A public STUN server is
// configured for server-reflexive candidate gathering on real deploys. TURN (relay) is needed
// for SYMMETRIC-NAT peers STUN cannot punch — add an entry like (uncomment + fill credentials):
//   {"urls":["turn:turn.example.com:3478"],"username":"USER","credential":"PASS"}
// to the iceServers array below. Localhost (host candidates) needs neither.
@(private = "file")
_ICE_CONFIG_JSON :: `{"iceServers":[{"urls":["stun:stun.l.google.com:19302"]}]}`

Webrtc_State :: enum {
	Idle,
	Connecting_Ws, // WebSocket opening
	Registering,   // sent create/join, waiting for created/joined (our id + room code)
	Waiting_Peer,  // have id + multiplayer_peer installed, waiting for the other peer
	Handshaking,   // peer connection created; trading SDP/ICE
	Failed,
}

Webrtc_Error :: enum {
	None,
	No_Room,
	Full,
	Bad_Msg,
	Closed,
}

// A live WebRTC signaling+connection session, owned by these helpers (one per hosting/joining
// node). Stored in a small fixed global pool so the helpers stay contextless + allocation-free
// (like the rest of the binding) — there is realistically one lobby per game, a handful at most.
Webrtc_Session :: struct {
	active:    bool,
	is_host:   bool,
	node:      Node,
	mp:        Multiplayer_Api,
	ws:        Web_Socket_Peer,
	rtc:       Web_Rtc_Multiplayer_Peer,
	conn:      Web_Rtc_Peer_Connection,
	have_conn: bool,
	my_id:     int,
	remote_id: int,
	state:     Webrtc_State,
	err:       Webrtc_Error,
	room_buf:  [64]u8, // the room CODE (host: filled on `created`; client: the code it joins)
	room_len:  int,
	// Server-provided ICE config: the relay ships an `ice` array (STUN + an ephemeral-cred TURN
	// entry) in `created`/`joined`, which arrives BEFORE the `peer`-triggered connection setup.
	// We stash it here (as `{"iceServers":[...]}` JSON) and feed it to WebRTCPeerConnection.initialize;
	// when absent we fall back to the built-in STUN config (_ICE_CONFIG_JSON).
	ice_buf:   [4096]u8,
	ice_len:   int,
	have_ice:  bool,
}

@(private = "file")
_WEBRTC_MAX_SESSIONS :: 4

@(private = "file")
_sessions: [_WEBRTC_MAX_SESSIONS]Webrtc_Session

@(private = "file")
_find_free :: proc "contextless" () -> ^Webrtc_Session {
	for i in 0 ..< _WEBRTC_MAX_SESSIONS {
		if !_sessions[i].active {return &_sessions[i]}
	}
	return nil
}

@(private = "file")
_find :: proc "contextless" (node: Node) -> ^Webrtc_Session {
	for i in 0 ..< _WEBRTC_MAX_SESSIONS {
		if _sessions[i].active && _sessions[i].node == node {return &_sessions[i]}
	}
	return nil
}

// webrtc_host starts a WebRTC session as the HOST (peer id 1): it opens the signaling WebSocket
// at `url` (e.g. "wss://relay.example.com/rtc"), sends `create`, and on `created` captures the
// ROOM CODE (read it back with `gd.webrtc_room_code(node)` to share with a friend). The handshake
// begins when the joining peer appears. Returns false if a session slot / the MultiplayerAPI /
// the socket could not be set up. Pump it with `gd.webrtc_poll(node)` every frame; once
// connected, use `gd.rpc`.
webrtc_host :: proc "contextless" (node: Node, url: cstring) -> bool {
	return _webrtc_start(node, url, "", true)
}

// webrtc_join starts a WebRTC session as a CLIENT: opens the signaling WebSocket at `url`, sends
// `join` with `room` (the code the host shared), receives a server-assigned peer id, and answers
// the host's offer. Returns false on setup failure. Pump it with `gd.webrtc_poll(node)` each
// frame; once connected, use `gd.rpc`.
webrtc_join :: proc "contextless" (node: Node, url: cstring, room: cstring) -> bool {
	return _webrtc_start(node, url, room, false)
}

@(private = "file")
_webrtc_start :: proc "contextless" (node: Node, url: cstring, room: cstring, is_host: bool) -> bool {
	s := _find_free()
	if s == nil {return false}
	mp := node_get_multiplayer(node)
	if cast(rawptr)mp == nil {return false}
	ws := new_web_socket_peer()
	if cast(rawptr)ws == nil {return false}
	tls: Tls_Options
	u := new_string_cstring(url)
	if web_socket_peer_connect_to_url(ws, u, tls) != .Ok {return false}
	s^ = Webrtc_Session {
		active  = true,
		is_host = is_host,
		node    = node,
		mp      = mp,
		ws      = ws,
		state   = .Connecting_Ws,
	}
	// Stash the join code (host's is assigned by the server on `created`).
	if !is_host {
		s.room_len = _cstr_to_buf(room, s.room_buf[:])
	}
	return true
}

// webrtc_room_code returns the room CODE for `node`'s session — empty until the server replies
// `created`/`joined`. The host shares this with a friend; the friend passes it to webrtc_join.
webrtc_room_code :: proc "contextless" (node: Node) -> string {
	s := _find(node)
	if s == nil {return ""}
	return string(s.room_buf[:s.room_len])
}

// webrtc_session_state returns the signaling state machine position (for lobby status UI).
webrtc_session_state :: proc "contextless" (node: Node) -> Webrtc_State {
	s := _find(node)
	if s == nil {return .Idle}
	return s.state
}

// webrtc_error_reason returns the last signaling error reason ("" if none) — the verbatim
// server `reason` string ("no_room" / "full" / "bad_msg") or "closed" for a dropped socket.
webrtc_error_reason :: proc "contextless" (node: Node) -> string {
	s := _find(node)
	if s == nil {return ""}
	switch s.err {
	case .None:    return ""
	case .No_Room: return "no_room"
	case .Full:    return "full"
	case .Bad_Msg: return "bad_msg"
	case .Closed:  return "closed"
	}
	return ""
}

// webrtc_poll pumps the signaling socket for `node`'s session: it advances the WebSocket
// handshake, sends create/join when open, and applies inbound created/joined/peer/signal/
// peer_left/error messages (creating the peer connection, trading SDP/ICE, installing the
// multiplayer peer). Safe to call every frame; it is a cheap no-op once the session is gone or
// has failed. The WebRTC peer connection itself is polled by the engine (it is the installed
// multiplayer_peer), so this only needs to service the WebSocket.
webrtc_poll :: proc "contextless" (node: Node) {
	s := _find(node)
	if s == nil || !s.active {return}

	web_socket_peer_poll(s.ws)
	rs := web_socket_peer_get_ready_state(s.ws)
	if rs == .State_Closing || rs == .State_Closed {
		if s.state != .Failed {s.err = .Closed}
		s.state = .Failed
		return
	}

	if s.state == .Connecting_Ws {
		if rs != .State_Open {return}
		m := new_dictionary_default()
		if s.is_host {
			_dset(&m, "type", _vstr("create"))
		} else {
			_dset(&m, "type", _vstr("join"))
			_dset(&m, "room", _vstr_odin(string(s.room_buf[:s.room_len])))
		}
		_send_json(s.ws, &m)
		s.state = .Registering
	}

	n := packet_peer_get_available_packet_count(s.ws)
	for ; n > 0; n -= 1 {
		_handle_packet(s)
	}
}

// webrtc_close tears down `node`'s WebRTC session: it sends `leave`, closes the signaling socket
// and frees the pool slot. The installed multiplayer peer is left in place — call multiplayer's
// own close/clear if you want to drop the RTC connection too.
webrtc_close :: proc "contextless" (node: Node) {
	s := _find(node)
	if s == nil {return}
	if cast(rawptr)s.ws != nil {
		rs := web_socket_peer_get_ready_state(s.ws)
		if rs == .State_Open {
			m := new_dictionary_default()
			_dset(&m, "type", _vstr("leave"))
			_send_json(s.ws, &m)
		}
		web_socket_peer_close(s.ws, 1000, string_empty())
	}
	s.active = false
}

@(private = "file")
_handle_packet :: proc "contextless" (s: ^Webrtc_Session) {
	pba := packet_peer_get_packet(s.ws)
	sz := int(packed_byte_array_size(&pba))
	buf: [32768]u8
	m := min(sz, len(buf))
	for i in 0 ..< m {
		buf[i] = u8(packed_byte_array_get(&pba, Int(i)))
	}

	gs := new_string_odin(string(buf[:m]))
	v := json_parse_string(gs)
	if gdext.variant_get_type(cast(gdext.VariantPtr)&v) != .Dictionary {return}
	d := variant_to_dictionary(&v)

	tbuf: [32]u8
	typ := _dget_str(&d, "type", tbuf[:])

	switch typ {
	case "created":
		_store_room(s, &d)
		_store_ice(s, &d)
		s.my_id = 1
		_install_peer(s, true)
		s.state = .Waiting_Peer

	case "joined":
		_store_room(s, &d)
		_store_ice(s, &d)
		s.my_id = _dget_int(&d, "id")
		_install_peer(s, false)
		s.state = .Waiting_Peer

	case "peer":
		s.remote_id = _dget_int(&d, "id")
		_setup_connection(s)

	case "signal":
		dv := _dget(&d, "data")
		if gdext.variant_get_type(cast(gdext.VariantPtr)&dv) == .Dictionary {
			dd := variant_to_dictionary(&dv)
			_apply_signal(s, &dd)
		}

	case "peer_left":
		// The other peer dropped. There is only one remote in a 2-peer lobby, so the session is
		// effectively over; surface it for the lobby UI.
		s.err = .Closed
		s.state = .Failed

	case "error":
		rbuf: [16]u8
		reason := _dget_str(&d, "reason", rbuf[:])
		switch reason {
		case "no_room": s.err = .No_Room
		case "full":    s.err = .Full
		case:           s.err = .Bad_Msg
		}
		s.state = .Failed
	}
}

@(private = "file")
_install_peer :: proc "contextless" (s: ^Webrtc_Session, server: bool) {
	s.rtc = new_web_rtc_multiplayer_peer()
	chans := new_array_default()
	if server {
		web_rtc_multiplayer_peer_create_server(s.rtc, chans)
	} else {
		web_rtc_multiplayer_peer_create_client(s.rtc, Int(s.my_id), chans)
	}
	multiplayer_api_set_multiplayer_peer(s.mp, s.rtc)
}

@(private = "file")
_store_room :: proc "contextless" (s: ^Webrtc_Session, d: ^Dictionary) {
	rv := _dget(d, "room")
	rs := variant_to_string(&rv)
	s.room_len = len(_str_to_buf(rs, s.room_buf[:]))
}

// _store_ice captures the server-provided `ice` array (sent in created/joined) so it can be used
// as the WebRTCPeerConnection iceServers. The relay mints per-peer ephemeral TURN creds (and a
// STUN entry); the array arrives BEFORE the peer-triggered _setup_connection, so we stash it as a
// `{"iceServers":[...]}` JSON config string here and re-parse it at initialize time. Absent or
// malformed `ice` ⇒ have_ice stays false and we fall back to the built-in STUN config.
@(private = "file")
_store_ice :: proc "contextless" (s: ^Webrtc_Session, d: ^Dictionary) {
	if !_dhas(d, "ice") {return}
	iv := _dget(d, "ice")
	if gdext.variant_get_type(cast(gdext.VariantPtr)&iv) != .Array {return}
	// Wrap the iceServers array in the config dict shape WebRTCPeerConnection.initialize expects,
	// then stringify via Godot's JSON so we never hand-roll Array/Dictionary persistence.
	cfg := new_dictionary_default()
	dictionary_set(&cfg, _vstr("iceServers"), iv)
	cv := variant_from_dictionary(&cfg)
	js := json_stringify(cv, string_empty(), false, false)
	s.ice_len = len(_str_to_buf(js, s.ice_buf[:]))
	s.have_ice = s.ice_len > 0
}

// _apply_signal applies a relayed SDP/ICE payload (the nested `data` object) to our connection.
@(private = "file")
_apply_signal :: proc "contextless" (s: ^Webrtc_Session, dd: ^Dictionary) {
	if !s.have_conn {return}
	if _dhas(dd, "sdp") {
		tv := _dget(dd, "sdp_type")
		t := variant_to_string(&tv)
		sv := _dget(dd, "sdp")
		sdp := variant_to_string(&sv)
		web_rtc_peer_connection_set_remote_description(s.conn, t, sdp)
	} else if _dhas(dd, "name") {
		mv := _dget(dd, "media")
		media := variant_to_string(&mv)
		idx := _dget_int(dd, "index")
		nv := _dget(dd, "name")
		name := variant_to_string(&nv)
		web_rtc_peer_connection_add_ice_candidate(s.conn, media, Int(idx), name)
	}
}

@(private = "file")
_setup_connection :: proc "contextless" (s: ^Webrtc_Session) {
	conn := new_web_rtc_peer_connection()

	// Configure ICE servers. Prefer the relay's server-provided `ice` array (captured on
	// created/joined into ice_buf) — it carries the ephemeral-cred TURN entry needed for
	// cross-NAT relaying. Fall back to the built-in STUN config when the relay sent none (e.g.
	// LAN / a relay with no TURN secret). Built by parsing JSON so the nested iceServers/urls
	// arrays need no hand-rolled Array construction.
	ice_js := s.have_ice ? new_string_odin(string(s.ice_buf[:s.ice_len])) : new_string_cstring(_ICE_CONFIG_JSON)
	cfgv := json_parse_string(ice_js)
	cfg := variant_to_dictionary(&cfgv)
	web_rtc_peer_connection_initialize(conn, cfg)

	// Route the connection's async outputs (SDP + ICE) into our relay procs via custom
	// Callables that carry the session pointer — no per-game handler methods required.
	sd_sig := new_string_name_cstring("session_description_created", true)
	ic_sig := new_string_name_cstring("ice_candidate_created", true)
	object_connect(conn, sd_sig, _make_callable(_on_session_description, s), 0)
	object_connect(conn, ic_sig, _make_callable(_on_ice_candidate, s), 0)

	s.conn = conn
	s.have_conn = true

	// add_peer builds the data channels the multiplayer peer needs; must precede create_offer.
	web_rtc_multiplayer_peer_add_peer(s.rtc, conn, Int(s.remote_id), 1)

	// The host initiates with an offer; the client answers automatically when it
	// set_remote_description's the offer.
	if s.is_host {
		web_rtc_peer_connection_create_offer(conn)
	}
	s.state = .Handshaking
}

// ---- custom-Callable signal relays (proc "c", contextless; read the session via userdata) ----

@(private = "file")
_make_callable :: proc "contextless" (cf: gdext.ExtensionCallableCustomCall, ud: rawptr) -> Callable {
	info: gdext.ExtensionCallableCustomInfo2
	info.callable_userdata = ud
	info.token = rawptr(gdext.library)
	info.call_func = cf
	cb: Callable
	gdext.callable_custom_create2(cast(gdext.TypePtr)&cb, &info)
	return cb
}

// session_description_created(type: String, sdp: String): set it as our LOCAL description, then
// relay it to the other peer as {"type":"signal","to":<remote>,"data":{"kind":"sdp",...}}.
@(private = "file")
_on_session_description :: proc "c" (
	userdata: rawptr,
	args: [^]gdext.VariantPtr,
	argc: i64,
	ret: gdext.VariantPtr,
	err: ^gdext.CallError,
) {
	s := cast(^Webrtc_Session)userdata
	to_str := gdext.get_variant_to_type_constructor(.String)
	type_s: String
	sdp_s: String
	to_str(cast(gdext.TypePtr)&type_s, args[0])
	to_str(cast(gdext.TypePtr)&sdp_s, args[1])

	web_rtc_peer_connection_set_local_description(s.conn, type_s, sdp_s)

	data := new_dictionary_default()
	_dset(&data, "kind", _vstr("sdp"))
	_dset(&data, "sdp_type", _vstr_g(type_s))
	_dset(&data, "sdp", _vstr_g(sdp_s))
	_send_signal(s, &data)

	if err != nil {err.error = .Ok}
	if ret != nil {(cast(^Variant)ret)^ = Variant{}}
}

// ice_candidate_created(media: String, index: int, name: String): relay the trickled candidate
// as {"type":"signal","to":<remote>,"data":{"kind":"ice","media":..,"index":..,"name":..}}.
@(private = "file")
_on_ice_candidate :: proc "c" (
	userdata: rawptr,
	args: [^]gdext.VariantPtr,
	argc: i64,
	ret: gdext.VariantPtr,
	err: ^gdext.CallError,
) {
	s := cast(^Webrtc_Session)userdata
	to_str := gdext.get_variant_to_type_constructor(.String)
	to_int := gdext.get_variant_to_type_constructor(.Int)
	media_s: String
	name_s: String
	index: i64
	to_str(cast(gdext.TypePtr)&media_s, args[0])
	to_int(cast(gdext.TypePtr)&index, args[1])
	to_str(cast(gdext.TypePtr)&name_s, args[2])

	data := new_dictionary_default()
	_dset(&data, "kind", _vstr("ice"))
	_dset(&data, "media", _vstr_g(media_s))
	_dset(&data, "index", _vint(int(index)))
	_dset(&data, "name", _vstr_g(name_s))
	_send_signal(s, &data)

	if err != nil {err.error = .Ok}
	if ret != nil {(cast(^Variant)ret)^ = Variant{}}
}

// _send_signal wraps `data` in the {"type":"signal","to":<remote>,"data":<data>} envelope and
// sends it as a JSON text frame.
@(private = "file")
_send_signal :: proc "contextless" (s: ^Webrtc_Session, data: ^Dictionary) {
	msg := new_dictionary_default()
	_dset(&msg, "type", _vstr("signal"))
	_dset(&msg, "to", _vint(s.remote_id))
	dv := variant_from_dictionary(data)
	dictionary_set(&msg, _vstr("data"), dv)
	_send_json(s.ws, &msg)
}

// ---- small contextless helpers (JSON + Variant/Dictionary glue; no allocation context) -------

// _send_json stringifies a Dictionary via Godot's JSON and sends it as one text frame.
@(private = "file")
_send_json :: proc "contextless" (ws: Web_Socket_Peer, d: ^Dictionary) {
	mv := variant_from_dictionary(d)
	js := json_stringify(mv, string_empty(), false, false)
	web_socket_peer_send_text(ws, js)
}

@(private = "file")
_vstr :: proc "contextless" (s: cstring) -> Variant {
	gs := new_string_cstring(s)
	return variant_from_string(&gs)
}
@(private = "file")
_vstr_odin :: proc "contextless" (s: string) -> Variant {
	gs := new_string_odin(s)
	return variant_from_string(&gs)
}
@(private = "file")
_vstr_g :: proc "contextless" (gs: String) -> Variant {
	gs := gs
	return variant_from_string(&gs)
}
@(private = "file")
_vint :: proc "contextless" (i: int) -> Variant {
	v := Int(i)
	return variant_from_int(&v)
}
@(private = "file")
_dset :: proc "contextless" (d: ^Dictionary, key: cstring, val: Variant) {
	dictionary_set(d, _vstr(key), val)
}
@(private = "file")
_dget :: proc "contextless" (d: ^Dictionary, key: cstring) -> Variant {
	return dictionary_get(d, _vstr(key), Variant{})
}
@(private = "file")
_dhas :: proc "contextless" (d: ^Dictionary, key: cstring) -> bool {
	return bool(dictionary_has(d, _vstr(key)))
}
@(private = "file")
_dget_int :: proc "contextless" (d: ^Dictionary, key: cstring) -> int {
	v := _dget(d, key)
	return int(variant_to_int(&v))
}
@(private = "file")
_dget_str :: proc "contextless" (d: ^Dictionary, key: cstring, buf: []u8) -> string {
	v := _dget(d, key)
	s := variant_to_string(&v)
	return _str_to_buf(s, buf)
}

// _str_to_buf copies a Godot String's UTF-8 bytes into `buf` and returns it as an Odin string
// (valid while `buf` lives).
@(private = "file")
_str_to_buf :: proc "contextless" (str: String, buf: []u8) -> string {
	str := str
	need := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&str, nil, 0)
	if need <= 0 {return ""}
	n := min(int(need), len(buf))
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&str, cast(cstring)raw_data(buf), i64(n))
	return string(buf[:n])
}

// _cstr_to_buf copies a cstring into `buf`, returning the length copied.
@(private = "file")
_cstr_to_buf :: proc "contextless" (s: cstring, buf: []u8) -> int {
	p := cast([^]u8)s
	n := 0
	for n < len(buf) && p[n] != 0 {
		buf[n] = p[n]
		n += 1
	}
	return n
}

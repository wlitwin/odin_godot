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
//     // host (becomes peer id 1):
//     gd.webrtc_host(self.owner, "ws://127.0.0.1:9080")
//     // client (gets a server-assigned id):
//     gd.webrtc_join(self.owner, "ws://127.0.0.1:9080")
//     // ...then EVERY frame, pump the signaling socket until connected:
//     gd.webrtc_poll(self.owner)
//
// Once connected, the SAME `@(gd_rpc)` methods + `gd.rpc` / `gd.rpc_id` used over ENet just
// work — a WebRTCMultiplayerPeer is a MultiplayerPeer like any other, and the high-level
// multiplayer RPC layer is transport-agnostic. So the ENet co-op code is reused verbatim;
// only the transport setup differs.
//
// SIGNALING PROTOCOL (text frames over a WebSocket; see tests/webrtc/signal_server.mjs):
//   field separator is the ASCII Unit-Separator byte 0x1f (never present in SDP/ICE text).
//     client -> server, first frame : "HELLO\x1f<role>"   role = "host" | "join"
//     server -> client              : "ID\x1f<peer_id>"   (host always 1; client random > 1)
//     server -> client (both ready) : "PEER\x1f<other_id>"  begin the handshake
//     peer  <-> peer (relayed)      : "SDP\x1f<type>\x1f<sdp>"        type = "offer"|"answer"
//                                     "ICE\x1f<media>\x1f<index>\x1f<name>"
//   The server only authors ID/PEER; it relays SDP/ICE between the two peers VERBATIM (it
//   never parses their contents). The host (lower id) creates the offer; the client answers.
//
// NATIVE CAVEAT: desktop/native Godot has NO bundled WebRTC implementation ("No default
// WebRTC extension configured" — `WebRTCPeerConnection` is an abstract extension point that
// the separate `godot-webrtc` GDExtension must fill). So these helpers are a WEB-target path:
// on a native build they compile and run, but `WebRTCPeerConnection.initialize` fails unless
// godot-webrtc is installed (out of scope here). Prove + use them in the browser export.
//
// 2-PEER scope: this implements a host + one client lobby (exactly what the signaling server
// brokers), so each side has a SINGLE remote peer connection — which is why no per-callable
// peer disambiguation is needed. The structure generalizes, but the helpers target 2 peers.
// ----------------------------------------------------------------------------

import gdext "godot:gdext"

// Field separator for the signaling protocol — ASCII Unit Separator (0x1f). Chosen because
// it never occurs in SDP blobs or ICE candidate strings, so framing needs no escaping.
@(private = "file")
SEP :: "\x1f"

Webrtc_State :: enum {
	Idle,
	Connecting_Ws, // WebSocket opening
	Waiting_Id,    // HELLO sent, waiting for our assigned peer id
	Waiting_Peer,  // have id + multiplayer_peer installed, waiting for the other peer
	Handshaking,   // peer connection created; trading SDP/ICE
	Failed,
}

// A live WebRTC signaling+connection session, owned by these helpers (one per hosting/joining
// node). Stored in a small fixed global pool so the helpers stay contextless + allocation-free
// (like the rest of the binding) — there is realistically one lobby per game, a handful at most.
Webrtc_Session :: struct {
	active:     bool,
	is_host:    bool,
	node:       Node,
	mp:         Multiplayer_Api,
	ws:         Web_Socket_Peer,
	rtc:        Web_Rtc_Multiplayer_Peer,
	conn:       Web_Rtc_Peer_Connection,
	have_conn:  bool,
	my_id:      int,
	remote_id:  int,
	state:      Webrtc_State,
	role:       cstring,
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

// webrtc_host starts a WebRTC session as the HOST (peer id 1): it opens the signaling
// WebSocket at `url` (e.g. "ws://host:9080") and begins the handshake when the client appears.
// Returns false if a session slot / the MultiplayerAPI / the socket could not be set up. Call
// `gd.webrtc_poll(node)` every frame after this to drive it; once connected, use `gd.rpc`.
webrtc_host :: proc "contextless" (node: Node, url: cstring) -> bool {
	return _webrtc_start(node, url, true)
}

// webrtc_join starts a WebRTC session as a CLIENT: opens the signaling WebSocket at `url`,
// receives a server-assigned peer id, and answers the host's offer. Returns false on setup
// failure. Pump it with `gd.webrtc_poll(node)` each frame; once connected, use `gd.rpc`.
webrtc_join :: proc "contextless" (node: Node, url: cstring) -> bool {
	return _webrtc_start(node, url, false)
}

@(private = "file")
_webrtc_start :: proc "contextless" (node: Node, url: cstring, is_host: bool) -> bool {
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
		role    = is_host ? "host" : "join",
	}
	return true
}

// webrtc_poll pumps the signaling socket for `node`'s session: it advances the WebSocket
// handshake, sends HELLO when open, and applies inbound ID / PEER / SDP / ICE messages
// (creating the peer connection, trading SDP/ICE, installing the multiplayer peer). Safe to
// call every frame; it is a cheap no-op once the session is gone or has failed. The WebRTC
// peer connection itself is polled by the engine (it is the installed multiplayer_peer), so
// this only needs to service the WebSocket.
webrtc_poll :: proc "contextless" (node: Node) {
	s := _find(node)
	if s == nil || !s.active {return}

	web_socket_peer_poll(s.ws)
	rs := web_socket_peer_get_ready_state(s.ws)
	if rs == .State_Closing || rs == .State_Closed {
		s.state = .Failed
		return
	}

	if s.state == .Connecting_Ws {
		if rs != .State_Open {return}
		_send(s.ws, "HELLO", string(s.role))
		s.state = .Waiting_Id
	}

	n := packet_peer_get_available_packet_count(s.ws)
	for ; n > 0; n -= 1 {
		_handle_packet(s)
	}
}

// webrtc_close tears down `node`'s WebRTC session (closes the signaling socket and frees the
// pool slot). The installed multiplayer peer is left in place — call multiplayer's own
// close/clear if you want to drop the RTC connection too.
webrtc_close :: proc "contextless" (node: Node) {
	s := _find(node)
	if s == nil {return}
	if cast(rawptr)s.ws != nil {web_socket_peer_close(s.ws, 1000, string_empty())}
	s.active = false
}

@(private = "file")
_handle_packet :: proc "contextless" (s: ^Webrtc_Session) {
	pba := packet_peer_get_packet(s.ws)
	sz := int(packed_byte_array_size(&pba))
	buf: [16384]u8
	m := min(sz, len(buf))
	for i in 0 ..< m {
		buf[i] = u8(packed_byte_array_get(&pba, Int(i)))
	}
	msg := string(buf[:m])

	fields: [4]string
	fc := _split(msg, &fields)
	if fc == 0 {return}

	switch fields[0] {
	case "ID":
		s.my_id = _atoi(fields[1])
		s.rtc = new_web_rtc_multiplayer_peer()
		chans := new_array_default()
		if s.is_host {
			web_rtc_multiplayer_peer_create_server(s.rtc, chans)
		} else {
			web_rtc_multiplayer_peer_create_client(s.rtc, Int(s.my_id), chans)
		}
		multiplayer_api_set_multiplayer_peer(s.mp, s.rtc)
		s.state = .Waiting_Peer

	case "PEER":
		s.remote_id = _atoi(fields[1])
		_setup_connection(s)

	case "SDP":
		if s.have_conn && fc >= 3 {
			t := new_string_odin(fields[1])
			sdp := new_string_odin(fields[2])
			web_rtc_peer_connection_set_remote_description(s.conn, t, sdp)
		}

	case "ICE":
		if s.have_conn && fc >= 4 {
			media := new_string_odin(fields[1])
			name := new_string_odin(fields[3])
			web_rtc_peer_connection_add_ice_candidate(s.conn, media, Int(_atoi(fields[2])), name)
		}
	}
}

@(private = "file")
_setup_connection :: proc "contextless" (s: ^Webrtc_Session) {
	conn := new_web_rtc_peer_connection()
	cfg := new_dictionary_default()
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

	// The host (peer id 1, the lower id in a 2-peer lobby) initiates with an offer; the client
	// answers automatically when it set_remote_description's the offer.
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

// session_description_created(type: String, sdp: String): set it as our LOCAL description,
// then relay it to the other peer over the signaling socket.
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

	tbuf: [64]u8
	sbuf: [16384]u8
	_send(s.ws, "SDP", _str_to_buf(type_s, tbuf[:]), _str_to_buf(sdp_s, sbuf[:]))

	if err != nil {err.error = .Ok}
	if ret != nil {(cast(^Variant)ret)^ = Variant{}}
}

// ice_candidate_created(media: String, index: int, name: String): relay the trickled
// candidate to the other peer over the signaling socket.
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

	mbuf: [256]u8
	ibuf: [24]u8
	nbuf: [4096]u8
	_send(s.ws, "ICE", _str_to_buf(media_s, mbuf[:]), _itoa(int(index), ibuf[:]), _str_to_buf(name_s, nbuf[:]))

	if err != nil {err.error = .Ok}
	if ret != nil {(cast(^Variant)ret)^ = Variant{}}
}

// ---- small contextless string helpers (stack buffers; no allocation / no Odin context) ----

// _send frames `parts` with the 0x1f separator and sends them as one text frame.
@(private = "file")
_send :: proc "contextless" (ws: Web_Socket_Peer, parts: ..string) {
	buf: [20480]u8
	pos := 0
	for p, i in parts {
		if i > 0 && pos < len(buf) {
			buf[pos] = 0x1f
			pos += 1
		}
		pos += copy(buf[pos:], p)
	}
	gs := new_string_odin(string(buf[:pos]))
	web_socket_peer_send_text(ws, gs)
}

// _str_to_buf copies a Godot String's UTF-8 bytes into `buf` and returns it as an Odin string
// (valid while `buf` lives). Used to read SDP/ICE text out for relaying.
@(private = "file")
_str_to_buf :: proc "contextless" (str: String, buf: []u8) -> string {
	str := str
	need := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&str, nil, 0)
	if need <= 0 {return ""}
	n := min(int(need), len(buf))
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&str, cast(cstring)raw_data(buf), i64(n))
	return string(buf[:n])
}

// _split fills up to 4 fields split on 0x1f, returning the count.
@(private = "file")
_split :: proc "contextless" (s: string, out: ^[4]string) -> int {
	cnt := 0
	start := 0
	for i in 0 ..< len(s) {
		if s[i] == 0x1f {
			if cnt < 4 {
				out[cnt] = s[start:i]
				cnt += 1
			}
			start = i + 1
		}
	}
	if cnt < 4 {
		out[cnt] = s[start:]
		cnt += 1
	}
	return cnt
}

@(private = "file")
_atoi :: proc "contextless" (s: string) -> int {
	n := 0
	neg := false
	i := 0
	if len(s) > 0 && s[0] == '-' {
		neg = true
		i = 1
	}
	for ; i < len(s); i += 1 {
		c := s[i]
		if c < '0' || c > '9' {break}
		n = n * 10 + int(c - '0')
	}
	return neg ? -n : n
}

@(private = "file")
_itoa :: proc "contextless" (v: int, buf: []u8) -> string {
	if v == 0 {
		buf[0] = '0'
		return string(buf[:1])
	}
	neg := v < 0
	m := neg ? -v : v
	i := len(buf)
	for m > 0 && i > 0 {
		i -= 1
		buf[i] = u8('0' + m % 10)
		m /= 10
	}
	if neg && i > 0 {
		i -= 1
		buf[i] = '-'
	}
	return string(buf[i:])
}

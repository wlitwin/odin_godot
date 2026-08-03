package godot

// ----------------------------------------------------------------------------
// Ergonomic helpers for WebRTC multiplayer — the WEB / browser co-op transport.
// Hand-written (like the other Ergonomics_*.odin) and owned here (binding regeneration only
// rewrites *.gen.odin).
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
//     {"type":"create","room":"<CODE>"}                // ...reserving a code — honored when
//                                                      // free/valid, else assigned (read the
//                                                      // `created` reply for the truth)
//     {"type":"join","room":"<CODE>"}                  // join a room
//     {"type":"signal","to":<peerId>,"data":<opaque>}  // relay SDP/ICE to a peer
//     {"type":"leave"}
//   server -> client:
//     {"type":"created","room":"<CODE>","id":1}
//     {"type":"joined","room":"<CODE>","id":<n>}
//     {"type":"peer","id":<peerId>}                    // host: one per joiner; joiner: the host
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
// N-PEER scope: the room is a STAR — one host (peer 1) plus up to seven joiners (the relay
// assigns ids 2, 3, … in join order and never reuses one). Each JOINER holds a single
// connection (to the host); the HOST holds one per joiner. Godot's WebRTCMultiplayerPeer in
// server mode relays client<->client game traffic through the host, so joiners never
// handshake with each other yet the SceneMultiplayer layer above sees every peer.
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

// One live WebRTCPeerConnection to a REMOTE peer, plus the back-pointer the signal-relay
// Callables need: their userdata must name both the session AND which remote's connection
// emitted (an SDP/ICE payload is addressed to exactly one peer). The host fills one slot per
// joiner; a client fills a single slot (the host's). `conn_id` is the connection's INSTANCE
// ID: the engine owns post-connect teardown (its poll reaps dead channels and frees the
// object), so before touching `conn` on a signaling message the slot must prove the object
// still exists — instance ids are never reused, a nil lookup means freed.
Webrtc_Conn :: struct {
	used:      bool,
	remote_id: int,
	conn:      Web_Rtc_Peer_Connection,
	conn_id:   u64,
	ses:       ^Webrtc_Session,
}

// _conn_alive: the connection object still exists (the engine frees a reaped peer's
// connection out from under the slot — see conn_id above).
@(private = "file")
_conn_alive :: proc "contextless" (c: ^Webrtc_Conn) -> bool {
	return gdext.object_get_instance_from_id(gdext.ObjectInstanceId(c.conn_id)) != nil
}

// Remote-connection slots per session: the relay's room cap (host + seven joiners), so the
// host side can hold every joiner the relay will ever introduce.
@(private = "file")
_WEBRTC_MAX_REMOTES :: 8

// A live WebRTC signaling+connection session, owned by these helpers (one per hosting/joining
// node). Stored in a small fixed global pool so the helpers stay contextless + allocation-free
// (like the rest of the binding) — there is realistically one lobby per game, a handful at most.
Webrtc_Session :: struct {
	active:    bool,
	is_host:   bool,
	// The owning node's INSTANCE ID (object_get_instance_id), not its raw pointer: a freed
	// node's pointer can be reused by a new allocation, which would alias a stale session
	// slot onto an unrelated node. Instance ids are never reused.
	node_id:   u64,
	mp:        Multiplayer_Api,
	ws:        Web_Socket_Peer,
	rtc:       Web_Rtc_Multiplayer_Peer,
	conns:     [_WEBRTC_MAX_REMOTES]Webrtc_Conn,
	my_id:     int,
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
	id := object_get_instance_id(node)
	for i in 0 ..< _WEBRTC_MAX_SESSIONS {
		if _sessions[i].active && _sessions[i].node_id == id {return &_sessions[i]}
	}
	return nil
}

@(private = "file")
_conn_find :: proc "contextless" (s: ^Webrtc_Session, remote_id: int) -> ^Webrtc_Conn {
	for i in 0 ..< _WEBRTC_MAX_REMOTES {
		if s.conns[i].used && s.conns[i].remote_id == remote_id {return &s.conns[i]}
	}
	return nil
}

@(private = "file")
_conn_free_slot :: proc "contextless" (s: ^Webrtc_Session) -> ^Webrtc_Conn {
	for i in 0 ..< _WEBRTC_MAX_REMOTES {
		if !s.conns[i].used {return &s.conns[i]}
	}
	return nil
}

@(private = "file")
_conn_count :: proc "contextless" (s: ^Webrtc_Session) -> int {
	n := 0
	for i in 0 ..< _WEBRTC_MAX_REMOTES {
		if s.conns[i].used {n += 1}
	}
	return n
}

// webrtc_host starts a WebRTC session as the HOST (peer id 1): it opens the signaling WebSocket
// at `url` (e.g. "wss://relay.example.com/rtc"), sends `create`, and on `created` captures the
// ROOM CODE (read it back with `gd.webrtc_room_code(node)` to share with a friend). A non-empty
// `room` RESERVES that code — the relay honors it when free and valid, else assigns fresh (host
// migration pre-arranges tomorrow's room this way, so survivors can chase a code they already
// know; webrtc_room_code always reports the code that actually opened). The handshake begins
// when the joining peer appears. Returns false if a session slot / the MultiplayerAPI / the
// socket could not be set up. Pump it with `gd.webrtc_poll(node)` every frame; once connected,
// use `gd.rpc`.
webrtc_host :: proc "contextless" (node: Node, url: cstring, room: cstring = "") -> bool {
	return _webrtc_start(node, url, room, true)
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
	defer free_string(u)
	if web_socket_peer_connect_to_url(ws, u, tls) != .Ok {return false}
	s^ = Webrtc_Session {
		active  = true,
		is_host = is_host,
		node_id = object_get_instance_id(node),
		mp      = mp,
		ws      = ws,
		state   = .Connecting_Ws,
	}
	// Stash the code: the client's join target, or the host's RESERVATION
	// (the `created` reply overwrites it with whatever actually opened).
	s.room_len = _cstr_to_buf(room, s.room_buf[:])
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
		defer free_dictionary(m)
		if s.is_host {
			_dset(&m, "type", _vstr("create"))
			if s.room_len > 0 { // a reservation rides along; the relay decides
				_dset(&m, "room", _vstr_odin(string(s.room_buf[:s.room_len])))
			}
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

// webrtc_close tears down `node`'s WebRTC session COMPLETELY so a fresh webrtc_host/webrtc_join
// can start clean: it sends `leave`, closes the signaling socket, DETACHES the installed WebRTC
// multiplayer peer from the MultiplayerAPI (back to offline), and zeroes the pool slot (clearing
// the room/ICE buffers + the peer-connection handles). This is what lets a failed connection
// attempt recover and be retried in-place (no page reload): after webrtc_close the slot is free
// and the MultiplayerAPI has no stale peer, so a re-host/re-join installs a brand-new one.
webrtc_close :: proc "contextless" (node: Node) {
	s := _find(node)
	if s == nil {return}
	if cast(rawptr)s.ws != nil {
		rs := web_socket_peer_get_ready_state(s.ws)
		if rs == .State_Open {
			m := new_dictionary_default()
			defer free_dictionary(m)
			_dset(&m, "type", _vstr("leave"))
			_send_json(s.ws, &m)
		}
		web_socket_peer_close(s.ws, 1000, string_empty())
	}
	// Close every remote connection STILL STANDING (the engine frees reaped peers'
	// connections out from under the slots — never touch a freed one), then detach the
	// WebRTC multiplayer peer so the MultiplayerAPI returns to offline; the engine drops
	// its ref to the (RefCounted) WebRTCMultiplayerPeer + its peer connections, which free.
	for i in 0 ..< _WEBRTC_MAX_REMOTES {
		if s.conns[i].used && _conn_alive(&s.conns[i]) {
			web_rtc_peer_connection_close(s.conns[i].conn)
		}
	}
	if cast(rawptr)s.mp != nil {
		none: Multiplayer_Peer
		multiplayer_api_set_multiplayer_peer(s.mp, none)
	}
	// Zero the slot: clears active/state/err, the room + ICE buffers, and the ws/rtc/conn handles,
	// so the pool slot is fully reusable by a subsequent webrtc_host/webrtc_join.
	s^ = Webrtc_Session{}
}

@(private = "file")
_handle_packet :: proc "contextless" (s: ^Webrtc_Session) {
	pba := packet_peer_get_packet(s.ws)
	defer free_packed_byte_array(pba)
	sz := int(packed_byte_array_size(&pba))
	buf: [32768]u8
	m := min(sz, len(buf))
	for i in 0 ..< m {
		buf[i] = u8(packed_byte_array_get(&pba, Int(i)))
	}

	gs := new_string_odin(string(buf[:m]))
	defer free_string(gs)
	v := json_parse_string(gs)
	defer variant_destroy(&v)
	if gdext.variant_get_type(cast(gdext.VariantPtr)&v) != .Dictionary {return}
	d := variant_to_dictionary(&v)
	defer free_dictionary(d)

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
		_setup_connection(s, _dget_int(&d, "id"))

	case "signal":
		// Route by SENDER: each remote has its own connection (the host holds several).
		c := _conn_find(s, _dget_int(&d, "from"))
		if c != nil {
			if !_conn_alive(c) {
				// The engine already reaped this peer and freed the connection; a
				// straggler SDP/ICE frame has nowhere to land. Forget the slot.
				c^ = Webrtc_Conn{}
			} else {
				dv := _dget(&d, "data")
				defer variant_destroy(&dv)
				if gdext.variant_get_type(cast(gdext.VariantPtr)&dv) == .Dictionary {
					dd := variant_to_dictionary(&dv)
					defer free_dictionary(dd)
					_apply_signal(c, &dd)
				}
			}
		}

	case "peer_left":
		// The relay broadcasts departures to the whole room. A client hearing about
		// ANOTHER joiner has no connection to it (star topology) — nothing to do.
		id := _dget_int(&d, "id")
		c := _conn_find(s, id)
		if c == nil {break}
		// THE PRODUCTION ORDER OF DEATH: media dies fast — the engine's poll notices
		// the dead channel in seconds, reaps the peer, and FREES the connection —
		// while a dead tab's signaling socket can linger to a TCP timeout, so this
		// message often arrives AFTER the object is gone. Touch the connection only
		// if it still exists, and reap it ourselves only when it never finished the
		// handshake (nobody else will free THAT one). Everything post-connect is the
		// ENGINE's teardown to run — racing it is how the web host died mid-game
		// ("indirect call to null" through a freed connection). A LIVE connected
		// link stays untouched entirely: a relay blip must not kill a healthy game
		// (the engine notices real departures through the channel itself).
		pre := false
		if _conn_alive(c) {
			st := web_rtc_peer_connection_get_connection_state(c.conn)
			if st == .State_Connected {break} // healthy link; the slot stays too
			pre = st == .State_New || st == .State_Connecting
			if pre {
				web_rtc_multiplayer_peer_remove_peer(s.rtc, Int(id))
				web_rtc_peer_connection_close(c.conn)
			}
		}
		c^ = Webrtc_Conn{}
		if !s.is_host && pre {
			// The HOST vanished before the channel ever came up: the lobby is over;
			// surface it for the UI. (A post-connect departure is the ENGINE's news
			// — the game hears server_disconnected and decides.)
			s.err = .Closed
			s.state = .Failed
		} else if s.is_host && _conn_count(s) == 0 {
			s.state = .Waiting_Peer
		}

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
	// The toolkit (kit/netgd) sends on channel 1 (RELIABLE — commands,
	// snapshots) and channel 2 (UNRELIABLE_ORDERED — owner streams), beyond
	// the engine's own channel 0. A WebRTCMultiplayerPeer created with an
	// EMPTY config has only channel 0's three modes, so a send on channel 1/2
	// fails with "channel N, max channels: 3". Declare the two extra channels
	// with the modes the toolkit uses (config[i] = the mode for channel i+1).
	// ENet games never hit this — ENet has channels for free; WebRTC must
	// reserve them up front. (Harmless for channel-0-only RPC games.)
	chans := new_array_default()
	defer free_array(chans)
	c1 := Int(Multiplayer_Peer_Transfer_Mode.Transfer_Mode_Reliable) // channel 1
	c2 := Int(Multiplayer_Peer_Transfer_Mode.Transfer_Mode_Unreliable_Ordered) // channel 2
	array_push_back(&chans, variant_from_int(&c1))
	array_push_back(&chans, variant_from_int(&c2))
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
	defer variant_destroy(&rv)
	rs := variant_to_string(&rv)
	defer free_string(rs)
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
	if gdext.variant_get_type(cast(gdext.VariantPtr)&iv) != .Array {
		variant_destroy(&iv)
		return
	}
	// Wrap the iceServers array in the config dict shape WebRTCPeerConnection.initialize expects,
	// then stringify via Godot's JSON so we never hand-roll Array/Dictionary persistence.
	cfg := new_dictionary_default()
	defer free_dictionary(cfg)
	_dset(&cfg, "iceServers", iv) // _dset consumes iv
	cv := variant_from_dictionary(&cfg)
	defer variant_destroy(&cv)
	js := json_stringify(cv, string_empty(), false, false)
	defer free_string(js)
	s.ice_len = len(_str_to_buf(js, s.ice_buf[:]))
	s.have_ice = s.ice_len > 0
}

// _apply_signal applies a relayed SDP/ICE payload (the nested `data` object) to the sender's
// connection.
@(private = "file")
_apply_signal :: proc "contextless" (c: ^Webrtc_Conn, dd: ^Dictionary) {
	if _dhas(dd, "sdp") {
		tv := _dget(dd, "sdp_type")
		defer variant_destroy(&tv)
		t := variant_to_string(&tv)
		defer free_string(t)
		sv := _dget(dd, "sdp")
		defer variant_destroy(&sv)
		sdp := variant_to_string(&sv)
		defer free_string(sdp)
		web_rtc_peer_connection_set_remote_description(c.conn, t, sdp)
	} else if _dhas(dd, "name") {
		mv := _dget(dd, "media")
		defer variant_destroy(&mv)
		media := variant_to_string(&mv)
		defer free_string(media)
		idx := _dget_int(dd, "index")
		nv := _dget(dd, "name")
		defer variant_destroy(&nv)
		name := variant_to_string(&nv)
		defer free_string(name)
		web_rtc_peer_connection_add_ice_candidate(c.conn, media, Int(idx), name)
	}
}

@(private = "file")
_setup_connection :: proc "contextless" (s: ^Webrtc_Session, remote_id: int) {
	if _conn_find(s, remote_id) != nil {return} // duplicate `peer` — already wired
	c := _conn_free_slot(s)
	if c == nil {return} // more remotes than slots; the relay's room cap sits below this
	conn := new_web_rtc_peer_connection()

	// Configure ICE servers. Prefer the relay's server-provided `ice` array (captured on
	// created/joined into ice_buf) — it carries the ephemeral-cred TURN entry needed for
	// cross-NAT relaying. Fall back to the built-in STUN config when the relay sent none (e.g.
	// LAN / a relay with no TURN secret). Built by parsing JSON so the nested iceServers/urls
	// arrays need no hand-rolled Array construction.
	ice_js := s.have_ice ? new_string_odin(string(s.ice_buf[:s.ice_len])) : new_string_cstring(_ICE_CONFIG_JSON)
	defer free_string(ice_js)
	cfgv := json_parse_string(ice_js)
	defer variant_destroy(&cfgv)
	cfg := variant_to_dictionary(&cfgv)
	defer free_dictionary(cfg)
	web_rtc_peer_connection_initialize(conn, cfg)

	// Claim the slot BEFORE wiring signals: the Callables carry the slot pointer as their
	// userdata (it names both the session and the remote this connection talks to).
	c^ = Webrtc_Conn {
		used      = true,
		remote_id = remote_id,
		conn      = conn,
		conn_id   = object_get_instance_id(cast(Object)conn),
		ses       = s,
	}

	// Route the connection's async outputs (SDP + ICE) into our relay procs via custom
	// Callables that carry the conn-slot pointer — no per-game handler methods required.
	// object_connect copies the Callable into the connection, so release our temporaries.
	sd_sig := new_string_name_cstring("session_description_created", true)
	ic_sig := new_string_name_cstring("ice_candidate_created", true)
	sd_cb := _make_callable(_on_session_description, c)
	defer free_callable(sd_cb)
	ic_cb := _make_callable(_on_ice_candidate, c)
	defer free_callable(ic_cb)
	object_connect(cast(Object)conn, sd_sig, sd_cb, 0)
	object_connect(cast(Object)conn, ic_sig, ic_cb, 0)

	// add_peer builds the data channels the multiplayer peer needs; must precede create_offer.
	web_rtc_multiplayer_peer_add_peer(s.rtc, conn, Int(remote_id), 1)

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
// relay it to that connection's remote as {"type":"signal","to":<remote>,"data":{"kind":"sdp",...}}.
@(private = "file")
_on_session_description :: proc "c" (
	userdata: rawptr,
	args: [^]gdext.VariantPtr,
	argc: i64,
	ret: gdext.VariantPtr,
	err: ^gdext.CallError,
) {
	c := cast(^Webrtc_Conn)userdata
	if !c.used || cast(rawptr)c.conn == nil {
		// The slot was reaped between this signal queuing and firing (a dying
		// connection's last gasp) — there is nothing left to describe.
		if err != nil {err.error = .Ok}
		if ret != nil {(cast(^Variant)ret)^ = Variant{}}
		return
	}
	to_str := gdext.get_variant_to_type_constructor(.String)
	type_s: String
	sdp_s: String
	to_str(cast(gdext.TypePtr)&type_s, args[0])
	defer free_string(type_s)
	to_str(cast(gdext.TypePtr)&sdp_s, args[1])
	defer free_string(sdp_s)

	web_rtc_peer_connection_set_local_description(c.conn, type_s, sdp_s)

	data := new_dictionary_default()
	defer free_dictionary(data)
	_dset(&data, "kind", _vstr("sdp"))
	_dset(&data, "sdp_type", _vstr_g(type_s))
	_dset(&data, "sdp", _vstr_g(sdp_s))
	_send_signal(c.ses, c.remote_id, &data)

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
	c := cast(^Webrtc_Conn)userdata
	if !c.used || cast(rawptr)c.conn == nil {
		// Reaped slot (see _on_session_description) — drop the candidate.
		if err != nil {err.error = .Ok}
		if ret != nil {(cast(^Variant)ret)^ = Variant{}}
		return
	}
	to_str := gdext.get_variant_to_type_constructor(.String)
	to_int := gdext.get_variant_to_type_constructor(.Int)
	media_s: String
	name_s: String
	index: i64
	to_str(cast(gdext.TypePtr)&media_s, args[0])
	defer free_string(media_s)
	to_int(cast(gdext.TypePtr)&index, args[1])
	to_str(cast(gdext.TypePtr)&name_s, args[2])
	defer free_string(name_s)

	data := new_dictionary_default()
	defer free_dictionary(data)
	_dset(&data, "kind", _vstr("ice"))
	_dset(&data, "media", _vstr_g(media_s))
	_dset(&data, "index", _vint(int(index)))
	_dset(&data, "name", _vstr_g(name_s))
	_send_signal(c.ses, c.remote_id, &data)

	if err != nil {err.error = .Ok}
	if ret != nil {(cast(^Variant)ret)^ = Variant{}}
}

// _send_signal wraps `data` in the {"type":"signal","to":<to>,"data":<data>} envelope and
// sends it as a JSON text frame.
@(private = "file")
_send_signal :: proc "contextless" (s: ^Webrtc_Session, to: int, data: ^Dictionary) {
	msg := new_dictionary_default()
	defer free_dictionary(msg)
	_dset(&msg, "type", _vstr("signal"))
	_dset(&msg, "to", _vint(to))
	_dset(&msg, "data", variant_from_dictionary(data)) // _dset consumes the Variant
	_send_json(s.ws, &msg)
}

// ---- small contextless helpers (JSON + Variant/Dictionary glue; no allocation context) -------
//
// Ownership convention: the _vstr*/_vint builders return a Variant OWNED BY THE CALLER (the
// intermediate Godot String is freed inside — the Variant constructor takes its own
// reference). `_dset` CONSUMES its `val` Variant (dictionary_set stores a copy, so _dset
// destroys both the key and the value temporaries); `_dget` returns a Variant the caller must
// destroy.

// _send_json stringifies a Dictionary via Godot's JSON and sends it as one text frame.
// `d` is not consumed.
@(private = "file")
_send_json :: proc "contextless" (ws: Web_Socket_Peer, d: ^Dictionary) {
	mv := variant_from_dictionary(d)
	defer variant_destroy(&mv)
	js := json_stringify(mv, string_empty(), false, false)
	defer free_string(js)
	web_socket_peer_send_text(ws, js)
}

@(private = "file")
_vstr :: proc "contextless" (s: cstring) -> Variant {
	gs := new_string_cstring(s)
	defer free_string(gs)
	return variant_from_string(&gs)
}
@(private = "file")
_vstr_odin :: proc "contextless" (s: string) -> Variant {
	gs := new_string_odin(s)
	defer free_string(gs)
	return variant_from_string(&gs)
}
// _vstr_g does NOT consume `gs` — the caller still owns (and must free) its String.
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
// _dset stores `val` under `key` and CONSUMES `val` (dictionary_set copies; the key and value
// temporaries are destroyed here).
@(private = "file")
_dset :: proc "contextless" (d: ^Dictionary, key: cstring, val: Variant) {
	val := val
	defer variant_destroy(&val)
	k := _vstr(key)
	defer variant_destroy(&k)
	dictionary_set(d, k, val)
}
// _dget returns the value Variant OWNED BY THE CALLER (destroy with variant_destroy).
@(private = "file")
_dget :: proc "contextless" (d: ^Dictionary, key: cstring) -> Variant {
	k := _vstr(key)
	defer variant_destroy(&k)
	return dictionary_get(d, k, Variant{})
}
@(private = "file")
_dhas :: proc "contextless" (d: ^Dictionary, key: cstring) -> bool {
	k := _vstr(key)
	defer variant_destroy(&k)
	return bool(dictionary_has(d, k))
}
@(private = "file")
_dget_int :: proc "contextless" (d: ^Dictionary, key: cstring) -> int {
	v := _dget(d, key)
	defer variant_destroy(&v)
	return int(variant_to_int(&v))
}
@(private = "file")
_dget_str :: proc "contextless" (d: ^Dictionary, key: cstring, buf: []u8) -> string {
	v := _dget(d, key)
	defer variant_destroy(&v)
	s := variant_to_string(&v)
	defer free_string(s)
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

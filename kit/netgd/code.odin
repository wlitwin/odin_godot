package kit_netgd

// JOIN CODES for native ENet — "send your friend a four-letter code" without
// Steam, without reading out an IP. The same signaling relay the browser
// build already uses (tests/webrtc/signal_server.mjs speaks the protocol;
// the production relay serves it at /rtc) grows a NATIVE room mode: the host
// registers its ENet UDP port under a minted code, a joiner trades the code
// for the host's observed endpoint, and the game connects plain ENet as if
// the friend had typed the address. No SDP, no WebRTC — the relay is a
// phonebook that answers once per join.
//
//   // host — after begin_host(port, ...) succeeded:
//   netgd.code_host_open(&self.rdv, RELAY_URL, port)
//   // joiner — instead of an address:
//   netgd.code_join_open(&self.rdv, RELAY_URL, "KWXP")
//
//   // both — every frame until it resolves:
//   switch netgd.code_poll(&self.rdv, &self.boot.wire) {
//   case .Ready:
//       if !self.rdv.is_host {   // the phonebook answered: connect for real
//           ip, port := netgd.code_endpoint(&self.rdv)
//           begin_join(&self.boot.wire, ip, port, token, name)
//       }
//       // hosts are Ready the moment the code exists: show code_room(&rdv)
//   case .Failed: // netgd.Code_Error in rdv.err — say WHY, then offer the browser/Steam doors
//   }
//
// NAT HONESTY (the part every "just works" pitch hides): this covers the
// same-LAN pair, the port-forwarded or public host, and the common
// port-preserving home NAT (the relay hands the host each joiner's observed
// endpoint and the host PUNCHES a few UDP packets at it, so the joiner's
// inbound connect finds a warm mapping). It does NOT cover symmetric NATs —
// there is no TURN for raw ENet. When the connect times out, say so and
// point at the doors that always work: the browser build (WebRTC + TURN)
// and Steam. That trade — a copyable code that works for most, with two
// spare doors — is the deliberate stance.

import gd "godot:godot"
import "godot:gdext"
import "core:fmt"

Code_State :: enum u8 {
	Idle,
	Opening, // WebSocket connecting; create/join not yet sent
	Waiting, // sent; waiting for the relay's answer
	Ready,   // host: code minted (code_room). joiner: endpoint known (code_endpoint)
	Failed,  // rdv.err says why
}

Code_Error :: enum u8 {
	None,
	No_Room, // the code names no live room (typo, or the host closed)
	Full,
	Bad_Msg,
	Closed, // the relay socket dropped before answering
}

Code_Rendezvous :: struct {
	ws:        gd.Web_Socket_Peer,
	active:    bool,
	is_host:   bool,
	state:     Code_State,
	err:       Code_Error,
	udp:       int, // my declared ENet port (host: the bound server port)
	sent:      bool, // create/join dispatched once the socket opened
	want:      [12]u8, // joiner: the code being chased
	want_len:  int,
	code:      [12]u8, // the room code that actually opened
	code_len:  int,
	host_ip:   [64]u8, // joiner: the host's endpoint, from the relay
	ip_len:    int,
	host_port: int,
}

// Host side: register the ALREADY-BOUND ENet port under a fresh code. Call
// after begin_host succeeded; poll until .Ready, then show code_room to the
// humans. `room` reserves a code when free (succession pre-arranges).
code_host_open :: proc(cr: ^Code_Rendezvous, url: cstring, udp_port: int, room: string = "") -> bool {
	return _code_open(cr, url, udp_port, room, true)
}

// Joiner side: trade `code` for the host's endpoint. Poll until .Ready, then
// code_endpoint feeds begin_join — the rest is a normal ENet join.
code_join_open :: proc(cr: ^Code_Rendezvous, url: cstring, code: string) -> bool {
	return _code_open(cr, url, 0, code, false)
}

@(private = "file")
_code_open :: proc(cr: ^Code_Rendezvous, url: cstring, udp_port: int, room: string, is_host: bool) -> bool {
	code_close(cr)
	ws := gd.new_web_socket_peer()
	if cast(rawptr)ws == nil {
		return false
	}
	gurl := gd.new_string_odin(string(url))
	defer gd.free_string(gurl)
	tls: gd.Tls_Options // zero = defaults (system CAs for wss://; ws:// ignores it)
	if gd.web_socket_peer_connect_to_url(ws, gurl, tls) != .Ok {
		return false
	}
	cr^ = {}
	cr.ws = ws
	cr.active = true
	cr.is_host = is_host
	cr.udp = udp_port
	cr.state = .Opening
	n := min(len(room), len(cr.want))
	copy(cr.want[:n], room[:n])
	cr.want_len = n
	return true
}

// The room code that actually opened ("" until .Ready on the host side;
// joiners echo the code they chased).
code_room :: proc(cr: ^Code_Rendezvous) -> string {
	return string(cr.code[:cr.code_len])
}

// Joiner, at .Ready: where the host lives — hand it to begin_join.
code_endpoint :: proc(cr: ^Code_Rendezvous) -> (ip: cstring, port: int) {
	return fmt.ctprintf("%s", string(cr.host_ip[:cr.ip_len])), cr.host_port
}

// Pump the rendezvous. `wire` lets the HOST punch a joiner's observed
// endpoint through its own bound ENet socket (nil skips the punch — the
// LAN/port-forward cases never needed it).
code_poll :: proc(cr: ^Code_Rendezvous, wire: ^Session_Wire = nil) -> Code_State {
	if !cr.active || cr.state == .Failed {
		return cr.state
	}
	gd.web_socket_peer_poll(cr.ws)
	rs := gd.web_socket_peer_get_ready_state(cr.ws)
	#partial switch rs {
	case .State_Connecting:
		return cr.state
	case .State_Closing, .State_Closed:
		// A host that already minted its code keeps it — the relay only
		// matters while joins are brokered... but a dead relay brokers no
		// NEW joins, so surface it once the answer never came.
		if cr.state != .Ready {
			cr.state = .Failed
			cr.err = .Closed
		}
		return cr.state
	}
	if !cr.sent {
		cr.sent = true
		msg: string
		if cr.is_host {
			msg = len(cr.want[:cr.want_len]) > 0 \
				? fmt.tprintf(`{{"type":"create","native":true,"udp":%d,"room":"%s"}}`, cr.udp, string(cr.want[:cr.want_len])) \
				: fmt.tprintf(`{{"type":"create","native":true,"udp":%d}}`, cr.udp)
		} else {
			msg = fmt.tprintf(`{{"type":"join","room":"%s"}}`, string(cr.want[:cr.want_len]))
		}
		gm := gd.new_string_odin(msg)
		defer gd.free_string(gm)
		gd.web_socket_peer_send_text(cr.ws, gm)
		cr.state = .Waiting
	}
	n := int(gd.packet_peer_get_available_packet_count(cast(gd.Packet_Peer)cr.ws))
	for ; n > 0; n -= 1 {
		_code_packet(cr, wire)
	}
	return cr.state
}

code_close :: proc(cr: ^Code_Rendezvous) {
	if !cr.active {
		return
	}
	gd.web_socket_peer_close(cr.ws, 1000, gd.string_empty())
	cr.active = false
}

// ---------------------------------------------------------------------------

@(private = "file")
_code_packet :: proc(cr: ^Code_Rendezvous, wire: ^Session_Wire) {
	pba := gd.packet_peer_get_packet(cast(gd.Packet_Peer)cr.ws)
	defer gd.free_packed_byte_array(pba)
	sz := int(gd.packed_byte_array_size(&pba))
	buf: [2048]u8
	m := min(sz, len(buf))
	for i in 0 ..< m {
		buf[i] = u8(gd.packed_byte_array_get(&pba, gd.Int(i)))
	}
	gs := gd.new_string_odin(string(buf[:m]))
	defer gd.free_string(gs)
	v := gd.json_parse_string(gs)
	defer gd.variant_destroy(&v)
	if gdext.variant_get_type(cast(gdext.VariantPtr)&v) != .Dictionary {
		return
	}
	d := gd.variant_to_dictionary(&v)
	defer gd.free_dictionary(d)

	tbuf: [32]u8
	typ := _dict_str(&d, "type", tbuf[:])
	switch typ {
	case "created":
		rbuf: [12]u8
		room := _dict_str(&d, "room", rbuf[:])
		cr.code_len = min(len(room), len(cr.code))
		copy(cr.code[:cr.code_len], room[:cr.code_len])
		cr.state = .Ready
	case "native":
		// The joiner's answer: the host's endpoint. Echo the code, keep it.
		copy(cr.code[:], cr.want[:])
		cr.code_len = cr.want_len
		hd, ok := _dict_dict(&d, "host")
		if !ok {
			cr.state = .Failed
			cr.err = .Bad_Msg
			return
		}
		defer gd.free_dictionary(hd)
		ibuf: [64]u8
		ip := _dict_str(&hd, "ip", ibuf[:])
		cr.ip_len = min(len(ip), len(cr.host_ip))
		copy(cr.host_ip[:cr.ip_len], ip[:cr.ip_len])
		cr.host_port = _dict_int(&hd, "port")
		cr.state = cr.host_port > 0 && cr.ip_len > 0 ? Code_State.Ready : Code_State.Failed
		if cr.state == .Failed {cr.err = .Bad_Msg}
	case "native_peer":
		// Host: a joiner's observed endpoint — PUNCH it so the joiner's
		// inbound connect meets a warm NAT mapping. A few tiny packets on
		// the wire's own bound socket; garbage to ENet, gold to the NAT.
		if wire == nil {
			return
		}
		ibuf: [64]u8
		ip := _dict_str(&d, "ip", ibuf[:])
		udp := _dict_int(&d, "udp")
		if len(ip) == 0 || udp <= 0 {
			return // joiner claimed no port: LAN/direct case, nothing to punch
		}
		wire_punch(wire, fmt.ctprintf("%s", ip), udp)
	case "error":
		rbuf: [16]u8
		reason := _dict_str(&d, "reason", rbuf[:])
		cr.state = .Failed
		switch reason {
		case "no_room":
			cr.err = .No_Room
		case "full":
			cr.err = .Full
		case:
			cr.err = .Bad_Msg
		}
	}
}

@(private = "file")
_dget :: proc(d: ^gd.Dictionary, key: cstring) -> gd.Variant {
	ks := gd.new_string_cstring(key)
	defer gd.free_string(ks)
	k := gd.variant_from_string(&ks)
	defer gd.variant_destroy(&k)
	return gd.dictionary_get(d, k, gd.Variant{})
}

@(private = "file")
_dict_str :: proc(d: ^gd.Dictionary, key: cstring, buf: []u8) -> string {
	v := _dget(d, key)
	defer gd.variant_destroy(&v)
	s := gd.variant_to_string(&v)
	defer gd.free_string(s)
	need := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if need <= 0 {
		return ""
	}
	n := min(int(need), len(buf))
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), i64(n))
	return string(buf[:n])
}

@(private = "file")
_dict_int :: proc(d: ^gd.Dictionary, key: cstring) -> int {
	v := _dget(d, key)
	defer gd.variant_destroy(&v)
	return int(gd.variant_to_int(&v))
}

@(private = "file")
_dict_dict :: proc(d: ^gd.Dictionary, key: cstring) -> (gd.Dictionary, bool) {
	v := _dget(d, key)
	defer gd.variant_destroy(&v)
	if gdext.variant_get_type(cast(gdext.VariantPtr)&v) != .Dictionary {
		return {}, false
	}
	return gd.variant_to_dictionary(&v), true
}

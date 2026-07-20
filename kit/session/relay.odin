package kit_session

// relay — the app channel's HOST-RELAY shape, owned once.
//
// kit/comms and kit/xfer each hand-rolled the same state machine over
// session_app_route, and xfer.md said so out loud ("kit/comms' shape, sized
// up"), which is the extraction bar: a third citizen — voice lines, emotes,
// a drawing board — would have written it a third time. The machine:
//
//     [SES_APP][tag][RELAY_UP][payload]                     client -> host
//     [SES_APP][tag][RELAY_CAST][author u64][payload]       host -> all / one
//
// and with it the four rules that were being copied:
//
//   * STAMP. The author never rides the wire upward. The host writes the
//     Player_Id the session already resolved from the sending peer, so a
//     client cannot speak as somebody else — and the rider above never sees
//     an unvouched id.
//   * SPOOF. A cast that did not arrive from HOST_PEER — or that arrives on
//     the authority at all — is dropped. Every transport relays peer to peer,
//     so "only the host casts" is a CHECK, never a guarantee.
//   * ECHO. One flag answers "does the machine that authored a message also
//     receive it?" for both roles at once: the host's own broadcast delivers
//     locally, and a client's cast coming back around with `author == me`
//     delivers — iff `echo`. kit/comms echoes (authoritative order beats a
//     few milliseconds: what you see IS what everyone sees); kit/xfer does
//     not (you already hold the bytes you sent), and neither did the fire
//     lane before it.
//   * ADDRESSED. A cast aimed at ONE peer — comms' catch-up replay, the
//     album's late-joiner backlog — is for that peer, so it never echoes
//     locally. Otherwise replaying history to a joiner would re-file it into
//     the host's own log.
//
// What rides above is now a PAYLOAD CODEC and nothing else: kit/comms writes
// [kind][text], kit/xfer writes [id][seq][chunks][total][bytes], and neither
// carries a direction byte, an author, or a role branch at its send door.
// The receive half is the queue next door (appq.odin) — the two files are the
// send and receive ends of one story, and a rider that uses both writes no
// plumbing at all.

import knet "godot:kit/net"

// The relay's own framing byte, first inside the SES_APP payload.
@(private = "file")
RELAY_UP :: u8(0)
@(private = "file")
RELAY_CAST :: u8(1)

// What a rider gets: the payload, positioned, and the author the relay
// vouched for. It FILES (an appq_push) and returns — it must not author on
// the same relay, which would reset the session's scratch writer under the
// payload it is holding. That is the same events-not-callbacks discipline the
// queue exists to enforce, stated where it can bite.
Relay_Proc :: proc(user: rawptr, author: knet.Player_Id, r: ^knet.Reader)

Host_Relay :: struct {
	ses:     ^Session,
	tag:     u8,
	user:    rawptr,
	deliver: Relay_Proc,
	echo:    bool,
	// begin -> flush scratch: who this message is from, whether it is going
	// UP (an upload carries no stamp), and where its payload starts inside
	// the session's app writer — the local echo reads it back from there
	// instead of copying it a second time.
	author:  knet.Player_Id,
	up:      bool,
	body:    int,
}

// Bind the relay to a session under `tag` (host or client, before or after
// start — routes survive re-init like every pre-start hookup). `echo` is the
// author's-own-copy policy above.
relay_route :: proc(hr: ^Host_Relay, s: ^Session, tag: u8, user: rawptr, deliver: Relay_Proc, echo := true) {
	// A tag collision is LOUD, still: session_app_route identifies a
	// subsystem by its HANDLER, and every relay now registers the same one,
	// so the DELIVER proc has to carry that identity instead. Without this,
	// two riders on one tag would silently steal each other's packets again
	// (kxfer's default tag once landed on a game's own).
	prev := s.app[tag]
	if prev.handler == relay_handle {
		old := cast(^Host_Relay)prev.user
		assert(
			old.deliver == deliver,
			"relay_route: tag already relayed by a different subsystem — pick distinct tag bytes (comms 0, combat's fires 1, xfer 2, kit/sim 3)",
		)
	}
	hr^ = Host_Relay {
		ses     = s,
		tag     = tag,
		user    = user,
		deliver = deliver,
		echo    = echo,
	}
	session_app_route(s, tag, hr, relay_handle)
}

// Unroute and forget the session (the rider's destroy calls this before it
// frees the state `deliver` writes into).
relay_unroute :: proc(hr: ^Host_Relay) {
	if hr.ses != nil {
		session_app_route(hr.ses, hr.tag, nil, nil)
	}
	hr^ = {}
}

// Author a message as MYSELF — the one send door both roles call. On the host
// it comes back framed as a stamped cast; on a client as an upload the host
// will stamp. Write the payload straight into the returned writer (the
// session's scratch — payload bytes are written exactly once), then
// relay_flush. The `is_host ? broadcast : upload` branch every rider used to
// hold at its own send door lives here now, once.
relay_begin :: proc(hr: ^Host_Relay) -> ^knet.Writer {
	return relay_frame(hr, hr.ses.me, !hr.ses.is_host)
}

// HOST ONLY: cast under someone ELSE's name. Three shapes use it — a line the
// authority authored with no speaker (comms' SYSTEM_LINE), history replayed
// under its original speaker (comms_catchup), and a kept payload re-cast under
// the player who published it (the album's welcome backlog). None of them
// rides the wire upward, so none of them can be spoofed into existence.
relay_begin_as :: proc(hr: ^Host_Relay, author: knet.Player_Id) -> ^knet.Writer {
	assert(hr.ses.is_host, "only the authority stamps an author — a client's word goes up through relay_begin")
	return relay_frame(hr, author, false)
}

@(private = "file")
relay_frame :: proc(hr: ^Host_Relay, author: knet.Player_Id, up: bool) -> ^knet.Writer {
	w := session_app_begin(hr.ses, hr.tag)
	if up {
		knet.write_u8(w, RELAY_UP)
	} else {
		knet.write_u8(w, RELAY_CAST)
		knet.write_player_id(w, author)
	}
	hr.author = author
	hr.up = up
	hr.body = len(w.buf)
	return w
}

// Ship the message begun above. `to` is the HOST's choice of audience —
// BROADCAST_PEER (the usual) or one seated peer for an addressed catch-up. A
// client's message always goes to the authority; passing a peer there is a
// bug, not a route.
relay_flush :: proc(hr: ^Host_Relay, to: Peer_Id = BROADCAST_PEER) {
	assert(!hr.up || to == BROADCAST_PEER, "a client's word goes UP to the authority — addressing a peer is the host's move")
	session_app_flush(hr.ses, hr.up ? HOST_PEER : to)
	if hr.up || !hr.echo || to != BROADCAST_PEER {
		return
	}
	// The author's own copy, on the machine that wrote it. A client's arrives
	// with the broadcast instead (the CAST arm below) — same bytes, same
	// position in the host's order, one delivery path per side.
	r := knet.reader_make(knet.writer_bytes(&hr.ses.app_w)[hr.body:])
	hr.deliver(hr.user, hr.author, &r)
}

@(private = "file")
relay_handle :: proc(user: rawptr, from: knet.Player_Id, from_peer: Peer_Id, r: ^knet.Reader) {
	hr := cast(^Host_Relay)user
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	switch kind {
	case RELAY_UP:
		// Uploads are addressed to the authority, which has already resolved
		// `from` to a seated player (an unseated peer never reached the
		// route). A client hearing one is a transport relay leaking.
		if !hr.ses.is_host {
			return
		}
		body := r.off
		w := relay_begin_as(hr, from)
		append(&w.buf, ..r.data[body:])
		// Relay first, stamped, so every peer hears it from the one machine
		// that can vouch for the author — then keep our own copy. The raw
		// flush on purpose: relay_flush's echo arm would deliver the COPY,
		// and the original frame is right here, already positioned.
		session_app_flush(hr.ses, BROADCAST_PEER)
		hr.deliver(hr.user, from, r)
	case RELAY_CAST:
		if hr.ses.is_host || from_peer != HOST_PEER {
			return
		}
		author := knet.read_player_id(r)
		if r.err {
			return
		}
		if author == hr.ses.me && !hr.echo {
			return // my own upload, come back around — I already have it
		}
		hr.deliver(hr.user, author, r)
	}
}

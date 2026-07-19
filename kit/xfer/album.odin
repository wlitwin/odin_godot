package kit_xfer

// The ALBUM — the latest payload per (player, kind), kept and replayed.
//
// xfer ships ONE-SHOT transfers; every game that ships an identity payload
// (a spray tag, a custom skin, a voice line) rebuilt the same three shelves
// around it by hand (scrapyard's spray wall is the worked example):
//
//   * my own copy, short-circuited locally — my screen never waits on my
//     own upload coming back around;
//   * everyone's LATEST payload cached by (player, kind) — a re-send
//     supersedes, consumers repaint off a landed event;
//   * the late joiner's catch-up — without it, whoever joins after a
//     payload shipped simply never sees it (the transfer is one-shot).
//
// The album owns them:
//
//     kxfer.album_init(&self.album, &self.ses)         // once, by the session
//     kxfer.album_put(&self.album, SPRAY_ID, png)      // mine: cached + shipped
//     kxfer.album_pump(&self.album)                    // once per net tick
//     for from, id in kxfer.album_poll(&self.album) {  // landed: decode/repaint
//         bytes, _ := kxfer.album_get(&self.album, from, id)
//     }
//     // HOST, on Ev_Player_Joined (rejoin included — their cache died with
//     // their process):
//     kxfer.album_welcome(&self.album, e.id)
//
// Decoded artifacts (textures, sounds) stay the game's to cache — the album
// keeps BYTES, and album_poll marks exactly when to re-decode.

import knet "godot:kit/net"
import ksess "godot:kit/session"

@(private = "file")
Fresh :: struct {
	from: knet.Player_Id,
	id:   u8,
}

// A queued catch-up shipment: one kept payload, re-cast to ONE peer with the
// same pacing as live sends. Owns its copy — a supersede mid-catch-up must
// not tear the bytes under it (the fresher payload lands via the normal
// broadcast right after).
@(private = "file")
Replay :: struct {
	to:   ksess.Peer_Id,
	from: knet.Player_Id,
	id:   u8,
	data: []u8,
	seq:  int,
}

Album :: struct {
	x:       Xfer,
	blobs:   map[Xfer_Key][]u8, // (player, id) -> the latest bytes, owned
	fresh:   [dynamic]Fresh,
	replays: [dynamic]Replay,
}

album_init :: proc(a: ^Album, ses: ^ksess.Session, tag := XFER_TAG) {
	xfer_init(&a.x, ses, tag)
}

album_destroy :: proc(a: ^Album) {
	xfer_destroy(&a.x)
	for _, bytes in a.blobs {
		delete(bytes)
	}
	delete(a.blobs)
	delete(a.fresh)
	for r in a.replays {
		delete(r.data)
	}
	delete(a.replays)
	a^ = {}
}

// Publish MY payload of `kind`: cached under (me, kind) immediately — my own
// screen never waits — and shipped to everyone over the next pumps. Returns
// false on the same size gates as xfer_send.
album_put :: proc(a: ^Album, id: u8, bytes: []u8) -> bool {
	if !xfer_send(&a.x, id, bytes) {
		return false
	}
	album_keep(a, a.x.ses.me, id, bytes)
	append(&a.fresh, Fresh{from = a.x.ses.me, id = id})
	return true
}

// The latest payload `player` published under `kind` — nil/false until one
// lands. Bytes are owned by the album: valid until that (player, kind) is
// superseded or the album dies; decode, don't retain.
album_get :: proc(a: ^Album, player: knet.Player_Id, id: u8) -> ([]u8, bool) {
	bytes, has := a.blobs[key_of(player, id)]
	return bytes, has
}

// Ship + receive, once per net tick. Landed payloads move into the shelf
// and queue for album_poll; catch-up replays share the chunk budget so a
// joiner's backlog never starves live traffic.
album_pump :: proc(a: ^Album, budget := PUMP_CHUNKS) {
	xfer_pump(&a.x, budget)
	replay_pump(a, budget)
	for {
		ev, ok := xfer_poll(&a.x)
		if !ok {
			break
		}
		if done, is_done := ev.(Ev_Done); is_done {
			album_keep(a, done.from, done.id, done.bytes)
			append(&a.fresh, Fresh{from = done.from, id = done.id})
		}
	}
}

// Landed payloads since the last poll (mine included, the frame it was put)
// — the decode/repaint hook. Drain until ok = false.
album_poll :: proc(a: ^Album) -> (from: knet.Player_Id, id: u8, ok: bool) {
	if len(a.fresh) == 0 {
		return knet.PLAYER_ID_INVALID, 0, false
	}
	f := a.fresh[0]
	ordered_remove(&a.fresh, 0)
	return f.from, f.id, true
}

// HOST, on Ev_Player_Joined: queue every kept payload for the newcomer —
// the catch-up that makes a transfer behave like state for late joiners.
// (Their own entries are skipped; rejoiners re-put, which also refreshes
// everyone else.) No-op off the host.
album_welcome :: proc(a: ^Album, player: knet.Player_Id) {
	ses := a.x.ses
	// Same teaching assert as comms_welcome — the identical join-time role
	// on the identical trigger; a silent no-op here taught the wrong lesson
	// its sibling refuses loudly.
	assert(ses == nil || ses.is_host, "album_welcome is the HOST's half — call it from your _player_joined_then")
	if ses == nil || !ses.is_host || player == ses.me {
		return
	}
	p, ok := ksess.session_player(ses, player)
	if !ok || p.peer == ksess.NO_PEER {
		return
	}
	for k, bytes in a.blobs {
		if k.from == player {
			continue
		}
		queue_replay(a, p.peer, k.from, k.id, bytes)
	}
}

// ---- internals --------------------------------------------------------------

@(private = "file")
album_keep :: proc(a: ^Album, from: knet.Player_Id, id: u8, bytes: []u8) {
	k := key_of(from, id)
	if old, has := a.blobs[k]; has {
		delete(old)
	}
	kept := make([]u8, len(bytes))
	copy(kept, bytes)
	a.blobs[k] = kept
	// A fresher payload obsoletes any in-flight catch-up of the old one —
	// interleaving two chunk streams for one (from, id) would tear the
	// receiver's assembly.
	for i := len(a.replays) - 1; i >= 0; i -= 1 {
		if a.replays[i].from == from && a.replays[i].id == id {
			delete(a.replays[i].data)
			ordered_remove(&a.replays, i)
		}
	}
}

@(private = "file")
queue_replay :: proc(a: ^Album, to: ksess.Peer_Id, from: knet.Player_Id, id: u8, bytes: []u8) {
	data := make([]u8, len(bytes))
	copy(data, bytes)
	append(&a.replays, Replay{to = to, from = from, id = id, data = data})
}

// The catch-up sender: XF_CAST frames addressed to one peer, same chunk
// size, same budget discipline as xfer_pump.
@(private = "file")
replay_pump :: proc(a: ^Album, budget: int) {
	ses := a.x.ses
	if ses == nil || len(a.replays) == 0 {
		return
	}
	left := budget
	for left > 0 && len(a.replays) > 0 {
		r := &a.replays[0]
		if chunk_send(ses, a.x.tag, XF_CAST, r.from, r.id, &r.seq, r.data, r.to) {
			delete(r.data)
			ordered_remove(&a.replays, 0)
		}
		left -= 1
	}
}

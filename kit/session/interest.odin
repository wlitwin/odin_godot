package kit_session

// INTEREST MANAGEMENT (area of interest) — "existence global, freshness
// local." Every peer still knows every entity (spawns, despawns, joins,
// saves, backups: all unfiltered — the model that makes drop-ins and
// migration free stays intact). What interest filters is the PER-TICK STATE
// traffic: a peer only receives deltas and owner-stream samples for entities
// near its FOCUS. Off by default; a session that never calls
// session_set_interest behaves exactly as before.
//
// The three moving parts:
//
//   * deltas    — collected once (one shadow commit, as ever), then composed
//                 into per-recipient batches: you get the segments for what
//                 you can see.
//   * re-entry  — a filtered delta is gone forever, so when an entity ENTERS
//                 a peer's interest the host sends that peer a full spawn
//                 tuple (the same reconcile path a same-session rejoin uses):
//                 everything missed while far — fields and blob — lands at
//                 once. Hysteresis keeps border-dancers from thrashing this.
//   * streams   — owners send their batches to the HOST instead of the
//                 transport's blind relay (the packets already pass through
//                 that machine; this adds no hop), and the host forwards
//                 per-recipient at entity granularity. A re-entering peer
//                 needs no stream resync: samples are absolute and the ring
//                 flushes on the next warp/stamp.
//
// The session cannot know where an entity "is" — position lives in game
// fields it can't interpret — so the game lends it eyes: a LOCATOR proc
// mapping entity -> (x, y, always). `always` marks entities with no
// meaningful place (the world/level entity, global timers): they are
// relevant to everyone, forever.

import knet "godot:kit/net"

Locator_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) -> (x, y: f32, always: bool)

// Host: turn interest management on (radius <= 0 turns it off). `hysteresis`
// widens the EXIT edge so an entity at the border doesn't flicker in and out
// (enter at `radius`, leave at `radius + hysteresis`). Call any time; joins
// mid-run are fine (the welcome tells clients how to route streams).
session_set_interest :: proc(s: ^Session, radius: f32, hysteresis: f32, user: rawptr, locator: Locator_Proc) {
	s.interest_r = radius
	s.interest_hys = hysteresis
	s.interest_user = user
	s.locator = locator
}

// Host: where `player` is looking from — almost always their avatar, fed
// every host frame. A player with no focus yet receives EVERYTHING (safe
// default: filtering starts when the game starts saying where they are).
session_set_focus :: proc(s: ^Session, player: knet.Player_Id, x, y: f32) {
	s.focus[player] = {x, y}
}

@(private)
interest_on :: proc(s: ^Session) -> bool {
	return s.is_host && s.interest_r > 0 && s.locator != nil
}

@(private = "file")
ikey :: proc(player: knet.Player_Id, id: knet.Net_Id) -> u64 {
	return u64(player) << 32 | u64(id)
}

@(private = "file")
d2 :: proc(ax, ay, bx, by: f32) -> f32 {
	dx, dy := bx - ax, by - ay
	return dx * dx + dy * dy
}

// Host, once per net tick before the delta send: refresh every peer's
// interest set. ENTER sends the full spawn tuple (the missed-state resync);
// EXIT just forgets — the peer keeps a stale ghost until re-entry.
@(private)
interest_tick :: proc(s: ^Session) {
	for pid, p in s.players {
		if !p.connected || pid == s.me {
			continue
		}
		focus, watching := s.focus[pid]
		if !watching {
			continue // no focus yet: this peer receives everything (see below)
		}
		for id in s.types {
			e, live := s.reg.entries[id]
			if !live {
				continue
			}
			x, y, always := s.locator(s.interest_user, id, e.entity)
			key := ikey(pid, id)
			in_set := s.interest[key]
			lim := in_set ? s.interest_r + s.interest_hys : s.interest_r
			near := always || d2(focus.x, focus.y, x, y) <= lim * lim
			if near && !in_set {
				s.interest[key] = true
				// The re-entry resync: everything this peer missed while the
				// entity was out of sight, in one reconciling spawn tuple.
				w := knet.writer_make()
				defer knet.writer_destroy(&w)
				knet.write_u8(&w, SES_SPAWN)
				write_spawn_tuple(s, &w, id)
				s.send(s.send_user, p.peer, knet.writer_bytes(&w), .Reliable)
			} else if !near && in_set {
				delete_key(&s.interest, key)
			}
		}
	}
}

// Is `id` currently in `player`'s interest? Peers with no focus see all.
@(private)
interest_has :: proc(s: ^Session, player: knet.Player_Id, id: knet.Net_Id) -> bool {
	if _, watching := s.focus[player]; !watching {
		return true
	}
	return s.interest[ikey(player, id)]
}

// Host: the interest-aware SES_STATE send — one collection (one shadow
// commit), N compositions. Returns the dirty count for the host's own
// state events.
@(private)
interest_send_state :: proc(s: ^Session, changed: ^[dynamic]knet.Net_Id) -> int {
	scratch := knet.writer_make(4096, context.temp_allocator)
	segs := make([dynamic]knet.Delta_Seg, context.temp_allocator)
	dirty := knet.registry_collect_deltas(&scratch, &s.reg, &segs, changed)
	if dirty == 0 {
		return 0
	}
	for pid, p in s.players {
		if !p.connected || pid == s.me {
			continue
		}
		w := knet.writer_make(256, context.temp_allocator)
		knet.write_u8(&w, SES_STATE)
		count_at := len(w.buf)
		knet.write_u16(&w, 0)
		count := 0
		for seg in segs {
			if !interest_has(s, pid, seg.id) {
				continue
			}
			append(&w.buf, ..scratch.buf[seg.from:seg.to])
			count += 1
		}
		if count == 0 {
			continue
		}
		w.buf[count_at] = u8(count)
		w.buf[count_at + 1] = u8(count >> 8)
		s.send(s.send_user, p.peer, knet.writer_bytes(&w), .Reliable)
	}
	return dirty
}

// Split a raw stream batch (everything after the SES_STREAM tag: the sender
// stamp, then self-describing [id][warp][len][bytes] segments) into
// per-recipient batches and send them. Used by the host both for its OWN
// outgoing batch and to forward a client owner's batch (exclude the origin).
@(private)
interest_route_streams :: proc(s: ^Session, raw: []u8, exclude: Peer_Id) {
	r := knet.reader_make(raw)
	sender_now := knet.read_f64(&r)
	count := int(knet.read_u16(&r))
	if r.err {
		return
	}
	Seg :: struct {
		id:       knet.Net_Id,
		from, to: int,
	}
	segs := make([dynamic]Seg, 0, count, context.temp_allocator)
	for _ in 0 ..< count {
		start := r.off
		id := knet.read_net_id(&r)
		_ = knet.read_u8(&r) // warp
		n := int(knet.read_u16(&r))
		if r.err || n < 0 || r.off + n > len(raw) {
			return // torn batch: forward nothing (the next tick supersedes)
		}
		r.off += n
		append(&segs, Seg{id = id, from = start, to = r.off})
	}
	for pid, p in s.players {
		if !p.connected || pid == s.me || p.peer == exclude {
			continue
		}
		w := knet.writer_make(128, context.temp_allocator)
		knet.write_u8(&w, SES_STREAM)
		knet.write_f64(&w, sender_now)
		count_at := len(w.buf)
		knet.write_u16(&w, 0)
		n := 0
		for seg in segs {
			if !interest_has(s, pid, seg.id) {
				continue
			}
			append(&w.buf, ..raw[seg.from:seg.to])
			n += 1
		}
		if n == 0 {
			continue
		}
		w.buf[count_at] = u8(n)
		w.buf[count_at + 1] = u8(n >> 8)
		s.send(s.send_user, p.peer, knet.writer_bytes(&w), .Stream)
	}
}

// Forget an entity everywhere (despawn) or a player entirely (teardown).
@(private)
interest_forget_entity :: proc(s: ^Session, id: knet.Net_Id) {
	for pid in s.players {
		delete_key(&s.interest, ikey(pid, id))
	}
}

@(private)
interest_forget_player :: proc(s: ^Session, player: knet.Player_Id) {
	delete_key(&s.focus, player)
	for id in s.types {
		delete_key(&s.interest, ikey(player, id))
	}
}

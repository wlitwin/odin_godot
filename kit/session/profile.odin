package kit_session

// THE PLAYER PROFILE — the typed per-player record every lobby rebuilt on
// stat columns and app channels: picks, loadout, cosmetics, ready lamps,
// declared meta. One POD struct per seat, with the ownership rule the rest
// of the kit already taught: EVERY ROW HAS ONE WRITER, its player.
//
//   Pick :: struct { look, iron: u8, ready: bool }
//
//   // THE DECLARATION (scriptgen games): tag the Session field — the install
//   // generates into the ready thunk and the row's shape folds into the wire
//   // fingerprint, so a drifted Pick refuses the join at the version door:
//   ses: ksess.Session `gd:"profile=Pick"`
//
//   // (raw kit consumers install by hand — ready(), before *_start:)
//   ksess.session_profile_install(&self.ses, Pick)
//
//   // MY row — write freely, read instantly (the local echo is the row):
//   ksess.session_profile_mine(&self.ses, Pick).look += 1
//
//   // anyone's row, this peer's view (arrives host-relayed, reliable) —
//   // session_roster gives the stable draw order (sorted by seat id):
//   for p in ksess.session_roster(&self.ses) {
//       pick, _ := ksess.session_profile_of(&self.ses, p.id, Pick)
//       draw_row(p, pick)
//   }
//
// The lessons this absorbs (each was a hand-rolled special case in a real
// game's muster/vault):
//   * LOCAL-ECHO-FIRST — your own click renders this frame from your own
//     row; the round trip only carries it to everyone else. (The stats-echo
//     lag read as a broken button at 2Hz.)
//   * ONE serializer — the row IS the wire bytes (POD, fixed size); no
//     hand-matched write_u8/read_u8 declare to drift.
//   * The DECLARE is automatic — the session diffs my row once per net tick
//     and ships the change; there is no "remember to declare" call. Seat it
//     (a rejoin, a fresh join) and the current row declares itself.
//   * Late joiners get the whole table behind their WELCOME; every peer
//     holds every row, so a host takeover already has the lot.
//
// What this is NOT: host-validated inventory (rows are the declarer's WORD —
// the friendslop trust model; put host-minted truth in replicated entity
// fields), and not a per-frame pose channel (rows ride reliable at stat
// cadence — streams exist for poses).
//
// The game reacts through Ev_Profile_Changed{player} — fired on every peer
// whose VIEW of a row changed (the host hears declares land, clients hear
// the relay), never for your own local writes (you made them; repaint is
// yours). Drop-in lobbies key their spawn gate on it: see session.md's
// muster recipe.

import "base:intrinsics"
import "core:mem"
import knet "godot:kit/net"

// A row may carry a small loadout, not an inventory dump — same POD-and-
// bounded discipline as replicated fields (collections fork applies).
PROFILE_MAX_SIZE :: 256

Ev_Profile_Changed :: struct {
	player: knet.Player_Id,
}

// The byte-level table (one per session; the typed views below wrap it).
Profile_Table :: struct {
	size:   int, // 0 = never installed
	rows:   map[knet.Player_Id][]u8,
	shadow: []u8, // MY row as last declared — the auto-declare's diff base
	dirty:  bool, // host: relay goes out on the next low-rate tick
}

// Install the profile type — pre-start wiring, both ends, same T. Scriptgen
// games declare it instead (`ses: ksess.Session \`gd:"profile=T"\`` — the
// install generates into the ready thunk AND the row's field-by-field shape
// folds into NET_FINGERPRINT, so profile drift refuses the join). A raw
// consumer calling this directly keeps the runtime guard only: a T that
// differs in SIZE degrades to dropped rows (never a torn one) — but a
// SAME-SIZE layout drift misreads rows silently; the declaration form is
// how that gets caught.
session_profile_install :: proc(s: ^Session, $T: typeid) {
	#assert(size_of(T) <= PROFILE_MAX_SIZE, "a profile row is a loadout, not an inventory dump — shrink it or blob it")
	#assert(intrinsics.type_is_nearly_simple_compare(T) && !intrinsics.type_is_pointer(T), "profile rows are POD — no strings, slices, maps, or pointers (the row IS the wire bytes)")
	assert(s.prof.size == 0 || s.prof.size == size_of(T), "session_profile_install called twice with different types")
	s.prof.size = size_of(T)
}

@(private = "file")
prof_row :: proc(s: ^Session, pid: knet.Player_Id, make_missing: bool) -> []u8 {
	if row, ok := s.prof.rows[pid]; ok {
		return row
	}
	if !make_missing {
		return nil
	}
	row := make([]u8, s.prof.size)
	s.prof.rows[pid] = row
	return row
}

// MY row, writable — the local echo IS this memory. The session diffs it
// against the last declare once per net tick and ships the change itself.
session_profile_mine :: proc(s: ^Session, $T: typeid) -> ^T {
	assert(s.prof.size == size_of(T), "session_profile_mine before session_profile_install (or with a different T)")
	return cast(^T)raw_data(prof_row(s, s.me, true))
}

// Anyone's row, as THIS peer currently sees it (value copy; zero row until
// their first declare arrives). Reading your own returns your live row.
session_profile_of :: proc(s: ^Session, pid: knet.Player_Id, $T: typeid) -> (p: T, ok: bool) {
	if s.prof.size != size_of(T) {
		return {}, false
	}
	row := prof_row(s, pid, false)
	if row == nil {
		return {}, false
	}
	return (cast(^T)raw_data(row))^, true
}

// (Draw order comes from session_roster — already sorted by seat id.)

// ---------------------------------------------------------------------------
// The wire half (driven from net_tick / the packet switch — no game calls).

@(private)
prof_destroy :: proc(t: ^Profile_Table) {
	for _, row in t.rows {
		delete(row)
	}
	delete(t.rows)
	delete(t.shadow)
	t^ = {}
}

// Per net tick, both roles: my row changed since the last declare? Host —
// its word lands directly (it IS the relay); client — ship it. The shadow
// commits either way, so an unchanged row costs one memcmp and zero bytes.
@(private)
prof_tick :: proc(s: ^Session) {
	if s.prof.size == 0 || s.me == knet.PLAYER_ID_INVALID {
		return
	}
	row := prof_row(s, s.me, true)
	if s.prof.shadow == nil {
		s.prof.shadow = make([]u8, s.prof.size)
	} else if mem.compare(row, s.prof.shadow) == 0 {
		return
	}
	copy(s.prof.shadow, row)
	if s.is_host {
		s.prof.dirty = true
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_DECLARE)
	knet.write_u16(&w, u16(s.prof.size))
	append(&w.buf, ..row)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// Host: a declare landed — the row is its player's word, verbatim. A size
// mismatch is a foreign build (the fingerprint door already refuses those);
// drop it whole rather than tear a row.
@(private)
prof_handle_declare :: proc(s: ^Session, from: knet.Player_Id, r: ^knet.Reader) {
	n := int(knet.read_u16(r))
	if r.err || s.prof.size == 0 || n != s.prof.size || r.off + n > len(r.data) {
		r.err = true
		return
	}
	row := prof_row(s, from, true)
	copy(row, r.data[r.off:r.off + n])
	r.off += n
	s.prof.dirty = true
	append(&s.events, Ev_Profile_Changed{player = from})
}

// Host: the relay — the whole table, stats-style (small and rare beats a
// delta scheme to get wrong). Broadcast when dirty; to one peer behind its
// welcome.
@(private)
prof_send :: proc(s: ^Session, to_peer := BROADCAST_PEER) {
	if s.prof.size == 0 {
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_PROFILES)
	knet.write_u16(&w, u16(s.prof.size))
	assert(len(s.prof.rows) <= int(max(u16)))
	knet.write_u16(&w, u16(len(s.prof.rows)))
	for pid, row in s.prof.rows {
		knet.write_player_id(&w, pid)
		append(&w.buf, ..row)
	}
	if to_peer == BROADCAST_PEER {
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	} else {
		s.send(s.send_user, to_peer, knet.writer_bytes(&w), .Reliable)
	}
}

// Client: the relay lands — adopt every row but MINE (my row is my echo; the
// relay of it exists for everyone else), and say which views moved.
@(private)
prof_handle_table :: proc(s: ^Session, r: ^knet.Reader) {
	n := int(knet.read_u16(r))
	count := int(knet.read_u16(r))
	if r.err || s.prof.size == 0 || n != s.prof.size {
		r.err = true
		return
	}
	for _ in 0 ..< count {
		pid := knet.read_player_id(r)
		if r.err || r.off + n > len(r.data) {
			r.err = true
			return
		}
		bytes := r.data[r.off:r.off + n]
		r.off += n
		if pid == s.me {
			continue
		}
		row := prof_row(s, pid, true)
		if mem.compare(row, bytes) != 0 {
			copy(row, bytes)
			append(&s.events, Ev_Profile_Changed{player = pid})
		}
	}
}

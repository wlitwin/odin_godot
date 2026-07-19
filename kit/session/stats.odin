package kit_session

// stats — the per-player stat registry, a session SUBSYSTEM like interest
// and profile: its own wire kind (SES_STATS), its own net_tick slot (the
// ping feed + dirty relay, ~2 Hz), welcome participation (the join parade
// sends the current board), snapshot participation (session_snapshot carries
// schema + rows so saves and takeovers keep the score), and its run state
// (stat_names/stats/stats_dirty) in Session_Run. session.md's "adding a
// subsystem" checklist names those touchpoints; this file is one of the
// four worked examples.
//
// Generic named counters on the player record: kills, deaths, damage, score —
// whatever the game declares. HOST-accumulated (gameplay mutates them on the
// authority only) and replicated to everyone as a full snapshot at a low rate
// when dirty (~2 Hz: display data, not simulation data). Stats live on the
// PLAYER, so they survive disconnects and come back with a reclaimed identity
// like everything else. Column 0 is always "ping": the host pings its clients
// and feeds each player's measured RTT (ms) in automatically.

import knet "godot:kit/net"
import "core:strings"

// A column HANDLE, 1-based on purpose: the zero value is INVALID and every
// read/write asserts on it. Why: `session_stat_column` registers on the HOST
// (typically in a Start handler) — a Stat_Col stored there is zero-value on
// every client, and when 0 meant "column 0" a client's read silently returned
// the auto-fed PING (homestead's acid caught a resource gate passing on 254
// milliseconds of latency). Now the same mistake is a loud assert pointing at
// `session_stat_find` — resolve BY NAME on peers that didn't register.
Stat_Col :: distinct u8

MAX_STAT_COLS :: 16

STAT_COL_INVALID :: Stat_Col(0) // the zero value: never a real column

// Always declared, always fed by the session itself.
STAT_PING :: Stat_Col(1)

// Host: declare (or find) a named column. Idempotent by name — safe to call
// from ready() on every run. Clients get columns from the wire.
session_stat_column :: proc(s: ^Session, name: string) -> Stat_Col {
	assert(s.is_host, "the authority declares stat columns; clients receive them")
	context.allocator = ses_allocator(s) // the cloned column name is owned run state, freed in run_destroy
	if col, ok := session_stat_find(s, name); ok {
		return col
	}
	assert(len(s.stat_names) < MAX_STAT_COLS, "too many stat columns")
	append(&s.stat_names, strings.clone(name))
	s.stats_dirty = true
	return Stat_Col(len(s.stat_names)) // 1-based handle (index + 1)
}

// Look a column up by name — how clients resolve what the scoreboard shows.
session_stat_find :: proc(s: ^Session, name: string) -> (Stat_Col, bool) {
	for n, i in s.stat_names {
		if n == name {
			return Stat_Col(i + 1), true
		}
	}
	return STAT_COL_INVALID, false
}

// Handle -> row index, with THE trap turned into a message: a zero-value
// Stat_Col is a column that was registered on another peer (or never).
@(private = "file")
stat_idx :: proc(col: Stat_Col) -> int {
	assert(
		col != STAT_COL_INVALID,
		"zero-value Stat_Col — session_stat_column registers on the HOST; on a peer that didn't register, resolve by name with session_stat_find (cheap — do it per read)",
	)
	return int(col) - 1
}

session_stat_names :: proc(s: ^Session) -> []string {
	return s.stat_names[:]
}

// NOTE: all row reads use the comma-ok form — a plain missing-key index of a
// map with a large value type faults in the current compiler (found by the
// acid test's crash reporter; a missing player must read as an all-zero row).
session_stat_set :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, value: i64) {
	assert(s.is_host, "stats are host-accumulated")
	idx := stat_idx(col)
	row, _ := s.stats[player]
	if row[idx] == value {
		return
	}
	row[idx] = value
	s.stats[player] = row
	s.stats_dirty = true
}

session_stat_add :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, delta: i64) {
	assert(s.is_host, "stats are host-accumulated")
	idx := stat_idx(col)
	row, _ := s.stats[player]
	row[idx] += delta
	s.stats[player] = row
	s.stats_dirty = true
}

session_stat :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col) -> i64 {
	idx := stat_idx(col)
	row, ok := s.stats[player]
	if !ok {
		return 0
	}
	return row[idx]
}

// Full stat snapshot: schema + every player's row. Small (16 cols x 8 players
// ≈ 1KB) and rare (~2 Hz when dirty) — no delta machinery to get wrong.
// Called by the net_tick slot and the join parade (session.odin).
@(private)
send_stats :: proc(s: ^Session, to_peer := BROADCAST_PEER) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_STATS)
	knet.write_u8(&w, u8(len(s.stat_names)))
	for n in s.stat_names {
		knet.write_string(&w, n)
	}
	assert(len(s.players) <= int(max(u16)))
	knet.write_u16(&w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(&w, p.id)
		row, _ := s.stats[p.id]
		for i in 0 ..< len(s.stat_names) {
			knet.write_i64(&w, row[i])
		}
	}
	if to_peer == BROADCAST_PEER {
		broadcast(s, knet.writer_bytes(&w), .Reliable)
		// The host is a reader of the scoreboard too, and it never hears its
		// own broadcast — without this, a game that repaints only on
		// Ev_Stats_Updated ships a board that is permanently empty on the
		// host's screen (both games independently discovered the workaround
		// of refreshing at show time; now the event fires everywhere).
		append(&s.events, Ev_Stats_Updated{})
	} else {
		s.send(s.send_user, to_peer, knet.writer_bytes(&w), .Reliable)
	}
}

// Client: one incoming SES_STATS snapshot (the packet switch role-gates
// before calling; sticky r.err rides back for the malformed counter).
@(private)
stats_recv :: proc(s: ^Session, r: ^knet.Reader) {
	cols := int(knet.read_u8(r))
	if r.err || cols > MAX_STAT_COLS {
		return
	}
	// Schema first (the host may declare columns mid-run): rebuild ours.
	names: [MAX_STAT_COLS]string
	for i in 0 ..< cols {
		names[i] = knet.read_string(r)
	}
	players := int(knet.read_u16(r))
	if r.err {
		return
	}
	for n in s.stat_names {
		delete(n)
	}
	clear(&s.stat_names)
	for i in 0 ..< cols {
		append(&s.stat_names, strings.clone(names[i]))
	}
	for _ in 0 ..< players {
		id := knet.read_player_id(r)
		row: [MAX_STAT_COLS]i64
		for i in 0 ..< cols {
			row[i] = knet.read_i64(r)
		}
		if r.err {
			return
		}
		s.stats[id] = row
	}
	append(&s.events, Ev_Stats_Updated{})
}

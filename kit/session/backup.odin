package kit_session

// backup — migration-readiness and host succession, a session SUBSYSTEM like
// interest/profile/stats: its own wire kinds (SES_BACKUP, SES_SUCCESSOR), its
// own net_tick slot (backup_slot: target election + refresh cadence), welcome
// participation (the join parade re-sends the torch), resume participation
// (session_host_resume IS this subsystem's biggest verb), and its run state
// (backup_*/succ_*/successor*) in Session_Run. session.md's "adding a
// subsystem" checklist names those touchpoints; this file is one of the four
// worked examples.
//
// The shape: the host periodically ships a complete re-hostable snapshot to
// the ELDEST connected client (the designated backup host), and separately
// broadcasts WHO would carry the torch and HOW to reach them (the transport
// rendezvous blob, opaque to the session). When the lights go out, every
// peer already holds the answer: the designee resumes from its backup, the
// rest chase the rendezvous. Saving a run to disk and surviving a dead host
// are the SAME snapshot contract — kit/save wraps session_snapshot in a
// versioned envelope.

import knet "godot:kit/net"
import "core:strings"

// The eldest connected client (lowest Player_Id) — deterministic, stable
// across everything except that player leaving.
@(private = "file")
backup_target :: proc(s: ^Session) -> knet.Player_Id {
	best := knet.PLAYER_ID_INVALID
	for _, p in s.players {
		if !p.connected || p.id == s.me || p.spectator {
			continue // a watcher can never hold the torch
		}
		if best == knet.PLAYER_ID_INVALID || p.id < best {
			best = p.id
		}
	}
	return best
}

// The host's net_tick slot (called at the stats cadence, ~2 Hz): keep the
// eldest connected client holding a fresh re-hostable snapshot — refreshed on
// the interval, and immediately when the target changes (first client seats,
// old target leaves). Never on a DEDICATED server: migration is the peer
// model's answer to a host who is also a player leaving; a server restarts.
@(private)
backup_slot :: proc(s: ^Session, t: u64) {
	if !s.replicating || s.dedicated {
		return
	}
	target := backup_target(s)
	if target == knet.PLAYER_ID_INVALID {
		return
	}
	if target != s.backup_target || t - s.backup_tick >= s.backup_every {
		if target != s.backup_target {
			// The torch-bearer changed: tell the game (it computes the
			// rendezvous info) — the successor broadcast follows from
			// session_set_successor_info.
			append(&s.events, Ev_Backup_Target{player = target})
		}
		s.backup_target = target
		s.backup_tick = t
		p, _ := s.players[target]
		send_backup(s, p.peer)
	}
}

// The re-hostable snapshot: everything needed to BECOME the host of this
// run — identity table (hashed tokens), roster names, allocation cursors,
// the stat registry, and every entity as a spawn tuple. session_host_resume
// parses it. Two consumers: the backup-host wire (below) and kit/save, which
// wraps it in a versioned file envelope — saving a run and surviving a dead
// host are the SAME contract.
//
// Layout: [next_player u64][host_id u64]
//         [cols u8] x [name string]
//         [players u16] x ([id u64][name string][token_hash u64][cols x i64])
//         [locked bool][denied u16] x ([token_hash u64][id u64])
//         [next_net_id u32]
//         [entities u16] x the SES_SPAWN tuple
session_snapshot :: proc(s: ^Session, w: ^knet.Writer) {
	assert(s.is_host, "the authority owns the truth being snapshotted")
	knet.write_u64(w, u64(s.next_player))
	// WHO is hosting when this snapshot is taken. A heir reads it back as the
	// OLD host's id and re-owns that player's entities to itself — the world
	// entities the dead host was streaming (owner = its player id) would freeze
	// on every screen otherwise (each game hand-rolled the re-own loop; now the
	// kit does). It is s.me, not a fixed HOST id, because a heir-turned-host
	// carries its own id — and the hash-0 "never JOINed" host signal is
	// ambiguous once a migration leaves the dead host's row in the roster.
	knet.write_u64(w, u64(s.me))
	knet.write_u8(w, u8(len(s.stat_names)))
	for n in s.stat_names {
		knet.write_string(w, n)
	}
	assert(len(s.players) <= int(max(u16)))
	knet.write_u16(w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(w, p.id)
		knet.write_string(w, p.name)
		hash := u64(0)
		for h, id in s.tokens {
			if id == p.id {
				hash = h
			}
		}
		knet.write_u64(w, hash) // 0 for the host itself (hosts never JOINed)
		row, _ := s.stats[p.id]
		for i in 0 ..< len(s.stat_names) {
			knet.write_i64(w, row[i])
		}
	}
	// The DOOR travels with the roster: a ban outlives the host that issued
	// it and a locked room stays locked through a takeover — otherwise the
	// kicked-with-ban player just waits for the migration and walks back in.
	knet.write_bool(w, s.locked)
	assert(len(s.denied) <= int(max(u16)))
	knet.write_u16(w, u16(len(s.denied)))
	for h, id in s.denied {
		knet.write_u64(w, h)
		knet.write_player_id(w, id)
	}
	knet.write_u32(w, u32(s.reg.next_id))
	assert(knet.registry_count(&s.reg) <= int(max(u16)))
	knet.write_u16(w, u16(knet.registry_count(&s.reg)))
	for id in s.types {
		write_spawn_tuple(s, w, id)
	}
}

// Host-side state the SESSION cannot know about — wave directors, AI
// clocks, quest flags — written into every backup so a would-be new host
// resumes the CAMPAIGN, not just the roster and entities (the same split
// kit/save's envelope makes; write the same bytes in both).
Backup_Blob_Proc :: proc(user: rawptr, w: ^knet.Writer)

// Install the game-blob writer for backups (pre-start wiring; survives
// *_start like the rest). Without one, backups carry an empty blob and a
// takeover restores the world but not the campaign around it.
session_set_backup_blob :: proc(s: ^Session, user: rawptr, write: Backup_Blob_Proc) {
	s.backup_blob_user = user
	s.backup_blob = write
}

// Split a received backup payload into the game's blob and the re-hostable
// session snapshot (what session_host_resume eats). ok=false when no backup
// has arrived (we were never the designated holder) or it is malformed.
// Returns COPIES (temp-allocated by default) on purpose: the resume you are
// about to run RE-INITS the session, which frees the stored payload —
// slices into it would dangle exactly when you need them.
session_backup_parts :: proc(s: ^Session, allocator := context.temp_allocator) -> (game_blob: []u8, snapshot: []u8, ok: bool) {
	if len(s.backup) < 4 {
		return nil, nil, false
	}
	r := knet.reader_make(s.backup)
	n := int(knet.read_u32(&r))
	if r.err || n < 0 || r.off + n > len(s.backup) { // <0: 32-bit wrap on hostile lengths
		return nil, nil, false
	}
	game_blob = make([]u8, n, allocator)
	copy(game_blob, s.backup[r.off:r.off + n])
	snapshot = make([]u8, len(s.backup) - r.off - n, allocator)
	copy(snapshot, s.backup[r.off + n:])
	return game_blob, snapshot, true
}

// Host: how peers find the successor if you die — an opaque transport blob
// (address:port for ENet, a lobby id for Steam, a room code for WebRTC).
// Call from Ev_Backup_Target (the session names WHO; the transport layer
// knows WHERE); broadcast immediately and to every later joiner. With no
// info set, host loss stays v1-shaped: Ev_Host_Left, run over, no auto arc.
session_set_successor_info :: proc(s: ^Session, info: []u8) {
	assert(s.is_host)
	context.allocator = ses_allocator(s) // succ_info is owned run state, freed in run_destroy — copy it under the stored allocator
	delete(s.succ_info)
	s.succ_info = make([]u8, len(info))
	copy(s.succ_info, info)
	send_successor(s, BROADCAST_PEER)
}

// The torch's bytes, in a shape you cannot print by accident.
//
// This used to be a plain []u8, and for most of the kit's life it happened to
// hold a human-readable "addr:port" — so a game logging its torch wrote
// `string(info)` and it read fine. The day the rendezvous became a typed
// binary record (a kind byte, a length-prefixed address, a u16 port) that line
// kept COMPILING — []u8 converts to string, and so does a `distinct []u8`,
// which was checked rather than assumed — and started printing raw bytes into
// a log an acid test scraped. One unprintable string cost a whole succession
// act, three failures deep, with the real machinery working the entire time.
//
// A struct is the smallest thing the compiler actually refuses to stringify.
// The bytes are still right there for anyone who means it (`info.bytes`); what
// is gone is the accident. To render a torch for a human, decode it —
// netgd.succession_decode, then netgd.succession_words.
Successor_Info :: struct {
	bytes: []u8,
}

// Who carries the torch, and the rendezvous blob. Answers on BOTH roles:
// a client reads what the wire delivered; the HOST reads what it authored
// (it wrote the torch — an empty answer to its own question was a wart the
// backup_target words halves fell into).
session_successor :: proc(s: ^Session) -> (knet.Player_Id, Successor_Info) {
	if s.is_host {
		return s.backup_target, {bytes = s.succ_info}
	}
	return s.successor, {bytes = s.successor_info}
}

// Called here and by the join parade (a late joiner hears the standing torch).
@(private)
send_successor :: proc(s: ^Session, to: Peer_Id) {
	if len(s.succ_info) == 0 {
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_SUCCESSOR)
	knet.write_player_id(&w, s.backup_target)
	knet.write_bytes(&w, s.succ_info)
	if to == BROADCAST_PEER {
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	} else {
		s.send(s.send_user, to, knet.writer_bytes(&w), .Reliable)
	}
}

@(private = "file")
send_backup :: proc(s: ^Session, peer: Peer_Id) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_BACKUP)
	// [blob_len u32][game blob][session snapshot] — parts split it back out.
	blob := knet.writer_make()
	defer knet.writer_destroy(&blob)
	if s.backup_blob != nil {
		s.backup_blob(s.backup_blob_user, &blob)
	}
	knet.write_u32(&w, u32(len(knet.writer_bytes(&blob))))
	append(&w.buf, ..knet.writer_bytes(&blob))
	session_snapshot(s, &w)
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)
}

// Client: the designated backup host keeps the blob, opaque, replacing any
// older one. Parsing happens only if we ever resume. (The packet switch
// role-gates before calling.)
@(private)
backup_recv :: proc(s: ^Session, r: ^knet.Reader) {
	blob := knet.reader_remaining(r)
	delete(s.backup)
	s.backup = make([]u8, len(blob))
	copy(s.backup, blob)
	s.backup_at = s.now
	append(&s.events, Ev_Backup_Received{size = len(blob)})
}

// Client: who carries the torch, and how to find them. (Role-gated by the
// packet switch; sticky r.err rides back for the malformed counter.)
@(private)
successor_recv :: proc(s: ^Session, r: ^knet.Reader) {
	succ := knet.read_player_id(r)
	info := knet.read_bytes(r)
	if r.err {
		return
	}
	s.successor = succ
	delete(s.successor_info)
	s.successor_info = make([]u8, len(info))
	copy(s.successor_info, info)
}

// Become the host of a run someone else was hosting, from a backup blob this
// session (or a previous run's session) received as the designated backup.
// Call on a FRESH session with the factory already installed; `me` is the
// caller's own Player_Id from the dead run. Every other player comes back
// disconnected — they rejoin with their tokens and reclaim ids, stats, and
// owned entities exactly like any reconnect. That includes the dead HOST,
// if it started with a token (session_host_start's `token` param); without
// one it returns as a NEW player.
// Returns false on a corrupt blob (destroy the session and start clean).
session_host_resume :: proc(s: ^Session, me: knet.Player_Id, name: string, backup: []u8) -> bool {
	assert(s.factory_make != nil, "resume recreates entities through the factory — install it first")
	// The heir carries every player's profile row into the resumed run —
	// keep_profiles=true lifts the table over the run wipe (see session_init).
	session_init(s, true) // resolves + stores s.allocator (a fresh session's first start)
	context.allocator = ses_allocator(s) // the resumed roster's name/stat clones below ride the stored allocator
	s.is_host = true
	s.ctx.is_authority = true
	s.me = me
	s.ctx.me = me
	s.joined = true

	r := knet.reader_make(backup)
	s.next_player = knet.Player_Id(knet.read_u64(&r))
	old_host := knet.Player_Id(knet.read_u64(&r)) // who wrote this backup; its entities re-own to us
	cols := int(knet.read_u8(&r))
	if r.err || cols == 0 || cols > MAX_STAT_COLS { // 0: even a fresh run has "ping"
		return false
	}
	for n in s.stat_names { // replace the init-time default schema wholesale
		delete(n)
	}
	clear(&s.stat_names)
	for _ in 0 ..< cols {
		append(&s.stat_names, strings.clone(knet.read_string(&r)))
	}
	players := int(knet.read_u16(&r))
	if r.err {
		return false
	}
	for _ in 0 ..< players {
		id := knet.read_player_id(&r)
		pname := knet.read_string(&r)
		hash := knet.read_u64(&r)
		row: [MAX_STAT_COLS]i64
		for i in 0 ..< cols {
			row[i] = knet.read_i64(&r)
		}
		if r.err {
			return false
		}
		mine := id == me
		s.players[id] = Player {
			id        = id,
			name      = strings.clone(mine ? name : pname),
			peer      = mine ? HOST_PEER : NO_PEER,
			connected = mine,
		}
		if hash != 0 {
			s.tokens[hash] = id
		}
		s.stats[id] = row
	}
	// The door: bans + the lock survive the takeover (written by
	// session_snapshot right after the roster).
	s.locked = knet.read_bool(&r)
	nden := int(knet.read_u16(&r))
	if r.err {
		return false
	}
	for _ in 0 ..< nden {
		h := knet.read_u64(&r)
		s.denied[h] = knet.read_player_id(&r)
	}
	next_net := knet.Net_Id(knet.read_u32(&r))
	entities := int(knet.read_u16(&r))
	if r.err {
		return false
	}
	for _ in 0 ..< entities {
		apply_spawn_tuple(s, &r)
		if r.err {
			return false
		}
	}
	knet.registry_reserve_ids(&s.reg, next_net)
	knet.registry_commit_shadows(&s.reg)

	// RE-OWN THE ORPHANS. The dead host was STREAMING every entity it owned under
	// its own player id (wanderers, mobs, carried props — anything alive and
	// moving that a game spawned `owner = ses.me` on the host). That id is gone
	// for good, so those entities have no one to stream them: they freeze on
	// every screen, silently, forever. The heir is the new authority — it takes
	// the leash. Host-authoritative deltas (owner = PLAYER_ID_INVALID: static
	// world, flora) already flow from whoever is_host and need no move; a still-
	// connected client's entities keep their owner and resume when that client
	// rejoins. Only the OLD HOST's are stranded, and only they move here. Fired
	// before `replicating`, so no SES_SETOWNER goes out (nobody to tell yet — the
	// corrected owner rides the SES_WORLD every rejoiner gets); Ev_Owner_Changed
	// still fires, so a game gluing an entity to its owner adopts it here.
	if old_host != me && old_host != knet.PLAYER_ID_INVALID {
		orphans := make([dynamic]knet.Net_Id, context.temp_allocator)
		for id in s.types {
			if session_owner_of(s, id) == old_host {
				append(&orphans, id)
			}
		}
		for id in orphans {
			session_set_owner(s, id, me)
		}
	}

	s.replicating = true // the world is live: rejoiners get SES_WORLD + stats
	s.stats_dirty = true
	return true
}

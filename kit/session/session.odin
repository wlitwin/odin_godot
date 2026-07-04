package kit_session

// kit/session — player identity and the shared roster: who is in this run,
// under which stable Player_Id, connected or not. The session core of the
// friendslop toolkit (phase 1), grown from the acid test's session node.
//
// THE IDENTITY MODEL: a player IS a reconnect token — a random u64 secret the
// client generates once and persists (the game saves it; the tests pass it in).
// The host maps token → Player_Id forever: reconnecting with the same token —
// from a NEW transport peer, after a crash, mid-game — reclaims the same id,
// and with it (in later bricks) name, stats, and owned entities. Player_Ids
// are never derived from transport peer ids, which is what makes reconnect
// (and post-v1 host migration) possible at all. Departed players stay in the
// roster as disconnected for exactly this reason.
//
// ENGINE-FREE, like kit/net: the game script owns the sockets and the framing.
// The contract is three hookups —
//   * send:            the session hands complete message bytes + a target
//                      peer to the game, which prefixes ITS session kind byte
//                      and ships them on the reliable channel (kit/netgd).
//   * handle_packet:   the game routes its session kind byte back here.
//   * peer up/down:    the game forwards the transport's connect/disconnect
//                      signals (session join is a JOIN message, not a socket
//                      event — a connected-but-never-joined peer is nobody).
// Everything the game needs to REACT to comes out of one event queue, drained
// per frame (session_poll) — no callbacks into half-initialized script state.
//
// v1 has no host migration: the host vanishing ends the run (Ev_Host_Left —
// the game shows its "run over" screen). Backup-host snapshots (a later
// brick) keep the door open.

import knet "godot:kit/net"
import "core:strings"

// Which wire the message rides — maps to kit/netgd's channel plan.
Channel :: enum u8 {
	Reliable, // commands, results, state batches, roster, pings
	Stream,   // owner-stream snapshots: unreliable-ordered, last-value
}

// The transport hookup. `to_peer` is a transport peer id (ENet/WebRTC/Steam
// semantics belong to the game+netgd layer; the session never broadcasts —
// it targets connected players individually).
Send_Proc :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: Channel)

// ENet/SceneMultiplayer convention: the host is always transport peer 1.
HOST_PEER :: 1

Player :: struct {
	id:        knet.Player_Id,
	name:      string, // owned by the session
	peer:      int, // transport peer id; 0 while disconnected
	connected: bool,
}

// ---- events: everything the game reacts to, drained per frame --------------

Ev_Welcomed :: struct {
	me: knet.Player_Id, // (client) the host accepted us; the roster is seeded
}

Ev_Player_Joined :: struct {
	id:     knet.Player_Id,
	rejoin: bool, // reclaimed an existing identity (reconnect)
}

Ev_Player_Left :: struct {
	id: knet.Player_Id, // stays in the roster, disconnected (may reconnect)
}

Ev_Host_Left :: struct {} // (client) the run is over — v1 has no migration

Ev_Spawned :: struct {
	id:    knet.Net_Id, // (client) the factory made it and the snapshot applied
	type:  Entity_Type,
	owner: knet.Player_Id,
}

Ev_Despawned :: struct {
	id: knet.Net_Id, // (client) already removed; the factory's free ran
}

Ev_State_Applied :: struct {
	entities: int, // (client) a host state batch landed on this many entities
}

Ev_Command_Executed :: struct {
	ok: bool, // (host) a client command ran (or was rejected) authoritatively
}

Ev_Command_Confirmed :: struct {
	seq: knet.Intent_Seq, // (client) prediction stands
}

Ev_Command_Rejected :: struct {
	seq:    knet.Intent_Seq, // (client) truth applied (or revert fallback)
	entity: knet.Net_Id,
}

Event :: union {
	Ev_Welcomed,
	Ev_Player_Joined,
	Ev_Player_Left,
	Ev_Host_Left,
	Ev_Spawned,
	Ev_Despawned,
	Ev_State_Applied,
	Ev_Command_Executed,
	Ev_Command_Confirmed,
	Ev_Command_Rejected,
}

// ---- entity factories --------------------------------------------------------
//
// The game's kind of thing: a small u16 the host stamps on every spawn so
// remote peers know WHAT to create (the values come in the same message).
Entity_Type :: distinct u16

// Client-side: create the local counterpart of a spawned entity — instantiate
// the node/scene for `type`, return its struct + command set. Returning nil
// skips the entity safely (unknown type: the wire carries its length). This is
// the one place the session CALLS INTO the game synchronously — the registry
// needs the pointer before the snapshot can apply; react to the spawn itself
// via Ev_Spawned, which fires right after.
Make_Entity_Proc :: proc(user: rawptr, type: Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (entity: rawptr, set: ^knet.Command_Set)

// Client-side: the entity was despawned and already removed from the registry
// — free the node/struct.
Free_Entity_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)

// ---- wire (sub-framed: the game's session kind byte comes first, then ours) --

@(private)
SES_JOIN :: u8(0) // client -> host  [token u64][name string]
@(private)
SES_WELCOME :: u8(1) // host -> client  [your_id][count u16] x ([id][name][connected u8])
@(private)
SES_UPSERT :: u8(2) // host -> others  [id][name][connected u8][rejoin u8]
@(private)
SES_LEFT :: u8(3) // host -> all     [id]
@(private)
SES_BYE :: u8(4) // client -> host  graceful leave (no payload)
@(private)
SES_STATE :: u8(5) // host -> all     registry delta batch, per net tick
@(private)
SES_CMD :: u8(6) // client -> host  command header + args
@(private)
SES_RESULT :: u8(7) // host -> issuer  confirm / reject+truth
@(private)
SES_STREAM :: u8(8) // owner -> all    owner-stream batch (Channel.Stream)
@(private)
SES_PING :: u8(9) // any -> any      [local_send f64]
@(private)
SES_PONG :: u8(10) // reply           [echoed_send][remote_time]
@(private)
SES_SPAWN :: u8(11) // host -> all    [type u16][id][owner][len u16][full fields]
@(private)
SES_DESPAWN :: u8(12) // host -> all  [id]
@(private)
SES_WORLD :: u8(13) // host -> one    [count u16] x the SES_SPAWN tuple (join snapshot)

// Remote entities render this far in the past (~3 net ticks at 20 Hz): almost
// always a bracketing sample pair, smooth through jitter and single drops.
DEFAULT_INTERP_DELAY :: 0.15

// Predictions whose result never arrives revert after this many net ticks.
DEFAULT_PENDING_MAX_AGE :: 60 // 3s at 20 Hz — far beyond any sane RTT

Session :: struct {
	is_host:   bool,
	me:        knet.Player_Id,
	players:   map[knet.Player_Id]Player,
	events:    [dynamic]Event,
	send:      Send_Proc,
	send_user: rawptr,

	// the replicated world (kit/net): the session drives the per-tick walks
	reg:          knet.Registry,
	ctx:          knet.Command_Ctx,
	ticker:       knet.Ticker,
	clocks:       map[int]knet.Clock_Sync, // per transport peer, fed by ping/pong
	pongs:        int, // pong samples applied (games gate "clock is warm" on this)
	now:          f64, // the game's monotonic seconds, updated each session_tick
	replicating:  bool, // host: the world is LIVE (deltas flow; joiners get SES_WORLD)
	interp_delay: f64,

	// entity types + client-side factories
	types:        map[knet.Net_Id]Entity_Type, // host: for (re-)announcing spawns
	factory_user: rawptr,
	factory_make: Make_Entity_Proc,
	factory_free: Free_Entity_Proc,

	// host bookkeeping
	next_player: knet.Player_Id,
	tokens:      map[u64]knet.Player_Id, // reconnect identity, forever
	by_peer:     map[int]knet.Player_Id,

	// client bookkeeping
	token:  u64, // our reconnect secret (the game persists it across runs)
	name:   string, // owned; the name we asked for
	joined: bool, // WELCOME received
}

@(private = "file")
session_init :: proc(s: ^Session) {
	s.reg = knet.registry_make()
	s.ctx = knet.command_ctx_make()
	s.ticker = knet.ticker_make()
	s.interp_delay = DEFAULT_INTERP_DELAY
	// Commands always go host-ward through the session's own framing.
	s.ctx.send = ctx_send_command
	s.ctx.send_user = s
}

session_destroy :: proc(s: ^Session) {
	for _, p in s.players {
		delete(p.name)
	}
	delete(s.players)
	delete(s.events)
	delete(s.tokens)
	delete(s.by_peer)
	delete(s.name)
	knet.registry_destroy(&s.reg)
	knet.command_ctx_destroy(&s.ctx)
	delete(s.clocks)
	delete(s.types)
	s^ = {}
}

// Install the client-side entity factory (do it before joining).
session_set_factory :: proc(s: ^Session, user: rawptr, make_entity: Make_Entity_Proc, free_entity: Free_Entity_Proc) {
	s.factory_user = user
	s.factory_make = make_entity
	s.factory_free = free_entity
}

// The Command_Ctx send hook: wrap raw command bytes in session framing and
// ship them to the host. Installed by session_init — the generated `<proc>_cmd`
// wrappers reach the wire without the game writing any glue.
@(private = "file")
ctx_send_command :: proc(user: rawptr, bytes: []u8) {
	s := cast(^Session)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_CMD)
	append(&w.buf, ..bytes)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// ---- the replicated world ----------------------------------------------------

// Host: spawn an entity into the session. Allocates its net id, records its
// type, and — once the world is live — announces it to every seated peer
// (reliable, so the spawn always precedes any delta naming the id). The HOST
// game creates its own entity however it likes; remote peers create theirs
// through the factory when the announcement arrives.
session_spawn :: proc(s: ^Session, type: Entity_Type, entity: rawptr, set: ^knet.Command_Set, owner := knet.PLAYER_ID_INVALID) -> knet.Net_Id {
	assert(s.is_host, "only the authority spawns; clients create via the factory")
	id := knet.registry_spawn(&s.reg, entity, set, owner)
	s.types[id] = type
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SPAWN)
		write_spawn_tuple(s, &w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
	return id
}

// Host: remove an entity from the session and tell everyone. The host game
// frees its own node after this returns; remote peers free theirs through the
// factory. Clients' in-flight predictions on the entity clean up on their own
// (results/expiry handle a missing entity).
session_despawn :: proc(s: ^Session, id: knet.Net_Id) {
	assert(s.is_host)
	if !knet.registry_remove(&s.reg, id) {
		return
	}
	delete_key(&s.types, id)
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_DESPAWN)
		knet.write_net_id(&w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
}

// Host: the world is set up — go live. Commits shadows, ships the full world
// (SES_WORLD) to every ALREADY-seated client, and from here on the per-tick
// delta walk broadcasts and every later joiner gets SES_WORLD right behind
// its WELCOME: drop-in mid-game join is the same code path as being early.
session_start_replicating :: proc(s: ^Session) {
	assert(s.is_host)
	knet.registry_commit_shadows(&s.reg)
	s.replicating = true
	for _, p in s.players {
		if !p.connected || p.id == s.me {
			continue
		}
		send_world(s, p.peer)
	}
}

// [type][id][owner][len][full fields] — len makes unknown types skippable.
@(private = "file")
write_spawn_tuple :: proc(s: ^Session, w: ^knet.Writer, id: knet.Net_Id) {
	e, _ := knet.registry_get(&s.reg, id)
	knet.write_u16(w, u16(s.types[id]))
	knet.write_net_id(w, id)
	knet.write_player_id(w, e.owner)
	n := knet.desc_data_size(e.set.entity_desc)
	assert(n <= int(max(u16)))
	knet.write_u16(w, u16(n))
	knet.write_full(w, e.entity, e.set.entity_desc)
}

@(private = "file")
send_world :: proc(s: ^Session, peer: int) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_WORLD)
	assert(knet.registry_count(&s.reg) <= int(max(u16)))
	knet.write_u16(&w, u16(knet.registry_count(&s.reg)))
	for id in s.types {
		write_spawn_tuple(s, &w, id)
	}
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)
}

// Client: one incoming spawn tuple — factory-create (or reconcile onto an
// entity we already have: a same-session rejoin re-receives the world), apply
// the snapshot, event. Unknown types skip by length.
@(private = "file")
apply_spawn_tuple :: proc(s: ^Session, r: ^knet.Reader) {
	type := Entity_Type(knet.read_u16(r))
	id := knet.read_net_id(r)
	owner := knet.read_player_id(r)
	n := int(knet.read_u16(r))
	if r.err || r.off + n > len(r.data) {
		r.err = true
		return
	}
	body := knet.reader_make(r.data[r.off:r.off + n])
	r.off += n

	if e, exists := knet.registry_get(&s.reg, id); exists {
		knet.apply_full(&body, e.entity, e.set.entity_desc)
		return
	}
	if s.factory_make == nil {
		return
	}
	entity, set := s.factory_make(s.factory_user, type, id, owner)
	if entity == nil || set == nil {
		return // unknown type: skipped whole, by length
	}
	knet.registry_insert(&s.reg, id, entity, set, owner)
	s.types[id] = type
	knet.apply_full(&body, entity, set.entity_desc)
	append(&s.events, Ev_Spawned{id = id, type = type, owner = owner})
}

// Drive the session once per frame. `now` is the game's monotonic seconds
// (any base — it stamps stream rings and clock pings). Returns how many net
// ticks fired and how many remote entities were stream-sampled this frame.
session_tick :: proc(s: ^Session, dt: f64, now: f64) -> (ticks: int, sampled: int) {
	s.now = now
	ticks = knet.ticker_advance(&s.ticker, dt)
	for _ in 0 ..< ticks {
		net_tick(s)
	}
	sampled = knet.registry_sample_streams(&s.reg, now - s.interp_delay, s.me)
	return
}

@(private = "file")
net_tick :: proc(s: ^Session) {
	t := s.ticker.tick
	s.ctx.now_tick = t

	if s.is_host && s.replicating {
		// Host state: ONE batched delta message for every dirty entity, to
		// every joined peer, reliable (the shadow commits on send — a dropped
		// delta would be lost forever; spawn/despawn shares this channel so
		// ids are always known before a batch names them).
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_STATE)
		if knet.registry_write_deltas(&w, &s.reg) > 0 {
			broadcast(s, knet.writer_bytes(&w), .Reliable)
		}
	}

	// Owner streams: last-value snapshots of every entity WE own, unreliable
	// (a drop is superseded by the next tick's snapshot). Any peer can own.
	{
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_STREAM)
		if knet.registry_write_streams(&w, &s.reg, s.me, s.now) > 0 {
			broadcast(s, knet.writer_bytes(&w), .Stream)
		}
	}

	// Clock ping toward the host, ~1/s, once seated. (Per-peer mesh pings —
	// for sender-stamped stream timelines — come with a later brick.)
	if !s.is_host && s.joined && t % 20 == 5 {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_PING)
		knet.ping_write(&w, s.now)
		s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
	}

	if n := knet.registry_expire_pending(&s.reg, &s.ctx, DEFAULT_PENDING_MAX_AGE); n > 0 {
		for _ in 0 ..< n {
			append(&s.events, Ev_Command_Rejected{}) // loud auto-revert: silence means no
		}
	}
}

// Transport-level "everyone but me" (engine semantics: netgd relays peer 0 to
// all other peers, server-relayed for clients). World traffic uses this — only
// the HOST knows other players' transport peers, but any peer may own streamed
// entities. Roster messages stay host-targeted (they need per-peer exclusion).
BROADCAST_PEER :: 0

@(private = "file")
broadcast :: proc(s: ^Session, bytes: []u8, channel: Channel) {
	s.send(s.send_user, BROADCAST_PEER, bytes, channel)
}

// This peer's clock estimate for `peer` (zero value until a pong lands).
session_clock :: proc(s: ^Session, peer: int) -> knet.Clock_Sync {
	return s.clocks[peer]
}

// Drain one queued event (call until ok=false each frame).
session_poll :: proc(s: ^Session) -> (ev: Event, ok: bool) {
	if len(s.events) == 0 {
		return nil, false
	}
	ev = s.events[0]
	ordered_remove(&s.events, 0)
	return ev, true
}

session_player :: proc(s: ^Session, id: knet.Player_Id) -> (Player, bool) {
	p, ok := s.players[id]
	return p, ok
}

session_count :: proc(s: ^Session, connected_only := false) -> int {
	if !connected_only {
		return len(s.players)
	}
	n := 0
	for _, p in s.players {
		if p.connected {
			n += 1
		}
	}
	return n
}

// ---- host ------------------------------------------------------------------

// Become the session authority. The host is a full player too (name, id,
// stats) — it just never JOINs over the wire.
session_host_start :: proc(s: ^Session, name: string) {
	session_init(s)
	s.is_host = true
	s.ctx.is_authority = true
	s.next_player = 1
	s.me = s.next_player
	s.next_player += 1
	s.players[s.me] = Player {
		id        = s.me,
		name      = strings.clone(name),
		peer      = HOST_PEER,
		connected = true,
	}
	s.joined = true
}

// The transport told us a peer vanished. A peer that never joined is nobody;
// a player's departure is broadcast and the roster keeps them (disconnected)
// so the same token can reclaim the identity later.
session_peer_disconnected :: proc(s: ^Session, peer: int) {
	if !s.is_host {
		if peer == HOST_PEER {
			append(&s.events, Ev_Host_Left{})
		}
		return
	}
	id, was := s.by_peer[peer]
	if !was {
		return
	}
	delete_key(&s.by_peer, peer)
	mark_left(s, id)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_LEFT)
	knet.write_player_id(&w, id)
	host_broadcast(s, knet.writer_bytes(&w), except = id)
}

@(private = "file")
mark_left :: proc(s: ^Session, id: knet.Player_Id) {
	p := s.players[id]
	p.connected = false
	p.peer = 0
	s.players[id] = p
	append(&s.events, Ev_Player_Left{id = id})
}

@(private = "file")
host_broadcast :: proc(s: ^Session, bytes: []u8, except := knet.PLAYER_ID_INVALID) {
	for _, p in s.players {
		if !p.connected || p.id == s.me || p.id == except {
			continue
		}
		s.send(s.send_user, p.peer, bytes, .Reliable)
	}
}

@(private = "file")
host_handle_join :: proc(s: ^Session, peer: int, r: ^knet.Reader) {
	token := knet.read_u64(r)
	name := knet.read_string(r)
	if r.err {
		return
	}

	id, known := s.tokens[token]
	rejoin := false
	if known {
		// The token IS the identity: reclaim it. If the roster still shows the
		// player connected, the old peer is a zombie (crashed socket that
		// hasn't timed out) — the new connection takes over.
		rejoin = true
		p := s.players[id]
		if p.connected && p.peer != peer {
			delete_key(&s.by_peer, p.peer)
		}
		delete(p.name)
		p.name = strings.clone(name)
		p.peer = peer
		p.connected = true
		s.players[id] = p
	} else {
		id = s.next_player
		s.next_player += 1
		s.tokens[token] = id
		s.players[id] = Player {
			id        = id,
			name      = strings.clone(name),
			peer      = peer,
			connected = true,
		}
	}
	s.by_peer[peer] = id

	// WELCOME the joiner with the full roster (their own entry included —
	// clients learn `me` from your_id).
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_WELCOME)
	knet.write_player_id(&w, id)
	assert(len(s.players) <= int(max(u16)))
	knet.write_u16(&w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(&w, p.id)
		knet.write_string(&w, p.name)
		knet.write_bool(&w, p.connected)
	}
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)

	// Everyone else learns about (or re-learns) the joiner.
	up := knet.writer_make()
	defer knet.writer_destroy(&up)
	knet.write_u8(&up, SES_UPSERT)
	knet.write_player_id(&up, id)
	knet.write_string(&up, name)
	knet.write_bool(&up, true)
	knet.write_bool(&up, rejoin)
	host_broadcast(s, knet.writer_bytes(&up), except = id)

	// DROP-IN JOIN: a live world follows the welcome on the same ordered
	// channel — the joiner materializes everything before any delta can name
	// an id it doesn't know. (Deltas broadcast before this arrive at the
	// still-unseated client and are dropped; SES_WORLD supersedes them.)
	if s.replicating {
		send_world(s, peer)
	}

	append(&s.events, Ev_Player_Joined{id = id, rejoin = rejoin})
}

// ---- client ------------------------------------------------------------------

// Remember who we are; the JOIN goes out when the game confirms the transport
// is up (session_client_join). `token` is the persistent reconnect secret.
session_client_start :: proc(s: ^Session, token: u64, name: string) {
	session_init(s)
	s.is_host = false
	s.token = token
	s.name = strings.clone(name)
}

// Transport is connected: ask the host to seat us.
session_client_join :: proc(s: ^Session) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_JOIN)
	knet.write_u64(&w, s.token)
	knet.write_string(&w, s.name)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// Graceful goodbye (the host also handles the plain transport disconnect —
// this just makes the departure immediate instead of timeout-shaped).
session_client_leave :: proc(s: ^Session) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_BYE)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

@(private = "file")
roster_upsert :: proc(s: ^Session, id: knet.Player_Id, name: string, connected: bool, peer := 0) {
	if old, had := s.players[id]; had {
		delete(old.name)
	}
	s.players[id] = Player {
		id        = id,
		name      = strings.clone(name),
		peer      = peer,
		connected = connected,
	}
}

@(private = "file")
client_handle_welcome :: proc(s: ^Session, r: ^knet.Reader) {
	me := knet.read_player_id(r)
	count := int(knet.read_u16(r))
	if r.err {
		return
	}
	for _ in 0 ..< count {
		id := knet.read_player_id(r)
		name := knet.read_string(r)
		connected := knet.read_bool(r)
		if r.err {
			return // partial roster is fine: entries already applied are valid
		}
		roster_upsert(s, id, name, connected)
	}
	s.me = me
	s.joined = true
	append(&s.events, Ev_Welcomed{me = me})
}

// ---- shared receive path -----------------------------------------------------

// The game routes its session kind byte here with the rest of the packet.
// `from_peer` is the transport sender (hosts route by it; clients only ever
// hear from the host — except streams, which any owning peer may broadcast).
session_handle_packet :: proc(s: ^Session, from_peer: int, r: ^knet.Reader) {
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	switch kind {
	// ---- roster ----
	case SES_JOIN:
		if s.is_host {
			host_handle_join(s, from_peer, r)
		}
	case SES_BYE:
		if s.is_host {
			session_peer_disconnected(s, from_peer)
		}
	case SES_WELCOME:
		if !s.is_host {
			client_handle_welcome(s, r)
		}
	case SES_UPSERT:
		if s.is_host {
			return
		}
		id := knet.read_player_id(r)
		name := knet.read_string(r)
		connected := knet.read_bool(r)
		rejoin := knet.read_bool(r)
		if r.err {
			return
		}
		roster_upsert(s, id, name, connected)
		append(&s.events, Ev_Player_Joined{id = id, rejoin = rejoin})
	case SES_LEFT:
		if s.is_host {
			return
		}
		id := knet.read_player_id(r)
		if r.err {
			return
		}
		if p, had := s.players[id]; had {
			p.connected = false
			p.peer = 0
			s.players[id] = p
			append(&s.events, Ev_Player_Left{id = id})
		}

	// ---- the replicated world (clients ignore it all until SEATED: a spawn
	// arriving before our WELCOME would collide with the SES_WORLD that
	// follows it — everything pre-seat is superseded by that snapshot) ----
	case SES_WORLD:
		if s.is_host || !s.joined {
			return
		}
		count := int(knet.read_u16(r))
		for _ in 0 ..< count {
			apply_spawn_tuple(s, r)
			if r.err {
				return
			}
		}
		knet.registry_commit_shadows(&s.reg)
	case SES_SPAWN:
		if s.is_host || !s.joined {
			return
		}
		apply_spawn_tuple(s, r)
	case SES_DESPAWN:
		if s.is_host || !s.joined {
			return
		}
		id := knet.read_net_id(r)
		if r.err {
			return
		}
		e, exists := knet.registry_get(&s.reg, id)
		if !exists {
			return
		}
		knet.registry_remove(&s.reg, id)
		delete_key(&s.types, id)
		if s.factory_free != nil {
			s.factory_free(s.factory_user, id, e.entity)
		}
		append(&s.events, Ev_Despawned{id = id})
	case SES_STATE:
		if s.is_host || !s.joined {
			return
		}
		n := knet.registry_apply_deltas(r, &s.reg, &s.ctx)
		if !r.err {
			append(&s.events, Ev_State_Applied{entities = n})
		}
	case SES_CMD:
		if !s.is_host {
			return
		}
		// Dedup keyed by PLAYER id, not transport peer: a reconnecting player's
		// retransmits stay exactly-once across the peer change. A command from
		// a peer that never JOINed is from nobody — dropped.
		pid, seated := s.by_peer[from_peer]
		if !seated {
			return
		}
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_RESULT)
		responded, ok := knet.registry_host_command(&s.reg, &s.ctx, u64(pid), r, &w)
		if !responded {
			return
		}
		s.send(s.send_user, from_peer, knet.writer_bytes(&w), .Reliable)
		append(&s.events, Ev_Command_Executed{ok = ok})
	case SES_RESULT:
		if s.is_host {
			return
		}
		res := knet.registry_client_result(&s.reg, &s.ctx, r)
		if res.seq == 0 {
			return // truncated header: not a result at all (seqs start at 1)
		}
		if res.ok {
			append(&s.events, Ev_Command_Confirmed{seq = res.seq})
		} else {
			// A truncated truth snapshot already fell back to the local revert
			// inside command_reject — the rejection event holds either way.
			append(&s.events, Ev_Command_Rejected{seq = res.seq, entity = res.entity})
		}
	case SES_STREAM:
		if !s.joined {
			return
		}
		_ = knet.registry_stream_time(r) // sender stamp (clock-mapped timelines later)
		_ = knet.registry_apply_streams(r, &s.reg, s.me, s.now)
	case SES_PING:
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_PONG)
		knet.ping_answer(r, &w, s.now)
		if !r.err {
			s.send(s.send_user, from_peer, knet.writer_bytes(&w), .Reliable)
		}
	case SES_PONG:
		c := s.clocks[from_peer]
		if knet.pong_apply(r, &c, s.now) {
			s.clocks[from_peer] = c
			s.pongs += 1
		}
	}
}

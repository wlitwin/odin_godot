package kit_session_test

// Standalone tests for kit/session — player identity, join/leave/reconnect,
// roster sync. No Godot runtime:
//
//   odin test tests/kitsession -collection:godot=$PWD
//
// Sessions are wired through an in-memory pipe (Peer_Box), so the full wire
// path — JOIN/WELCOME/UPSERT/LEFT bytes included — is exercised exactly as it
// runs over the real transport, minus the socket.

import "core:testing"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// The default wire fingerprint, set ONCE at load — exactly the shape the
// generated guard file's @(init) gives a real game, and the only shape that
// is safe: tests run in PARALLEL threads over package globals, so a test
// that mutated this mid-run would race every concurrently-joining session
// into a .Version denial (three seat-count tests once failed exactly that
// way). Every fingerprint-less session in this binary now gates on 0xF00D
// (both ends match, so nothing changes for them); opting OUT is
// FINGERPRINT_NONE, the production story.
@(init)
_test_default_fingerprint :: proc "contextless" () {
	ksess.default_net_fingerprint = 0xF00D
}

Envelope :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Peer_Box :: struct {
	peer:  ksess.Peer_Id,
	s:     ksess.Session,
	out:   [dynamic]Envelope,
	bots:  map[knet.Net_Id]^Bot, // factory-created entities (clients)
	freed: int, // factory frees observed

	// the `<field>_edge` probe: what the hp edge half saw on this peer
	edge_fires: int,
	edge_old:   i32,
	edge_new:   i32,
}

box_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make :: proc(b: ^Peer_Box, peer: ksess.Peer_Id) {
	b.peer = peer
	b.s.send = box_send
	b.s.send_user = b
	ksess.session_set_factory(&b.s, b, box_make_entity, box_free_entity)
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {
		delete(e.data)
	}
	delete(b.out)
	for _, bot in b.bots {
		free(bot)
	}
	delete(b.bots)
	ksess.session_destroy(&b.s)
}

// Deliver every queued message (including ones queued by handling) until the
// network is quiet. `to == BROADCAST_PEER` reaches everyone but the sender,
// matching the transport's relay semantics.
pump :: proc(boxes: []^Peer_Box) {
	for progress := true; progress; {
		progress = false
		for b in boxes {
			for len(b.out) > 0 {
				e := b.out[0]
				ordered_remove(&b.out, 0)
				for dst in boxes {
					if dst.peer == b.peer {
						continue
					}
					if e.to == ksess.BROADCAST_PEER || dst.peer == e.to {
						r := knet.reader_make(e.data)
						ksess.session_handle_packet(&dst.s, b.peer, &r)
					}
				}
				delete(e.data)
				progress = true
			}
		}
	}
}

drain :: proc(s: ^ksess.Session) -> [dynamic]ksess.Event {
	evs := make([dynamic]ksess.Event, context.temp_allocator)
	for {
		ev, ok := ksess.session_poll(s)
		if !ok {break}
		append(&evs, ev)
	}
	return evs
}

TOKEN_ALICE :: u64(0xA11CE)
TOKEN_BOB :: u64(0xB0B)

@(test)
join_builds_the_roster_everywhere :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	testing.expect_value(t, host.s.me, knet.Player_Id(1))
	testing.expect_value(t, ksess.session_count(&host.s), 1)

	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	testing.expect_value(t, alice.s.me, knet.Player_Id(2))
	testing.expect(t, alice.s.joined)
	testing.expect_value(t, ksess.session_count(&alice.s), 2) // host + self
	hp, _ := ksess.session_player(&alice.s, 1)
	testing.expect_value(t, hp.name, "hosty")

	aev := drain(&alice.s)
	testing.expect_value(t, len(aev), 2) // WELCOME, then the join-time stats snapshot
	_, welcomed := aev[0].(ksess.Ev_Welcomed)
	testing.expect(t, welcomed)
	_, statsed := aev[1].(ksess.Ev_Stats_Updated)
	testing.expect(t, statsed, "the scoreboard rides along with the welcome")

	hev := drain(&host.s)
	testing.expect_value(t, len(hev), 1)
	j, joined := hev[0].(ksess.Ev_Player_Joined)
	testing.expect(t, joined && j.id == 2 && !j.rejoin)

	// Bob joins: alice must hear about him WITHOUT rejoining anything.
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	testing.expect_value(t, bob.s.me, knet.Player_Id(3))
	testing.expect_value(t, ksess.session_count(&bob.s), 3)
	testing.expect_value(t, ksess.session_count(&alice.s), 3)
	bp, _ := ksess.session_player(&alice.s, 3)
	testing.expect_value(t, bp.name, "bob")
	testing.expect(t, bp.connected)

	aev2 := drain(&alice.s)
	testing.expect_value(t, len(aev2), 1)
	j2, _ := aev2[0].(ksess.Ev_Player_Joined)
	testing.expect(t, j2.id == 3 && !j2.rejoin)
}

@(test)
reconnect_reclaims_identity :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{&host, &alice, &bob})
	drain(&host.s)
	drain(&alice.s)
	drain(&bob.s)

	// Bob's transport drops. He stays in every roster, disconnected.
	ksess.session_peer_disconnected(&host.s, 200)
	pump([]^Peer_Box{&host, &alice})

	hleft := drain(&host.s)
	testing.expect_value(t, len(hleft), 1)
	l, _ := hleft[0].(ksess.Ev_Player_Left)
	testing.expect_value(t, l.id, knet.Player_Id(3))
	bp, still := ksess.session_player(&alice.s, 3)
	testing.expect(t, still, "departed players stay in the roster")
	testing.expect(t, !bp.connected)
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true), 2)
	drain(&alice.s)

	// Bob returns — NEW process, NEW transport peer, SAME persisted token.
	bob2: Peer_Box
	box_make(&bob2, 300)
	defer box_destroy(&bob2)
	ksess.session_client_start(&bob2.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob2.s)
	pump([]^Peer_Box{&host, &alice, &bob2})

	testing.expect_value(t, bob2.s.me, knet.Player_Id(3)) // identity reclaimed
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true), 3)

	hj := drain(&host.s)
	testing.expect_value(t, len(hj), 1)
	j, _ := hj[0].(ksess.Ev_Player_Joined)
	testing.expect(t, j.id == 3 && j.rejoin, "host must see a REJOIN, not a new player")
	aj := drain(&alice.s)
	testing.expect_value(t, len(aj), 1)
	ja, _ := aj[0].(ksess.Ev_Player_Joined)
	testing.expect(t, ja.id == 3 && ja.rejoin)
	rb, _ := ksess.session_player(&alice.s, 3)
	testing.expect(t, rb.connected)

	// The host never allocated a fourth id for the returning bob.
	testing.expect_value(t, host.s.next_player, knet.Player_Id(4))
}

@(test)
doppelganger_same_token_fresh_seat :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	drain(&host.s)
	drain(&alice.s)

	// The same token arrives from a NEW peer while alice's seat is still
	// CONNECTED. The wire cannot tell a crashed-socket zombie from a LIVE
	// second instance sharing the identity file (same-origin storage hands
	// every browser tab the same token), so a live seat is never hijacked:
	// the newcomer is seated FRESH. The transport reaps real zombies within
	// seconds and a disconnected seat reclaims as ever.
	alice2: Peer_Box
	box_make(&alice2, 400)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})

	testing.expect_value(t, alice2.s.me, knet.Player_Id(3)) // a fresh seat, not alice's
	p, _ := ksess.session_player(&host.s, 2)
	testing.expect_value(t, p.peer, 100) // the live seat is untouched
	testing.expect(t, p.connected)
	hj := drain(&host.s)
	testing.expect_value(t, len(hj), 1)
	j, _ := hj[0].(ksess.Ev_Player_Joined)
	testing.expect(t, j.id == 3 && !j.rejoin, "the doppelganger is a NEW player, not a rejoin")

	// The zombie's eventual transport timeout reaps the OLD seat normally.
	ksess.session_peer_disconnected(&host.s, 100)
	p2, _ := ksess.session_player(&host.s, 2)
	testing.expect(t, !p2.connected, "the stale seat dies with its own peer")

	// The shared token now maps to the NEWEST seat: once the doppelganger
	// drops too, a reconnect reclaims id 3 — id 2 is abandoned for good.
	ksess.session_peer_disconnected(&host.s, 400)
	drain(&host.s)
	alice3: Peer_Box
	box_make(&alice3, 500)
	defer box_destroy(&alice3)
	ksess.session_client_start(&alice3.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice3.s)
	pump([]^Peer_Box{&host, &alice3})
	testing.expect_value(t, alice3.s.me, knet.Player_Id(3))
}

@(test)
graceful_bye_and_host_loss :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	drain(&host.s)
	drain(&alice.s)

	// Polite exit: BYE lands as an immediate departure.
	ksess.session_client_leave(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	hev := drain(&host.s)
	testing.expect_value(t, len(hev), 1)
	l, left := hev[0].(ksess.Ev_Player_Left)
	testing.expect(t, left && l.id == 2)

	// The later transport disconnect for the same peer is a no-op.
	ksess.session_peer_disconnected(&host.s, 100)
	testing.expect_value(t, len(drain(&host.s)), 0)

	// Client side: the host's peer dropping ends the run.
	ksess.session_peer_disconnected(&alice.s, ksess.HOST_PEER)
	aev := drain(&alice.s)
	testing.expect_value(t, len(aev), 1)
	_, over := aev[0].(ksess.Ev_Host_Left)
	testing.expect(t, over)
}

@(test)
rename_on_rejoin :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")

	alice: Peer_Box
	box_make(&alice, 100)
	defer box_destroy(&alice)
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	ksess.session_peer_disconnected(&host.s, 100)

	// Same identity, new display name: the token wins, the name refreshes.
	alice2: Peer_Box
	box_make(&alice2, 101)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alicia")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})

	testing.expect_value(t, alice2.s.me, knet.Player_Id(2))
	p, _ := ksess.session_player(&host.s, 2)
	testing.expect_value(t, p.name, "alicia")
}

// ---- the replicated world through the session ---------------------------------
//
// The session owns registry + command ctx + ticker (the acid test's node,
// promoted). One fixture entity exercises the whole loop: host deltas,
// predicted commands with confirm/reject events, owner streams, clock pings.

Bot :: struct {
	hp: i32,
	x:  f32,
}

bot_cmd_hit :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	b := cast(^Bot)entity
	amount := knet.read_i32(r)
	if r.err {return false}
	if b.hp <= amount {return false} // can't drop to/below zero: reject
	b.hp -= amount
	return true
}

// File-scope like generated code: the registry and factories keep pointers.
bot_fields := [?]knet.Field_Desc{
	{offset = offset_of(Bot, hp), size = size_of(i32)},
	{offset = offset_of(Bot, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
}
bot_desc := knet.Entity_Desc{fields = bot_fields[:]}
BOT_HIT :: u16(0x6232) // hash-sized like a generated id — the suite rides the production shape
bot_cmds := [?]knet.Command_Desc{{name = "hit", id = BOT_HIT, predict = true, invoke = bot_cmd_hit}}

// The hp edge half, hand-built like generated code would be: cast, deref old,
// record. Living on the SHARED set means every kitsession scenario (spawns,
// reconnects, migration, interest) exercises the edge machinery incidentally.
bot_hp_edge_thunk :: proc(entity: rawptr, game: rawptr, old: rawptr) {
	b := cast(^Peer_Box)game // the factory user — the same `game` a _then receives
	b.edge_fires += 1
	b.edge_old = (cast(^i32)old)^
	b.edge_new = (cast(^Bot)entity).hp
}

bot_edges := [?]knet.Edge_Desc{{field = 0, fire = bot_hp_edge_thunk}}
bot_command_set := knet.Command_Set{entity_desc = &bot_desc, commands = bot_cmds[:], edges = bot_edges[:]}

BOT_TYPE :: ksess.Entity_Type(7)
UNKNOWN_TYPE :: ksess.Entity_Type(99)

// The client-side factory: heap-allocate a Bot for BOT_TYPE, refuse the rest.
box_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	b := cast(^Peer_Box)user
	if type != BOT_TYPE {
		return nil, nil
	}
	bot := new(Bot)
	b.bots[id] = bot
	return bot, &bot_command_set
}

box_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Peer_Box)user
	delete_key(&b.bots, id)
	free(entity)
	b.freed += 1
}

// Advance both peers' sessions one net tick's worth and deliver the traffic.
step :: proc(boxes: []^Peer_Box, now: ^f64) {
	now^ += 0.05 // exactly one 20 Hz tick
	for b in boxes {
		_, _ = ksess.session_tick(&b.s, 0.05, now^)
	}
	pump(boxes)
}

@(test)
world_over_the_session :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	drain(&host.s)
	drain(&alice.s)

	// World setup: the host spawns its own entity; going live ships SES_WORLD
	// and alice's FACTORY creates her copy. Alice owns the bot's streamed x.
	hbot := Bot{hp = 10, x = 1}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set, owner = alice.s.me)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	abot := alice.bots[id]
	testing.expect(t, abot != nil, "the factory must have made alice's bot")
	testing.expect_value(t, abot.hp, i32(10))
	testing.expect_value(t, abot.x, f32(1))
	drain(&alice.s) // Ev_Spawned

	now := 100.0

	// HOST STATE: a host-side mutation deltas out on the next net tick.
	hbot.hp = 8
	step(boxes, &now)
	testing.expect_value(t, abot.hp, i32(8))
	aev := drain(&alice.s)
	found_state := false
	for ev in aev {
		if st, ok := ev.(ksess.Ev_State_Applied); ok && st.entities == 1 {
			found_state = true
		}
	}
	testing.expect(t, found_state, "client must see the state batch land")

	// PREDICTED COMMAND, CONFIRM: alice hits for 3 — instant locally, host
	// executes, confirm event drains the pending.
	knet.command_begin(&alice.s.ctx, id, BOT_HIT)
	knet.write_i32(&alice.s.ctx.msg, 3)
	testing.expect(t, knet.command_issue(&alice.s.ctx, abot, &bot_command_set, BOT_HIT))
	testing.expect_value(t, abot.hp, i32(5))
	pump(boxes)
	testing.expect_value(t, hbot.hp, i32(5))

	hev := drain(&host.s)
	exec_ok := false
	for ev in hev {
		if ex, ok := ev.(ksess.Ev_Command_Executed); ok && ex.ok {
			exec_ok = true
		}
	}
	testing.expect(t, exec_ok)
	aev2 := drain(&alice.s)
	confirmed := false
	for ev in aev2 {
		if _, ok := ev.(ksess.Ev_Command_Confirmed); ok {
			confirmed = true
		}
	}
	testing.expect(t, confirmed)
	testing.expect_value(t, knet.pending_count(&alice.s.ctx.pending), 0)

	// PREDICTED COMMAND, REJECT: hitting for 5 would kill (hp 5) — alice's
	// stale-free prediction also rejects locally, the host's reject + truth
	// still settles it (and the event names the entity).
	knet.command_begin(&alice.s.ctx, id, BOT_HIT)
	knet.write_i32(&alice.s.ctx.msg, 5)
	testing.expect(t, !knet.command_issue(&alice.s.ctx, abot, &bot_command_set, BOT_HIT))
	testing.expect_value(t, abot.hp, i32(5)) // local revert
	pump(boxes)
	testing.expect_value(t, hbot.hp, i32(5)) // host rejected too
	aev3 := drain(&alice.s)
	rejected := false
	for ev in aev3 {
		if rj, ok := ev.(ksess.Ev_Command_Rejected); ok && rj.entity == id {
			rejected = true
		}
	}
	testing.expect(t, rejected)
	drain(&host.s)

	// Flush the delta the command's hp mutation legitimately owes (it goes out
	// on the next net tick), so the stream section below can assert silence.
	step(boxes, &now)
	drain(&alice.s)

	// OWNER STREAM: alice owns x — she writes it, her session streams it, the
	// HOST samples it (the host is just another remote for owned fields).
	abot.x = 10
	step(boxes, &now) // stream snapshot t=now
	abot.x = 20
	step(boxes, &now) // second snapshot; host ring has a bracketing pair
	// Sample far enough past both snapshots to land on the newest.
	now += 1.0
	_, sampled := ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, sampled, 1)
	testing.expect_value(t, hbot.x, f32(20))
	// The host's OWN delta walk must never re-broadcast alice's stream.
	step(boxes, &now)
	aev4 := drain(&alice.s)
	for ev in aev4 {
		if _, ok := ev.(ksess.Ev_State_Applied); ok {
			testing.expect(t, false, "owner-streamed fields leaked into a host delta batch")
		}
	}

	// CLOCK: alice pings ~1/s once seated; the host answers; the estimate warms.
	for _ in 0 ..< 25 { // > one ping interval of net ticks
		step(boxes, &now)
	}
	testing.expect(t, alice.s.pongs > 0, "ping/pong must feed the client clock")
	c := ksess.session_clock(&alice.s, ksess.HOST_PEER)
	testing.expect(t, c.initialized)
}

@(test)
commands_from_unseated_peers_are_dropped :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")

	hbot := Bot{hp = 10}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set)
	drain(&host.s) // the host hears its own spawn (Ev_Spawned = born, every peer)

	// A raw SES_CMD from a transport peer that never JOINed: dropped whole —
	// no execution, no result, no event.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, 6) // SES_CMD
	knet.write_net_id(&w, id)
	knet.write_u16(&w, 0)
	knet.write_u32(&w, 1)
	knet.write_i32(&w, 3)
	r := knet.reader_make(knet.writer_bytes(&w))
	ksess.session_handle_packet(&host.s, 666, &r)
	testing.expect_value(t, hbot.hp, i32(10))
	testing.expect_value(t, len(drain(&host.s)), 0)
}

// ---- spawn/despawn by type, drop-in join, reconnect reclaim --------------------

@(test)
spawn_and_despawn_via_factory :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	drain(&host.s)
	drain(&alice.s)

	// Pre-live spawn travels via SES_WORLD at go-live.
	b1 := Bot{hp = 30, x = 3}
	id1 := ksess.session_spawn(&host.s, BOT_TYPE, &b1, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	testing.expect(t, alice.bots[id1] != nil)
	testing.expect_value(t, alice.bots[id1].hp, i32(30))

	// LIVE spawn: announced immediately (SES_SPAWN), snapshot included.
	b2 := Bot{hp = 55, x = 5}
	id2 := ksess.session_spawn(&host.s, BOT_TYPE, &b2, &bot_command_set)
	pump(boxes)
	testing.expect(t, alice.bots[id2] != nil)
	testing.expect_value(t, alice.bots[id2].hp, i32(55))
	spawned := 0
	for ev in drain(&alice.s) {
		if _, ok := ev.(ksess.Ev_Spawned); ok {
			spawned += 1
		}
	}
	testing.expect_value(t, spawned, 2)

	// Deltas reach the factory-made copy.
	now := 50.0
	b2.hp = 44
	step(boxes, &now)
	testing.expect_value(t, alice.bots[id2].hp, i32(44))

	// Despawn: removed everywhere, the factory's free runs, event fires.
	ksess.session_despawn(&host.s, id1)
	pump(boxes)
	testing.expect(t, alice.bots[id1] == nil)
	testing.expect_value(t, alice.freed, 1)
	despawned := false
	for ev in drain(&alice.s) {
		if d, ok := ev.(ksess.Ev_Despawned); ok && d.id == id1 {
			despawned = true
		}
	}
	testing.expect(t, despawned)
	testing.expect_value(t, knet.registry_count(&host.s.reg), 1)
	testing.expect_value(t, knet.registry_count(&alice.s.reg), 1)
}

@(test)
drop_in_join_gets_the_world :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")

	// The run is ALREADY going: world spawned, live, and mutated — deltas have
	// been broadcast (to nobody) and shadows committed.
	b1 := Bot{hp = 30}
	b2 := Bot{hp = 55}
	id1 := ksess.session_spawn(&host.s, BOT_TYPE, &b1, &bot_command_set)
	id2 := ksess.session_spawn(&host.s, BOT_TYPE, &b2, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	now := 50.0
	b1.hp = 25
	step([]^Peer_Box{&host}, &now)

	// Bob drops in mid-game: WELCOME, then the CURRENT world.
	bob: Peer_Box
	box_make(&bob, 200)
	defer box_destroy(&bob)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	boxes := []^Peer_Box{&host, &bob}
	pump(boxes)

	testing.expect(t, bob.s.joined)
	testing.expect(t, bob.bots[id1] != nil && bob.bots[id2] != nil)
	testing.expect_value(t, bob.bots[id1].hp, i32(25)) // post-mutation state
	testing.expect_value(t, bob.bots[id2].hp, i32(55))

	// And the ongoing delta stream just works for him.
	b2.hp = 40
	step(boxes, &now)
	testing.expect_value(t, bob.bots[id2].hp, i32(40))
}

@(test)
reconnect_reclaims_owned_entities :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	// Alice's pawn: host-spawned, owned by her — she streams its x.
	pawn := Bot{hp = 10, x = 1}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &pawn, &bot_command_set, owner = alice.s.me)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	now := 50.0
	alice.bots[id].x = 5
	step(boxes, &now)
	step(boxes, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, pawn.x, f32(5)) // her stream reached the host

	// She vanishes; the world persists.
	ksess.session_peer_disconnected(&host.s, 100)

	// Fresh process, same token: seat reclaimed, WORLD recreates her pawn —
	// owned by HER id — and her stream authority resumes without ceremony.
	alice2: Peer_Box
	box_make(&alice2, 300)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	boxes2 := []^Peer_Box{&host, &alice2}
	pump(boxes2)

	testing.expect_value(t, alice2.s.me, knet.Player_Id(2))
	repawn := alice2.bots[id]
	testing.expect(t, repawn != nil, "the world snapshot must recreate her pawn")
	e, _ := knet.registry_get(&alice2.s.reg, id)
	testing.expect_value(t, e.owner, alice2.s.me)

	repawn.x = 77
	step(boxes2, &now)
	step(boxes2, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, pawn.x, f32(77)) // authority reclaimed, stream flows
}

@(test)
unknown_entity_type_is_skipped :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	// One knowable bot, one type alice's factory refuses: the WORLD parse must
	// skip the stranger by length and still deliver the bot.
	known := Bot{hp = 30}
	strange := Bot{hp = 66}
	kid := ksess.session_spawn(&host.s, BOT_TYPE, &known, &bot_command_set)
	_ = ksess.session_spawn(&host.s, UNKNOWN_TYPE, &strange, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	pump(boxes)

	testing.expect(t, alice.bots[kid] != nil, "known entity survives an unknown neighbor")
	testing.expect_value(t, alice.bots[kid].hp, i32(30))
	testing.expect_value(t, knet.registry_count(&alice.s.reg), 1)
}

// ---- the stat registry ---------------------------------------------------------

@(test)
stats_declare_accumulate_replicate :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	drain(&host.s)
	drain(&alice.s)

	kills := ksess.session_stat_column(&host.s, "kills")
	testing.expect_value(t, ksess.session_stat_column(&host.s, "kills"), kills) // idempotent
	testing.expect_value(t, kills, ksess.Stat_Col(2)) // handles are 1-based; handle 1 is always ping
	// Reading a player with no row yet (nil/missing map entry) is all zeros —
	// the acid test's crash reporter caught a compiler fault on the plain index.
	testing.expect_value(t, ksess.session_stat(&host.s, alice.s.me, kills), i64(0))

	ksess.session_start_replicating(&host.s)
	ksess.session_stat_add(&host.s, alice.s.me, kills, 2)
	ksess.session_stat_add(&host.s, host.s.me, kills, 1)

	// Stats ship on the low-rate tick (every 10 net ticks when dirty).
	now := 50.0
	for _ in 0 ..< 10 {
		step(boxes, &now)
	}
	akills, found := ksess.session_stat_find(&alice.s, "kills")
	testing.expect(t, found, "the schema must reach the client")
	testing.expect_value(t, ksess.session_stat(&alice.s, alice.s.me, akills), i64(2))
	testing.expect_value(t, ksess.session_stat(&alice.s, host.s.me, akills), i64(1))
	updated := false
	for ev in drain(&alice.s) {
		if _, ok := ev.(ksess.Ev_Stats_Updated); ok {
			updated = true
		}
	}
	testing.expect(t, updated)

	// Mid-run column declaration: the schema grows on the client too.
	deaths := ksess.session_stat_column(&host.s, "deaths")
	ksess.session_stat_set(&host.s, alice.s.me, deaths, 7)
	for _ in 0 ..< 10 {
		step(boxes, &now)
	}
	adeaths, dfound := ksess.session_stat_find(&alice.s, "deaths")
	testing.expect(t, dfound)
	testing.expect_value(t, ksess.session_stat(&alice.s, alice.s.me, adeaths), i64(7))
	testing.expect_value(t, ksess.session_stat(&alice.s, alice.s.me, akills), i64(2)) // untouched
}

@(test)
ping_stat_auto_feeds :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	ksess.session_start_replicating(&host.s)

	// Walk the host up to its ping tick, HOLD the traffic for 300ms of host
	// time (simulated latency), then deliver — the measured rtt must be the
	// gap the pong actually took on the host's clock.
	now := 50.0
	for _ in 0 ..< 5 { // host ticks 1..5; ping goes out at tick 5
		now += 0.05
		_, _ = ksess.session_tick(&host.s, 0.05, now)
	}
	now += 0.3
	_, _ = ksess.session_tick(&host.s, 0.05, now) // host clock advances; ping still queued
	pump(boxes) // alice answers; host applies the pong at its CURRENT now

	c := ksess.session_clock(&host.s, 100)
	testing.expect(t, c.initialized, "host must measure its clients")
	testing.expect(t, c.rtt >= 0.29, "rtt must reflect the held round trip")

	// The next low-rate stats tick feeds the ping column and ships it.
	for _ in 0 ..< 10 {
		step(boxes, &now)
	}
	ping, found := ksess.session_stat_find(&alice.s, "ping")
	testing.expect(t, found)
	testing.expect(t, ksess.session_stat(&alice.s, alice.s.me, ping) >= 290, "alice sees her own measured ping")
}

@(test)
stats_survive_reconnect :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	ksess.session_start_replicating(&host.s)

	kills := ksess.session_stat_column(&host.s, "kills")
	ksess.session_stat_set(&host.s, alice.s.me, kills, 5)

	// She drops; her stats stay on her PLAYER record, not her connection.
	ksess.session_peer_disconnected(&host.s, 100)
	testing.expect_value(t, ksess.session_stat(&host.s, 2, kills), i64(5))

	// Fresh process, same token: the join-time stats snapshot restores her
	// scoreboard row under the reclaimed identity.
	alice2: Peer_Box
	box_make(&alice2, 300)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})

	akills, found := ksess.session_stat_find(&alice2.s, "kills")
	testing.expect(t, found, "join-time stats snapshot must carry the schema")
	testing.expect_value(t, ksess.session_stat(&alice2.s, alice2.s.me, akills), i64(5))
}

// ---- backup hosting: the snapshot ships, and it is genuinely re-hostable -------

@(test)
backup_ships_to_the_eldest_client :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)
	ksess.session_start_replicating(&host.s)

	// The target-change trigger fires on the next low-rate tick — no waiting
	// out the full refresh interval for the FIRST backup.
	now := 50.0
	for _ in 0 ..< 10 {
		step(boxes, &now)
	}
	testing.expect(t, len(alice.s.backup) > 0, "the eldest client holds the blob")
	testing.expect_value(t, len(bob.s.backup), 0)
	got_ev := false
	for ev in drain(&alice.s) {
		if b, ok := ev.(ksess.Ev_Backup_Received); ok && b.size > 0 {
			got_ev = true
		}
	}
	testing.expect(t, got_ev)

	// The eldest leaves: the duty (and the blob) moves to the next client.
	ksess.session_peer_disconnected(&host.s, 100)
	for _ in 0 ..< 10 {
		step([]^Peer_Box{&host, &bob}, &now)
	}
	testing.expect(t, len(bob.s.backup) > 0, "the duty must move when the target leaves")
}

// ---- dedicated server: an infrastructure seat, and succession never arms -------

@(test)
dedicated_server_seat :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "tower", dedicated = true)
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	// The flag crossed the wire: a CLIENT sees the server's seat as
	// infrastructure (the welcome roster carried it), and itself as a person.
	sp, sok := ksess.session_player(&alice.s, host.s.me)
	testing.expect(t, sok, "the server seat is on the client roster")
	testing.expect(t, sp.dedicated, "the welcome carried the dedicated flag")
	ap, aok := ksess.session_player(&alice.s, alice.s.me)
	testing.expect(t, aok && !ap.dedicated, "a joiner is a person")

	// Player gates skip it: three seats on the wire, two players in the game
	// (the wire's view now spells players_only=false; the bare call IS the gate).
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true, players_only = false), 3)
	testing.expect_value(t, ksess.session_count(&host.s), 2)

	// SUCCESSION NEVER ARMS: replicate and run well past the first backup
	// window — no torch-bearer is named, no blob ships to anyone. (A dead
	// server restarts; migration answers a PLAYER-host leaving.)
	ksess.session_start_replicating(&host.s)
	now := 50.0
	for _ in 0 ..< 20 {
		step(boxes, &now)
	}
	testing.expect_value(t, len(alice.s.backup), 0)
	testing.expect_value(t, len(bob.s.backup), 0)
	for ev in drain(&host.s) {
		_, is_bt := ev.(ksess.Ev_Backup_Target)
		testing.expect(t, !is_bt, "a dedicated authority names no successor")
	}
}

@(test)
resume_run_from_backup :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	// A real run: two entities (one owned by bob), stats on the board.
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	world_bot := Bot{hp = 30, x = 3}
	wid := ksess.session_spawn(&host.s, BOT_TYPE, &world_bot, &bot_command_set)
	pawn := Bot{hp = 10, x = 1}
	pid := ksess.session_spawn(&host.s, BOT_TYPE, &pawn, &bot_command_set, owner = bob.s.me)
	ksess.session_start_replicating(&host.s)

	kills := ksess.session_stat_column(&host.s, "kills")
	ksess.session_stat_set(&host.s, bob.s.me, kills, 9)
	world_bot.hp = 21 // post-spawn mutation: the backup must carry CURRENT state
	// The game's own campaign state rides every backup (the kit/save split).
	ksess.session_set_backup_blob(&host.s, nil, proc(user: rawptr, w: ^knet.Writer) {
		knet.write_u64(w, 0xCAFE)
	})

	now := 50.0
	for _ in 0 ..< 10 {
		step(boxes, &now)
	}
	testing.expect(t, len(alice.s.backup) > 0)

	// THE HOST DIES. Alice's game splits the backup into the campaign blob
	// and the snapshot, and resumes the run as the new host.
	game_blob, snap, pok := ksess.session_backup_parts(&alice.s) // copies — safe across the re-init
	testing.expect(t, pok, "the backup payload must split")
	br := knet.reader_make(game_blob)
	testing.expect_value(t, knet.read_u64(&br), u64(0xCAFE)) // the game's bytes round-trip
	old_me := alice.s.me

	host2: Peer_Box
	box_make(&host2, 1)
	defer box_destroy(&host2)
	testing.expect(t, ksess.session_host_resume(&host2.s, old_me, "alice", snap))

	// The roster survived: 3 players, only alice connected; identity table
	// intact for everyone who ever JOINed (the dead host has no token — v1).
	testing.expect_value(t, ksess.session_count(&host2.s, connected_only = false, players_only = false), 3)
	testing.expect_value(t, ksess.session_count(&host2.s, connected_only = true), 1)
	me, _ := ksess.session_player(&host2.s, old_me)
	testing.expect(t, me.connected && me.peer == ksess.HOST_PEER)

	// The world survived, through HER factory, with post-mutation values.
	rebot := host2.bots[wid]
	testing.expect(t, rebot != nil, "resume must recreate entities")
	testing.expect_value(t, rebot.hp, i32(21))
	k2, kfound := ksess.session_stat_find(&host2.s, "kills")
	testing.expect(t, kfound)
	testing.expect_value(t, ksess.session_stat(&host2.s, bob.s.me, k2), i64(9))

	// Bob rejoins the RESUMED run with his old token: same id, his stats, and
	// his OWNED pawn back under his authority — streams flow again.
	bob2: Peer_Box
	box_make(&bob2, 500)
	defer box_destroy(&bob2)
	ksess.session_client_start(&bob2.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob2.s)
	boxes2 := []^Peer_Box{&host2, &bob2}
	pump(boxes2)

	testing.expect_value(t, bob2.s.me, bob.s.me) // identity reclaimed across HOSTS
	repawn := bob2.bots[pid]
	testing.expect(t, repawn != nil)
	e, _ := knet.registry_get(&bob2.s.reg, pid)
	testing.expect_value(t, e.owner, bob2.s.me)
	bk, _ := ksess.session_stat_find(&bob2.s, "kills")
	testing.expect_value(t, ksess.session_stat(&bob2.s, bob2.s.me, bk), i64(9))

	repawn.x = 42
	step(boxes2, &now)
	step(boxes2, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host2.s, 0.0, now)
	rpawn := host2.bots[pid]
	testing.expect(t, rpawn != nil)
	testing.expect_value(t, rpawn.x, f32(42)) // owner streams flow to the NEW host

	// Allocation cursors came through: nothing collides.
	fresh := Bot{hp = 1}
	nid := ksess.session_spawn(&host2.s, BOT_TYPE, &fresh, &bot_command_set)
	testing.expect(t, nid != wid && nid != pid)
	testing.expect(t, host2.s.next_player > bob.s.me)
}


// ---- moderation: kick / ban / the door -----------------------------------------

@(test)
kick_with_ban_shuts_the_door :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)
	drain(&host.s)
	drain(&alice.s)
	drain(&bob.s)

	// Kick bob WITH a ban: he learns it was deliberate, alice sees an
	// ordinary departure, and the host gets the seat back to sever.
	was, ok := ksess.session_kick(&host.s, 3, ban = true)
	testing.expect(t, ok)
	testing.expect_value(t, was, ksess.Peer_Id(200))
	pump(boxes)

	bev := drain(&bob.s)
	testing.expect_value(t, len(bev), 1)
	_, kicked := bev[0].(ksess.Ev_Kicked)
	testing.expect(t, kicked, "the target hears a deliberate removal, not a mystery")
	testing.expect(t, !bob.s.joined)

	aev := drain(&alice.s)
	testing.expect_value(t, len(aev), 1)
	l, _ := aev[0].(ksess.Ev_Player_Left)
	testing.expect_value(t, l.id, knet.Player_Id(3))
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true), 2)

	// The banned token bounces — NEW process, NEW peer, same identity.
	bob2: Peer_Box
	box_make(&bob2, 300)
	defer box_destroy(&bob2)
	ksess.session_client_start(&bob2.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob2.s)
	pump([]^Peer_Box{&host, &alice, &bob2})

	dev := drain(&bob2.s)
	testing.expect_value(t, len(dev), 1)
	d, denied := dev[0].(ksess.Ev_Join_Denied)
	testing.expect(t, denied)
	testing.expect_value(t, d.reason, ksess.Deny_Reason.Banned)
	testing.expect(t, !bob2.s.joined)
	testing.expect_value(t, bob2.s.join_waited, -1) // a deliberate no disarms the timeout
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true), 2)

	// Kicking the departed (or yourself) is a no, not a crash.
	_, again := ksess.session_kick(&host.s, 3)
	testing.expect(t, !again)
	_, self_kick := ksess.session_kick(&host.s, 1)
	testing.expect(t, !self_kick)
}

// The DOOR survives a takeover: bans and the lock ride the re-hostable
// snapshot. Without them, a kicked-with-ban player just waited for the host
// to die and walked back into the resumed run.
@(test)
ban_and_lock_survive_resume :: proc(t: ^testing.T) {
	host, bob: Peer_Box
	box_make(&host, 1)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	_, kicked := ksess.session_kick(&host.s, 2, ban = true)
	testing.expect(t, kicked)
	pump(boxes)
	ksess.session_set_locked(&host.s, true)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksess.session_snapshot(&host.s, &w)

	host2: Peer_Box
	box_make(&host2, 1)
	defer box_destroy(&host2)
	testing.expect(t, ksess.session_host_resume(&host2.s, 1, "hosty", knet.writer_bytes(&w)))
	testing.expect(t, host2.s.locked, "the lock rode the snapshot")

	// The banned token bounces off the RESUMED host.
	bob2: Peer_Box
	box_make(&bob2, 300)
	defer box_destroy(&bob2)
	ksess.session_client_start(&bob2.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob2.s)
	pump([]^Peer_Box{&host2, &bob2})
	dev := drain(&bob2.s)
	testing.expect_value(t, len(dev), 1)
	d, denied := dev[0].(ksess.Ev_Join_Denied)
	testing.expect(t, denied)
	testing.expect_value(t, d.reason, ksess.Deny_Reason.Banned)

	// A stranger hits the surviving lock (bans check first; the lock is next).
	carol: Peer_Box
	box_make(&carol, 400)
	defer box_destroy(&carol)
	ksess.session_client_start(&carol.s, u64(0xCA401), "carol")
	ksess.session_client_join(&carol.s)
	pump([]^Peer_Box{&host2, &carol})
	cev := drain(&carol.s)
	testing.expect_value(t, len(cev), 1)
	c, cden := cev[0].(ksess.Ev_Join_Denied)
	testing.expect(t, cden)
	testing.expect_value(t, c.reason, ksess.Deny_Reason.Locked)
}

@(test)
locked_and_full_doors_spare_returning_seats :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)

	ksess.session_configure(&host.s, {max_players = 2})
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	drain(&host.s)
	drain(&alice.s)

	// Room for 2, 2 seated: bob bounces off .Full.
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{&host, &alice, &bob})
	bev := drain(&bob.s)
	testing.expect_value(t, len(bev), 1)
	d, _ := bev[0].(ksess.Ev_Join_Denied)
	testing.expect_value(t, d.reason, ksess.Deny_Reason.Full)

	// The host locks the door; even a freed seat refuses NEW identities...
	ksess.session_peer_disconnected(&host.s, 100)
	ksess.session_set_locked(&host.s, true)
	pump([]^Peer_Box{&host})
	drain(&host.s)
	carol: Peer_Box
	box_make(&carol, 300)
	defer box_destroy(&carol)
	ksess.session_client_start(&carol.s, u64(0xCA401), "carol")
	ksess.session_client_join(&carol.s)
	pump([]^Peer_Box{&host, &carol})
	cev := drain(&carol.s)
	testing.expect_value(t, len(cev), 1)
	dl, _ := cev[0].(ksess.Ev_Join_Denied)
	testing.expect_value(t, dl.reason, ksess.Deny_Reason.Locked)

	// ...but alice's RETURN passes the lock — her seat is her own.
	alice2: Peer_Box
	box_make(&alice2, 400)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})
	testing.expect(t, alice2.s.joined, "a rejoin passes the locked door")
	testing.expect_value(t, alice2.s.me, knet.Player_Id(2))
}


// ---- ownership transfer ---------------------------------------------------------

@(test)
ownership_transfer_hands_the_stream_over :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)
	drain(&host.s)
	drain(&alice.s)
	drain(&bob.s)

	hbot := Bot{hp = 10, x = 1}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set, owner = alice.s.me)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	abot := alice.bots[id]
	bbot := bob.bots[id]
	drain(&host.s)
	drain(&alice.s)
	drain(&bob.s)
	now := 100.0

	// Alice owns the streamed x: her writes reach the host AND bob.
	abot.x = 10
	step(boxes, &now)
	abot.x = 20
	step(boxes, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	_, _ = ksess.session_tick(&bob.s, 0.0, now)
	testing.expect_value(t, hbot.x, f32(20))
	testing.expect_value(t, bbot.x, f32(20))

	// THE HANDOFF: bob carries it now. Every peer hears the same transfer.
	ksess.session_set_owner(&host.s, id, bob.s.me)
	pump(boxes)
	for b in boxes {
		evs := drain(&b.s)
		changed := false
		for ev in evs {
			if oc, ok := ev.(ksess.Ev_Owner_Changed); ok {
				changed = oc.id == id && oc.owner == bob.s.me && oc.prev == alice.s.me
			}
		}
		testing.expect(t, changed, "every peer must hear the handoff")
	}
	testing.expect_value(t, ksess.session_owner_of(&alice.s, id), bob.s.me)

	// The OLD owner's writes now go nowhere — she no longer streams it.
	abot.x = 55
	step(boxes, &now)
	step(boxes, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, hbot.x, f32(20))

	// The NEW owner's writes drive every other screen — the host's, and the
	// old owner's own copy (she samples now, like any remote).
	bbot.x = 77
	step(boxes, &now)
	bbot.x = 78
	step(boxes, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	_, _ = ksess.session_tick(&alice.s, 0.0, now)
	testing.expect_value(t, hbot.x, f32(78))
	testing.expect_value(t, abot.x, f32(78))

	// And back to NOBODY: it rests where the last owner left it.
	ksess.session_set_owner(&host.s, id, knet.PLAYER_ID_INVALID)
	pump(boxes)
	bbot.x = 99
	step(boxes, &now)
	now += 1.0
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, hbot.x, f32(78))
}


@(test)
succession_names_the_torch_bearer_ahead_of_need :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	hbot := Bot{hp = 10}
	_ = ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	now := 50.0
	for _ in 0 ..< 12 { // let a backup ship and the target event fire
		step(boxes, &now)
	}

	// The host learns WHO holds the backup, computes the rendezvous, names it.
	named := knet.PLAYER_ID_INVALID
	for ev in drain(&host.s) {
		if bt, ok := ev.(ksess.Ev_Backup_Target); ok {
			named = bt.player
		}
	}
	testing.expect_value(t, named, alice.s.me) // the eldest client
	ksess.session_set_successor_info(&host.s, {1, 2, 7})
	pump(boxes)

	// EVERY peer holds the answer before the lights go out.
	for b in ([]^Peer_Box{&alice, &bob}) {
		succ, info := ksess.session_successor(&b.s)
		testing.expect_value(t, succ, alice.s.me)
		testing.expect_value(t, len(info), 3)
		testing.expect_value(t, info[2], u8(7))
	}
	drain(&alice.s)
	drain(&bob.s)

	// The host dies. Both clients hear the succession alongside host-left.
	ksess.session_peer_disconnected(&alice.s, ksess.HOST_PEER)
	ksess.session_peer_disconnected(&bob.s, ksess.HOST_PEER)
	for b in ([]^Peer_Box{&alice, &bob}) {
		evs := drain(&b.s)
		heard := false
		for ev in evs {
			if sc, ok := ev.(ksess.Ev_Succession); ok {
				heard = sc.successor == alice.s.me
			}
		}
		testing.expect(t, heard, "the succession must fire with the host-left")
	}
}


@(test)
change_events_name_the_dirty_entity :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	// Opt in on BOTH roles (pre-start wiring, like everything).
	ksess.session_configure(&host.s, {change_events = true})
	ksess.session_configure(&alice.s, {change_events = true})
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	hbot := Bot{hp = 10}
	quiet := Bot{hp = 5}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set)
	_ = ksess.session_spawn(&host.s, BOT_TYPE, &quiet, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	drain(&host.s)
	drain(&alice.s)
	now := 50.0

	// One entity changes; BOTH roles hear exactly that one, by id.
	hbot.hp = 9
	step(boxes, &now)
	for b in boxes {
		evs := drain(&b.s)
		hits := 0
		for ev in evs {
			if ch, ok := ev.(ksess.Ev_Entity_Changed); ok {
				testing.expect_value(t, ch.id, id)
				hits += 1
			}
		}
		testing.expect_value(t, hits, 1)
	}

	// A quiet tick emits none.
	step(boxes, &now)
	for b in boxes {
		for ev in drain(&b.s) {
			if _, ok := ev.(ksess.Ev_Entity_Changed); ok {
				testing.expect(t, false, "no change, no event")
			}
		}
	}
}

@(test)
world_time_is_the_hosts_clock_everywhere :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	now := 100.0
	for _ in 0 ..< 30 { // let pings and pongs flow both ways
		step(boxes, &now)
	}
	testing.expect(t, alice.s.pongs > 0, "the clock must be warm")
	testing.expect_value(t, ksess.session_world_time(&host.s), host.s.now)
	// In-box transport has zero latency: the shared timeline agrees tightly.
	dt := ksess.session_world_time(&alice.s) - host.s.now
	testing.expect(t, abs(dt) < 0.01, "world time must track the host's clock")
}

// ---- entity blobs: variable-length state that new observers must see -----------

@(test)
entity_blobs_ride_change_join_and_backup :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	hbot := Bot{hp = 10}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set)

	// Set before the world goes live: the host hears its own event...
	ksess.session_set_blob(&host.s, id, transmute([]u8)string("rune-1"))
	saw := false
	for ev in drain(&host.s) {
		if b, ok := ev.(ksess.Ev_Blob_Changed); ok && b.id == id && b.size == 6 {
			saw = true
		}
	}
	testing.expect(t, saw, "the host reacts to its own blob like any peer")

	// ...and a client that has never seen the entity gets the blob WITH the
	// world — spawn first, then the blob event, no catch-up code anywhere.
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	spawn_at, blob_at := -1, -1
	for ev, i in drain(&alice.s) {
		#partial switch e in ev {
		case ksess.Ev_Spawned:
			if e.id == id {spawn_at = i}
		case ksess.Ev_Blob_Changed:
			if e.id == id {blob_at = i}
		}
	}
	testing.expect(t, spawn_at >= 0 && blob_at > spawn_at, "join carry: blob event lands after the spawn")
	testing.expect_value(t, string(ksess.session_blob(&alice.s, id)), "rune-1")

	// A mid-run change ships reliably on its own.
	ksess.session_set_blob(&host.s, id, transmute([]u8)string("rune-2 with more to say"))
	pump(boxes)
	saw = false
	for ev in drain(&alice.s) {
		if b, ok := ev.(ksess.Ev_Blob_Changed); ok && b.id == id {
			saw = true
		}
	}
	testing.expect(t, saw)
	testing.expect_value(t, string(ksess.session_blob(&alice.s, id)), "rune-2 with more to say")

	// The blob rides the backup: a resumed host holds it without any game code.
	now := 50.0
	for _ in 0 ..< 10 {
		step(boxes, &now)
	}
	testing.expect(t, len(alice.s.backup) > 0)
	_, snap, pok := ksess.session_backup_parts(&alice.s)
	testing.expect(t, pok)
	host2: Peer_Box
	box_make(&host2, 1)
	defer box_destroy(&host2)
	testing.expect(t, ksess.session_host_resume(&host2.s, alice.s.me, "alice", snap))
	testing.expect_value(t, string(ksess.session_blob(&host2.s, id)), "rune-2 with more to say")
}

// ---- session_present: the two-timelines discipline in one call -----------------

@(private = "file")
Present_Log :: struct {
	shown: [dynamic]u64,
}

@(private = "file")
present_show :: proc(user: rawptr, id: knet.Net_Id, a: u64) {
	l := cast(^Present_Log)user
	append(&l.shown, a)
}

@(test)
present_now_for_mine_render_delayed_for_theirs :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")

	log: Present_Log
	defer delete(log.shown)

	now := 100.0
	_, _ = ksess.session_tick(&host.s, 0.05, now)

	// MY simulation caused it: shown synchronously, nothing queued.
	ksess.session_present(&host.s, true, &log, present_show, a = 1)
	testing.expect_value(t, len(log.shown), 1)

	// Someone else's: queued for the render timeline (now + interp_delay).
	ksess.session_present(&host.s, false, &log, present_show, a = 2)
	testing.expect_value(t, len(log.shown), 1)

	// A tick just BEFORE the render clock arrives: still pending.
	now += host.s.interp_delay - 0.01
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, len(log.shown), 1)

	// ...and on it: shown by the session's own drain.
	now += 0.02
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, len(log.shown), 2)
	testing.expect_value(t, log.shown[1], u64(2))

	// `extra` stacks on top — the authority's lingering despawn.
	ksess.session_present(&host.s, false, &log, present_show, a = 3, extra = 1.0)
	now += host.s.interp_delay + 0.5
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, len(log.shown), 2) // interp alone is not enough
	now += 0.6
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, len(log.shown), 3)

	// A restart drops pending presentations (they were the old run's world).
	ksess.session_present(&host.s, false, &log, present_show, a = 4)
	ksess.session_host_start(&host.s, "hosty2")
	now += 10
	_, _ = ksess.session_tick(&host.s, 0.0, now)
	testing.expect_value(t, len(log.shown), 3)
}

// ---- interest management (interest.odin) ---------------------------------------
//
// "Existence global, freshness local": spawns reach everyone; per-tick state
// only reaches peers whose FOCUS is near. The locator lends the session eyes
// (Bot.x doubles as the position).

bot_locate :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) -> (x, y: f32, always: bool) {
	b := cast(^Bot)entity
	return b.x, 0, false
}

@(test)
interest_filters_deltas_and_resyncs_on_entry :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}
	now := f64(1000)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_set_interest(&host.s, 300, 50, nil, bot_locate)
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	ksess.session_start_replicating(&host.s)

	near := Bot{hp = 10, x = 100}
	far := Bot{hp = 20, x = 1000}
	idn := ksess.session_spawn(&host.s, BOT_TYPE, &near, &bot_command_set)
	idf := ksess.session_spawn(&host.s, BOT_TYPE, &far, &bot_command_set)
	pump(boxes)

	// EXISTENCE is global: alice materialized both, fields intact.
	testing.expect_value(t, len(alice.bots), 2)
	testing.expect_value(t, alice.bots[idf].hp, i32(20))

	// Alice stands by the near bot; the far one goes quiet for her.
	ksess.session_set_focus(&host.s, 2, 100, 0)
	step(boxes, &now)
	near.hp = 11
	far.hp = 21
	step(boxes, &now)
	testing.expect_value(t, alice.bots[idn].hp, i32(11)) // fresh: in interest
	testing.expect_value(t, alice.bots[idf].hp, i32(20)) // STALE: filtered

	// She walks over to the far one: the ENTER resync delivers everything
	// she missed — the delta that was never sent is not lost truth. The
	// catch-up announces itself as Ev_Resynced (NOT a second Ev_Spawned:
	// the entity was never gone here) — the game's cue to re-seed edge
	// scratch, or the missed wounds present as fresh hits.
	drain(&alice.s)
	ksess.session_set_focus(&host.s, 2, 1000, 0)
	step(boxes, &now)
	testing.expect_value(t, alice.bots[idf].hp, i32(21)) // caught up whole
	resynced, respawned := false, false
	for ev in drain(&alice.s) {
		if r, is_r := ev.(ksess.Ev_Resynced); is_r && r.id == idf {resynced = true}
		if sp, is_s := ev.(ksess.Ev_Spawned); is_s && sp.id == idf {respawned = true}
	}
	testing.expect(t, resynced, "re-entry must announce itself as Ev_Resynced")
	testing.expect(t, !respawned, "re-entry must not re-fire Ev_Spawned")
	near.hp = 12
	step(boxes, &now)
	testing.expect_value(t, alice.bots[idn].hp, i32(11)) // now THIS one is stale

	// Hysteresis: standing at the edge, the set doesn't flicker. The far bot
	// sits at x=1000 and alice at 1000-320: outside enter radius (300), so a
	// FRESH peer wouldn't see it — but alice is IN (from the visit) and 320 <
	// 300+50 keeps her in.
	ksess.session_set_focus(&host.s, 2, 680, 0)
	far.hp = 22
	step(boxes, &now)
	testing.expect_value(t, alice.bots[idf].hp, i32(22)) // exit edge holds her in
}

// Flipping interest ON mid-run must re-declare stream routing to clients
// seated BEFORE the flip — their welcome said broadcast, and without SES_AOI
// they kept broadcasting owner streams unfiltered forever.
@(test)
aoi_flip_mid_run_rewires_streams :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	testing.expect(t, !alice.s.aoi_client, "no interest at join: streams broadcast")

	ksess.session_set_interest(&host.s, 300, 50, nil, bot_locate)
	pump(boxes)
	testing.expect(t, alice.s.aoi_client, "the mid-run flip re-declared routing")

	ksess.session_set_interest(&host.s, 0, 0, nil, nil)
	pump(boxes)
	testing.expect(t, !alice.s.aoi_client, "and the flip back re-declares again")
}

@(test)
interest_streams_route_via_host_and_filter :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}
	now := f64(1000)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_set_interest(&host.s, 300, 50, nil, bot_locate)
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)
	testing.expect(t, alice.s.aoi_client, "the welcome routes alice's streams via the host")
	ksess.session_start_replicating(&host.s)

	// Alice owns a streaming bot at the origin; bob watches from far away.
	pawn := Bot{hp = 5, x = 0}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &pawn, &bot_command_set, owner = alice.s.me)
	pump(boxes)
	abot := alice.bots[id]
	bbot := bob.bots[id]
	ksess.session_set_focus(&host.s, 2, 0, 0) // alice: near her own pawn
	ksess.session_set_focus(&host.s, 3, 5000, 0) // bob: far away
	step(boxes, &now)

	// Alice strolls; her samples reach the HOST (it owns the routing) but
	// never bob — his copy of the stream field stays exactly at spawn.
	for _ in 0 ..< 10 {
		abot.x += 3
		step(boxes, &now)
	}
	testing.expect(t, host.s.reg.entries[id].entity != nil && (cast(^Bot)host.s.reg.entries[id].entity).x > 0, "the host heard the stream")
	testing.expect_value(t, bbot.x, f32(0)) // filtered: not one sample

	// Bob wanders over: the resync snaps the pawn to truth and the stream
	// starts flowing (absolute samples — no special stream catch-up needed).
	ksess.session_set_focus(&host.s, 3, abot.x, 0)
	before := abot.x
	for _ in 0 ..< 8 {
		abot.x += 3
		step(boxes, &now)
	}
	testing.expect(t, bbot.x >= before, "bob's copy moves again after re-entry")
}

// ---- per-type hook routing -------------------------------------------------------

Hook_Log :: struct {
	calls: [dynamic]u64, // (entity << 16 | cmd) per firing — order preserved; cmd is a full hash-sized u16
}

log_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	l := cast(^Hook_Log)user
	if ok {append(&l.calls, u64(entity) << 16 | u64(cmd))}
}

@(test)
type_hooks_route_and_catch_all_falls_back :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}
	now := f64(1000)

	typed, general: Hook_Log
	defer delete(typed.calls)
	defer delete(general.calls)
	ksess.session_set_command_hook(&host.s, &general, log_hook)
	ksess.session_set_type_hook(&host.s, BOT_TYPE, &typed, log_hook)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	ksess.session_start_replicating(&host.s)

	bot := Bot{hp = 10}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &bot, &bot_command_set)
	stranger := Bot{hp = 10}
	sid := ksess.session_spawn(&host.s, UNKNOWN_TYPE, &stranger, &bot_command_set)
	pump(boxes)

	// A CLIENT's command on the routed type fires the TYPE hook, not the
	// catch-all — the wrong-classification bug is structurally impossible.
	abot := alice.bots[id]
	knet.command_begin(&alice.s.ctx, id, BOT_HIT)
	knet.write_i32(&alice.s.ctx.msg, 3)
	testing.expect(t, knet.command_issue(&alice.s.ctx, abot, &bot_command_set, BOT_HIT))
	step(boxes, &now)
	testing.expect_value(t, len(typed.calls), 1)
	testing.expect_value(t, typed.calls[0], u64(id) << 16 | u64(BOT_HIT))
	testing.expect_value(t, len(general.calls), 0)

	// The HOST's own local issue routes identically (one dispatcher).
	hbot := cast(^Bot)host.s.reg.entries[id].entity
	_ = hbot
	// (games use the generated wrapper; the raw authority path is invoke+hook)
	r := knet.reader_make([]u8{3, 0, 0, 0})
	env := knet.Command_Env{authority = true, by = host.s.me}
	_ = bot_cmd_hit(host.s.reg.entries[id].entity, &r, &env)
	knet.command_hook_local(&host.s.ctx, id, BOT_HIT, true)
	testing.expect_value(t, len(typed.calls), 2)

	// An UNROUTED type falls back to the catch-all.
	if e, ok := host.s.reg.entries[sid]; ok {
		_ = e
		knet.command_hook_local(&host.s.ctx, sid, BOT_HIT, true)
	}
	testing.expect_value(t, len(general.calls), 1)
	testing.expect_value(t, general.calls[0], u64(sid) << 16 | u64(BOT_HIT))
}

// ---- kcombat fire routing over SES_APP -------------------------------------------

@(test)
fire_listen_routes_to_other_screens_only :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	TAG :: u8(7)
	hroute, aroute, broute: kcombat.Fire_Route
	defer kcombat.fire_route_destroy(&hroute)
	defer kcombat.fire_route_destroy(&aroute)
	defer kcombat.fire_route_destroy(&broute)
	kcombat.fire_listen(&hroute, &host.s, TAG)
	kcombat.fire_listen(&aroute, &alice.s, TAG)
	kcombat.fire_listen(&broute, &bob.s, TAG)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	// The host confirms alice's cast and announces it: BOB polls it out
	// (payload intact); ALICE skips her own echo (she drew at cast time);
	// the HOST skips (its screen drew at launch). Nothing fires mid-pump —
	// the queue holds until each game's own drain.
	f := kcombat.Fire{shooter = 2, origin = {10, 20, 0}, vel = {3, 0, 0}, ttl = 30, kind = 1}
	kcombat.fire_announce(&host.s, f, TAG)
	pump(boxes)
	bf, drew := kcombat.fire_poll(&broute)
	testing.expect(t, drew, "bob draws the announced fire")
	testing.expect_value(t, bf.shooter, knet.Player_Id(2))
	testing.expect_value(t, bf.ttl, u16(30))
	testing.expect_value(t, bf.origin.x, f32(10))
	_, extra := kcombat.fire_poll(&broute)
	testing.expect(t, !extra, "one announcement, one fire")
	_, aecho := kcombat.fire_poll(&aroute)
	testing.expect(t, !aecho, "alice skips her own echo")
	_, hecho := kcombat.fire_poll(&hroute)
	testing.expect(t, !hecho, "the host's screen drew at launch")

	// A CLIENT trying to author a fire reaches no other screen. The
	// announce wrapper asserts against the attempt now, so the spoof takes
	// the RAW path a real cheater would — hand-framed bytes on the tag —
	// and the receiver guard (the security boundary) drops it everywhere.
	w := ksess.session_app_begin(&alice.s, TAG)
	kcombat.fire_write(w, f)
	ksess.session_app_flush(&alice.s, ksess.BROADCAST_PEER)
	pump(boxes)
	_, spoofed := kcombat.fire_poll(&broute)
	testing.expect(t, !spoofed, "a client's announcement is dropped by every receiver")
	_, hspoof := kcombat.fire_poll(&hroute)
	testing.expect(t, !hspoof)

	// The session's tick clock is the ticker's own count, exposed.
	before := ksess.session_tick_no(&host.s)
	now := f64(1000)
	step(boxes, &now)
	testing.expect(t, ksess.session_tick_no(&host.s) > before, "the tick clock advances")
}

// ---------------------------------------------------------------------------
// The VERSION door: Session_Config.fingerprint rides SES_JOIN, and the host
// refuses a build whose wire contract disagrees — with a sentence (.Version),
// not garbage-field deltas. Unchecked (0) opts out on either end.

@(test)
version_skew_is_denied_at_the_door :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)

	ksess.session_configure(&host.s, {fingerprint = 0xF00D})
	ksess.session_host_start(&host.s, "hosty")

	// The same build: welcomed like any other day.
	ksess.session_configure(&alice.s, {fingerprint = 0xF00D})
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	testing.expect(t, alice.s.joined, "a matching fingerprint joins as ever")

	// A skewed build: denied with the reason, join timeout disarmed.
	ksess.session_configure(&bob.s, {fingerprint = 0xBAD})
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{&host, &alice, &bob})
	bev := drain(&bob.s)
	testing.expect_value(t, len(bev), 1)
	d, denied := bev[0].(ksess.Ev_Join_Denied)
	testing.expect(t, denied)
	testing.expect_value(t, d.reason, ksess.Deny_Reason.Version)
	testing.expect(t, !bob.s.joined)
	testing.expect_value(t, bob.s.join_waited, -1)

	// A PRE-FINGERPRINT build (its JOIN ends at the name): the checked host
	// reads the missing tail as "no fingerprint" and refuses it the same way.
	carol: Peer_Box
	box_make(&carol, 300)
	defer box_destroy(&carol)
	ksess.session_client_start(&carol.s, u64(0xCA401), "carol")
	{
		w := knet.writer_make(64, context.temp_allocator)
		knet.write_u8(&w, 0) // SES_JOIN — the kind's wire value, pinned
		knet.write_u64(&w, u64(0xCA401))
		knet.write_string(&w, "carol")
		r := knet.reader_make(knet.writer_bytes(&w))
		ksess.session_handle_packet(&host.s, 300, &r)
	}
	pump([]^Peer_Box{&host, &carol})
	cev := drain(&carol.s)
	testing.expect_value(t, len(cev), 1)
	dl, _ := cev[0].(ksess.Ev_Join_Denied)
	testing.expect_value(t, dl.reason, ksess.Deny_Reason.Version)

	// The roster never grew past the matching build.
	testing.expect_value(t, ksess.session_count(&host.s), 2)
}

@(test)
unchecked_fingerprint_opts_out :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	// Host opts OUT on purpose (FINGERPRINT_NONE — with a generated default
	// registered, 0 means "use it", so the deliberate no-gate needs the
	// sentinel): a checked client still seats — the authority owns the door,
	// and an unchecked authority holds it open.
	ksess.session_configure(&host.s, {fingerprint = ksess.FINGERPRINT_NONE})
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_configure(&alice.s, {fingerprint = 0xBEEF})
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	testing.expect(t, alice.s.joined, "an unchecked host accepts any build")
}

@(test)
default_fingerprint_gates_without_wiring :: proc(t: ^testing.T) {
	// The generated guard file registers NET_FINGERPRINT as the session
	// default at load — games wire nothing and the version door is closed.
	// Pin the fallthrough: cfg 0 means "use the default" (the package @(init)
	// above set 0xF00D, load-time like production), an explicit value still
	// overrides, and FINGERPRINT_NONE opts out on purpose.
	host, alice, bob, carol: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	box_make(&carol, 300)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	defer box_destroy(&carol)

	ksess.session_host_start(&host.s, "hosty") // cfg 0: gates on the default
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice") // cfg 0: same build
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	testing.expect(t, alice.s.joined, "two default-fingerprint builds seat with zero wiring")

	ksess.session_configure(&bob.s, {fingerprint = 0xBAD}) // an override still overrides
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{&host, &bob})
	bev := drain(&bob.s)
	testing.expect_value(t, len(bev), 1)
	d, denied := bev[0].(ksess.Ev_Join_Denied)
	testing.expect(t, denied)
	testing.expect_value(t, d.reason, ksess.Deny_Reason.Version)

	// FINGERPRINT_NONE: the client OPTS OUT — and the checked host refuses a
	// fingerprint-less build the same way it always has.
	ksess.session_configure(&carol.s, {fingerprint = ksess.FINGERPRINT_NONE})
	ksess.session_client_start(&carol.s, u64(0xCA401), "carol")
	ksess.session_client_join(&carol.s)
	pump([]^Peer_Box{&host, &carol})
	cev := drain(&carol.s)
	testing.expect_value(t, len(cev), 1)
	dc, _ := cev[0].(ksess.Ev_Join_Denied)
	testing.expect_value(t, dc.reason, ksess.Deny_Reason.Version)
}

@(test)
profiles_declare_echo_and_catchup :: proc(t: ^testing.T) {
	// The typed per-player PROFILE (profile.odin): my row echoes locally this
	// instant, the auto-declare ships it, the host relays the table, and a
	// late joiner catches the lot behind her welcome — the lobby machinery
	// every game rebuilt on stat columns, as one POD struct per seat.
	Pick :: struct {
		look:  u8,
		ready: bool,
	}
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_profile_install(&host.s, Pick)
	ksess.session_profile_install(&alice.s, Pick)
	ksess.session_profile_install(&bob.s, Pick)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)
	drain(&host.s); drain(&alice.s); drain(&bob.s)
	now := 100.0

	// LOCAL ECHO: my write reads back this instant — no round trip, no cadence.
	mine := ksess.session_profile_mine(&alice.s, Pick)
	mine.look = 3
	mine.ready = true
	got, gok := ksess.session_profile_of(&alice.s, alice.s.me, Pick)
	testing.expect(t, gok, "my row exists the moment I write it")
	testing.expect_value(t, got.look, u8(3))

	// The auto-declare ships on the next net tick; the relay rides the
	// low-rate (stats-cadence) block — give it half a second of ticks.
	for _ in 0 ..< 12 {step(boxes, &now)}
	hv, hok := ksess.session_profile_of(&host.s, alice.s.me, Pick)
	testing.expect(t, hok, "the declare landed on the host")
	testing.expect_value(t, hv.look, u8(3))
	testing.expect(t, hv.ready, "the whole row rode one declare")
	heard := false
	for ev in drain(&host.s) {
		if pc, k := ev.(ksess.Ev_Profile_Changed); k && pc.player == alice.s.me {
			heard = true
		}
	}
	testing.expect(t, heard, "the host heard the view change")
	bv, bok := ksess.session_profile_of(&bob.s, alice.s.me, Pick)
	testing.expect(t, bok, "the relay reached the third screen")
	testing.expect_value(t, bv.look, u8(3))

	// The HOST's own row rides the same lane (its word IS the relay).
	ksess.session_profile_mine(&host.s, Pick).look = 7
	for _ in 0 ..< 12 {step(boxes, &now)}
	av, aok := ksess.session_profile_of(&alice.s, host.s.me, Pick)
	testing.expect(t, aok, "the host's row reached the clients")
	testing.expect_value(t, av.look, u8(7))

	// LATE JOINER: the whole table rides behind her welcome, no cadence wait.
	carol: Peer_Box
	box_make(&carol, 300)
	defer box_destroy(&carol)
	ksess.session_profile_install(&carol.s, Pick)
	ksess.session_client_start(&carol.s, u64(0xCA401), "carol")
	ksess.session_client_join(&carol.s)
	all := []^Peer_Box{&host, &alice, &bob, &carol}
	pump(all)
	cv, cok := ksess.session_profile_of(&carol.s, alice.s.me, Pick)
	testing.expect(t, cok, "the joiner caught the table behind her welcome")
	testing.expect_value(t, cv.look, u8(3))
	testing.expect(t, cv.ready)
}

@(test)
profile_table_scopes_to_the_run :: proc(t: ^testing.T) {
	// The rehost/re-declare hole: profile rows are RUN state. A back-to-lobby
	// rehost must not relay the dead run's rows under recycled seats, and a
	// client whose row is UNCHANGED since the last run must still re-declare
	// to a NEW host — the declare shadow dies with the run (and again at
	// every join), or the diff eats the declare and the row stays invisible
	// all session. host_resume is the one keeper (the heir swaps its table
	// around the re-init); a rejoin re-declares anyway, so even a
	// fresh-session resume repopulates.
	Pick :: struct {
		look:  u8,
		ready: bool,
	}
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_profile_install(&host.s, Pick)
	ksess.session_profile_install(&alice.s, Pick)

	// Run one: alice declares.
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	now := 100.0
	ksess.session_profile_mine(&alice.s, Pick).look = 3
	for _ in 0 ..< 12 {step(boxes, &now)}
	hv, hok := ksess.session_profile_of(&host.s, alice.s.me, Pick)
	testing.expect(t, hok, "run one: the declare landed")
	testing.expect_value(t, hv.look, u8(3))
	old_seat := alice.s.me

	// Back to lobby, RE-HOST: the dead run's rows are gone — a fresh player
	// seated on the recycled id inherits nothing.
	ksess.session_host_start(&host.s, "hosty")
	_, stale := ksess.session_profile_of(&host.s, old_seat, Pick)
	testing.expect(t, !stale, "a rehost relays no dead run's rows")

	// Alice rejoins and writes the SAME row bytes as last run — unchanged
	// state must still reach the new host (a surviving shadow would eat it).
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)
	ksess.session_profile_mine(&alice.s, Pick).look = 3
	for _ in 0 ..< 12 {step(boxes, &now)}
	hv2, hok2 := ksess.session_profile_of(&host.s, alice.s.me, Pick)
	testing.expect(t, hok2, "an unchanged row re-declares to a NEW host")
	testing.expect_value(t, hv2.look, u8(3))
}

@(test)
write_guard_names_a_client_rogue_write :: proc(t: ^testing.T) {
	// THE canonical co-op bug: a client assigns to a host-lane field —
	// compiles, looks right locally, never replicates. The shadow-as-bless
	// invariant turns it into a named finding within one net tick; legal
	// writes (host deltas, coop speculation while pending, owner streams)
	// stay silent. The walk is called directly here — the session turns a
	// finding into the teaching assert, and a pin shouldn't die on it.
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	hbot := Bot{hp = 10, x = 1}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set, owner = alice.s.me)
	ksess.session_start_replicating(&host.s)
	pump(boxes)
	abot := alice.bots[id]
	testing.expect(t, abot != nil, "the factory must have made alice's bot")
	now := 100.0

	// Clean after a legit host delta.
	hbot.hp = 8
	step(boxes, &now)
	_, _, _, dirty := knet.registry_write_guard(&alice.s.reg, &alice.s.ctx)
	testing.expect(t, !dirty, "a host delta blesses the shadow — nothing to flag")

	// Coop speculation is exempt while pending, blessed once it settles.
	knet.command_begin(&alice.s.ctx, id, BOT_HIT)
	knet.write_i32(&alice.s.ctx.msg, 3)
	testing.expect(t, knet.command_issue(&alice.s.ctx, abot, &bot_command_set, BOT_HIT))
	_, _, _, dirty = knet.registry_write_guard(&alice.s.reg, &alice.s.ctx)
	testing.expect(t, !dirty, "an in-flight prediction is legal divergence")
	pump(boxes) // the confirm lands and blesses the speculative bytes
	_, _, _, dirty = knet.registry_write_guard(&alice.s.reg, &alice.s.ctx)
	testing.expect(t, !dirty, "a confirmed prediction blesses on retire")

	// The rogue write: found, naming entity and field.
	abot.hp += 5
	_, field, fid, found := knet.registry_write_guard(&alice.s.reg, &alice.s.ctx)
	testing.expect(t, found, "a client-side host-lane write is a finding")
	testing.expect_value(t, fid, id)
	testing.expect_value(t, field, "field #0") // hand-built desc carries no names

	// Owner-stream fields on the OWNER are never the guard's business.
	abot.hp -= 5 // undo the rogue write
	abot.x = 42  // alice owns the stream
	_, _, _, dirty = knet.registry_write_guard(&alice.s.reg, &alice.s.ctx)
	testing.expect(t, !dirty, "owner-stream fields are the owner's to write")
}

// ---------------------------------------------------------------------------
// The `<field>_edge` halves: NET delta-lane change per frame, on every peer —
// the machinery that replaces hand-rolled seen_* mirrors. Spawn seeds
// silently, coalesced writes fire once, cancelled pulses never fire, and a
// resync (the caught-up spawn tuple) re-seeds without firing.

@(test)
edge_halves_fire_on_net_change :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	hbot := Bot{hp = 10}
	id := ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	now := 0.0
	step(boxes, &now)
	step(boxes, &now)

	// Spawn values are a baseline, not an edge — on both screens.
	testing.expect_value(t, host.edge_fires, 0)
	testing.expect_value(t, alice.edge_fires, 0)

	// Two writes inside one frame: ONE net edge, old 10 -> new 6, host and
	// client alike (the host's own mutations edge — zero role branches).
	hbot.hp = 8
	hbot.hp = 6
	step(boxes, &now)
	testing.expect_value(t, host.edge_fires, 1)
	testing.expect_value(t, host.edge_old, i32(10))
	testing.expect_value(t, host.edge_new, i32(6))
	step(boxes, &now) // alice's delta landed last step; her pass has run by now
	testing.expect_value(t, alice.edge_fires, 1)
	testing.expect_value(t, alice.edge_old, i32(10))
	testing.expect_value(t, alice.edge_new, i32(6))

	// A pulse that cancels within the frame is not a change — and it never
	// even ships (the wire's own shadow agrees).
	hbot.hp = 1
	hbot.hp = 6
	step(boxes, &now)
	step(boxes, &now)
	testing.expect_value(t, host.edge_fires, 1)
	testing.expect_value(t, alice.edge_fires, 1)

	// RESYNC IS SILENT: mutate and re-announce the spawn tuple before any
	// net tick ships the delta — alice catches up wholesale (Ev_Resynced),
	// her mirror re-seeds, and her half stays quiet. The HOST's own screen
	// still edges (its mutation was real gameplay there).
	drain(&alice.s)
	hbot.hp = 3
	ksess.session_spawn_send(&host.s, id)
	pump(boxes)
	resynced := false
	for ev in drain(&alice.s) {
		if _, is := ev.(ksess.Ev_Resynced); is {resynced = true}
	}
	testing.expect(t, resynced, "the redundant tuple lands as a resync")
	step(boxes, &now)
	step(boxes, &now)
	testing.expect_value(t, host.edge_fires, 2) // the host's screen flashed
	testing.expect_value(t, host.edge_new, i32(3))
	testing.expect_value(t, alice.edge_fires, 1) // the catch-up presented NOTHING
}

// session_run_edges: the authority's SAME-FRAME pass — a game tick that
// mutates after the frame's session_tick calls it and the halves fire NOW,
// not next frame; the pass is idempotent, so the automatic one that follows
// re-fires nothing.
@(test)
edge_pass_is_idempotent_and_callable :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)

	ksess.session_host_start(&host.s, "hosty")
	hbot := Bot{hp = 10}
	_ = ksess.session_spawn(&host.s, BOT_TYPE, &hbot, &bot_command_set)
	ksess.session_start_replicating(&host.s)
	ksess.session_run_edges(&host.s) // first sight: seeds silently
	testing.expect_value(t, host.edge_fires, 0)

	// The "post-pump game tick" mutation: fires the SAME frame via the
	// explicit pass, before any session_tick has run.
	hbot.hp = 7
	ksess.session_run_edges(&host.s)
	testing.expect_value(t, host.edge_fires, 1)
	testing.expect_value(t, host.edge_old, i32(10))
	testing.expect_value(t, host.edge_new, i32(7))

	// Idempotent: the automatic pass (or a second call) re-fires nothing.
	ksess.session_run_edges(&host.s)
	now := 0.0
	step([]^Peer_Box{&host}, &now)
	testing.expect_value(t, host.edge_fires, 1)
}

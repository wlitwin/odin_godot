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
import knet "godot:kit/net"
import ksess "godot:kit/session"

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
// network is quiet. `to == BROADCAST_PEER (0)` reaches everyone but the sender,
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
zombie_takeover_same_token :: proc(t: ^testing.T) {
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

	// Alice's machine crashed and reconnected before the old socket timed out:
	// the same token arrives from a new peer while the roster still shows her
	// connected. The new connection takes over; the zombie peer is unmapped.
	alice2: Peer_Box
	box_make(&alice2, 400)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})

	testing.expect_value(t, alice2.s.me, knet.Player_Id(2))
	p, _ := ksess.session_player(&host.s, 2)
	testing.expect_value(t, p.peer, 400)
	testing.expect(t, p.connected)

	// The zombie's eventual transport timeout must NOT mark the player gone —
	// its peer id is no longer mapped to anyone.
	ksess.session_peer_disconnected(&host.s, 100)
	p2, _ := ksess.session_player(&host.s, 2)
	testing.expect(t, p2.connected, "stale peer timeout must not disconnect the taken-over player")
	testing.expect_value(t, len(drain(&host.s)), 1) // only the rejoin event queued
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

bot_cmd_hit :: proc(entity: rawptr, r: ^knet.Reader) -> bool {
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
bot_cmds := [?]knet.Command_Desc{{name = "hit", predict = true, invoke = bot_cmd_hit}}
bot_command_set := knet.Command_Set{entity_desc = &bot_desc, commands = bot_cmds[:]}

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
	knet.command_begin(&alice.s.ctx, id, 0)
	knet.write_i32(&alice.s.ctx.msg, 3)
	testing.expect(t, knet.command_issue(&alice.s.ctx, abot, &bot_command_set, 0))
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
	knet.command_begin(&alice.s.ctx, id, 0)
	knet.write_i32(&alice.s.ctx.msg, 5)
	testing.expect(t, !knet.command_issue(&alice.s.ctx, abot, &bot_command_set, 0))
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
	testing.expect_value(t, kills, ksess.Stat_Col(1)) // 0 is always ping
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
	testing.expect_value(t, ksess.session_count(&host2.s), 3)
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

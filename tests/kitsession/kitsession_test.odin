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
	to:   int,
	data: []u8,
}

Peer_Box :: struct {
	peer:  int,
	s:     ksess.Session,
	out:   [dynamic]Envelope,
	bots:  map[knet.Net_Id]^Bot, // factory-created entities (clients)
	freed: int, // factory frees observed
}

box_send :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make :: proc(b: ^Peer_Box, peer: int) {
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
	testing.expect_value(t, len(aev), 1)
	_, welcomed := aev[0].(ksess.Ev_Welcomed)
	testing.expect(t, welcomed)

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

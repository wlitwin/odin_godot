package kit_arena_test

// THE PHASE-4 INTEGRATION TEST: combat over the full session pipeline
// (in-memory pipe — the wire path minus the socket).
//
//   * A cast is a PREDICTED command on your own avatar: the ability gate
//     (cooldown + stamina) bites instantly on your screen, and the SAME gate
//     refuses the same cast on the host.
//   * The rock itself is not an entity: the host's command hook launches a
//     host-side sim (kit/combat's swept projectile math), and only THAT sim
//     deals damage — peer-owned visuals, host-validated hits.
//   * Damage, the killing blow, death, respawn, the chill wearing off, and
//     the damage/kills/deaths ledger all replicate to every peer through the
//     machinery phases 0-1 built.
//
//   odin test tests/kitarena -collection:godot=$PWD

import "core:testing"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"
import ksess "godot:kit/session"

MAX_HP :: i32(100)
MAX_STAMINA :: i32(10)
ROCK_DMG :: i32(40)
ROCK_SPEED :: f32(30) // per tick
ROCK_TTL :: u16(10)
BODY_RADIUS :: f32(6)
RESPAWN_TICKS :: 8
CHILL :: u8(1)
CHILL_TICKS :: u16(6)

THROW :: kcombat.Ability_Def{name = "throw", cooldown = 5, cost = 3}

Brawler :: struct {
	x, y:    f32, // owner-streamed
	hp:      i32, // replicated
	stamina: i32, // replicated
	cds:     [2]u16, // replicated: ability cooldowns, host-decayed
	fx:      [2]kcombat.Effect, // replicated: status effects, host-decayed
	aim:     [2]f32, // scratch for the throw hook — never on the wire
}

BRAWLER_TYPE :: ksess.Entity_Type(1)
CMD_THROW :: 0 // args: [dx f32][dy f32] — untyped: used as both the hook's raw u16 cmd and a knet.Cmd_Id at issue

// The whole cast, zero role branches: gate, pay, remember the aim.
brawler_cmd_throw :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	b := cast(^Brawler)entity
	dx := knet.read_f32(r)
	dy := knet.read_f32(r)
	if r.err {return false}
	if b.hp <= 0 {return false} // the dead throw nothing
	if dx == 0 && dy == 0 {return false}
	if !kcombat.ability_try(b.cds[:], 0, THROW, &b.stamina) {return false}
	b.aim = {dx, dy}
	return true
}

brawler_fields := [?]knet.Field_Desc {
	{offset = offset_of(Brawler, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
	{offset = offset_of(Brawler, y), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
	{offset = offset_of(Brawler, hp), size = size_of(i32)},
	{offset = offset_of(Brawler, stamina), size = size_of(i32)},
	{offset = offset_of(Brawler, cds), size = size_of([2]u16)},
	{offset = offset_of(Brawler, fx), size = size_of([2]kcombat.Effect)},
}
brawler_desc := knet.Entity_Desc{fields = brawler_fields[:]}
brawler_cmds := [?]knet.Command_Desc{{name = "throw", policy = knet.ACTION_ANY_SEAT_PREDICTED, invoke = brawler_cmd_throw}}
brawler_set := knet.Command_Set{entity_desc = &brawler_desc, commands = brawler_cmds[:]}

// ---- the peer harness ----------------------------------------------------------

Envelope :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Flying :: struct {
	p:       kcombat.Projectile,
	shooter: knet.Player_Id,
}

Peer_Box :: struct {
	peer:      ksess.Peer_Id,
	s:         ksess.Session,
	out:       [dynamic]Envelope,
	brawlers:  map[knet.Net_Id]^Brawler,
	avatar_of: map[knet.Player_Id]knet.Net_Id,

	// host-only game state (the authoritative sim + respawn clocks)
	cols:       kcombat.Combat_Cols,
	flying:     [dynamic]Flying,
	respawn_at: map[knet.Net_Id]int,
	tick:       int,
}

box_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	b := cast(^Peer_Box)user
	if type != BRAWLER_TYPE {
		return nil, nil
	}
	br := new(Brawler)
	b.brawlers[id] = br
	if owner != knet.PLAYER_ID_INVALID {
		b.avatar_of[owner] = id
	}
	return br, &brawler_set
}

box_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Peer_Box)user
	delete_key(&b.brawlers, id)
	free(entity)
}

// Host: a confirmed throw launches the authoritative rock from the shooter's
// position toward their recorded aim. Peer-owned visuals draw from the same
// announcement in a real game; only THIS sim deals damage.
throw_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	b := cast(^Peer_Box)user
	if !ok || cmd != CMD_THROW {return}
	shooter, is_brawler := b.brawlers[entity]
	if !is_brawler {return}
	dx, dy := shooter.aim.x, shooter.aim.y
	n := abs(dx) + abs(dy) // cheap normalize is fine for axis-aligned tests
	append(&b.flying, Flying {
		p = kcombat.Projectile {
			pos  = {shooter.x, shooter.y, 0},
			vel  = {dx / n * ROCK_SPEED, dy / n * ROCK_SPEED, 0},
			left = ROCK_TTL,
		},
		shooter = player,
	})
}

// The host's game tick: decay ability clocks and effects, fly the rocks,
// deal the damage, credit the ledger, run the respawn clocks.
host_tick :: proc(b: ^Peer_Box) {
	b.tick += 1
	for _, br in b.brawlers {
		kcombat.abilities_tick(br.cds[:])
		kcombat.effects_tick(br.fx[:])
	}

	for i := 0; i < len(b.flying); {
		fl := &b.flying[i]
		from := fl.p.pos
		alive := kcombat.projectile_step(&fl.p)

		targets := make([dynamic]kcombat.Target, context.temp_allocator)
		for id, br in b.brawlers {
			if id == b.avatar_of[fl.shooter] || br.hp <= 0 {
				continue
			}
			append(&targets, kcombat.Target{id = u32(id), pos = {br.x, br.y, 0}, radius = BODY_RADIUS})
		}
		if hit, hit_ok := kcombat.projectile_hit(from, fl.p.vel, targets[:]); hit_ok {
			victim_id := knet.Net_Id(hit.id)
			victim := b.brawlers[victim_id]
			kcombat.credit_hit(&b.s, b.cols, fl.shooter, ROCK_DMG)
			if kcombat.hit(&victim.hp, ROCK_DMG) {
				victim_pid := knet.PLAYER_ID_INVALID
				for pid, av in b.avatar_of {
					if av == victim_id {victim_pid = pid}
				}
				kcombat.credit_kill(&b.s, b.cols, fl.shooter, victim_pid)
				b.respawn_at[victim_id] = b.tick + RESPAWN_TICKS
			} else {
				_ = kcombat.effects_add(victim.fx[:], CHILL, 50, CHILL_TICKS)
			}
			unordered_remove(&b.flying, i)
			continue
		}
		if !alive {
			unordered_remove(&b.flying, i)
			continue
		}
		i += 1
	}

	// Respawn restores STATE (hp/stamina ride deltas). Position is owner-
	// streamed — owner-authoritative by design — so the host cannot teleport
	// anyone: the OWNER repositions itself when it sees its own respawn.
	for id, at in b.respawn_at {
		if b.tick >= at {
			br := b.brawlers[id]
			br.hp = MAX_HP
			br.stamina = MAX_STAMINA
			delete_key(&b.respawn_at, id)
		}
	}
}

// The owner's half of respawning (game code on the owning client): my hp
// came back — walk out of the grave to the spawn point. Owner-streamed
// fields move only when their owner writes them.
owner_respawn_check :: proc(b: ^Peer_Box, avatar: knet.Net_Id, was_dead: ^bool) {
	br, ok := b.brawlers[avatar]
	if !ok {return}
	if br.hp <= 0 {
		was_dead^ = true
		return
	}
	if was_dead^ {
		was_dead^ = false
		br.x = 0
		br.y = 0
	}
}

box_make :: proc(b: ^Peer_Box, peer: ksess.Peer_Id) {
	b.peer = peer
	b.s.send = box_send
	b.s.send_user = b
	ksess.session_set_factory(&b.s, b, box_make_entity, box_free_entity)
	ksess.session_set_command_hook(&b.s, b, throw_hook)
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {
		delete(e.data)
	}
	delete(b.out)
	for _, br in b.brawlers {free(br)}
	delete(b.brawlers)
	delete(b.avatar_of)
	delete(b.flying)
	delete(b.respawn_at)
	ksess.session_destroy(&b.s)
}

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

// One 20 Hz net tick everywhere: the host's game logic first, then the
// session flush, then delivery — the shape of a real frame.
step :: proc(boxes: []^Peer_Box, now: ^f64) {
	now^ += 0.05
	host_tick(boxes[0])
	for b in boxes {
		_, _ = ksess.session_tick(&b.s, 0.05, now^)
	}
	pump(boxes)
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

Arena :: struct {
	host, alice, bob: Peer_Box,
	boxes:            []^Peer_Box,
	alice_av, bob_av: knet.Net_Id,
	now:              f64,
}

// Host + two seated clients, a brawler each: alice at (0,0), bob 90 units
// east — three ticks of rock flight away.
arena_make :: proc(ar: ^Arena) {
	box_make(&ar.host, 1)
	box_make(&ar.alice, 100)
	box_make(&ar.bob, 200)
	ar.boxes = make([]^Peer_Box, 3)
	ar.boxes[0] = &ar.host
	ar.boxes[1] = &ar.alice
	ar.boxes[2] = &ar.bob

	ksess.session_host_start(&ar.host.s, "hosty")
	ar.host.cols = kcombat.combat_columns(&ar.host.s)
	ksess.session_client_start(&ar.alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&ar.alice.s)
	ksess.session_client_start(&ar.bob.s, 0xB0B, "bob")
	ksess.session_client_join(&ar.bob.s)
	pump(ar.boxes)

	spawn :: proc(ar: ^Arena, owner: knet.Player_Id, x: f32) -> knet.Net_Id {
		br := new(Brawler)
		br.x = x
		br.hp = MAX_HP
		br.stamina = MAX_STAMINA
		id := ksess.session_spawn(&ar.host.s, BRAWLER_TYPE, br, &brawler_set, owner = owner)
		ar.host.brawlers[id] = br
		ar.host.avatar_of[owner] = id
		return id
	}
	ar.alice_av = spawn(ar, ar.alice.s.me, 0)
	ar.bob_av = spawn(ar, ar.bob.s.me, 90)
	ksess.session_start_replicating(&ar.host.s)
	pump(ar.boxes)
	for b in ar.boxes {
		_ = drain(&b.s)
	}
}

arena_destroy :: proc(ar: ^Arena) {
	box_destroy(&ar.host)
	box_destroy(&ar.alice)
	box_destroy(&ar.bob)
	delete(ar.boxes)
}

throw_cmd :: proc(b: ^Peer_Box, avatar: knet.Net_Id, dx, dy: f32) -> bool {
	knet.command_begin(&b.s.ctx, avatar, CMD_THROW)
	knet.write_f32(&b.s.ctx.msg, dx)
	knet.write_f32(&b.s.ctx.msg, dy)
	return knet.command_issue(&b.s.ctx, b.brawlers[avatar], &brawler_set, CMD_THROW).prediction_applied
}

// ---- tests -----------------------------------------------------------------------

@(test)
a_thrown_rock_finds_its_mark :: proc(t: ^testing.T) {
	ar: Arena
	arena_make(&ar)
	defer arena_destroy(&ar)

	// Alice throws east. The gate bites BEFORE any packet moves: stamina
	// paid, cooldown hot, on her screen this frame.
	testing.expect(t, throw_cmd(&ar.alice, ar.alice_av, 1, 0))
	me := ar.alice.brawlers[ar.alice_av]
	testing.expect_value(t, me.stamina, MAX_STAMINA - THROW.cost)
	testing.expect_value(t, me.cds[0], THROW.cooldown)

	// 90 units at 30/tick: the swept third tick connects.
	pump(ar.boxes)
	for _ in 0 ..< 4 {
		step(ar.boxes, &ar.now)
	}

	for b in ar.boxes {
		testing.expect_value(t, b.brawlers[ar.bob_av].hp, MAX_HP - ROCK_DMG)
		chill, chilled := kcombat.effect_of(b.brawlers[ar.bob_av].fx[:], CHILL)
		testing.expect(t, chilled, "the chill replicates with the damage")
		testing.expect_value(t, chill.power, i8(50))
	}
	// The chill wears off everywhere, back to the exact empty value.
	for _ in 0 ..< int(CHILL_TICKS) + 1 {
		step(ar.boxes, &ar.now)
	}
	for b in ar.boxes {
		_, still := kcombat.effect_of(b.brawlers[ar.bob_av].fx[:], CHILL)
		testing.expect(t, !still)
		testing.expect_value(t, b.brawlers[ar.bob_av].fx[0], kcombat.Effect{})
	}

	// The ledger, read from a CLIENT's replicated scoreboard (stat snapshots
	// flush at a low rate — by now one has crossed the wire).
	dmg, _ := ksess.session_stat_find(&ar.bob.s, "damage")
	testing.expect_value(t, ksess.session_stat(&ar.bob.s, ar.alice.s.me, dmg), i64(ROCK_DMG))
}

@(test)
the_gate_refuses_spam_identically :: proc(t: ^testing.T) {
	ar: Arena
	arena_make(&ar)
	defer arena_destroy(&ar)

	testing.expect(t, throw_cmd(&ar.alice, ar.alice_av, 1, 0))
	testing.expect(t, !throw_cmd(&ar.alice, ar.alice_av, 1, 0), "same gate, same no, zero latency")
	me := ar.alice.brawlers[ar.alice_av]
	testing.expect_value(t, me.stamina, MAX_STAMINA - THROW.cost) // paid ONCE

	pump(ar.boxes) // both commands reach the host: one rock, one rejection
	testing.expect_value(t, len(ar.host.flying), 1)
	rejected := false
	for ev in drain(&ar.alice.s) {
		if _, is_rej := ev.(ksess.Ev_Command_Rejected); is_rej {
			rejected = true
		}
	}
	testing.expect(t, rejected, "the host said no too — the reject carries truth")
	step(ar.boxes, &ar.now)
	testing.expect_value(t, me.stamina, MAX_STAMINA - THROW.cost) // still paid once

	// The cooldown decays back through replication; then she may throw again.
	for _ in 0 ..< int(THROW.cooldown) {
		step(ar.boxes, &ar.now)
	}
	testing.expect(t, kcombat.ability_ready(me.cds[:], 0))
	testing.expect(t, throw_cmd(&ar.alice, ar.alice_av, 0, 1))
}

@(test)
death_respawn_and_the_ledger :: proc(t: ^testing.T) {
	ar: Arena
	arena_make(&ar)
	defer arena_destroy(&ar)

	// Bob is one rock from the grave (the authority arranges the scenario).
	ar.host.brawlers[ar.bob_av].hp = ROCK_DMG
	step(ar.boxes, &ar.now)

	testing.expect(t, throw_cmd(&ar.alice, ar.alice_av, 1, 0))
	pump(ar.boxes)
	for _ in 0 ..< 4 {
		step(ar.boxes, &ar.now)
	}
	for b in ar.boxes {
		testing.expect_value(t, b.brawlers[ar.bob_av].hp, i32(0)) // down everywhere
	}
	// A corpse cannot throw: the same hp<=0 gate refuses bob's own cast.
	testing.expect(t, !throw_cmd(&ar.bob, ar.bob_av, -1, 0))

	// The respawn clock brings him back whole (host deltas), and BOB walks
	// out of the grave himself — position is owner-streamed, so only its
	// owner can teleport it; his write reaches everyone as stream samples.
	bob_dead := false
	for _ in 0 ..< RESPAWN_TICKS + 4 {
		owner_respawn_check(&ar.bob, ar.bob_av, &bob_dead)
		step(ar.boxes, &ar.now)
	}
	for b in ar.boxes {
		br := b.brawlers[ar.bob_av]
		testing.expect_value(t, br.hp, MAX_HP)
	}
	testing.expect_value(t, ar.bob.brawlers[ar.bob_av].x, f32(0)) // his own screen: instant
	testing.expect_value(t, ar.host.brawlers[ar.bob_av].x, f32(0)) // the host's view: streamed

	// The ledger, read from a CLIENT's replicated scoreboard (the low-rate
	// snapshot has crossed the wire by now).
	kills, _ := ksess.session_stat_find(&ar.bob.s, "kills")
	deaths, _ := ksess.session_stat_find(&ar.bob.s, "deaths")
	testing.expect_value(t, ksess.session_stat(&ar.bob.s, ar.alice.s.me, kills), i64(1))
	testing.expect_value(t, ksess.session_stat(&ar.bob.s, ar.bob.s.me, deaths), i64(1))
}

@(test)
misses_cost_stamina_and_hurt_nobody :: proc(t: ^testing.T) {
	ar: Arena
	arena_make(&ar)
	defer arena_destroy(&ar)

	testing.expect(t, throw_cmd(&ar.alice, ar.alice_av, 0, -1)) // north: nobody there
	pump(ar.boxes)
	for _ in 0 ..< int(ROCK_TTL) + 2 {
		step(ar.boxes, &ar.now)
	}
	testing.expect_value(t, len(ar.host.flying), 0) // expired, removed
	for b in ar.boxes {
		testing.expect_value(t, b.brawlers[ar.bob_av].hp, MAX_HP)
	}
	dmg, _ := ksess.session_stat_find(&ar.host.s, "damage")
	testing.expect_value(t, ksess.session_stat(&ar.host.s, ar.alice.s.me, dmg), i64(0))
	testing.expect_value(t, ar.alice.brawlers[ar.alice_av].stamina, MAX_STAMINA - THROW.cost)
}

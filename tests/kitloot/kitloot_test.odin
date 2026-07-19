package kit_loot_test

// THE PHASE-3 INTEGRATION TEST: chests, bags, doors and the cross-entity
// command pattern, over the full session pipeline (in-memory pipe — the wire
// path minus the socket):
//
//   * a command proc mutates ONLY its target (chest) — kit/net's predict/
//     revert/reject-truth machinery protects exactly that;
//   * what it took is recorded in a NON-replicated scratch field;
//   * the session's synchronous command hook does the cross-entity half on
//     the host (credit the issuer's bag, return overflow to the chest) — a
//     host-authoritative mutation that reaches everyone as a plain delta.
//
// The headline: TWO SPELUNKERS, ONE GEM. Both predict success; the host runs
// them in arrival order; the second take finds the slot empty and rejects —
// the loser is never credited and every peer converges on exactly one gem in
// the world. Conflict resolution isn't a feature, it's the intent pipeline.
//
//   odin test tests/kitloot -collection:godot=$PWD

import "core:testing"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"

GEM :: kitems.Item_Id(1) // stacks to 99
TORCH :: kitems.Item_Id(2) // stacks to 5

REACH :: f32(2.0) // the ONE range constant: prompt and host gate share it

make_table :: proc() -> kitems.Table {
	t: kitems.Table
	kitems.items_register(&t, GEM, "gem", 99)
	kitems.items_register(&t, TORCH, "torch", 5)
	return t
}

// ---- entities (hand-authored like generated code would be) --------------------

Chest :: struct {
	x, y:      f32, // replicated: where it stands (host places it)
	slots:     [4]kitems.Slot, // replicated: ONE 16-byte POD field
	last_take: kitems.Slot, // NOT replicated: scratch for the command hook
}

Spelunker :: struct {
	x, y:      f32, // owner-streamed
	bag:       [4]kitems.Slot, // replicated (host-authoritative; only the hook writes it)
	last_drop: kitems.Slot, // scratch for the drop hook
}

Door :: struct {
	x, y: f32,
	open: bool, // replicated
}

// A dropped stack lying on the cave floor: an ordinary entity, spawned by
// the drop hook, despawned by the grab hook.
Pickup :: struct {
	x, y:      f32,
	item:      kitems.Item_Id, // replicated
	count:     u16, // replicated (0 = already grabbed; predicted grabs zero it)
	last_grab: kitems.Slot, // scratch for the grab hook
}

// Untyped: each is used as both the loot_hook's raw u16 cmd and a knet.Cmd_Id at issue.
CHEST_TAKE :: 0 // args: [slot u8][count u16][px f32][py f32]
DOOR_TOGGLE :: 0 // args: [px f32][py f32]
SPEL_DROP :: 0 // args: [slot u8]
PICKUP_GRAB :: 0 // args: [px f32][py f32]

// The whole loot rule, written once, zero role branches: the predicting
// client and the host run this same proc from byte-identical args.
chest_cmd_take :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	c := cast(^Chest)entity
	slot := int(knet.read_u8(r))
	count := knet.read_u16(r)
	px := knet.read_f32(r)
	py := knet.read_f32(r)
	if r.err {return false}
	if !kinter.in_range({px, py, 0}, {c.x, c.y, 0}, REACH) {return false}
	taken := kitems.take(c.slots[:], slot, count)
	if taken.count == 0 {return false}
	c.last_take = taken
	return true
}

door_cmd_toggle :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	d := cast(^Door)entity
	px := knet.read_f32(r)
	py := knet.read_f32(r)
	if r.err {return false}
	if !kinter.in_range({px, py, 0}, {d.x, d.y, 0}, REACH) {return false}
	d.open = !d.open
	return true
}

// Drop a bag slot on the floor: mutates MY avatar only (bag out, scratch in);
// the hook turns the scratch into a Pickup entity at my feet.
spel_cmd_drop :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	sp := cast(^Spelunker)entity
	slot := int(knet.read_u8(r))
	if r.err {return false}
	dropped := kitems.take(sp.bag[:], slot, max(u16))
	if dropped.count == 0 {return false}
	sp.last_drop = dropped
	return true
}

// Grab a pickup: the contended race in its smallest form — one field pair,
// zeroed by whoever the host says got there first.
pickup_cmd_grab :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	p := cast(^Pickup)entity
	px := knet.read_f32(r)
	py := knet.read_f32(r)
	if r.err {return false}
	if !kinter.in_range({px, py, 0}, {p.x, p.y, 0}, REACH) {return false}
	if p.count == 0 {return false}
	p.last_grab = kitems.Slot{item = p.item, count = p.count}
	p.item = kitems.ITEM_NONE
	p.count = 0
	return true
}

// File-scope like generated code: the registry and factories keep pointers.
chest_fields := [?]knet.Field_Desc {
	{offset = offset_of(Chest, x), size = size_of(f32)},
	{offset = offset_of(Chest, y), size = size_of(f32)},
	{offset = offset_of(Chest, slots), size = size_of([4]kitems.Slot)},
}
chest_desc := knet.Entity_Desc{fields = chest_fields[:]}
chest_cmds := [?]knet.Command_Desc{{name = "take", predict = true, invoke = chest_cmd_take}}
chest_set := knet.Command_Set{entity_desc = &chest_desc, commands = chest_cmds[:]}

spel_fields := [?]knet.Field_Desc {
	{offset = offset_of(Spelunker, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
	{offset = offset_of(Spelunker, y), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
	{offset = offset_of(Spelunker, bag), size = size_of([4]kitems.Slot)},
}
spel_desc := knet.Entity_Desc{fields = spel_fields[:]}
spel_cmds := [?]knet.Command_Desc{{name = "drop", predict = true, invoke = spel_cmd_drop}}
spel_set := knet.Command_Set{entity_desc = &spel_desc, commands = spel_cmds[:]}

pickup_fields := [?]knet.Field_Desc {
	{offset = offset_of(Pickup, x), size = size_of(f32)},
	{offset = offset_of(Pickup, y), size = size_of(f32)},
	{offset = offset_of(Pickup, item), size = size_of(kitems.Item_Id)},
	{offset = offset_of(Pickup, count), size = size_of(u16)},
}
pickup_desc := knet.Entity_Desc{fields = pickup_fields[:]}
pickup_cmds := [?]knet.Command_Desc{{name = "grab", predict = true, invoke = pickup_cmd_grab}}
pickup_set := knet.Command_Set{entity_desc = &pickup_desc, commands = pickup_cmds[:]}

door_fields := [?]knet.Field_Desc {
	{offset = offset_of(Door, x), size = size_of(f32)},
	{offset = offset_of(Door, y), size = size_of(f32)},
	{offset = offset_of(Door, open), size = size_of(bool)},
}
door_desc := knet.Entity_Desc{fields = door_fields[:]}
door_cmds := [?]knet.Command_Desc{{name = "toggle", predict = true, invoke = door_cmd_toggle}}
door_set := knet.Command_Set{entity_desc = &door_desc, commands = door_cmds[:]}

CHEST_TYPE :: ksess.Entity_Type(1)
SPEL_TYPE :: ksess.Entity_Type(2)
DOOR_TYPE :: ksess.Entity_Type(3)
PICKUP_TYPE :: ksess.Entity_Type(4)

// ---- the peer harness ----------------------------------------------------------

Envelope :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Peer_Box :: struct {
	peer:       ksess.Peer_Id,
	s:          ksess.Session,
	out:        [dynamic]Envelope,
	table:      kitems.Table,
	chests:     map[knet.Net_Id]^Chest,
	spelunkers: map[knet.Net_Id]^Spelunker,
	doors:      map[knet.Net_Id]^Door,
	pickups:    map[knet.Net_Id]^Pickup,
	avatar_of:  map[knet.Player_Id]knet.Net_Id,
	freed:      int, // factory frees observed (pickups despawn on grab)
}

box_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	b := cast(^Peer_Box)user
	switch type {
	case CHEST_TYPE:
		c := new(Chest)
		b.chests[id] = c
		return c, &chest_set
	case SPEL_TYPE:
		sp := new(Spelunker)
		b.spelunkers[id] = sp
		if owner != knet.PLAYER_ID_INVALID {
			b.avatar_of[owner] = id
		}
		return sp, &spel_set
	case DOOR_TYPE:
		d := new(Door)
		b.doors[id] = d
		return d, &door_set
	case PICKUP_TYPE:
		p := new(Pickup)
		b.pickups[id] = p
		return p, &pickup_set
	}
	return nil, nil
}

box_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Peer_Box)user
	delete_key(&b.chests, id)
	delete_key(&b.spelunkers, id)
	delete_key(&b.doors, id)
	delete_key(&b.pickups, id)
	free(entity)
	b.freed += 1
}

// THE cross-entity half, host only. Chest take: credit the issuer's bag,
// overflow back in the chest. Drop: mint a Pickup entity at the dropper's
// feet. Grab: credit and DESPAWN. Items cannot vanish anywhere in this.
loot_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	b := cast(^Peer_Box)user
	if !ok {return}
	av, has_avatar := b.avatar_of[player]
	if !has_avatar {return}
	spel := b.spelunkers[av]

	if chest, is_chest := b.chests[entity]; is_chest && cmd == CHEST_TAKE {
		credited := kitems.add(&b.table, spel.bag[:], chest.last_take.item, chest.last_take.count)
		if leftover := chest.last_take.count - credited; leftover > 0 {
			returned := kitems.add(&b.table, chest.slots[:], chest.last_take.item, leftover)
			assert(returned == leftover, "the chest slot we just drained must have room back")
		}
		return
	}
	if dropper, is_spel := b.spelunkers[entity]; is_spel && cmd == SPEL_DROP {
		p := new(Pickup)
		p.x = dropper.x
		p.y = dropper.y
		p.item = dropper.last_drop.item
		p.count = dropper.last_drop.count
		id := ksess.session_spawn(&b.s, PICKUP_TYPE, p, &pickup_set)
		b.pickups[id] = p
		return
	}
	if pickup, is_pickup := b.pickups[entity]; is_pickup && cmd == PICKUP_GRAB {
		grabbed := pickup.last_grab
		credited := kitems.add(&b.table, spel.bag[:], grabbed.item, grabbed.count)
		assert(credited == grabbed.count, "test bags have room for grabs")
		ksess.session_despawn(&b.s, entity)
		delete_key(&b.pickups, entity)
		free(pickup)
	}
}

box_make :: proc(b: ^Peer_Box, peer: ksess.Peer_Id) {
	b.peer = peer
	b.s.send = box_send
	b.s.send_user = b
	b.table = make_table()
	ksess.session_set_factory(&b.s, b, box_make_entity, box_free_entity)
	ksess.session_set_command_hook(&b.s, b, loot_hook)
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {
		delete(e.data)
	}
	delete(b.out)
	for _, c in b.chests {free(c)}
	for _, sp in b.spelunkers {free(sp)}
	for _, d in b.doors {free(d)}
	for _, p in b.pickups {free(p)}
	delete(b.chests)
	delete(b.spelunkers)
	delete(b.doors)
	delete(b.pickups)
	delete(b.avatar_of)
	kitems.table_destroy(&b.table)
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

// One 20 Hz net tick everywhere, then deliver: deltas flush and land.
step :: proc(boxes: []^Peer_Box, now: ^f64) {
	now^ += 0.05
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

Cave :: struct {
	host, alice, bob:  Peer_Box,
	boxes:             []^Peer_Box,
	chest_id, door_id: knet.Net_Id,
	now:               f64,
}

// Host + two seated clients + a placed world: chest at (0,0) with 30 gems in
// slot 0 and one lone gem in slot 3, a door at (5,0), a spelunker per player
// (alice/bob stand AT the chest unless a test moves them).
cave_make :: proc(cv: ^Cave) {
	box_make(&cv.host, 1)
	box_make(&cv.alice, 100)
	box_make(&cv.bob, 200)
	cv.boxes = make([]^Peer_Box, 3)
	cv.boxes[0] = &cv.host
	cv.boxes[1] = &cv.alice
	cv.boxes[2] = &cv.bob

	ksess.session_host_start(&cv.host.s, "hosty")
	ksess.session_client_start(&cv.alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&cv.alice.s)
	ksess.session_client_start(&cv.bob.s, 0xB0B, "bob")
	ksess.session_client_join(&cv.bob.s)
	pump(cv.boxes)

	chest := new(Chest)
	chest.slots[0] = {GEM, 30}
	chest.slots[3] = {GEM, 1} // the contended one
	cv.chest_id = ksess.session_spawn(&cv.host.s, CHEST_TYPE, chest, &chest_set)
	cv.host.chests[cv.chest_id] = chest

	door := new(Door)
	door.x = 5
	cv.door_id = ksess.session_spawn(&cv.host.s, DOOR_TYPE, door, &door_set)
	cv.host.doors[cv.door_id] = door

	for b in cv.boxes[1:] {
		sp := new(Spelunker)
		id := ksess.session_spawn(&cv.host.s, SPEL_TYPE, sp, &spel_set, owner = b.s.me)
		cv.host.spelunkers[id] = sp
		cv.host.avatar_of[b.s.me] = id
	}
	ksess.session_start_replicating(&cv.host.s)
	pump(cv.boxes)
	for b in cv.boxes {
		_ = drain(&b.s)
	}
}

cave_destroy :: proc(cv: ^Cave) {
	box_destroy(&cv.host)
	box_destroy(&cv.alice)
	box_destroy(&cv.bob)
	delete(cv.boxes)
}

// Issue a chest take from a client, exactly as a generated wrapper would.
// Returns the optimistic answer (did the prediction apply locally).
take_cmd :: proc(b: ^Peer_Box, chest: knet.Net_Id, slot: u8, count: u16, px, py: f32) -> bool {
	knet.command_begin(&b.s.ctx, chest, CHEST_TAKE)
	knet.write_u8(&b.s.ctx.msg, slot)
	knet.write_u16(&b.s.ctx.msg, count)
	knet.write_f32(&b.s.ctx.msg, px)
	knet.write_f32(&b.s.ctx.msg, py)
	return knet.command_issue(&b.s.ctx, b.chests[chest], &chest_set, CHEST_TAKE)
}

toggle_cmd :: proc(b: ^Peer_Box, door: knet.Net_Id, px, py: f32) -> bool {
	knet.command_begin(&b.s.ctx, door, DOOR_TOGGLE)
	knet.write_f32(&b.s.ctx.msg, px)
	knet.write_f32(&b.s.ctx.msg, py)
	return knet.command_issue(&b.s.ctx, b.doors[door], &door_set, DOOR_TOGGLE)
}

// Every gem this peer can see, anywhere in the world — conservation checks.
gems_in_view :: proc(b: ^Peer_Box) -> int {
	total := 0
	for _, c in b.chests {
		total += kitems.count_of(c.slots[:], GEM)
	}
	for _, sp in b.spelunkers {
		total += kitems.count_of(sp.bag[:], GEM)
	}
	for _, p in b.pickups {
		if p.item == GEM {
			total += int(p.count)
		}
	}
	return total
}

drop_cmd :: proc(b: ^Peer_Box, avatar: knet.Net_Id, slot: u8) -> bool {
	knet.command_begin(&b.s.ctx, avatar, SPEL_DROP)
	knet.write_u8(&b.s.ctx.msg, slot)
	return knet.command_issue(&b.s.ctx, b.spelunkers[avatar], &spel_set, SPEL_DROP)
}

grab_cmd :: proc(b: ^Peer_Box, pickup: knet.Net_Id, px, py: f32) -> bool {
	knet.command_begin(&b.s.ctx, pickup, PICKUP_GRAB)
	knet.write_f32(&b.s.ctx.msg, px)
	knet.write_f32(&b.s.ctx.msg, py)
	return knet.command_issue(&b.s.ctx, b.pickups[pickup], &pickup_set, PICKUP_GRAB)
}

// ---- tests -----------------------------------------------------------------------

@(test)
loot_lands_in_the_bag :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// Alice, standing at the chest, takes 2 gems. Prediction: her chest copy
	// empties immediately, her bag does NOT (that half is host-authoritative).
	testing.expect(t, take_cmd(&cv.alice, cv.chest_id, 0, 2, 0, 0))
	testing.expect_value(t, cv.alice.chests[cv.chest_id].slots[0], kitems.Slot{GEM, 28})

	pump(cv.boxes) // command executes; the hook credits her avatar on the host
	host_bag := cv.host.spelunkers[cv.host.avatar_of[cv.alice.s.me]]
	testing.expect_value(t, host_bag.bag[0], kitems.Slot{GEM, 2})

	step(cv.boxes, &cv.now) // deltas carry chest + bag to every peer
	aev := drain(&cv.alice.s)
	confirmed := false
	for ev in aev {
		if _, ok := ev.(ksess.Ev_Command_Confirmed); ok {
			confirmed = true
		}
	}
	testing.expect(t, confirmed)
	for b in cv.boxes {
		testing.expect_value(t, b.chests[cv.chest_id].slots[0], kitems.Slot{GEM, 28})
		testing.expect_value(t, gems_in_view(b), 31) // 28 + 2 in the bag + the lone one
	}
	// Bob watches alice's bag fill from across the cave (bags are world state).
	bob_view := cv.bob.spelunkers[cv.bob.avatar_of[cv.alice.s.me]]
	testing.expect_value(t, bob_view.bag[0], kitems.Slot{GEM, 2})
}

@(test)
two_spelunkers_one_gem :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// Both grab the LONE gem in slot 3 in the same instant — both predictions
	// succeed locally before any packet moves.
	testing.expect(t, take_cmd(&cv.alice, cv.chest_id, 3, 1, 0, 0))
	testing.expect(t, take_cmd(&cv.bob, cv.chest_id, 3, 1, 0, 0))
	testing.expect_value(t, cv.alice.chests[cv.chest_id].slots[3].count, u16(0))
	testing.expect_value(t, cv.bob.chests[cv.chest_id].slots[3].count, u16(0))

	pump(cv.boxes) // host order decides: alice's arrives first
	step(cv.boxes, &cv.now)

	// Alice won; bob's reject-truth agrees with his prediction (slot empty).
	aev := drain(&cv.alice.s)
	confirmed := false
	for ev in aev {
		if _, ok := ev.(ksess.Ev_Command_Confirmed); ok {confirmed = true}
	}
	testing.expect(t, confirmed, "the winner's prediction stands")
	bev := drain(&cv.bob.s)
	rejected := false
	for ev in bev {
		if _, ok := ev.(ksess.Ev_Command_Rejected); ok {rejected = true}
	}
	testing.expect(t, rejected, "the loser hears no")

	alice_av := cv.host.avatar_of[cv.alice.s.me]
	bob_av := cv.host.avatar_of[cv.bob.s.me]
	for b in cv.boxes {
		testing.expect_value(t, b.chests[cv.chest_id].slots[3].count, u16(0))
		testing.expect_value(t, kitems.count_of(b.spelunkers[alice_av].bag[:], GEM), 1)
		testing.expect_value(t, kitems.count_of(b.spelunkers[bob_av].bag[:], GEM), 0)
		testing.expect_value(t, gems_in_view(b), 31) // EXACTLY one gem left the chest
	}
}

@(test)
out_of_reach_never_flickers :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// Bob is across the cave. The SAME gate runs in his predicted attempt as
	// on the host: the prediction fails locally (no optimistic flicker), the
	// host rejects authoritatively, nothing anywhere moves.
	testing.expect(t, !take_cmd(&cv.bob, cv.chest_id, 0, 1, 100, 100))
	testing.expect_value(t, cv.bob.chests[cv.chest_id].slots[0], kitems.Slot{GEM, 30})

	pump(cv.boxes)
	hev := drain(&cv.host.s)
	saw_reject := false
	for ev in hev {
		if ex, ok := ev.(ksess.Ev_Command_Executed); ok {
			testing.expect(t, !ex.ok)
			testing.expect_value(t, ex.player, cv.bob.s.me)
			testing.expect_value(t, ex.entity, cv.chest_id)
			saw_reject = true
		}
	}
	testing.expect(t, saw_reject)
	step(cv.boxes, &cv.now)
	for b in cv.boxes {
		testing.expect_value(t, gems_in_view(b), 31)
	}
}

@(test)
door_prediction_holds :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// Alice walks to the door and toggles it: open on her screen this frame.
	testing.expect(t, toggle_cmd(&cv.alice, cv.door_id, 5, 1))
	testing.expect(t, cv.alice.doors[cv.door_id].open)

	pump(cv.boxes)
	step(cv.boxes, &cv.now)
	testing.expect(t, cv.host.doors[cv.door_id].open)
	testing.expect(t, cv.bob.doors[cv.door_id].open, "the observer sees it swing")
	testing.expect(t, cv.alice.doors[cv.door_id].open, "no flicker through confirm+delta")

	// And from too far away, it won't budge — same gate, both sides.
	testing.expect(t, !toggle_cmd(&cv.bob, cv.door_id, 50, 50))
	pump(cv.boxes)
	step(cv.boxes, &cv.now)
	testing.expect(t, cv.host.doors[cv.door_id].open)
}

@(test)
overflow_goes_back_in_the_chest :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// The host stuffs alice's bag almost full (authority mutates directly);
	// deltas tell everyone.
	alice_av := cv.host.avatar_of[cv.alice.s.me]
	host_bag := cv.host.spelunkers[alice_av]
	host_bag.bag = {{TORCH, 5}, {TORCH, 5}, {TORCH, 5}, {TORCH, 3}} // room for 2
	step(cv.boxes, &cv.now)
	testing.expect_value(t, cv.alice.spelunkers[alice_av].bag[3], kitems.Slot{TORCH, 3})

	// Host restocks the chest with torches, then alice grabs a stack of 5.
	cv.host.chests[cv.chest_id].slots[1] = {TORCH, 5}
	step(cv.boxes, &cv.now)
	testing.expect(t, take_cmd(&cv.alice, cv.chest_id, 1, 5, 0, 0))
	pump(cv.boxes)
	step(cv.boxes, &cv.now)

	// 2 fit; 3 went straight back into the chest. Nothing vanished, anywhere.
	for b in cv.boxes {
		bag := b.spelunkers[alice_av]
		testing.expect_value(t, bag.bag[3], kitems.Slot{TORCH, 5})
		testing.expect_value(t, kitems.count_of(b.chests[cv.chest_id].slots[:], TORCH), 3)
		testing.expect_value(t, kitems.count_of(bag.bag[:], TORCH), 20) // 18 + the 2 that fit
	}
}

@(test)
dropped_loot_lies_where_it_fell :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// Alice loots 4 gems, walks off, and drops them. Her bag change is
	// predicted; the pickup MATERIALIZES for everyone when the host's drop
	// hook mints the entity at her feet.
	testing.expect(t, take_cmd(&cv.alice, cv.chest_id, 0, 4, 0, 0))
	pump(cv.boxes)
	step(cv.boxes, &cv.now)

	alice_av := cv.host.avatar_of[cv.alice.s.me]
	cv.alice.spelunkers[alice_av].x = 9 // owner writes; streams carry it
	cv.alice.spelunkers[alice_av].y = 7
	step(cv.boxes, &cv.now) // a stream tick so the host knows where she stands
	cv.host.spelunkers[alice_av].x = 9 // streams are interp-delayed; pin the
	cv.host.spelunkers[alice_av].y = 7 // host view for a deterministic assert

	bag_slot := u8(0)
	testing.expect(t, drop_cmd(&cv.alice, alice_av, bag_slot))
	testing.expect_value(t, kitems.count_of(cv.alice.spelunkers[alice_av].bag[:], GEM), 0) // predicted out
	pump(cv.boxes) // hook mints the pickup
	step(cv.boxes, &cv.now)

	for b in cv.boxes {
		testing.expect_value(t, len(b.pickups), 1)
		for _, p in b.pickups {
			testing.expect_value(t, p.item, GEM)
			testing.expect_value(t, p.count, u16(4))
			testing.expect_value(t, p.x, f32(9))
			testing.expect_value(t, p.y, f32(7))
		}
		testing.expect_value(t, gems_in_view(b), 31) // conserved, floor included
	}
}

@(test)
grab_race_despawns_exactly_once :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// Seed a pickup the honest way: alice loots and drops at the chest. The
	// step between them matters — her PREDICTED drop needs the bag credit to
	// have arrived (the cross-entity half is host-authoritative and rides a
	// delta; you can't drop what your client doesn't hold yet).
	testing.expect(t, take_cmd(&cv.alice, cv.chest_id, 3, 1, 0, 0))
	pump(cv.boxes)
	step(cv.boxes, &cv.now)
	alice_av := cv.host.avatar_of[cv.alice.s.me]
	testing.expect(t, drop_cmd(&cv.alice, alice_av, 0))
	pump(cv.boxes)
	step(cv.boxes, &cv.now)

	pickup_id := knet.Net_Id(0)
	for id in cv.alice.pickups {
		pickup_id = id
	}
	testing.expect(t, pickup_id != 0)

	// Both lunge for it before any packet moves — both predictions zero it.
	testing.expect(t, grab_cmd(&cv.alice, pickup_id, 0, 0))
	testing.expect(t, grab_cmd(&cv.bob, pickup_id, 0, 0))
	pump(cv.boxes) // host: alice first (credit + DESPAWN), bob rejected on a gone entity
	step(cv.boxes, &cv.now)

	bob_av := cv.host.avatar_of[cv.bob.s.me]
	for b in cv.boxes {
		testing.expect_value(t, len(b.pickups), 0) // gone everywhere
		testing.expect_value(t, kitems.count_of(b.spelunkers[alice_av].bag[:], GEM), 1)
		testing.expect_value(t, kitems.count_of(b.spelunkers[bob_av].bag[:], GEM), 0)
		testing.expect_value(t, gems_in_view(b), 31)
	}
	// The clients' factories freed exactly one entity each.
	testing.expect_value(t, cv.alice.freed, 1)
	testing.expect_value(t, cv.bob.freed, 1)

	// Bob's grab named an entity the host had already despawned — no result
	// can carry truth for a missing entity, so his pending rides the EXPIRY
	// safety net (the despawn already cleaned his screen; this is pure
	// bookkeeping). It must time out into a loud auto-revert, not linger.
	testing.expect_value(t, knet.pending_count(&cv.bob.s.ctx.pending), 1)
	_ = drain(&cv.bob.s)
	for _ in 0 ..< 61 {
		step(cv.boxes, &cv.now)
	}
	testing.expect_value(t, knet.pending_count(&cv.bob.s.ctx.pending), 0)
	expired := false
	for ev in drain(&cv.bob.s) {
		if rej, is_rej := ev.(ksess.Ev_Command_Rejected); is_rej {
			expired = true
			// The timeout rejection is ADDRESSED like an explicit one: it
			// names the real seq and the entity the doomed grab targeted —
			// UI keyed on either matches both rejection paths.
			testing.expect(t, rej.seq != 0, "expiry carries the pending's real seq")
			testing.expect_value(t, rej.entity, pickup_id)
		}
	}
	testing.expect(t, expired, "expiry announces itself — silence means no")
}

@(test)
the_host_loots_like_anyone :: proc(t: ^testing.T) {
	cv: Cave
	cave_make(&cv)
	defer cave_destroy(&cv)

	// The host gets an avatar too (it is a player like any other).
	sp := new(Spelunker)
	host_av := ksess.session_spawn(&cv.host.s, SPEL_TYPE, sp, &spel_set, owner = cv.host.s.me)
	cv.host.spelunkers[host_av] = sp
	cv.host.avatar_of[cv.host.s.me] = host_av
	pump(cv.boxes)

	// Authority path: run the SAME proc directly (what a generated wrapper
	// does for the host), then the credit half inline — the mirror of the hook.
	chest := cv.host.chests[cv.chest_id]
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, 0)
	knet.write_u16(&w, 3)
	knet.write_f32(&w, 0)
	knet.write_f32(&w, 0)
	r := knet.reader_make(knet.writer_bytes(&w))
	env := knet.Command_Env{authority = true, by = cv.host.s.me}
	testing.expect(t, chest_cmd_take(chest, &r, &env))
	loot_hook(&cv.host, cv.host.s.me, cv.chest_id, CHEST_TAKE, true)

	step(cv.boxes, &cv.now)
	for b in cv.boxes {
		testing.expect_value(t, b.chests[cv.chest_id].slots[0], kitems.Slot{GEM, 27})
		testing.expect_value(t, kitems.count_of(b.spelunkers[host_av].bag[:], GEM), 3)
		testing.expect_value(t, gems_in_view(b), 31)
	}
}

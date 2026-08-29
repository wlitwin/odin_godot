package kit_save_test

// Standalone tests for kit/save's ENVELOPE (the FileAccess helpers are
// engine-bound and exercised by the cavecrawl suite run). THE SAGA: a live
// run — roster, stats, an owned entity — is saved, every process dies, and
// a fresh session resumes it from the bytes under the identity that saved
// it; a player rejoins with her persisted token and reclaims everything.
//
//   odin test tests/kitsave -collection:godot=$PWD

import "core:testing"
import knet "godot:kit/net"
import ksave "godot:kit/save"
import ksess "godot:kit/session"

Bot :: struct {
	hp: i32,
	x:  f32,
}

bot_cmd_poke :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
	b := cast(^Bot)entity
	amount := knet.read_i32(r)
	if r.err {return false}
	b.hp -= amount
	return true
}

bot_fields := [?]knet.Field_Desc {
	{offset = offset_of(Bot, hp), size = size_of(i32)},
	{offset = offset_of(Bot, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
}
bot_desc := knet.Entity_Desc{fields = bot_fields[:]}
bot_cmds := [?]knet.Command_Desc{{name = "poke", policy = knet.ACTION_ANY_SEAT_PREDICTED, invoke = bot_cmd_poke}}
bot_set := knet.Command_Set{entity_desc = &bot_desc, commands = bot_cmds[:]}

BOT_TYPE :: ksess.Entity_Type(7)
TOKEN_ALICE :: u64(0xA11CE)

Envelope :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Peer_Box :: struct {
	peer: ksess.Peer_Id,
	s:    ksess.Session,
	out:  [dynamic]Envelope,
	bots: map[knet.Net_Id]^Bot,
}

box_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	b := cast(^Peer_Box)user
	if type != BOT_TYPE {
		return nil, nil
	}
	bot := new(Bot)
	b.bots[id] = bot
	return bot, &bot_set
}

box_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Peer_Box)user
	delete_key(&b.bots, id)
	free(entity)
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

@(test)
the_save_saga :: proc(t: ^testing.T) {
	// ---- run 1: a live world worth keeping -------------------------------
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)

	ksess.session_host_start(&host.s, "hosty")
	score := ksess.session_stat_column(&host.s, "score")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})

	bot := new(Bot)
	bot.hp = 61
	bot.x = 12.5
	bot_id := ksess.session_spawn(&host.s, BOT_TYPE, bot, &bot_set, owner = alice.s.me)
	host.bots[bot_id] = bot
	ksess.session_start_replicating(&host.s)
	ksess.session_stat_add(&host.s, alice.s.me, score, 41)
	pump([]^Peer_Box{&host, &alice})

	// The host hits save. game_version and the game blob are the GAME's.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksave.save_write(&host.s, &w, 7, transmute([]u8)string("wave-2-brains"))
	file := make([]u8, len(knet.writer_bytes(&w)))
	defer delete(file)
	copy(file, knet.writer_bytes(&w))

	// ---- everything dies --------------------------------------------------
	box_destroy(&host)
	box_destroy(&alice)

	// ---- run 2: resume from the bytes --------------------------------------
	host2: Peer_Box
	box_make(&host2, 1)
	defer box_destroy(&host2)

	r := knet.reader_make(file)
	h, hok := ksave.save_read_header(&r)
	testing.expect(t, hok)
	testing.expect_value(t, h.game_version, u16(7)) // the game checks its own stamp
	testing.expect_value(t, string(h.game_blob), "wave-2-brains")
	testing.expect_value(t, h.saved_by, knet.Player_Id(1)) // hosts have no token; the file remembers

	testing.expect(t, ksave.save_restore(&host2.s, "hosty", &r, h))
	testing.expect_value(t, host2.s.me, knet.Player_Id(1))
	// Roster rows, disconnected included — alice is back as a SEAT, not yet present.
	testing.expect_value(t, ksess.session_count(&host2.s, connected_only = false, players_only = false), 2)
	ap, has_alice := ksess.session_player(&host2.s, 2)
	testing.expect(t, has_alice && !ap.connected)

	// The world came back through the factory, state intact.
	bot2, has_bot := host2.bots[bot_id]
	testing.expect(t, has_bot)
	testing.expect_value(t, bot2.hp, i32(61))
	testing.expect_value(t, bot2.x, f32(12.5))

	// Alice rejoins with her PERSISTED token: same id, her stats, her bot.
	alice2: Peer_Box
	box_make(&alice2, 300)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host2, &alice2})

	testing.expect_value(t, alice2.s.me, knet.Player_Id(2)) // identity reclaimed
	col2, cok := ksess.session_stat_find(&alice2.s, "score")
	testing.expect(t, cok)
	testing.expect_value(t, ksess.session_stat(&alice2.s, 2, col2), i64(41)) // score survived
	abot, alice_sees := alice2.bots[bot_id]
	testing.expect(t, alice_sees, "the world reached the rejoiner")
	testing.expect_value(t, abot.hp, i32(61))

	// Fresh ids never collide with saved ones (cursors persisted).
	testing.expect_value(t, host2.s.next_player, knet.Player_Id(3))
	fresh := new(Bot)
	host2.bots[ksess.session_spawn(&host2.s, BOT_TYPE, fresh, &bot_set)] = fresh
	testing.expect(t, ksess.session_count(&host2.s) == 2)

	// THE RESUMED RUN IS PLAYABLE: a command against the restored host
	// executes and answers (this is what the cavecrawl act-2 rejoiner does).
	knet.command_begin(&alice2.s.ctx, bot_id, 0)
	knet.write_i32(&alice2.s.ctx.msg, 11)
	testing.expect(t, knet.command_issue(&alice2.s.ctx, alice2.bots[bot_id], &bot_set, 0))
	pump([]^Peer_Box{&host2, &alice2})
	testing.expect_value(t, host2.bots[bot_id].hp, i32(50)) // 61 - 11, authoritatively
	confirmed := false
	for {
		ev, ok := ksess.session_poll(&alice2.s)
		if !ok {break}
		if _, is_conf := ev.(ksess.Ev_Command_Confirmed); is_conf {
			confirmed = true
		}
	}
	testing.expect(t, confirmed, "the resumed host answers commands")
}

@(test)
foreign_and_broken_saves_refuse_to_parse :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksave.save_write(&host.s, &w, 1)
	good := knet.writer_bytes(&w)

	// Wrong magic: not ours at all.
	garbage := make([]u8, len(good))
	defer delete(garbage)
	copy(garbage, good)
	garbage[0] ~= 0xFF
	rg := knet.reader_make(garbage)
	_, gok := ksave.save_read_header(&rg)
	testing.expect(t, !gok)

	// A future toolkit format: refuse, don't guess.
	future := make([]u8, len(good))
	defer delete(future)
	copy(future, good)
	future[4] = 0xEE
	rf := knet.reader_make(future)
	_, fok := ksave.save_read_header(&rf)
	testing.expect(t, !fok)

	// A truncated snapshot: header parses, restore says no, session unusable
	// state is the CALLER's to discard (documented contract).
	cut := knet.reader_make(good[:len(good) - 6])
	h, cok := ksave.save_read_header(&cut)
	testing.expect(t, cok)
	broken: Peer_Box
	box_make(&broken, 1)
	defer box_destroy(&broken)
	testing.expect(t, !ksave.save_restore(&broken.s, "hosty", &cut, h))
}
// ---- versioned local POD records (record_encode/decode, the pure core) -------

// v1 of a profile, and v2 with an appended field — the append-only migration
// the zero-default handles WITHOUT a version bump.
Rec_V1 :: struct {
	cores: u32,
	parts: u8,
}
Rec_V2 :: struct {
	cores:   u32,
	parts:   u8,
	unlocks: u16, // appended at the END — old files read it as zero
}

@(test)
record_round_trips_and_migrates :: proc(t: ^testing.T) {
	VER :: u16(1)
	p := Rec_V1{cores = 4200, parts = 0b101}
	bytes := ksave.record_encode(p, VER, context.temp_allocator)

	// Round trip: same type, same version.
	got, res := ksave.record_decode(Rec_V1, bytes, VER)
	testing.expect_value(t, res, ksave.Record_Result.Ok)
	testing.expect_value(t, got.cores, u32(4200))
	testing.expect_value(t, got.parts, u8(0b101))

	// APPEND-ONLY ZERO-DEFAULT: the v1 bytes decode into v2 at the SAME version —
	// the shared fields survive, the appended `unlocks` reads as zero.
	up, ures := ksave.record_decode(Rec_V2, bytes, VER)
	testing.expect_value(t, ures, ksave.Record_Result.Ok)
	testing.expect_value(t, up.cores, u32(4200))
	testing.expect_value(t, up.parts, u8(0b101))
	testing.expect_value(t, up.unlocks, u16(0)) // the migration, for free

	// A newer file read by an OLDER build truncates cleanly (shared fields only).
	full := ksave.record_encode(Rec_V2{cores = 1, parts = 2, unlocks = 9}, VER, context.temp_allocator)
	down, dres := ksave.record_decode(Rec_V1, full, VER)
	testing.expect_value(t, dres, ksave.Record_Result.Ok)
	testing.expect_value(t, down.cores, u32(1))
	testing.expect_value(t, down.parts, u8(2))

	// A different VERSION is .Skew (an incompatible reorder/remove/retype).
	_, skew := ksave.record_decode(Rec_V1, bytes, VER + 1)
	testing.expect_value(t, skew, ksave.Record_Result.Skew)

	// Wrong magic / truncation is .Corrupt, never a silent misread.
	_, badmagic := ksave.record_decode(Rec_V1, []u8{1, 2, 3, 4, 5, 6, 7, 8}, VER)
	testing.expect_value(t, badmagic, ksave.Record_Result.Corrupt)
	_, cut := ksave.record_decode(Rec_V1, bytes[:len(bytes) - 2], VER) // lop the tail
	testing.expect_value(t, cut, ksave.Record_Result.Corrupt)
}

//gd:extends Node
//gd:class CaveLobby
package cavecrawl_scripts

// ----------------------------------------------------------------------------
// CAVECRAWL — the friendslop toolkit's example game, grown one phase at a
// time. Phase 1: it boots to a WORKING LOBBY — host a cave or join one,
// watch the spelunker list fill in live (names, host crown, you-marker,
// measured ping), and reconnect-proof identity underneath it all.
// Phase 2: the spelunkers TALK — a kit/comms chat box (host-ordered lines,
// system flavor text on joins/leaves, history for drop-in joiners) and
// positional markers, all riding the session's wire with no new glue.
// Phase 3: the CAVE — press Start and the lobby becomes a world: a spelunker
// per player (owner-streamed motion), a chest to loot (predicted, host-
// serialized when two grab at once), a door to open, an interact prompt fed
// by the same range gate the host validates with, and your bag on screen.
//
// This file is the whole game: button wiring, world plumbing, input.
//   * The ENTITIES live in spelunker.odin / chest.odin / door.odin — a file
//     each, fields tagged gd:"replicate", commands as plain procs. That is
//     the entire multiplayer author surface.
//   * kit/ui builds lobby + chat + prompt + inventory controls.
//   * kit/session runs identity, roster, stats, spawns, and the replicated
//     world — this node forwards transport packets and drains events.
//   * kit/comms rides the session (SES_APP), so chat needs zero transport code.
//   * kit/netgd is the wire. Host = ENet :4242; Join = localhost for now
//     (room codes ride the WebRTC signaling server in a later phase).
//
// Identity: CAVE_NAME / CAVE_TOKEN env override the defaults so tests (and
// impatient friends sharing a machine) can pick who they are. A real build
// persists the token in user:// — that lands with save/load (phase 6).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "godot:gdext"
import rt "godot:runtime"
import kcomms "godot:kit/comms"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import netgd "godot:kit/netgd"
import "core:fmt"
import "core:strconv"
import "core:time"

DEFAULT_PORT :: 4242
MSG_SESSION :: u8(0) // all kit/session traffic under one game byte

// ---- the cave's vocabulary (shared by every script in this package) ----

REACH :: f32(40) // interaction reach in pixels — prompt AND host gate use it

GEM :: kitems.Item_Id(1)
TORCH :: kitems.Item_Id(2)

SPEL_TYPE :: ksess.Entity_Type(1)
CHEST_TYPE :: ksess.Entity_Type(2)
DOOR_TYPE :: ksess.Entity_Type(3)

WALK_SPEED :: f32(120) // px/s

// Spelunkers declare no commands, so scriptgen emits only their descriptor;
// the registry still wants a set.
spelunker_set := knet.Command_Set{entity_desc = &spelunker_net_desc}

CaveLobby :: struct {
	owner:     gd.Node,
	ses:       ksess.Session,
	comms:     kcomms.Comms,
	ui:        kui.Lobby,
	chat:      kui.Chat,
	running:   bool, // hosting or joining (transport is up)
	join_sent: bool, // client: JOIN goes out once the transport connects

	// ---- the world (phase 3) ----
	table:       kitems.Table,
	world:       gd.Node, // entity nodes live under here
	prompt:      kui.Prompt,
	inv:         kui.Inv,
	spelunkers:  map[knet.Net_Id]^Spelunker,
	chests:      map[knet.Net_Id]^Chest,
	doors:       map[knet.Net_Id]^Door,
	nodes:       map[knet.Net_Id]gd.Node, // for freeing on despawn
	avatar_of:   map[knet.Player_Id]knet.Net_Id,
	me_spel:     ^Spelunker, // my avatar (nil until spawned)
	started:     bool, // the world is live
	walking:     bool, // headless drivers steer via walk_to
	walk_target: gd.Vector2,
	target_id:   knet.Net_Id, // what the prompt points at right now
	target_kind: int, // 0 none, 1 chest, 2 door
}

@(private = "file")
now_s :: proc "contextless" () -> f64 {
	return f64(time.tick_now()._nsec) / 1e9
}

@(private = "file")
env_string :: proc(name: cstring, fallback: string) -> string {
	env := gd.os_get_environment(gd.singleton_os(), gd.new_string_cstring(name))
	buf: [64]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&env, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {
		return fallback
	}
	return fmt.tprintf("%s", string(buf[:n]))
}

@(private = "file")
port :: proc() -> int {
	if p, ok := strconv.parse_int(env_string("CAVE_PORT", "")); ok {
		return p
	}
	return DEFAULT_PORT
}

@(private = "file")
my_name :: proc() -> string {
	return env_string("CAVE_NAME", "spelunker")
}

@(private = "file")
my_token :: proc() -> u64 {
	t := env_string("CAVE_TOKEN", "")
	if t != "" {
		h := u64(1469598103934665603) // fnv64a over the env token string
		for c in transmute([]u8)t {
			h = (h ~ u64(c)) * 1099511628211
		}
		return h
	}
	// First run without persistence: derive from the clock. Phase 6 stores it.
	return u64(time.tick_now()._nsec)
}

@(private = "file")
session_send :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: ksess.Channel) {
	self := cast(^CaveLobby)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_SESSION)
	append(&w.buf, ..bytes)
	if channel == .Stream {
		_ = netgd.send_stream(self.owner, to_peer, knet.writer_bytes(&w))
	} else {
		_ = netgd.send_reliable(self.owner, to_peer, knet.writer_bytes(&w))
	}
}

cave_lobby_ready :: proc(self: ^CaveLobby) {
	self.ui = kui.lobby_make(self.owner, "C A V E C R A W L")
	kui.lobby_set_status(&self.ui, "Host a cave, or join one at localhost")
	gd.connect_to(cast(gd.Object)self.ui.host_btn, "pressed", self.owner, "on_host")
	gd.connect_to(cast(gd.Object)self.ui.join_btn, "pressed", self.owner, "on_join")

	gd.connect_to(cast(gd.Object)self.ui.start_btn, "pressed", self.owner, "on_start")

	// Comms bind before the session starts (routes survive host/client start);
	// the chat box stays hidden until there is a session to speak into.
	kcomms.comms_init(&self.comms, &self.ses)
	self.chat = kui.chat_make(self.owner)
	kui.chat_show(&self.chat, false)
	gd.connect_to(cast(gd.Object)self.chat.input, "text_submitted", self.owner, "on_chat")

	// The cave (phase 3): item defs are code — every peer declares the same
	// table. World hookups install now; entities exist only after Start.
	kitems.items_register(&self.table, GEM, "gem", 99)
	kitems.items_register(&self.table, TORCH, "torch", 5)
	self.world = gd.new_node()
	gd.node_set_name(self.world, gd.new_string_name_cstring("World", true))
	gd.add_child(self.owner, self.world)
	self.prompt = kui.prompt_make(self.owner)
	self.inv = kui.inv_make(self.owner, 6)
	kui.inv_show(&self.inv, false)
	ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
	ksess.session_set_command_hook(&self.ses, self, cave_command_hook)
	gd.print_str("CAVE_UI_READY")
}

// ---- the world: nodes, factory, spawning ------------------------------------------

// A script-backed entity node, made from code: base Label + the entity's own
// .odin script. Same flow the editor uses, no scene assets to install.
@(private = "file")
spawn_node :: proc(self: ^CaveLobby, script_path: cstring) -> gd.Node {
	node := cast(gd.Node)gd.new_label()
	script := gd.resource_loader_load(
		gd.singleton_resource_loader(),
		gd.new_string_cstring(script_path),
		gd.new_string_cstring(""),
		.Cache_Mode_Reuse,
	)
	obj := cast(gd.Object)script
	gd.object_set_script(cast(gd.Object)node, gd.variant_from_object(&obj))
	gd.add_child(self.world, node)
	return node
}

@(private = "file")
track_spelunker :: proc(self: ^CaveLobby, id: knet.Net_Id, sp: ^Spelunker, owner: knet.Player_Id) {
	sp.net_id = id
	self.spelunkers[id] = sp
	if owner != knet.PLAYER_ID_INVALID {
		self.avatar_of[owner] = id
		if owner == self.ses.me {
			self.me_spel = sp
		}
	}
}

// The session announces a spawn by type: make the node, hand back the struct
// and its generated command set. This runs on CLIENTS (and on resume).
@(private = "file")
cave_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	self := cast(^CaveLobby)user
	switch type {
	case SPEL_TYPE:
		node := spawn_node(self, "res://scripts/spelunker.odin")
		self.nodes[id] = node
		sp := rt.script_of(node, Spelunker)
		track_spelunker(self, id, sp, owner)
		return sp, &spelunker_set
	case CHEST_TYPE:
		node := spawn_node(self, "res://scripts/chest.odin")
		self.nodes[id] = node
		c := rt.script_of(node, Chest)
		c.net_id = id
		self.chests[id] = c
		return c, &chest_command_set
	case DOOR_TYPE:
		node := spawn_node(self, "res://scripts/door.odin")
		self.nodes[id] = node
		d := rt.script_of(node, Door)
		d.net_id = id
		self.doors[id] = d
		return d, &door_command_set
	}
	return nil, nil
}

@(private = "file")
cave_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	self := cast(^CaveLobby)user
	if node, ok := self.nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&self.nodes, id)
	}
	delete_key(&self.spelunkers, id)
	delete_key(&self.chests, id)
	delete_key(&self.doors, id)
}

// THE CROSS-ENTITY HALF of looting, host only (see chest.odin): a successful
// take credits the issuer's bag; what doesn't fit goes back in the chest.
@(private = "file")
cave_credit :: proc(self: ^CaveLobby, player: knet.Player_Id, chest: ^Chest) {
	av, has := self.avatar_of[player]
	if !has {return}
	sp := self.spelunkers[av]
	credited := kitems.add(&self.table, sp.bag[:], chest.last_take.item, chest.last_take.count)
	if leftover := chest.last_take.count - credited; leftover > 0 {
		_ = kitems.add(&self.table, chest.slots[:], chest.last_take.item, leftover)
	}
}

// Client commands land here right after they execute on the host.
@(private = "file")
cave_command_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	self := cast(^CaveLobby)user
	if !ok {return}
	if chest, is_chest := self.chests[entity]; is_chest && cmd == 0 {
		cave_credit(self, player, chest)
	}
}

// Host, Start pressed: build the world — a spelunker per seated player, a
// stocked chest, a door — and go live. Every already-seated client gets the
// whole world; later joiners get it behind their welcome (drop-in).
@(gd_method)
cave_lobby_on_start :: proc(self: ^CaveLobby) {
	if !self.ses.is_host || self.started {return}

	chest_node := spawn_node(self, "res://scripts/chest.odin")
	chest := rt.script_of(chest_node, Chest)
	chest.x = 300
	chest.y = 180
	chest.slots[0] = {GEM, 3}
	chest.slots[1] = {TORCH, 2}
	chest.net_id = ksess.session_spawn(&self.ses, CHEST_TYPE, chest, &chest_command_set)
	self.chests[chest.net_id] = chest
	self.nodes[chest.net_id] = chest_node

	door_node := spawn_node(self, "res://scripts/door.odin")
	door := rt.script_of(door_node, Door)
	door.x = 560
	door.y = 180
	door.net_id = ksess.session_spawn(&self.ses, DOOR_TYPE, door, &door_command_set)
	self.doors[door.net_id] = door
	self.nodes[door.net_id] = door_node

	i := 0
	for _, p in self.ses.players {
		if !p.connected {continue}
		node := spawn_node(self, "res://scripts/spelunker.odin")
		sp := rt.script_of(node, Spelunker)
		sp.x = 80 + f32(i) * 60
		sp.y = 120
		i += 1
		id := ksess.session_spawn(&self.ses, SPEL_TYPE, sp, &spelunker_set, owner = p.id)
		self.nodes[id] = node
		track_spelunker(self, id, sp, p.id)
	}

	ksess.session_start_replicating(&self.ses)
	enter_the_cave(self)
	kcomms.comms_system(&self.comms, "the descent begins")
	gd.print_str(fmt.tprintf("CAVE_STARTED spel=%d", i))
}

// Both roles flip to game mode the same way (host at Start, client at spawn).
@(private = "file")
enter_the_cave :: proc(self: ^CaveLobby) {
	self.started = true
	gd.set_bool(cast(gd.Object)self.ui.root, "visible", false)
	kui.inv_show(&self.inv, true)
	if self.me_spel != nil {
		kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
	}
}

@(gd_method)
cave_lobby_on_host :: proc(self: ^CaveLobby) {
	if self.running {return}
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.ui, "Could not host (port taken?)")
		gd.print_str("CAVE_HOST_FAIL")
		return
	}
	if netgd.listen_packets(self.owner, "on_packet") != .Ok {return}
	self.ses.send = session_send
	self.ses.send_user = self
	ksess.session_host_start(&self.ses, my_name())
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, fmt.ctprintf("Hosting on :%d — waiting for friends", port()))
	kui.lobby_refresh(&self.ui, &self.ses)
	kui.chat_show(&self.chat, true)
	gd.print_str("CAVE_HOSTING")
}

@(gd_method)
cave_lobby_on_join :: proc(self: ^CaveLobby) {
	if self.running {return}
	if !gd.join(self.owner, "127.0.0.1", port()) {
		kui.lobby_set_status(&self.ui, "Could not start joining")
		return
	}
	if netgd.listen_packets(self.owner, "on_packet") != .Ok {return}
	self.ses.send = session_send
	self.ses.send_user = self
	ksess.session_client_start(&self.ses, my_token(), my_name())
	self.running = true
	kui.lobby_show_menu(&self.ui, false, false)
	kui.lobby_set_status(&self.ui, "Joining the cave...")
	kui.chat_show(&self.chat, true)
	gd.print_str("CAVE_JOINING")
}

@(private = "file")
roster_changed :: proc(self: ^CaveLobby) {
	n := ksess.session_count(&self.ses, connected_only = true)
	gd.print_str(fmt.tprintf("CAVE_PLAYERS n=%d", n))
	if self.ses.is_host {
		kui.lobby_set_status(&self.ui, fmt.ctprintf("%d spelunkers ready", n))
		// Enough friends: the host may start (phase 3 gives Start a game).
		kui.lobby_show_menu(&self.ui, false, n >= 2)
	}
}

cave_lobby_process :: proc(self: ^CaveLobby, delta: f64) {
	if !self.running {return}

	// Client: seat ourselves as soon as the transport handshake completes.
	if !self.ses.is_host && !self.join_sent {
		mp := gd.node_get_multiplayer(self.owner)
		if cast(rawptr)mp != nil && gd.multiplayer_api_has_multiplayer_peer(mp) {
			peers := gd.multiplayer_api_get_peers(mp)
			if gd.packed_int32_array_size(&peers) > 0 {
				ksess.session_client_join(&self.ses)
				self.join_sent = true
			}
		}
	}

	_, _ = ksess.session_tick(&self.ses, delta, now_s())

	refresh := false
	for {
		ev, ok := ksess.session_poll(&self.ses)
		if !ok {break}
		#partial switch e in ev {
		case ksess.Ev_Welcomed:
			kui.lobby_set_status(&self.ui, "In the cave — waiting for the host to start")
			gd.print_str(fmt.tprintf("CAVE_SEATED me=%d", u64(e.me)))
			refresh = true
		case ksess.Ev_Player_Joined:
			roster_changed(self)
			refresh = true
			// The host words the flavor lines; comms ships them. Catchup goes
			// FIRST so a fresh joiner's replayed history doesn't duplicate the
			// join line it is about to receive from the broadcast.
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					if !e.rejoin {
						kcomms.comms_catchup(&self.comms, e.id)
					}
					verb := e.rejoin ? "returned to" : "joined"
					kcomms.comms_system(&self.comms, fmt.tprintf("%s %s the cave", p.name, verb))
				}
			}
		case ksess.Ev_Player_Left:
			roster_changed(self)
			refresh = true
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					kcomms.comms_system(&self.comms, fmt.tprintf("%s wandered off", p.name))
				}
			}
		case ksess.Ev_Stats_Updated:
			refresh = true // ping column repaint
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&self.ui, "The host left — this run is over")
			gd.print_str("CAVE_HOST_LEFT")
		case ksess.Ev_Spawned:
			// The world reached this client (factory already made the node).
			if !self.started {
				enter_the_cave(self)
			}
			gd.print_str(fmt.tprintf("CAVE_SPAWN id=%d mine=%v", u32(e.id), e.owner == self.ses.me))
		case ksess.Ev_State_Applied:
			if self.me_spel != nil {
				kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
			}
		case ksess.Ev_Command_Confirmed:
			gd.print_str("CAVE_CONFIRM")
		case ksess.Ev_Command_Rejected:
			gd.print_str(fmt.tprintf("CAVE_REJECT entity=%d", u32(e.entity)))
		}
	}
	if refresh {
		kui.lobby_refresh(&self.ui, &self.ses)
	}

	refresh_chat := false
	for {
		cev, cok := kcomms.comms_poll(&self.comms)
		if !cok {break}
		switch e in cev {
		case kcomms.Ev_Line:
			refresh_chat = true
		case kcomms.Ev_Marker:
			// No world yet to draw it in — phase 3 gives markers a cave wall.
			gd.print_str(fmt.tprintf("CAVE_MARK player=%d kind=%d x=%.1f", u64(e.player), e.kind, e.pos.x))
		}
	}
	if refresh_chat {
		kui.chat_refresh(&self.chat, &self.comms)
	}

	if self.started && self.me_spel != nil {
		drive_spelunker(self, delta)
		update_prompt(self)
	}
}

// Move MY spelunker: keyboard when a human is at the wheel, walk_to targets
// when a test drives. Writing x/y is the ENTIRE author surface for motion —
// they are owner-streamed fields.
@(private = "file")
drive_spelunker :: proc(self: ^CaveLobby, delta: f64) {
	me := self.me_spel
	step := WALK_SPEED * f32(delta)
	dir := gd.input_get_vector(
		gd.singleton_input(),
		gd.new_string_name_cstring("ui_left", true),
		gd.new_string_name_cstring("ui_right", true),
		gd.new_string_name_cstring("ui_up", true),
		gd.new_string_name_cstring("ui_down", true),
		0.2,
	)
	if dir.x != 0 || dir.y != 0 {
		self.walking = false
		me.x += dir.x * step
		me.y += dir.y * step
		return
	}
	if self.walking {
		dx := self.walk_target.x - me.x
		dy := self.walk_target.y - me.y
		if abs(dx) <= step && abs(dy) <= step {
			me.x = self.walk_target.x
			me.y = self.walk_target.y
			self.walking = false
			return
		}
		if abs(dx) > step {
			me.x += dx > 0 ? step : -step
		}
		if abs(dy) > step {
			me.y += dy > 0 ? step : -step
		}
	}
}

// What can I use from here? The prompt and the host's command gate share
// REACH and the same in_range math — they cannot disagree about geometry.
@(private = "file")
update_prompt :: proc(self: ^CaveLobby) {
	me := self.me_spel
	cands := make([dynamic]kinter.Candidate, context.temp_allocator)
	for id, c in self.chests {
		append(&cands, kinter.Candidate{id = u32(id), pos = {c.x, c.y, 0}})
	}
	for id, d in self.doors {
		append(&cands, kinter.Candidate{id = u32(id), pos = {d.x, d.y, 0}})
	}
	best, ok := kinter.pick(cands[:], {me.x, me.y, 0}, REACH)
	if !ok {
		self.target_kind = 0
		kui.prompt_set(&self.prompt, "")
		return
	}
	self.target_id = knet.Net_Id(best.id)
	if _, is_chest := self.chests[self.target_id]; is_chest {
		self.target_kind = 1
		kui.prompt_set(&self.prompt, "E — loot chest")
	} else {
		self.target_kind = 2
		door := self.doors[self.target_id]
		kui.prompt_set(&self.prompt, door.open ? "E — close door" : "E — open door")
	}
}

// Use whatever the prompt points at — the SAME call every peer makes; the
// generated _cmd wrappers hold the only role branch in the game.
@(gd_method)
cave_lobby_interact :: proc(self: ^CaveLobby) {
	if !self.started || self.me_spel == nil || self.target_kind == 0 {return}
	me := self.me_spel
	switch self.target_kind {
	case 1:
		chest := self.chests[self.target_id]
		slot := i32(-1)
		for s, i in chest.slots {
			if s.item != kitems.ITEM_NONE {
				slot = i32(i)
				break
			}
		}
		if slot < 0 {
			gd.print_str("CAVE_LOOT_DENIED empty")
			return
		}
		applied := chest_take_cmd(&self.ses.ctx, chest, slot, me.x, me.y)
		if applied && self.ses.is_host {
			cave_credit(self, self.ses.me, chest) // the authority's inline half
			kui.inv_refresh(&self.inv, me.bag[:], &self.table)
		}
		gd.print_str(fmt.tprintf("CAVE_LOOT applied=%v slot=%d", applied, slot))
	case 2:
		door := self.doors[self.target_id]
		applied := door_toggle_cmd(&self.ses.ctx, door, me.x, me.y)
		gd.print_str(fmt.tprintf("CAVE_TOGGLE applied=%v open=%v", applied, door.open))
	}
}

@(gd_method)
cave_lobby_walk_to :: proc(self: ^CaveLobby, x: gd.Float, y: gd.Float) {
	self.walking = true
	self.walk_target = {f32(x), f32(y)}
}

// The chat box's text_submitted — say it and clear the line.
@(gd_method)
cave_lobby_on_chat :: proc(self: ^CaveLobby, text: gd.String) {
	if !self.running {return}
	text := text
	buf: [512]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&text, cast(cstring)&buf[0], len(buf) - 1)
	if n > 0 {
		kcomms.comms_say(&self.comms, string(buf[:n]))
	}
	kui.chat_clear_input(&self.chat)
}

@(gd_method)
cave_lobby_on_packet :: proc(self: ^CaveLobby, id: gd.Int, packet: gd.Packed_Byte_Array) {
	packet := packet
	r := knet.reader_make(netgd.pba_view(&packet))
	if knet.read_u8(&r) == MSG_SESSION {
		ksess.session_handle_packet(&self.ses, int(id), &r)
	}
}

// ---- test drivers ----

// Drop a marker (the test's stand-in for a ping keybind; kind 1 = "look here").
@(gd_method)
cave_lobby_mark :: proc(self: ^CaveLobby) {
	if !self.running {return}
	kcomms.comms_ping(&self.comms, 1, {1, 2, 3})
}

@(gd_method)
cave_lobby_get_players :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(ksess.session_count(&self.ses, connected_only = true))
}

@(gd_method)
cave_lobby_is_seated :: proc(self: ^CaveLobby) -> gd.Bool {
	return gd.Bool(self.ses.joined)
}

// The world reached this peer: my avatar + everyone else's + chest + door.
@(gd_method)
cave_lobby_world_ready :: proc(self: ^CaveLobby) -> gd.Bool {
	return gd.Bool(
		self.started &&
		self.me_spel != nil &&
		len(self.spelunkers) >= ksess.session_count(&self.ses, connected_only = true) &&
		len(self.chests) > 0 &&
		len(self.doors) > 0,
	)
}

// 0 none, 1 chest, 2 door — what the prompt points at (drives test walking).
@(gd_method)
cave_lobby_prompt_kind :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(self.target_kind)
}

@(gd_method)
cave_lobby_my_gems :: proc(self: ^CaveLobby) -> gd.Int {
	if self.me_spel == nil {return 0}
	return gd.Int(kitems.count_of(self.me_spel.bag[:], GEM))
}

@(gd_method)
cave_lobby_my_torches :: proc(self: ^CaveLobby) -> gd.Int {
	if self.me_spel == nil {return 0}
	return gd.Int(kitems.count_of(self.me_spel.bag[:], TORCH))
}

// Every gem this peer can see anywhere — the conservation check.
@(gd_method)
cave_lobby_world_gems :: proc(self: ^CaveLobby) -> gd.Int {
	total := 0
	for _, c in self.chests {
		total += kitems.count_of(c.slots[:], GEM)
	}
	for _, sp in self.spelunkers {
		total += kitems.count_of(sp.bag[:], GEM)
	}
	return gd.Int(total)
}

// Items still sitting in chests, as this peer sees them.
@(gd_method)
cave_lobby_chest_items :: proc(self: ^CaveLobby) -> gd.Int {
	total := 0
	for _, c in self.chests {
		for s in c.slots {
			total += int(s.count)
		}
	}
	return gd.Int(total)
}

@(gd_method)
cave_lobby_door_open :: proc(self: ^CaveLobby) -> gd.Bool {
	for _, d in self.doors {
		return gd.Bool(d.open)
	}
	return false
}

@(gd_method)
cave_lobby_my_pos :: proc(self: ^CaveLobby) -> gd.Vector2 {
	if self.me_spel == nil {return {}}
	return {self.me_spel.x, self.me_spel.y}
}

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
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import netgd "godot:kit/netgd"
import "core:fmt"
import "core:math"
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
PICKUP_TYPE :: ksess.Entity_Type(4)

WALK_SPEED :: f32(120) // px/s

// ---- combat (phase 4) ----

MAX_HP :: i32(100)
MAX_STAMINA :: i32(10)
ROCK_ABILITY :: kcombat.Ability_Def{name = "rock", cooldown = 20, cost = 3} // 1s at 20 Hz
ROCK_DMG :: i32(35)
ROCK_SPEED :: f32(12) // px per net tick
ROCK_TTL :: u16(24) // ~288 px of flight
BODY_RADIUS :: f32(14)
RESPAWN_TICKS :: 60 // 3s in the grave
CHILL :: u8(1) // rocks chill what they don't kill
SPAWN_X :: f32(80)
SPAWN_Y :: f32(120)

// Command indices = @(gd_command) declaration order in spelunker.odin.
SPEL_CMD_DROP :: u16(0)
SPEL_CMD_THROW :: u16(1)

// kit/comms rides SES_APP tag 0; fire announcements ride tag 1.
TAG_FIRE :: u8(1)
FIRE_ROCK :: u8(1)

// One rock in the HOST's authoritative sim — the only rocks that hurt.
Cave_Rock :: struct {
	p:       kcombat.Projectile,
	shooter: knet.Player_Id,
}

// One rock on THIS screen — a peer-owned visual running the same sim math.
// The shooter's spawns at cast time (zero RTT: press fire, see rock);
// everyone else's spawns on the host's fire announcement.
Visual_Rock :: struct {
	p:       kcombat.Projectile,
	shooter: knet.Player_Id,
	node:    gd.Label,
}

// Injected receive latency for the acid run (CAVE_LATENCY ms): packets
// buffer here before routing — the suite proves casts feel instant anyway.
Delayed_Packet :: struct {
	due:  f64,
	from: int,
	data: []u8,
}

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
	pickups:     map[knet.Net_Id]^Pickup,
	nodes:       map[knet.Net_Id]gd.Node, // for freeing on despawn
	avatar_of:   map[knet.Player_Id]knet.Net_Id,
	me_spel:     ^Spelunker, // my avatar (nil until spawned)
	started:     bool, // the world is live
	walking:     bool, // headless drivers steer via walk_to
	walk_target: gd.Vector2,
	target_id:   knet.Net_Id, // what the prompt points at right now
	target_kind: int, // 0 none, 1 chest, 2 door, 3 pickup

	// ---- combat (phase 4) ----
	cols:       kcombat.Combat_Cols, // host: the auto-published ledger columns
	flying:     [dynamic]Cave_Rock, // host: the authoritative rock sim
	visuals:    [dynamic]Visual_Rock, // every peer: the rocks on THIS screen
	respawn_at: map[knet.Net_Id]int, // host: resurrection clocks
	host_ticks: int, // host: game ticks elapsed
	hud_hp:     kui.Health_Bar,
	hud_ab:     kui.Ability_Bar,
	score:      kui.Score,
	was_dead:   bool, // owner-side respawn edge detector
	issue_at:   f64, // when my last command left (confirm latency proof)

	// injected latency (CAVE_LATENCY ms; tests only)
	latency: f64,
	delayed: [dynamic]Delayed_Packet,
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
	self.hud_hp = kui.hp_make(self.owner)
	self.hud_ab = kui.abilities_make(self.owner, 2)
	self.score = kui.score_make(self.owner)
	self.latency = f64(env_int("CAVE_LATENCY", 0)) / 1000.0
	ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
	ksess.session_set_command_hook(&self.ses, self, cave_command_hook)
	ksess.session_app_route(&self.ses, TAG_FIRE, self, cave_on_fire)
	gd.print_str("CAVE_UI_READY")
}

@(private = "file")
env_int :: proc(name: cstring, fallback: int) -> int {
	if v, ok := strconv.parse_int(env_string(name, "")); ok {
		return v
	}
	return fallback
}

@(private = "file")
refresh_hud :: proc(self: ^CaveLobby) {
	if self.me_spel == nil {return}
	kui.hp_refresh(&self.hud_hp, hp_view(self.me_spel), MAX_HP)
	defs := [?]kcombat.Ability_Def{ROCK_ABILITY}
	kui.abilities_refresh(&self.hud_ab, defs[:], self.me_spel.cds[:], self.me_spel.stamina)
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
		return sp, &spelunker_command_set
	case PICKUP_TYPE:
		node := spawn_node(self, "res://scripts/pickup.odin")
		self.nodes[id] = node
		p := rt.script_of(node, Pickup)
		p.net_id = id
		self.pickups[id] = p
		return p, &pickup_command_set
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
	delete_key(&self.pickups, id)
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

// Host: mint the Pickup a drop left behind (the dropper's scratch tells us
// what; the host's view of their avatar tells us where).
@(private = "file")
cave_mint_pickup :: proc(self: ^CaveLobby, sp: ^Spelunker) {
	node := spawn_node(self, "res://scripts/pickup.odin")
	p := rt.script_of(node, Pickup)
	p.x = sp.x + 24 // at their feet, not under them
	p.y = sp.y
	p.item = sp.last_drop.item
	p.count = sp.last_drop.count
	p.net_id = ksess.session_spawn(&self.ses, PICKUP_TYPE, p, &pickup_command_set)
	self.pickups[p.net_id] = p
	self.nodes[p.net_id] = node
}

// Host: a grab succeeded — credit the grabber and remove the pickup for
// everyone (clients free through the factory; the host frees its own node).
@(private = "file")
cave_settle_grab :: proc(self: ^CaveLobby, player: knet.Player_Id, id: knet.Net_Id, p: ^Pickup) {
	if av, has := self.avatar_of[player]; has {
		sp := self.spelunkers[av]
		_ = kitems.add(&self.table, sp.bag[:], p.last_grab.item, p.last_grab.count)
	}
	ksess.session_despawn(&self.ses, id)
	if node, ok := self.nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&self.nodes, id)
	}
	delete_key(&self.pickups, id)
}

// Client commands land here right after they execute on the host.
@(private = "file")
cave_command_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	self := cast(^CaveLobby)user
	if !ok {return}
	if chest, is_chest := self.chests[entity]; is_chest && cmd == 0 {
		cave_credit(self, player, chest)
		return
	}
	if sp, is_spel := self.spelunkers[entity]; is_spel {
		switch cmd {
		case SPEL_CMD_DROP:
			cave_mint_pickup(self, sp)
		case SPEL_CMD_THROW:
			cave_launch_rock(self, player, sp)
		}
		return
	}
	if p, is_pickup := self.pickups[entity]; is_pickup && cmd == 0 {
		cave_settle_grab(self, player, entity, p)
	}
}

@(private = "file")
rock_fire :: proc(shooter: knet.Player_Id, sp: ^Spelunker) -> (f: kcombat.Fire, ok: bool) {
	dx, dy := sp.aim.x, sp.aim.y
	n := math.sqrt(dx * dx + dy * dy)
	if n == 0 {return}
	return kcombat.Fire {
			shooter = shooter,
			origin  = {sp.x, sp.y, 0},
			vel     = {dx / n * ROCK_SPEED, dy / n * ROCK_SPEED, 0},
			ttl     = ROCK_TTL,
			kind    = FIRE_ROCK,
		},
		true
}

// A rock on THIS screen: a plain Label (no entity, no wire) flown by the
// same sim math the host's damage runs on.
@(private = "file")
add_visual_rock :: proc(self: ^CaveLobby, f: kcombat.Fire) {
	node := gd.new_label()
	gd.set_string(cast(gd.Object)node, "text", "\xE2\x97\x8F") // ●
	gd.add_child(self.world, cast(gd.Node)node)
	gd.control_set_position(cast(gd.Control)node, {f.origin.x, f.origin.y}, false)
	append(&self.visuals, Visual_Rock {
		p = kcombat.Projectile{pos = f.origin, vel = f.vel, left = f.ttl},
		shooter = f.shooter,
		node = node,
	})
}

// Host: a confirmed throw launches the AUTHORITATIVE rock (the only kind
// that hurts), shows the host its own visual, and announces the fire so
// every other peer draws theirs. The shooter's visual already flew at cast
// time — it skips its own announcement.
@(private = "file")
cave_launch_rock :: proc(self: ^CaveLobby, shooter: knet.Player_Id, sp: ^Spelunker) {
	f, ok := rock_fire(shooter, sp)
	if !ok {return}
	append(&self.flying, Cave_Rock{p = kcombat.Projectile{pos = f.origin, vel = f.vel, left = f.ttl}, shooter = shooter})
	if shooter != self.ses.me {
		add_visual_rock(self, f) // the host's screen (its own casts drew at cast time)
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	kcombat.fire_write(&w, f)
	ksess.session_app_send(&self.ses, ksess.BROADCAST_PEER, TAG_FIRE, knet.writer_bytes(&w))
}

// Every peer: a fire announcement — draw the rock, unless it's my own echo
// (mine flew at cast time). Only the host authors these.
@(private = "file")
cave_on_fire :: proc(user: rawptr, from: knet.Player_Id, from_peer: int, r: ^knet.Reader) {
	self := cast(^CaveLobby)user
	if self.ses.is_host || from_peer != ksess.HOST_PEER {return}
	f, ok := kcombat.fire_read(r)
	if !ok || f.shooter == self.ses.me {return}
	add_visual_rock(self, f)
}

// Every peer, once per net tick: fly MY screen's rocks and, on visual
// contact with a body, play the impact NOW — a predicted hp dip (overlay,
// never the replicated field) and the effect. Truth arrives a beat later
// and squares the number; if the host saw a miss, the dip heals back.
@(private = "file")
cave_visual_tick :: proc(self: ^CaveLobby) {
	now := now_s()
	for i := 0; i < len(self.visuals); {
		v := &self.visuals[i]
		from := v.p.pos
		alive := kcombat.projectile_step(&v.p)
		gd.control_set_position(cast(gd.Control)v.node, {v.p.pos.x, v.p.pos.y}, false)

		targets := make([dynamic]kcombat.Target, context.temp_allocator)
		for id, sp in self.spelunkers {
			if id == self.avatar_of[v.shooter] || sp.hp <= 0 {continue}
			append(&targets, kcombat.Target{id = u32(id), pos = {sp.x, sp.y, 0}, radius = BODY_RADIUS})
		}
		if hit, hit_ok := kcombat.projectile_hit(from, v.p.vel, targets[:]); hit_ok {
			victim := self.spelunkers[knet.Net_Id(hit.id)]
			truth := victim.hp
			kcombat.php_note_hit(&victim.php, victim.hp, ROCK_DMG, now)
			view := kcombat.php_display(&victim.php, victim.hp, now)
			refresh_hud(self)
			gd.print_str(fmt.tprintf("CAVE_IMPACT mine=%v view=%d truth=%d", v.shooter == self.ses.me, view, truth))
			gd.node_queue_free(cast(gd.Node)v.node)
			unordered_remove(&self.visuals, i)
			continue
		}
		if !alive {
			gd.node_queue_free(cast(gd.Node)v.node)
			unordered_remove(&self.visuals, i)
			continue
		}
		i += 1
	}
}

// Host: death spills the whole bag onto the floor — phase 3's pickups are
// suddenly a combat mechanic. (Loot the fallen, or guard them.)
@(private = "file")
cave_spill_bag :: proc(self: ^CaveLobby, sp: ^Spelunker) {
	for slot in sp.bag {
		if slot.item == kitems.ITEM_NONE {continue}
		sp.last_drop = slot
		cave_mint_pickup(self, sp)
	}
	sp.bag = {}
}

// The host's game tick (once per 20 Hz net tick): decay ability clocks and
// effects, regen stamina, fly the rocks, deal the damage, credit the
// ledger, run the respawn clocks. Deltas carry every consequence.
@(private = "file")
cave_host_tick :: proc(self: ^CaveLobby) {
	self.host_ticks += 1
	for _, sp in self.spelunkers {
		kcombat.abilities_tick(sp.cds[:])
		kcombat.effects_tick(sp.fx[:])
		if self.host_ticks % 20 == 0 && sp.hp > 0 {
			sp.stamina = min(sp.stamina + 1, MAX_STAMINA)
		}
	}

	for i := 0; i < len(self.flying); {
		fl := &self.flying[i]
		from := fl.p.pos
		alive := kcombat.projectile_step(&fl.p)

		targets := make([dynamic]kcombat.Target, context.temp_allocator)
		for id, sp in self.spelunkers {
			if id == self.avatar_of[fl.shooter] || sp.hp <= 0 {continue}
			append(&targets, kcombat.Target{id = u32(id), pos = {sp.x, sp.y, 0}, radius = BODY_RADIUS})
		}
		if hit, hit_ok := kcombat.projectile_hit(from, fl.p.vel, targets[:]); hit_ok {
			victim_id := knet.Net_Id(hit.id)
			victim := self.spelunkers[victim_id]
			kcombat.credit_hit(&self.ses, self.cols, fl.shooter, ROCK_DMG)
			if kcombat.hit(&victim.hp, ROCK_DMG) {
				victim_pid := knet.PLAYER_ID_INVALID
				for pid, av in self.avatar_of {
					if av == victim_id {victim_pid = pid}
				}
				kcombat.credit_kill(&self.ses, self.cols, fl.shooter, victim_pid)
				cave_spill_bag(self, victim)
				self.respawn_at[victim_id] = self.host_ticks + RESPAWN_TICKS
			} else {
				_ = kcombat.effects_add(victim.fx[:], CHILL, 50, 40) // 2s of cold feet
			}
			unordered_remove(&self.flying, i)
			continue
		}
		if !alive {
			unordered_remove(&self.flying, i)
			continue
		}
		i += 1
	}

	// Respawn restores STATE; position is owner-streamed, so each OWNER
	// walks out of the grave themselves (see the was_dead edge in process).
	for id, at in self.respawn_at {
		if self.host_ticks >= at {
			sp := self.spelunkers[id]
			sp.hp = MAX_HP
			sp.stamina = MAX_STAMINA
			delete_key(&self.respawn_at, id)
		}
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
		sp.x = SPAWN_X + f32(i) * 60
		sp.y = SPAWN_Y
		sp.hp = MAX_HP
		sp.stamina = MAX_STAMINA
		i += 1
		id := ksess.session_spawn(&self.ses, SPEL_TYPE, sp, &spelunker_command_set, owner = p.id)
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
		refresh_hud(self)
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
	self.cols = kcombat.combat_columns(&self.ses) // the ledger, on the scoreboard
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

	// The fake wire delivers (acid runs only; self.latency == 0 otherwise).
	for len(self.delayed) > 0 && self.delayed[0].due <= now_s() {
		pkt := self.delayed[0]
		ordered_remove(&self.delayed, 0)
		r := knet.reader_make(pkt.data)
		if knet.read_u8(&r) == MSG_SESSION {
			ksess.session_handle_packet(&self.ses, pkt.from, &r)
		}
		delete(pkt.data)
	}

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

	ticks, _ := ksess.session_tick(&self.ses, delta, now_s())
	if self.started {
		for _ in 0 ..< ticks {
			// Visuals fly FIRST: on the host, the impact you see and the
			// damage the authority deals share a tick — noting the dip
			// before the truth applies lets the overlay consume it cleanly.
			cave_visual_tick(self) // every peer flies its own screen's rocks
			if self.ses.is_host {
				cave_host_tick(self)
			}
		}
	}

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
			kui.score_refresh(&self.score, &self.ses)
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
				refresh_hud(self)
			}
		case ksess.Ev_Command_Confirmed:
			dt_ms := self.issue_at > 0 ? int((now_s() - self.issue_at) * 1000) : 0
			gd.print_str(fmt.tprintf("CAVE_CONFIRM dt_ms=%d", dt_ms))
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
		// Owner-side respawn: hp coming back is the signal to walk out of
		// the grave — position is owner-streamed, only I can move me.
		if self.me_spel.hp <= 0 {
			if !self.was_dead {
				self.was_dead = true
				self.walking = false
				gd.print_str("CAVE_DIED")
			}
		} else if self.was_dead {
			self.was_dead = false
			self.me_spel.x = SPAWN_X
			self.me_spel.y = SPAWN_Y
			gd.print_str("CAVE_RESPAWNED")
		}
		if self.me_spel.hp > 0 {
			drive_spelunker(self, delta)
		}
		update_prompt(self)
		refresh_hud(self) // live bar + cooldown text (hosts get no state events)
	}
}

// Move MY spelunker: keyboard when a human is at the wheel, walk_to targets
// when a test drives. Writing x/y is the ENTIRE author surface for motion —
// they are owner-streamed fields.
@(private = "file")
drive_spelunker :: proc(self: ^CaveLobby, delta: f64) {
	me := self.me_spel
	speed := WALK_SPEED
	if chill, chilled := kcombat.effect_of(me.fx[:], CHILL); chilled {
		speed *= 1 - f32(chill.power) / 100 // cold feet
	}
	step := speed * f32(delta)
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
	for id, p in self.pickups {
		append(&cands, kinter.Candidate{id = u32(id), pos = {p.x, p.y, 0}})
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
	} else if _, is_pickup := self.pickups[self.target_id]; is_pickup {
		self.target_kind = 3
		p := self.pickups[self.target_id]
		kui.prompt_set(&self.prompt, fmt.ctprintf("E — pick up %s", kitems.items_name(&self.table, p.item)))
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
	case 3:
		id := self.target_id
		p := self.pickups[id]
		applied := pickup_grab_cmd(&self.ses.ctx, p, me.x, me.y)
		if applied && self.ses.is_host {
			cave_settle_grab(self, self.ses.me, id, p) // the authority's inline half
			kui.inv_refresh(&self.inv, me.bag[:], &self.table)
		}
		gd.print_str(fmt.tprintf("CAVE_GRAB applied=%v", applied))
	}
}

// Throw a rock toward (dx, dy) — the ONE author-surface call, every peer.
// The cast bites on this frame's screen; the host's rock flies ~RTT later.
@(gd_method)
cave_lobby_throw :: proc(self: ^CaveLobby, dx: gd.Float, dy: gd.Float) {
	if !self.started || self.me_spel == nil {return}
	self.issue_at = now_s()
	applied := spelunker_throw_cmd(&self.ses.ctx, self.me_spel, f32(dx), f32(dy))
	if applied {
		// Press fire, SEE rock — my visual flies this frame, no round trip.
		if f, ok := rock_fire(self.ses.me, self.me_spel); ok {
			add_visual_rock(self, f)
		}
		if self.ses.is_host {
			cave_launch_rock(self, self.ses.me, self.me_spel) // the authority's inline half
		}
	}
	refresh_hud(self)
	gd.print_str(fmt.tprintf("CAVE_THROW predicted=%v stamina=%d cd=%d", applied, self.me_spel.stamina, self.me_spel.cds[0]))
}

@(gd_method)
cave_lobby_show_score :: proc(self: ^CaveLobby, visible: gd.Bool) {
	kui.score_show(&self.score, bool(visible))
	kui.score_refresh(&self.score, &self.ses)
}

// Drop a bag slot at my feet (a real game binds this to a key / drag-out).
@(gd_method)
cave_lobby_drop :: proc(self: ^CaveLobby, slot: gd.Int) {
	if !self.started || self.me_spel == nil {return}
	applied := spelunker_drop_cmd(&self.ses.ctx, self.me_spel, i32(slot))
	if applied && self.ses.is_host {
		cave_mint_pickup(self, self.me_spel) // the authority's inline half
	}
	kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
	gd.print_str(fmt.tprintf("CAVE_DROP applied=%v", applied))
}

@(gd_method)
cave_lobby_pickups :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(len(self.pickups))
}

@(gd_method)
cave_lobby_rocks :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(len(self.visuals))
}

// What this peer DRAWS for an hp: truth plus any predicted dip from impacts
// seen on this screen (kcombat.php_display squares it with deltas).
@(private = "file")
hp_view :: proc(sp: ^Spelunker) -> i32 {
	return kcombat.php_display(&sp.php, sp.hp, now_s())
}

@(gd_method)
cave_lobby_my_hp :: proc(self: ^CaveLobby) -> gd.Int {
	if self.me_spel == nil {return 0}
	return gd.Int(hp_view(self.me_spel))
}

// The other spelunker's hp, as this peer sees it (2-player test scaffolding).
@(gd_method)
cave_lobby_their_hp :: proc(self: ^CaveLobby) -> gd.Int {
	my_av := self.avatar_of[self.ses.me]
	for id, sp in self.spelunkers {
		if id != my_av {
			return gd.Int(hp_view(sp))
		}
	}
	return 0
}

@(gd_method)
cave_lobby_can_throw :: proc(self: ^CaveLobby) -> gd.Bool {
	me := self.me_spel
	if me == nil || me.hp <= 0 {return false}
	return gd.Bool(kcombat.ability_ready(me.cds[:], 0) && me.stamina >= ROCK_ABILITY.cost)
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
	view := netgd.pba_view(&packet)
	if self.latency > 0 {
		// The acid run: buffer everything, route when the fake wire delivers.
		data := make([]u8, len(view))
		copy(data, view)
		append(&self.delayed, Delayed_Packet{due = now_s() + self.latency, from = int(id), data = data})
		return
	}
	r := knet.reader_make(view)
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
	for _, p in self.pickups {
		if p.item == GEM {
			total += int(p.count)
		}
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

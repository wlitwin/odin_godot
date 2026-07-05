package cavecrawl_scripts

// A human at the wheel: runtime key/mouse bindings and the player verbs they
// drive. Every verb is a plain @(gd_method), so the SAME surface serves the
// keyboard, the test drivers, and any future touch UI — keys are just
// another driver.

import gd "godot:godot"
import "godot:gdext"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kitems "godot:kit/items"
import kui "godot:kit/ui"
import "core:fmt"

// The demo's controls, registered at runtime (the InputMap autoload pattern)
// so the example stays a bare scene with no project-level input map.
install_controls :: proc "contextless" () {
	if gd.has_action("cave_throw") {return} // scene reloads re-run ready
	bind :: proc "contextless" (action: cstring, keys: ..i64) {
		gd.add_action(action)
		for k in keys {
			gd.action_add_key(action, k)
		}
	}
	bind("cave_left", i64('A'), i64(gd.Key.Left))
	bind("cave_right", i64('D'), i64(gd.Key.Right))
	bind("cave_up", i64('W'), i64(gd.Key.Up))
	bind("cave_down", i64('S'), i64(gd.Key.Down))
	bind("cave_interact", i64('E'))
	bind("cave_drop", i64('Q'))
	bind("cave_heal", i64('R'))
	bind("cave_score", i64(gd.Key.Tab))
	bind("cave_talk", i64(gd.Key.Enter))
	bind("cave_throw", i64(gd.Key.Space))
	gd.action_add_mouse_button("cave_throw", i64(gd.Mouse_Button.Left))
}

// Poll the controls each frame. Skipped entirely while the chat line has
// focus: "wasd" there is a word, not a stroll (the click that focuses chat
// also lands here as has_focus before this frame's poll, so it never
// doubles as a throw).
poll_controls :: proc(self: ^CaveLobby) {
	if bool(gd.control_has_focus(cast(gd.Control)self.chat.input, false)) {return}
	if gd.is_action_just_pressed("cave_talk") && !self.chat_sent {
		gd.control_grab_focus(cast(gd.Control)self.chat.input, false)
		return
	}
	self.chat_sent = false
	if gd.is_action_just_pressed("cave_score") {
		cave_lobby_show_score(self, true)
	}
	if gd.is_action_just_released("cave_score") {
		cave_lobby_show_score(self, false)
	}
	me := self.me_spel
	if me == nil || me.hp <= 0 {return} // the dead may chat and spectate
	if gd.is_action_just_pressed("cave_interact") {
		cave_lobby_interact(self)
	}
	if gd.is_action_just_pressed("cave_heal") {
		cave_lobby_heal(self)
	}
	if gd.is_action_just_pressed("cave_drop") {
		for s, i in me.bag {
			if s.item != kitems.ITEM_NONE {
				cave_lobby_drop(self, gd.Int(i))
				break
			}
		}
	}
	if gd.is_action_just_pressed("cave_throw") {
		m := gd.viewport_get_mouse_position(gd.node_get_viewport(self.owner))
		cave_lobby_throw(self, gd.Float(m.x - me.x), gd.Float(m.y - me.y))
	}
}

// Move MY spelunker: keyboard when a human is at the wheel, walk_to targets
// when a test drives. Writing x/y is the ENTIRE author surface for motion —
// they are owner-streamed fields.
drive_spelunker :: proc(self: ^CaveLobby, delta: f64) {
	me := self.me_spel
	speed := WALK_SPEED
	if chill, chilled := kcombat.effect_of(me.fx[:], CHILL); chilled {
		speed *= 1 - f32(chill.power) / 100 // cold feet
	}
	step := speed * f32(delta)
	dir := gd.Vector2{}
	if !bool(gd.control_has_focus(cast(gd.Control)self.chat.input, false)) {
		dir = gd.get_vector("cave_left", "cave_right", "cave_up", "cave_down", 0.2)
	}
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
	me := self.me_spel
	// Gate BEFORE issuing, like the bandage: a refused prediction still
	// rides the wire for the authority's verdict, so a spammed fire button
	// would flood the host with doomed casts (and each rejection is wire
	// noise the game never needed to make).
	if me.hp <= 0 || !kcombat.ability_ready(me.cds[:], 0) || me.stamina < ROCK_ABILITY.cost {return}
	self.issue_at = now_s()
	applied := spelunker_throw_cmd(&self.ses.ctx, me, f32(dx), f32(dy), me.x, me.y)
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

// Bandage up (ability slot 1) — predicted like every cast: the hp climbs on
// this frame's screen, the host's authoritative re-run confirms it.
@(gd_method)
cave_lobby_heal :: proc(self: ^CaveLobby) {
	if !self.started || self.me_spel == nil {return}
	me := self.me_spel
	// Gate BEFORE issuing: a refused prediction still rides the wire for
	// the authority's verdict (clients don't self-censor), so a key held
	// at full hp would otherwise flood the host with doomed commands.
	if me.hp <= 0 || me.hp >= MAX_HP || !kcombat.ability_ready(me.cds[:], 1) || me.stamina < HEAL_ABILITY.cost {return}
	applied := spelunker_heal_cmd(&self.ses.ctx, self.me_spel)
	refresh_hud(self)
	if applied {
		gd.print_str(fmt.tprintf("CAVE_HEAL applied=true hp=%d stamina=%d", self.me_spel.hp, self.me_spel.stamina))
	}
}

@(gd_method)
cave_lobby_show_score :: proc(self: ^CaveLobby, visible: gd.Bool) {
	kui.score_show(&self.score, bool(visible))
	kui.score_refresh(&self.score, &self.ses)
}

// Drop a bag slot at my feet (Q drops the first filled slot; a real game
// binds this to a hotbar selection / drag-out).
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
	gd.control_release_focus(cast(gd.Control)self.chat.input) // Enter sends AND puts the keys back on the wheel
	self.chat_sent = true
}

// Drop a marker (the test's stand-in for a ping keybind; kind 1 = "look here").
@(gd_method)
cave_lobby_mark :: proc(self: ^CaveLobby) {
	if !self.running {return}
	kcomms.comms_ping(&self.comms, 1, {1, 2, 3})
}

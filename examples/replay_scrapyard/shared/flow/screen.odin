package scrapyard_flow

import "core:math"

Screen_State :: struct {
	ready: bool,
	epoch: u64,
	run: u32,
	floor: u8,
	boss: bool,
	kick, fade, pulse: f32,
}

Screen_View :: struct {
	zoom_add, fade, vignette: f32,
}

screen_kick :: proc(state: ^Screen_State, amount: f32, motion_off: bool) {
	if !motion_off {
		state.kick = max(state.kick, amount)
	}
}

screen_step :: proc(
	state: ^Screen_State,
	epoch: u64,
	run: u32,
	floor: u8,
	hp: u8,
	active, boss, motion_off: bool,
	dt: f64,
) -> Screen_View {
	if !state.ready || state.epoch != epoch {
		state^ = {
			ready = true,
			epoch = epoch,
			run = run,
			floor = floor,
			boss = boss,
		}
	} else {
		if state.run != run || state.floor != floor {
			state.fade = 1
			state.kick = 0
		}
		if active && boss && !state.boss {
			screen_kick(state, 0.1, motion_off)
		}
		state.run, state.floor, state.boss = run, floor, boss
	}
	if motion_off || !active {
		state.kick = 0
	}
	state.kick = max(0, state.kick - f32(dt) * 0.5)
	state.fade = max(0, state.fade - f32(dt) * 2.2)
	alpha := f32(0)
	if active && hp > 0 && hp <= 3 {
		state.pulse += f32(dt) * (3.4 - f32(hp) * 0.6)
		pulse := (1 + math.sin(state.pulse)) * 0.5
		alpha = 0.2 + (1 - f32(hp) / 4) * 0.22 + pulse * 0.16
	}
	return {state.kick, state.fade, alpha}
}

package duel

import r "godot:replay"
import d "godot:replay/deterministic"
import rb "godot:replay/p2p"

CONTENT :: u64(0x524450325044554c)

Fighter :: struct {position, velocity: d.Vec2, hp: u8, facing: i8, cooldown: u16, respawn: u64, life: u32}
Bullet :: struct {position: d.Vec2, speed: d.Fixed, owner: u8, remaining: u16, id: u32}
World :: struct {tick: u64, fighters: [2]Fighter, bullets: r.Pool(Bullet, 16), rng: r.Rng, shots, hits: u32, kills: [2]u32}
Input :: struct {axis: i8, jump, fire: bool}
Event_Kind :: enum u8 {Shot, Hit, Death, Respawn}
Event :: struct {kind: Event_Kind, seat: u8, id: u32, position: d.Vec2}

initial :: proc(seed: u64 = 1) -> World {
	return {rng = r.rng_make(seed), fighters = {
		{position = {260 * 256, 300 * 256}, hp = 3, facing = 1, life = 1},
		{position = {380 * 256, 300 * 256}, hp = 3, facing = -1, life = 1},
	}}
}

model :: proc() -> rb.Model(World, Input, Event, 2) {
	return {step = step, input_valid = input_valid, state_valid = state_valid,
	        hold = proc(i: Input) -> Input {return {axis = i.axis}}}
}

input_valid :: proc(i: Input) -> bool {return i.axis >= -1 && i.axis <= 1}
state_valid :: proc(w: World) -> bool {
	for fighter in w.fighters {
		if fighter.hp > 3 || fighter.life == 0 || (fighter.facing != -1 && fighter.facing != 1) || fighter.cooldown > 12 ||
		   fighter.position[0] < 20 * 256 || fighter.position[0] > 620 * 256 || fighter.position[1] < 20 * 256 || fighter.position[1] > 300 * 256 {return false}
	}
	count := u32(0)
	for b, i in w.bullets.values {if w.bullets.alive[i] {
		count += 1
		if b.owner > 1 || b.remaining == 0 || b.remaining > 40 || b.id == 0 || w.bullets.generations[i] == 0 {return false}
	}}
	return count == w.bullets.count
}

step :: proc(w: ^World, inputs: [2]Input, ctx: ^r.Step(Event)) {
	if ctx.tick > max(u64) - 120 {r.abort(ctx); return}
	w.tick = ctx.tick
	for &f, i in w.fighters {
		if f.hp == 0 {
			if ctx.tick >= f.respawn {
				if f.life == max(u32) {r.abort(ctx); return}
				f.life += 1; f.hp, f.respawn, f.velocity = 3, 0, {}
				f.position = {i == 0 ? d.Fixed(260 * 256) : d.Fixed(380 * 256), 300 * 256}
				r.emit(ctx, u64(i + 1), 4, Event{.Respawn, u8(i), f.life, f.position})
			}
			continue
		}
		input := inputs[i]
		if f.cooldown > 0 {f.cooldown -= 1}
		if input.axis != 0 {f.facing = input.axis}
		f.velocity[0] = d.Fixed(i32(input.axis) * 3 * 256)
		if input.jump && f.position[1] == 300 * 256 {f.velocity[1] = -6 * 256}
		vy, velocity_ok := d.add(f.velocity[1], 50)
		if !velocity_ok {r.abort(ctx); return}; f.velocity[1] = vy
		for axis in 0 ..< 2 {
			next, ok := d.add(f.position[axis], f.velocity[axis])
			if !ok {r.abort(ctx); return}
			f.position[axis] = clamp(next, d.Fixed(20 * 256), axis == 0 ? d.Fixed(620 * 256) : d.Fixed(300 * 256))
		}
		if f.position[1] == 300 * 256 {f.velocity[1] = 0}
		if input.fire && f.cooldown == 0 {
			if w.shots == max(u32) {r.abort(ctx); return}
			w.shots += 1; f.cooldown = 12
			speed := d.Fixed((8 * 256 + i32(r.rng_next(&w.rng) % 65)) * i32(f.facing))
			position := f.position; position[0] += d.Fixed(i32(f.facing) * 12 * 256)
			_, ok := r.pool_insert(&w.bullets, Bullet{position, speed, u8(i), 40, w.shots})
			if !ok {r.abort(ctx); return}
			r.emit(ctx, u64(i + 1), 1, Event{.Shot, u8(i), w.shots, position})
		}
	}
	// All bullets resolve before damage is applied: same-tick trades are symmetric.
	damage: [2]u8
	for &bullet, i in w.bullets.values {if w.bullets.alive[i] {
		x, ok := d.add(bullet.position[0], bullet.speed)
		if !ok {r.abort(ctx); return}; bullet.position[0] = x
		bullet.remaining -= 1
		victim := 1 - int(bullet.owner)
		fighter := w.fighters[victim]
		dx := i64(bullet.position[0]) - i64(fighter.position[0]); dy := i64(bullet.position[1]) - i64(fighter.position[1])
		hit := fighter.hp > 0 && dx >= -10 * 256 && dx <= 10 * 256 && dy >= -18 * 256 && dy <= 18 * 256
		if hit {
			damage[victim] += 1
			if w.hits == max(u32) {r.abort(ctx); return}; w.hits += 1
			r.emit(ctx, 100 + u64(bullet.id), 2, Event{.Hit, u8(victim), bullet.id, fighter.position})
		}
		if hit || bullet.remaining == 0 || x < 0 || x > 640 * 256 {r.pool_remove(&w.bullets, r.Handle(Bullet){u32(i), w.bullets.generations[i]})}
	}}
	for amount, i in damage {if amount > 0 {
		f := &w.fighters[i]
		f.hp = f.hp > amount ? f.hp - amount : 0
		if f.hp == 0 {
			winner := 1 - i
			if w.kills[winner] == max(u32) {r.abort(ctx); return}; w.kills[winner] += 1
			f.respawn = ctx.tick + 90 + r.rng_next(&w.rng) % 31
			r.emit(ctx, u64(i + 1), 3, Event{.Death, u8(i), f.life, f.position})
		}
	}}
}

corpus_input :: proc(tick: u64, seat: int) -> Input {
	// Recorded deterministic controller: firing trades, jumps, approaches/retreats.
	phase := tick % 360
	axis := i8(0)
	if phase >= 180 && phase < 210 {axis = seat == 0 ? 1 : -1}
	if phase >= 210 && phase < 240 {axis = seat == 0 ? -1 : 1}
	return {axis = axis, fire = tick % 12 == 0, jump = tick % 240 == 120 + u64(seat) * 15}
}

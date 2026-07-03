package flow

// flow — a tiny data-driven sequencer for time/signal-based gameplay logic.
//
// GDScript's `await someSignal()` keeps "do A, wait, do B, wait, run X and Y in
// parallel, wait, do C" localized in one function and composing via nested awaits.
// Native Odin scripts are AOT-compiled with NO interpreter to suspend (see
// docs on the async story), so the idiomatic substitute is to make the sequence
// into DATA: one `Action` tree whose cursors/timers ARE the "where am I" state,
// ticked once per frame.
//
// Versus a pile of ad-hoc `timer: f32` / `phase: int` fields, the whole running
// orchestration is a single value you can:
//   * inspect   — print exactly where a sequence is,
//   * serialize — save/load mid-sequence (it's plain data, no suspended stack),
//   * pause/step/reset — just stop ticking, or `reset()` to run it again.
//
// HOT RELOAD: an `Action` tree stored in a script's struct caches raw proc pointers
// (`Call.fn`, `Custom.on_tick`, `Wait_Until.pred`) — and a `wait_flag` holds a raw `^bool`,
// which additionally dangles after a CHANGED-layout reload (the struct is reallocated).
// A same-layout hot reload preserves the
// struct in place, so those pointers survive pointing at the OLD (stale) code. This only
// bites a script that runs in the editor (`//gd:tool`) or is reloaded at runtime; if that's
// you, rebuild the tree in the `<class>_reload` hook so it re-captures fresh pointers:
//     boss_reload :: proc(self: ^Boss) { self.script = build_boss_sequence() }
// (Ordinary gameplay scripts never hot-reload themselves, so this is a non-issue for them.)
//
// It is engine-agnostic (no `godot` import) so it unit-tests standalone, but is
// built to be driven straight from a script's `_process`/`_physics_process`:
//
//     Boss :: struct { using node: gd.Node2d, script: flow.Action, hit: bool }
//
//     boss_ready :: proc(self: ^Boss) {
//         self.script = flow.sequence(
//             flow.call(spawn_wave),
//             flow.wait(1.5),
//             flow.parallel(flow.call(slide_in), flow.call(fade_in)),  // X and Y together...
//             flow.wait_flag(&self.hit),                               // ...then wait (signal sets `hit`)
//             flow.call(start_fight),
//         )
//     }
//
//     boss_physics_process :: proc(self: ^Boss, delta: f64) {
//         flow.tick(&self.script, self, delta)   // self is the rawptr ctx every callback receives
//     }
//
// Callbacks receive the `ctx` rawptr passed to `tick` (cast it back to your
// script struct, exactly like the generated lifecycle trampolines do). Odin procs
// are not closures, so any state a step needs is reached through `ctx`.
//
// ALLOCATION: the `sequence`/`parallel`/`race`/`repeat` builders allocate their
// child slices/bodies from `context.allocator`. Set it to an arena before building
// to keep a whole tree in one block and free it in one shot, or call `destroy` to
// release exactly what the builders allocated. Leaf builders (`wait`, `call`,
// `wait_flag`, `wait_until`) allocate nothing.

import "core:slice"

// Status is the result of ticking an Action (and, recursively, its subtree).
Status :: enum {
	Running, // not finished yet — tick again next frame
	Done, // finished; safe to stop ticking (re-ticking a Done node is a harmless no-op)
}

// Join selects when a Parallel is considered finished.
Join :: enum {
	All, // finished when every child is Done   (`parallel`)
	Any, // finished when the first child is Done (`race`)
}

Action_Proc :: proc(ctx: rawptr)
Predicate :: proc(ctx: rawptr) -> bool

// Custom step hooks (see `custom`): drive any external behavior — engine tweens,
// async tasks, … — without adding a variant to this closed union. `on_tick` runs
// each frame and returns the step's status; `on_reset`/`on_free` are optional.
Custom_Tick :: proc(data: rawptr, ctx: rawptr, dt: f64) -> Status
Custom_Reset :: proc(data: rawptr)
Custom_Free :: proc(data: rawptr)

// Action is one node in an orchestration tree. Every node LATCHES its Done state
// (a `Call` fires once, a satisfied wait stays satisfied, a finished `Parallel`
// stops ticking its children) so that re-ticking a finished node — which a
// `parallel` does to its already-done children while a slow sibling runs — never
// repeats a side effect or regresses.
Action :: union {
	Wait, // wait a fixed number of seconds
	Wait_Flag, // wait until a bool the caller owns becomes true (the `await signal` shape)
	Wait_Until, // wait until a predicate over ctx returns true
	Wait_Frames, // wait a fixed number of ticks regardless of delta
	Call, // run a proc once, then complete instantly
	Sequence, // run children in order
	Parallel, // run children together (see Join)
	Repeat, // run a body N times (or forever), resetting it between iterations
	Custom, // an externally-defined step (the engine-bridge escape hatch)
}

Wait :: struct {
	duration: f64,
	elapsed:  f64,
}
Wait_Flag :: struct {
	flag:      ^bool,
	satisfied: bool,
}
Wait_Until :: struct {
	pred:      Predicate,
	satisfied: bool,
}
Call :: struct {
	fn:    Action_Proc,
	fired: bool,
}
Sequence :: struct {
	steps:  []Action,
	cursor: int,
}
Parallel :: struct {
	steps:    []Action,
	join:     Join,
	finished: bool, // latch: once Done, children are never ticked again (see advance)
}
Repeat :: struct {
	body:      ^Action,
	total:     int,
	remaining: int,
}
Wait_Frames :: struct {
	total:     int,
	remaining: int,
}
Custom :: struct {
	data:     rawptr,
	on_tick:  Custom_Tick,
	on_reset: Custom_Reset,
	on_free:  Custom_Free,
}

// ---- builders -------------------------------------------------------------

// wait completes after `seconds` of accumulated delta. Overshoot is carried to
// the next step (see `advance`), so the total time of a chain of waits stays
// accurate regardless of frame rate.
wait :: proc(seconds: f64) -> Action {
	return Wait{duration = seconds}
}

// wait_flag completes once `flag^` is observed true. Point it at a field your
// signal handler sets (e.g. `&self.landed`); this is the native stand-in for
// `await some_signal`. Once satisfied it stays satisfied even if the flag flips
// back, so it is safe inside `parallel`.
wait_flag :: proc(flag: ^bool) -> Action {
	return Wait_Flag{flag = flag}
}

// wait_until completes once `pred(ctx)` returns true. Use for arbitrary game
// conditions ("hp < 0", "in range").
wait_until :: proc(pred: Predicate) -> Action {
	return Wait_Until{pred = pred}
}

// call runs `fn(ctx)` exactly once and completes in the same tick.
call :: proc(fn: Action_Proc) -> Action {
	return Call{fn = fn}
}

// sequence runs its children one after another, advancing when each completes.
sequence :: proc(steps: ..Action) -> Action {
	return Sequence{steps = slice.clone(steps)}
}

// parallel runs all children every tick and completes when ALL are Done.
parallel :: proc(steps: ..Action) -> Action {
	return Parallel{steps = slice.clone(steps), join = .All}
}

// race runs all children every tick and completes when the FIRST one is Done
// (e.g. `race(wait_flag(&landed), wait(5))` = "the signal, or a 5s timeout").
// The losers are CANCELLED at that moment: each unfinished branch is reset, so
// it never runs further and a Custom step gets its on_reset (flowgd.tween kills
// its still-running Tween).
race :: proc(steps: ..Action) -> Action {
	return Parallel{steps = slice.clone(steps), join = .Any}
}

// repeat runs `body` `times` times, resetting it between iterations. It advances
// at most one iteration per tick (so a `forever(call(...))` can't spin a frame).
repeat :: proc(times: int, body: Action) -> Action {
	b := new(Action)
	b^ = body
	return Repeat{body = b, total = times, remaining = times}
}

// forever runs `body` over and over, resetting between iterations; never Done.
forever :: proc(body: Action) -> Action {
	b := new(Action)
	b^ = body
	return Repeat{body = b, total = -1, remaining = -1}
}

// wait_frames completes after `n` ticks regardless of their delta — for the
// common "do this next frame" / "let the engine settle one frame" need. `n <= 0`
// completes immediately.
wait_frames :: proc(n: int) -> Action {
	return Wait_Frames{total = n, remaining = n}
}

// custom is the escape hatch for step kinds this package doesn't know about
// (engine tweens, async tasks, …) — it keeps the `Action` union closed and
// engine-agnostic while still being open for extension. `on_tick(data, ctx, dt)`
// runs each frame and returns .Running/.Done; optional `on_reset`/`on_free` let
// the step take part in `reset`/`destroy`. You own `data` — free it in `on_free`.
// The `flowgd` package's Tween step is built on this.
custom :: proc(
	data: rawptr,
	on_tick: Custom_Tick,
	on_reset: Custom_Reset = nil,
	on_free: Custom_Free = nil,
) -> Action {
	return Custom{data = data, on_tick = on_tick, on_reset = on_reset, on_free = on_free}
}

// ---- runtime --------------------------------------------------------------

// tick advances `a` by `dt` seconds and returns whether it (and its whole
// subtree) has finished. Drive it from `_process`/`_physics_process` with the
// frame delta; pass your script pointer as `ctx`. Either callback is fine — the
// sequencer just accumulates whatever delta it is given, so a variable `_process`
// delta is as correct as a fixed `_physics_process` one.
tick :: proc(a: ^Action, ctx: rawptr, dt: f64) -> Status {
	status, _ := advance(a, ctx, dt)
	return status
}

// advance is tick's worker. It also reports `leftover`: the slice of `dt` not
// consumed because a timed step finished partway through the frame. A Sequence
// feeds that leftover to its NEXT step instead of restarting it at the full dt,
// so a chain of waits keeps accurate total time regardless of frame rate (no
// per-step rounding drift). Instant steps (Call) and satisfied event gates
// (Wait_Flag/Wait_Until) consume no time and pass the whole dt through.
@(private)
advance :: proc(a: ^Action, ctx: rawptr, dt: f64) -> (status: Status, leftover: f64) {
	// `&v` binds a MUTABLE reference into the union's active variant, so field
	// writes below land directly in `a^` — no copy-back needed.
	switch &v in a^ {
	case Wait:
		v.elapsed += dt
		if v.elapsed >= v.duration {
			return .Done, v.elapsed - v.duration // hand the overshoot to the next step
		}
		return .Running, 0

	case Wait_Flag:
		if !v.satisfied && v.flag != nil && v.flag^ {
			v.satisfied = true
		}
		return (.Done if v.satisfied else .Running), (dt if v.satisfied else 0)

	case Wait_Until:
		if !v.satisfied && v.pred != nil && v.pred(ctx) {
			v.satisfied = true
		}
		return (.Done if v.satisfied else .Running), (dt if v.satisfied else 0)

	case Wait_Frames:
		if v.remaining <= 0 {
			return .Done, dt
		}
		v.remaining -= 1
		return .Running, 0

	case Call:
		if !v.fired {
			if v.fn != nil {
				v.fn(ctx)
			}
			v.fired = true
		}
		return .Done, dt

	case Custom:
		if v.on_tick == nil {
			return .Done, dt
		}
		// a Custom step owns its own timing and can't report a sub-frame
		// remainder, so it consumes the whole frame (like a Parallel barrier).
		return v.on_tick(v.data, ctx, dt), 0

	case Sequence:
		rem := dt
		for v.cursor < len(v.steps) {
			step_status, step_leftover := advance(&v.steps[v.cursor], ctx, rem)
			if step_status == .Running {
				return .Running, 0
			}
			rem = step_leftover
			v.cursor += 1
		}
		return .Done, rem

	case Parallel:
		// The latch matters: a parent Parallel re-ticks Done children while slow
		// siblings run. Without it a finished `race` would keep advancing its
		// LOSING branches, eventually firing their side effects.
		if v.finished {
			return .Done, dt
		}
		if len(v.steps) == 0 {
			v.finished = true
			return .Done, dt
		}
		done_count := 0
		for i in 0 ..< len(v.steps) {
			step_status, _ := advance(&v.steps[i], ctx, dt)
			if step_status == .Done {
				done_count += 1
			}
		}
		target := len(v.steps) if v.join == .All else 1
		if done_count >= target {
			v.finished = true
			if v.join == .Any {
				// race semantics: first winner cancels the losers. Resetting an
				// unfinished branch rewinds it and gives Custom steps their
				// cancellation hook (e.g. flowgd.tween kills a running Tween).
				for i in 0 ..< len(v.steps) {
					if !is_done(&v.steps[i]) {
						reset(&v.steps[i])
					}
				}
			}
			// a parallel is a barrier: its children consumed differing amounts of
			// dt, so there is no single remainder to carry — report none.
			return .Done, 0
		}
		return .Running, 0

	case Repeat:
		if v.remaining == 0 {
			return .Done, dt
		}
		body_status, body_leftover := advance(v.body, ctx, dt)
		if body_status == .Done {
			if v.remaining > 0 {
				v.remaining -= 1
			}
			if v.remaining == 0 {
				return .Done, body_leftover
			}
			reset(v.body)
			// one iteration per tick (keeps `forever(call(...))` from spinning a
			// frame); the sub-frame remainder between iterations is dropped.
		}
		return .Running, 0
	}

	return .Done, dt // nil / empty action is treated as already finished
}

// is_done reports whether a node has finished WITHOUT ticking it (no side
// effects). Used by a completing race to tell winners from cancellable losers.
// A Custom step's doneness isn't observable from outside, so it reports false —
// which means a race always resets its Custom children; on_reset must therefore
// tolerate being called after completion (flowgd.tween does: killing a finished
// Tween is a no-op).
@(private)
is_done :: proc(a: ^Action) -> bool {
	switch v in a^ {
	case Wait:
		return v.elapsed >= v.duration
	case Wait_Flag:
		return v.satisfied
	case Wait_Until:
		return v.satisfied
	case Wait_Frames:
		return v.remaining <= 0
	case Call:
		return v.fired
	case Custom:
		return false
	case Sequence:
		return v.cursor >= len(v.steps)
	case Parallel:
		return v.finished
	case Repeat:
		return v.remaining == 0
	}
	return true // nil / empty action
}

// reset rewinds a tree's cursors, timers, and one-shot latches so it can run
// again from the start. It does NOT touch caller-owned state (a `wait_flag`'s
// bool stays as the caller left it; only the internal "already satisfied" latch
// clears). Structure and allocations are preserved, so this is cheap.
reset :: proc(a: ^Action) {
	switch &v in a^ {
	case Wait:
		v.elapsed = 0
	case Wait_Flag:
		v.satisfied = false
	case Wait_Until:
		v.satisfied = false
	case Wait_Frames:
		v.remaining = v.total
	case Call:
		v.fired = false
	case Custom:
		if v.on_reset != nil {
			v.on_reset(v.data)
		}
	case Sequence:
		v.cursor = 0
		for i in 0 ..< len(v.steps) {
			reset(&v.steps[i])
		}
	case Parallel:
		v.finished = false
		for i in 0 ..< len(v.steps) {
			reset(&v.steps[i])
		}
	case Repeat:
		v.remaining = v.total
		reset(v.body)
	}
}

// destroy frees the child slices and repeat bodies the builders allocated, from
// the same allocator they used. Skip it entirely if you built into an arena and
// intend to `free_all` that arena instead.
destroy :: proc(a: ^Action, allocator := context.allocator) {
	#partial switch &v in a^ {
	case Sequence:
		for i in 0 ..< len(v.steps) {
			destroy(&v.steps[i], allocator)
		}
		delete(v.steps, allocator)
	case Parallel:
		for i in 0 ..< len(v.steps) {
			destroy(&v.steps[i], allocator)
		}
		delete(v.steps, allocator)
	case Repeat:
		destroy(v.body, allocator)
		free(v.body, allocator)
	case Custom:
		if v.on_free != nil {
			v.on_free(v.data)
		}
	}
}

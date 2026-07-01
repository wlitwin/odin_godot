package flow_test

// Standalone tests for the `flow` sequencer — no Godot runtime needed.
//
//   odin test tests/flow -collection:godot=$PWD
//
// (run from the repo root; `godot:` is the same collection the scripts use).

import "core:testing"
import flow "godot:flow"

State :: struct {
	log:    [dynamic]string,
	landed: bool,
	hp:     int,
}

@(test)
sequence_runs_in_order_with_timing :: proc(t: ^testing.T) {
	s := State{}
	defer delete(s.log)
	a := flow.sequence(
		flow.call(proc(ctx: rawptr) {append(&(cast(^State)ctx).log, "start")}),
		flow.wait(1.0),
		flow.call(proc(ctx: rawptr) {append(&(cast(^State)ctx).log, "after")}),
	)
	defer flow.destroy(&a)

	// 0.5s in: "start" fired, the wait is still counting.
	testing.expect_value(t, flow.tick(&a, &s, 0.5), flow.Status.Running)
	testing.expect_value(t, len(s.log), 1)

	// another 0.6s (1.1s total): wait elapses, "after" fires, whole tree done.
	testing.expect_value(t, flow.tick(&a, &s, 0.6), flow.Status.Done)
	testing.expect_value(t, len(s.log), 2)
	testing.expect_value(t, s.log[0], "start")
	testing.expect_value(t, s.log[1], "after")
}

@(test)
call_fires_exactly_once :: proc(t: ^testing.T) {
	s := State{}
	a := flow.call(proc(ctx: rawptr) {(cast(^State)ctx).hp += 1})
	defer flow.destroy(&a)

	testing.expect_value(t, flow.tick(&a, &s, 0.016), flow.Status.Done)
	// re-ticking a Done node must not re-run the side effect.
	flow.tick(&a, &s, 0.016)
	flow.tick(&a, &s, 0.016)
	testing.expect_value(t, s.hp, 1)
}

@(test)
parallel_waits_for_all_race_takes_first :: proc(t: ^testing.T) {
	s := State{}

	all := flow.parallel(flow.wait(1.0), flow.wait(2.0))
	defer flow.destroy(&all)
	testing.expect_value(t, flow.tick(&all, &s, 1.5), flow.Status.Running) // slow child still going
	testing.expect_value(t, flow.tick(&all, &s, 1.0), flow.Status.Done)

	first := flow.race(flow.wait(1.0), flow.wait(5.0))
	defer flow.destroy(&first)
	testing.expect_value(t, flow.tick(&first, &s, 1.0), flow.Status.Done) // fastest wins
}

@(test)
wait_flag_is_the_await_signal_shape :: proc(t: ^testing.T) {
	s := State{}
	defer delete(s.log)
	a := flow.sequence(
		flow.wait_flag(&s.landed), // a signal handler would set s.landed
		flow.call(proc(ctx: rawptr) {append(&(cast(^State)ctx).log, "go")}),
	)
	defer flow.destroy(&a)

	testing.expect_value(t, flow.tick(&a, &s, 0.1), flow.Status.Running)
	testing.expect_value(t, len(s.log), 0)

	s.landed = true // "signal" arrives
	testing.expect_value(t, flow.tick(&a, &s, 0.1), flow.Status.Done)
	testing.expect_value(t, len(s.log), 1)
}

@(test)
repeat_runs_body_n_times :: proc(t: ^testing.T) {
	s := State{}
	a := flow.repeat(3, flow.call(proc(ctx: rawptr) {(cast(^State)ctx).hp += 1}))
	defer flow.destroy(&a)

	// `repeat` advances one iteration per tick: two Running, then Done on the third.
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Running)
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Running)
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Done)
	testing.expect_value(t, s.hp, 3)
}

@(test)
wait_chain_carries_remainder :: proc(t: ^testing.T) {
	s := State{}
	// three 1s waits = 3s total, ticked at dt=0.75 (exactly representable, so the
	// tick count is exact). With remainder carry the chain finishes in ceil(3/0.75)
	// = 4 ticks; WITHOUT carry each wait would independently round up to 2 ticks = 6.
	a := flow.sequence(flow.wait(1.0), flow.wait(1.0), flow.wait(1.0))
	defer flow.destroy(&a)

	ticks := 0
	for flow.tick(&a, &s, 0.75) == .Running {
		ticks += 1
	}
	ticks += 1 // count the tick that returned Done
	testing.expect_value(t, ticks, 4)
}

@(test)
wait_frames_blocks_n_ticks :: proc(t: ^testing.T) {
	s := State{}
	a := flow.sequence(
		flow.wait_frames(2),
		flow.call(proc(ctx: rawptr) {(cast(^State)ctx).hp += 1}),
	)
	defer flow.destroy(&a)

	// two frames of waiting, regardless of delta, then the call fires.
	testing.expect_value(t, flow.tick(&a, &s, 99.0), flow.Status.Running)
	testing.expect_value(t, flow.tick(&a, &s, 99.0), flow.Status.Running)
	testing.expect_value(t, s.hp, 0)
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Done)
	testing.expect_value(t, s.hp, 1)
}

// A toy Custom step proving the escape hatch (what flowgd.tween is built on):
// "complete after being ticked `target` times", with reset/free participation.
Counter :: struct {
	count:  int,
	target: int,
	freed:  ^bool,
}

@(test)
custom_step_drives_external_state :: proc(t: ^testing.T) {
	freed := false
	c := new(Counter)
	c.target = 2
	c.freed = &freed

	a := flow.custom(
	c,
	proc(data: rawptr, ctx: rawptr, dt: f64) -> flow.Status {
		cc := cast(^Counter)data
		cc.count += 1
		return .Done if cc.count >= cc.target else .Running
	},
	proc(data: rawptr) {(cast(^Counter)data).count = 0}, 	// on_reset
	proc(data: rawptr) { 	// on_free
		cc := cast(^Counter)data
		cc.freed^ = true
		free(cc)
	},
	)

	s := State{}
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Running)
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Done)

	flow.reset(&a) // on_reset zeroes the counter
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Running)
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Done)

	flow.destroy(&a) // on_free runs
	testing.expect_value(t, freed, true)
}

@(test)
race_losers_are_cancelled_even_when_reticked :: proc(t: ^testing.T) {
	// Regression: a Done race used to keep advancing its LOSING branches when a
	// parent parallel re-ticked it, eventually firing the loser's side effects.
	s := State{}
	a := flow.parallel(
		flow.race(
			flow.wait(0.1), // wins immediately-ish
			flow.sequence(flow.wait(1.0), flow.call(proc(ctx: rawptr) {(cast(^State)ctx).hp += 100})),
		),
		flow.wait(10.0), // slow sibling keeps the parallel re-ticking the done race
	)
	defer flow.destroy(&a)

	// tick far past the loser's 1s wait; the race finished at 0.1s, so the
	// loser must have been cancelled and its call must never fire.
	for _ in 0 ..< 30 {
		flow.tick(&a, &s, 0.5)
	}
	testing.expect_value(t, s.hp, 0)
}

@(test)
race_winner_side_effects_still_fire :: proc(t: ^testing.T) {
	s := State{}
	a := flow.race(
		flow.sequence(flow.wait(0.5), flow.call(proc(ctx: rawptr) {(cast(^State)ctx).hp += 1})),
		flow.wait(9.0),
	)
	defer flow.destroy(&a)

	testing.expect_value(t, flow.tick(&a, &s, 0.6), flow.Status.Done)
	testing.expect_value(t, s.hp, 1)
	// re-ticking the latched race is inert.
	flow.tick(&a, &s, 5.0)
	testing.expect_value(t, s.hp, 1)
}

@(test)
reset_reruns_a_finished_tree :: proc(t: ^testing.T) {
	s := State{}
	a := flow.sequence(flow.call(proc(ctx: rawptr) {(cast(^State)ctx).hp += 1}))
	defer flow.destroy(&a)

	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Done)
	testing.expect_value(t, s.hp, 1)

	flow.reset(&a)
	testing.expect_value(t, flow.tick(&a, &s, 0.0), flow.Status.Done)
	testing.expect_value(t, s.hp, 2) // the call fired again after reset
}

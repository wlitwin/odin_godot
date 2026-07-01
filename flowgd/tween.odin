package flowgd

// flowgd — Godot engine steps for the `flow` sequencer.
//
// `flow` itself is engine-agnostic (so it unit-tests standalone); this package is
// the thin bridge that plugs Godot-specific steps into it via `flow.custom`. Mix
// them freely with the core builders:
//
//     self.script = flow.sequence(
//         flow.call(spawn),
//         flowgd.tween(self.owner, proc(t: gd.Tween, ctx: rawptr) {
//             self := cast(^Boss)ctx
//             gd.tween_tween_property(t, self.sprite, "position", target, 0.4)
//         }),
//         flow.wait_frames(1),         // let the engine settle one frame
//         flow.call(start_fight),
//     )
//
// AWAIT-SIGNAL: there is intentionally no `wait_signal` here. The idiomatic native
// way to "await a signal" in this binding is a `@(gd_connect)` handler that sets a
// bool, consumed by core `flow.wait_flag(&self.flag)` — no runtime Callable needed.

import "godot:flow"
import gd "godot:godot"

// Tween_Configure adds tweeners (property/interval/callback/...) to the freshly
// created Tween. `ctx` is the same pointer passed to `flow.tick` (your script).
Tween_Configure :: proc(t: gd.Tween, ctx: rawptr)

@(private)
Tween_Step :: struct {
	node:      gd.Node,
	configure: Tween_Configure,
	tween:     gd.Tween,
	started:   bool,
}

// tween builds a flow step that, on its first tick, calls `node.create_tween()`,
// hands the new Tween to `configure` to populate, then completes once the Tween
// stops running (or becomes invalid, e.g. its node left the tree). It participates
// in `flow.reset` (re-runs the animation) and `flow.destroy`/cancellation (kills a
// still-running Tween). The Tween is processed by the SceneTree, not by flow — this
// step only kicks it off and watches for completion.
tween :: proc(node: gd.Node, configure: Tween_Configure) -> flow.Action {
	s := new(Tween_Step)
	s.node = node
	s.configure = configure
	return flow.custom(s, tween_tick, tween_reset, tween_free)
}

@(private)
tween_tick :: proc(data: rawptr, ctx: rawptr, dt: f64) -> flow.Status {
	s := cast(^Tween_Step)data
	if s.node == nil {
		return .Done
	}
	if !s.started {
		s.tween = gd.node_create_tween(s.node)
		if s.configure != nil {
			s.configure(s.tween, ctx)
		}
		s.started = true
		return .Running // give the SceneTree at least one frame to run it
	}
	if s.tween == nil || !gd.tween_is_valid(s.tween) {
		return .Done
	}
	return .Running if gd.tween_is_running(s.tween) else .Done
}

@(private)
tween_reset :: proc(data: rawptr) {
	s := cast(^Tween_Step)data
	if s.started && s.tween != nil && gd.tween_is_valid(s.tween) {
		gd.tween_kill(s.tween)
	}
	s.tween = nil
	s.started = false
}

@(private)
tween_free :: proc(data: rawptr) {
	s := cast(^Tween_Step)data
	if s.started && s.tween != nil && gd.tween_is_valid(s.tween) {
		gd.tween_kill(s.tween)
	}
	free(s)
}

package replay_test

import "core:testing"
import "core:reflect"
import r "godot:replay"

fold_step :: proc(w: ^u32, amount: u32, ctx: ^r.Step(u32)) {
	w^ += amount
	r.emit(ctx, 1, 1, u32(3))
	r.emit_fold(ctx, 1, 1, amount, proc(a, b: u32) -> (u32, bool) {return a + b, b < 100})
}

@(test)
folded_occurrences_replay_and_failed_folds_abort_the_candidate :: proc(t: ^testing.T) {
	timeline: r.Timeline(u32, u32, u32)
	r.init(&timeline, r.Frame(u32){}, fold_step); defer r.destroy(&timeline)
	testing.expect_value(t, r.advance(&timeline, u32(2)).error, r.Error.None)
	events: [1]r.Occurrence(u32)
	count, err := r.copy_events(&timeline, 1, events[:]); testing.expect_value(t, err, r.Error.None)
	testing.expect_value(t, count, 1); testing.expect_value(t, events[0].value, u32(5)); identity := events[0].id
	testing.expect_value(t, r.revise_input(&timeline, 1, u32(4)).error, r.Error.None)
	r.copy_events(&timeline, 1, events[:]); testing.expect_value(t, events[0].value, u32(7)); testing.expect_value(t, events[0].id, identity)
	before, _ := r.current(&timeline)
	testing.expect_value(t, r.advance(&timeline, u32(100)).error, r.Error.Aborted)
	after, _ := r.current(&timeline); testing.expect(t, reflect.equal(before, after))
	testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
}

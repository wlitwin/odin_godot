package replay_scrapyard_test

import "core:testing"
import r "godot:replay"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
actor_cues_ignore_confirmation_replay_and_cancel_only_the_current_identity :: proc(t: ^testing.T) {
	cue: flow.Actor_Cue
	first := r.Event_Id{epoch = 1, tick = 10, source = 1, key = 2}
	flow.actor_cue(&cue, .Begin, first, 1, 0.09)
	cue.left = 0.03
	flow.actor_cue(&cue, .Confirm, first, 1, 0.09); testing.expect_value(t, cue.left, f32(0.03))
	flow.actor_cue(&cue, .Update, first, 1, 0.09); testing.expect_value(t, cue.left, f32(0.03))
	flow.actor_cue(&cue, .Cancel, first, 1, 0.09); testing.expect_value(t, cue.left, f32(0))
	flow.actor_cue(&cue, .Begin, first, 1, 0.09); testing.expect_value(t, cue.left, f32(0))
	second := first; second.tick = 11
	flow.actor_cue(&cue, .Begin, second, 1, 0.09)
	flow.actor_cue(&cue, .Cancel, first, 1, 0.09); testing.expect_value(t, cue.left, f32(0.09))
	new_epoch := first; new_epoch.epoch = 2; new_epoch.tick = 1
	flow.actor_cue(&cue, .Begin, new_epoch, 2, 0.3)
	flow.actor_cue(&cue, .Begin, second, 1, 0.09); testing.expect_value(t, cue.id, new_epoch)
}

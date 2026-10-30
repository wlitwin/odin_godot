package replay_scrapyard_test

import "core:testing"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
downed_camera_keeps_a_living_target_and_reselects_on_loss :: proc(t: ^testing.T) {
	w := yard()
	w.players[1] = w.players[0]; w.players[1].generation = 7
	w.players[2] = w.players[0]; w.players[2].generation = 9
	testing.expect_value(t, flow.camera_target(&w, 1, {3, 9}), flow.Camera_Target{1, 1})
	w.players[0].hp = 0
	testing.expect_value(t, flow.camera_target(&w, 1, {}), flow.Camera_Target{2, 7})
	testing.expect_value(t, flow.camera_target(&w, 1, {3, 9}), flow.Camera_Target{3, 9})
	w.players[2].connected = false
	testing.expect_value(t, flow.camera_target(&w, 1, {3, 9}), flow.Camera_Target{2, 7})
	w.players[1].generation = 8
	testing.expect_value(t, flow.camera_target(&w, 1, {2, 7}), flow.Camera_Target{2, 8})
	w.players[1].hp = 0
	testing.expect_value(t, flow.camera_target(&w, 1, {2, 8}), flow.Camera_Target{1, 1})
	w.players[0].hp = 4
	testing.expect_value(t, flow.camera_target(&w, 1, {2, 8}), flow.Camera_Target{1, 1})
	testing.expect_value(t, flow.camera_target(&w, 0, {2, 8}), flow.Camera_Target{})
	w.players[0].in_yard = false
	testing.expect_value(t, flow.camera_target(&w, 1, {2, 8}), flow.Camera_Target{})
}

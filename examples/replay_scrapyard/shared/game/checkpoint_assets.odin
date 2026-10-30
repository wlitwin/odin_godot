package scrapyard_game

import a "godot:replay/assets"
import net "godot:replay/net"

// Complete external dependency set: current sprays and executable accepted
// declarations that may install a new reference after the saved frame.
checkpoint_assets :: proc(_: rawptr, root: []u8, dst: []a.Ref, codec: ^net.Checkpoint_Codec = nil) -> (int, bool) {
	cp: net.Checkpoint(World, Control, Action, SEATS)
	defer net.checkpoint_destroy(&cp)
	if net.checkpoint_decode(&cp, root, model(), CONTENT, codec = codec) != .None {
		return 0, false
	}
	count := 0
	for player in cp.frame.state.players {
		if !checkpoint_ref(&count, dst, player.spray.image) {
			return 0, false
		}
	}
	for action in cp.actions {
		if action.reason == .None && action.value.kind == .Set_Spray {
			if !checkpoint_ref(&count, dst, action.value.image) {
				return 0, false
			}
		}
	}
	return count, true
}

@(private)
checkpoint_ref :: proc(count: ^int, dst: []a.Ref, ref: a.Ref) -> bool {
	if ref == (a.Ref{}) {
		return true
	}
	if !spray_ref_valid(ref) {
		return false
	}
	for previous in dst[:count^] {
		if previous == ref {
			return true
		}
	}
	if count^ == len(dst) {
		return false
	}
	dst[count^] = ref
	count^ += 1
	return true
}

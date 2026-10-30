package scrapyard_flow

import co "godot:replay/comms"
import game "../game"
import arena "../arena"

// Scrapyard is 2D. The marker's spare Z coordinate carries floor and the
// low run bit; the nonzero tag carries the other run bits. This represents
// every u32 run/u8 floor exactly, including run zero and max(u32).
ping_payload :: proc(w: ^game.World, position: [2]f32) -> co.Payload {
	return {
		kind = .Marker,
		tag = w.run | 1,
		position = {position[0], position[1], f32(w.floor) + f32(w.run & 1) * 256},
	}
}

ping_valid :: proc(w: ^game.World, payload: co.Payload) -> bool {
	if w.stage == .Staging || !co.valid(payload) || payload.kind != .Marker {
		return false
	}
	expected := ping_payload(w, {})
	return(
		payload.tag == expected.tag &&
		payload.position[2] == expected.position[2] &&
		payload.position[0] >= 0 &&
		payload.position[0] <= arena.WIDTH &&
		payload.position[1] >= 0 &&
		payload.position[1] <= arena.HEIGHT \
	)
}

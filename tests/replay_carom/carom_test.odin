package carom_test

import "core:testing"
import "core:reflect"
import p "godot:replay/play"

@(test)
faces_reflect_and_inside_origins_exit :: proc(t: ^testing.T) {
	boxes := [1]p.Aabb2{{{100, 100}, {120, 120}}}
	face := p.first_face2({80, 110}, {30, 0}, 1, boxes[:])
	testing.expect(t, face.hit); testing.expect_value(t, face.normal, [2]f32{-1, 0})
	testing.expect(t, !p.first_face2({110, 110}, {30, 0}, 1, boxes[:]).hit)
	body := p.Carom2{{80, 110}, {30, 0}}
	testing.expect(t, p.carom2_step(&body, 1, 0.72, 0.1, {{0, 0}, {200, 200}}, boxes[:]))
	testing.expect(t, body.position[0] < 100 && body.velocity[0] < 0)
}

@(test)
invalid_inputs_preserve_body_and_beam_projection_keeps_endpoints :: proc(t: ^testing.T) {
	body := p.Carom2{{10, 10}, {5, 0}}; before := body
	testing.expect(t, !p.carom2_step(&body, -1, 0.72, 0.1, {{0, 0}, {200, 200}}, nil))
	testing.expect(t, reflect.equal(body, before))
	at, hit := p.beam_circle({0, 0}, {10, 0}, {12, 0}, 2)
	testing.expect(t, hit); testing.expect_value(t, at, f32(1))
}

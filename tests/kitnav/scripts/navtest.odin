//gd:extends Node2D
//gd:class NavTest
package kitnav_scripts

// kit/nav adapter test. The scene's walkable area is a U — two arms joined
// only along the bottom — so the path from arm-tip to arm-tip MUST bend
// down and around (a straight line would cross the void). Then a kit/ai
// walker follows it with the next_point cursor, proving the two packages
// compose into "brain walks a navmesh".

import gd "godot:godot"
import kai "godot:kit/ai"
import knav "godot:kit/nav"
import "core:fmt"

FROM :: [3]f32{50, 50, 0} // left arm tip
TO :: [3]f32{250, 50, 0} // right arm tip

NavTest :: struct {
	owner:  gd.Node,
	frames: int,
	state:  int, // 0 pending, 1 ok, -1 fail (the driver polls)
}

nav_test_process :: proc(self: ^NavTest, delta: f64) {
	if self.state != 0 {return}
	self.frames += 1
	if self.frames < 5 {return} // regions sync on the server's physics cadence

	path := knav.path_2d(self.owner, FROM, TO, context.temp_allocator)
	max_y := f32(0)
	for p in path {
		max_y = max(max_y, p.y)
	}
	bent := len(path) >= 3 && max_y >= 190
	if !bent {
		if self.frames < 300 {
			return // the map may still be syncing; ask again next frame
		}
		gd.print_str(fmt.tprintf("NAVTEST_FAIL path_len=%d max_y=%.0f", len(path), max_y))
		self.state = -1
		return
	}
	gd.print_str(fmt.tprintf("NAVTEST bent=true path_len=%d max_y=%.0f", len(path), max_y))

	// A brain following it: kit/ai steps + the kit/nav cursor.
	pos := FROM
	idx := 0
	for _ in 0 ..< 500 {
		goal, ok := knav.next_point(path, &idx, pos, 8)
		if !ok {break}
		pos, _ = kai.step_toward(pos, goal, 5)
	}
	walked := kai.in_reach(pos, TO, 10)
	gd.print_str(fmt.tprintf("NAVTEST_WALKED ok=%v x=%.0f y=%.0f", walked, pos.x, pos.y))
	self.state = walked ? 1 : -1
}

@(gd_method)
nav_test_state :: proc(self: ^NavTest) -> gd.Int {
	return gd.Int(self.state)
}

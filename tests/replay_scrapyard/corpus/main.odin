package main

import "core:fmt"
import arena "../../../examples/replay_scrapyard/shared/arena"

main :: proc() {
	seeds := [4]u32{0, 1, 1337, 0xffffffff}
	floors := [3]u8{1, 2, 7}
	for seed in seeds {for floor in floors {
		layout := arena.generate(seed, floor)
		fmt.printf("ARENA %d %d %d\n", seed, floor, layout.checksum)
		for c in layout.covers {fmt.printf("C %d %d %d %d %d\n", c.kind, c.x, c.y, c.w, c.h)}
		directions := [4][2]f32{{1, 0}, {-1, 1}, {0.4, -0.7}, {0, 1}}
		for direction, scenario in directions {
			position := [2]f32{840, 544}
			for _ in 0 ..< 240 {position = arena.move(&layout, position, direction * 220, 1.0 / 60)}
			fmt.printf("MOVE %d %d %d\n", scenario, transmute(u32)position[0], transmute(u32)position[1])
		}
	}}
}

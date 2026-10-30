package scrapyard_arena

import "core:reflect"

WIDTH :: f32(1920)

HEIGHT :: f32(1088)

MARGIN :: f32(24)

COVER_COUNT :: 30

Junk :: struct {
	region: [4]u16,
	width, height: u8,
	art_dy: i8,
}

JUNK :: [10]Junk {
	{{70, 54, 35, 26}, 66, 46, 0},
	{{183, 53, 17, 27}, 30, 44, 0},
	{{73, 93, 15, 35}, 26, 58, 0},
	{{150, 51, 21, 29}, 38, 48, 0},
	{{132, 8, 23, 24}, 44, 40, 0},
	{{281, 219, 16, 53}, 20, 32, -43},
	{{73, 93, 15, 35}, 20, 32, -19},
	{{3, 52, 25, 28}, 46, 46, 0},
	{{211, 144, 25, 64}, 28, 26, -46},
	{{281, 219, 16, 53}, 20, 22, -38},
}

Cover :: struct {
	x, y: u16,
	w, h, kind: u8,
}

Layout :: struct {
	key: u32,
	checksum: u64,
	covers: [COVER_COUNT]Cover,
}

key :: proc(seed: u32, floor: u8) -> u32 {
	return seed ~ (u32(floor) * 0x9E3779B9)
}

splitmix32 :: proc(state: ^u32) -> u32 {
	state^ += 0x9E3779B9
	z := state^
	z = (z ~ (z >> 16)) * 0x21F0AAAD
	z = (z ~ (z >> 15)) * 0x735A2D97
	return z ~ (z >> 15)
}

generate :: proc(seed: u32, floor: u8) -> Layout {
	result := Layout {
		key = key(seed, floor),
		checksum = 0xCBF29CE484222325,
	}
	rng := result.key
	junk := JUNK
	for &cover in result.covers {
		kind := splitmix32(&rng) % u32(len(JUNK))
		def := junk[kind]
		x := 80 + splitmix32(&rng) % u32(WIDTH - 280)
		y := 80 + splitmix32(&rng) % u32(HEIGHT - 280)
		cover = {u16(x), u16(y), def.width, def.height, u8(kind)}
		values := [5]u32{kind, x, y, u32(def.width), u32(def.height)}
		for value in values {
			result.checksum = (result.checksum ~ u64(value)) * 0x100000001B3
		}
	}
	return result
}

valid :: proc(layout: Layout, seed: u32, floor: u8) -> bool {
	return reflect.equal(layout, generate(seed, floor))
}

// Original ordered axis-slide and inside-cover forgiveness, using value inputs.
// Rendering and collision share this same generated cover identity/footprint.
block_cover :: proc(covers: []Cover, from, wanted: [2]f32, radius: f32) -> [2]f32 {
	next := wanted
	for c in covers {
		x0, x1 := f32(c.x) - radius, f32(c.x) + f32(c.w) + radius
		y0, y1 := f32(c.y) - radius, f32(c.y) + f32(c.h) + radius
		if from[0] > x0 && from[0] < x1 && from[1] > y0 && from[1] < y1 {
			continue
		}
		if next[0] > x0 && next[0] < x1 && from[1] > y0 && from[1] < y1 {
			next[0] = from[0]
		}
		if next[0] > x0 && next[0] < x1 && next[1] > y0 && next[1] < y1 {
			next[1] = from[1]
		}
	}
	return next
}

move :: proc(layout: ^Layout, position, velocity: [2]f32, dt: f32, radius: f32 = 12) -> [2]f32 {
	wanted := position + velocity * dt
	wanted[0] = clamp(wanted[0], MARGIN, WIDTH - MARGIN)
	wanted[1] = clamp(wanted[1], MARGIN, HEIGHT - MARGIN)
	return block_cover(layout.covers[:], position, wanted, radius)
}

// Slab entry used by ballistic sweeps. As in the original, a muzzle already
// inside a cover can fire outward. Contact at a segment endpoint still blocks.
clip :: proc(layout: ^Layout, from, delta: [2]f32) -> (fraction: f32, hit: bool) {
	fraction, hit, _ = contact(layout, from, delta)
	return
}

// Outward face normal, with X winning a corner tie. Preserve clip's entry,
// endpoint and overlapping-cover ordering; normals never affect resolution.
contact :: proc(layout: ^Layout, from, delta: [2]f32) -> (fraction: f32, hit: bool, normal: [2]f32) {
	best := f32(1)
	for c in layout.covers {
		lo := [2]f32{f32(c.x), f32(c.y)}
		hi := lo + [2]f32{f32(c.w), f32(c.h)}
		near, far := f32(0), f32(1)
		face: [2]f32
		ok := true
		for axis in 0 ..< 2 {
			if delta[axis] == 0 {
				if from[axis] < lo[axis] || from[axis] > hi[axis] {
					ok = false
				}
				continue
			}
			a, b := (lo[axis] - from[axis]) / delta[axis], (hi[axis] - from[axis]) / delta[axis]
			if a > b {
				a, b = b, a
			}
			if a > near {
				face = {}
				face[axis] = delta[axis] > 0 ? -1 : 1
			}
			near, far = max(near, a), min(far, b)
		}
		if ok && near <= far && near > 0 && near <= best {
			best, hit, normal = near, true, face
		}
	}
	return best, hit, normal
}

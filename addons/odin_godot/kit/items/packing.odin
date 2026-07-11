package kit_items

// packing — grid inventories where SHAPE is the mechanic (2x3 rifles, 3x3
// crates, 1x2 potions; Resident Evil attachés, Tarkov stashes).
//
// THE SHAPE, same as items.odin: a packed inventory is a plain fixed-size
// array of POD entries inside a replicated entity struct —
//
//     Stash :: struct {
//         grid: [12]kitems.Packed_Entry `gd:"replicate"`,
//         ...
//     }
//
// — so replication, prediction, and reject-truth are already solved; the grid
// rides the shadow-delta walk like any other field. Board dimensions are game
// constants passed to the ops (they aren't state, so they don't ship).
//
// A placement is SELF-DESCRIBING: each entry stores its shape alongside the
// item, so every op below is pure over the entries slice — no defs table.
// That honors items.odin's RULE by construction: the table-free ops are
// exactly the ones a @(gd_command) proc (entity + args only) can run, which
// is where packing's conflict story lives — two players dragging into the
// same corner both predict, the host runs them in arrival order, the loser's
// placement finds the cells taken and reverts. Shapes get INTO entries where
// the game's table lives (host code / command hooks): look the shape up with
// items_shape, then pack_place / pack_add.
//
// Deterministic and allocation-free throughout, like everything that runs
// inside commands.

// An item's footprint: a w x h bounding box (up to 4x4) plus a row-major bit
// mask inside it — bit (y*w + x) set = that cell is solid. A zero mask with
// nonzero w/h means "the full box" (the common case reads clean in tables).
Shape :: struct {
	w, h: u8,
	mask: u16,
}

// 1x1 full box — the default for anything unregistered or shapeless.
SHAPE_SINGLE :: Shape{w = 1, h = 1, mask = 1}

// Build a Shape from row strings: shape_of("XX.", "XXX") is an L. 'X' (or
// anything not '.'/' ') marks a solid cell. Compile-time-friendly authoring
// for the game's ready(): assert-loud on anything over 4x4.
shape_of :: proc(rows: ..string) -> Shape {
	assert(len(rows) >= 1 && len(rows) <= 4, "shapes fit a 4x4 box")
	s := Shape{h = u8(len(rows)), w = u8(len(rows[0]))}
	assert(s.w >= 1 && s.w <= 4, "shapes fit a 4x4 box")
	for row, y in rows {
		assert(len(row) == int(s.w), "ragged shape rows")
		for c, x in transmute([]u8)row {
			if c != '.' && c != ' ' {
				s.mask |= 1 << u16(y * int(s.w) + x)
			}
		}
	}
	assert(s.mask != 0, "a shape needs at least one solid cell")
	return s
}

// Does `s` cover its local cell (lx, ly)?
@(private = "file")
shape_solid :: proc(s: Shape, lx, ly: int) -> bool {
	if lx < 0 || ly < 0 || lx >= int(s.w) || ly >= int(s.h) {
		return false
	}
	if s.mask == 0 { // zero mask = full box
		return true
	}
	return s.mask & (1 << u16(ly * int(s.w) + lx)) != 0
}

// One placed item: 10 POD bytes. INVARIANT: an empty entry is exactly {} —
// ops normalize on the way out so byte-level delta diffing stays meaningful.
Packed_Entry :: struct {
	item:  Item_Id, // ITEM_NONE = empty entry
	count: u16,
	x, y:  u8, // anchor: the shape box's top-left board cell
	shape: Shape, // stored WITH the placement — ops need no table
}

// Does entry `e` cover board cell (cx, cy)?
@(private = "file")
entry_covers :: proc(e: Packed_Entry, cx, cy: int) -> bool {
	if e.item == ITEM_NONE {
		return false
	}
	return shape_solid(e.shape, cx - int(e.x), cy - int(e.y))
}

// Would `shape` anchored at (x, y) fit a bw x bh board without overlapping
// any occupied entry? `ignore` skips one entry index — pass the entry being
// MOVED so it doesn't collide with itself.
pack_fits :: proc(entries: []Packed_Entry, bw, bh: int, shape: Shape, x, y: int, ignore := -1) -> bool {
	assert(bw <= 256 && bh <= 256, "packed anchors are u8 — boards cap at 256 a side")
	for ly in 0 ..< int(shape.h) {
		for lx in 0 ..< int(shape.w) {
			if !shape_solid(shape, lx, ly) {
				continue
			}
			cx, cy := x + lx, y + ly
			if cx < 0 || cy < 0 || cx >= bw || cy >= bh {
				return false
			}
			for e, i in entries {
				if i != ignore && entry_covers(e, cx, cy) {
					return false
				}
			}
		}
	}
	return true
}

// Place a new item at an explicit anchor. Host/hook side: the caller looked
// the shape up in its table (items_shape). Returns false when nothing fits
// (no free entry slot, out of bounds, or cells taken) — nothing changes.
pack_place :: proc(entries: []Packed_Entry, bw, bh: int, item: Item_Id, count: u16, shape: Shape, x, y: int) -> bool {
	if item == ITEM_NONE || count == 0 || !pack_fits(entries, bw, bh, shape, x, y) {
		return false
	}
	for &e in entries {
		if e.item == ITEM_NONE {
			e = Packed_Entry{item = item, count = count, x = u8(x), y = u8(y), shape = shape}
			return true
		}
	}
	return false // every entry slot used (board full in a different way)
}

// Move entry `idx` to a new anchor — THE predicted-command op (the shape
// travels with the entry, so the proc needs nothing but the grid and args).
pack_move :: proc(entries: []Packed_Entry, bw, bh: int, idx: int, nx, ny: int) -> bool {
	if idx < 0 || idx >= len(entries) || entries[idx].item == ITEM_NONE {
		return false
	}
	if !pack_fits(entries, bw, bh, entries[idx].shape, nx, ny, ignore = idx) {
		return false
	}
	entries[idx].x = u8(nx)
	entries[idx].y = u8(ny)
	return true
}

// Take entry `idx` out entirely, returning what it held ({ITEM_NONE, 0} for
// an empty/invalid index). Table-free: a drain op, command-safe.
pack_remove :: proc(entries: []Packed_Entry, idx: int) -> Slot {
	if idx < 0 || idx >= len(entries) || entries[idx].item == ITEM_NONE {
		return {}
	}
	out := Slot{item = entries[idx].item, count = entries[idx].count}
	entries[idx] = {}
	return out
}

// Which entry covers board cell (cx, cy)? The click-handling primitive.
pack_at :: proc(entries: []Packed_Entry, cx, cy: int) -> (idx: int, ok: bool) {
	for e, i in entries {
		if entry_covers(e, cx, cy) {
			return i, true
		}
	}
	return -1, false
}

// First anchor (row-major scan) where `shape` fits — the auto-pickup helper.
pack_find_spot :: proc(entries: []Packed_Entry, bw, bh: int, shape: Shape) -> (x, y: int, ok: bool) {
	for cy in 0 ..< bh {
		for cx in 0 ..< bw {
			if pack_fits(entries, bw, bh, shape, cx, cy) {
				return cx, cy, true
			}
		}
	}
	return 0, 0, false
}

// Auto-place, stacking first: tops up same-item entries to max_stack, then
// finds a spot for the remainder. Takes the TABLE (it grows stacks and looks
// up the shape) — host/hook side, per items.odin's rule. Returns how many of
// `count` found a home (0 = board is full for this shape).
pack_add :: proc(t: ^Table, entries: []Packed_Entry, bw, bh: int, item: Item_Id, count: u16) -> (added: u16) {
	if item == ITEM_NONE || count == 0 {
		return 0
	}
	left := count
	maxs := stack_max(t, item)
	for &e in entries {
		if left == 0 {
			break
		}
		if e.item == item && e.count < maxs {
			take := min(left, maxs - e.count)
			e.count += take
			left -= take
		}
	}
	shape := items_shape(t, item)
	for left > 0 {
		put := min(left, maxs)
		x, y, ok := pack_find_spot(entries, bw, bh, shape)
		if !ok || !pack_place(entries, bw, bh, item, put, shape, x, y) {
			break
		}
		left -= put
	}
	return count - left
}

// How many cells of the board are covered (UI fullness meters).
pack_used_cells :: proc(entries: []Packed_Entry) -> int {
	n := 0
	for e in entries {
		if e.item == ITEM_NONE {
			continue
		}
		for ly in 0 ..< int(e.shape.h) {
			for lx in 0 ..< int(e.shape.w) {
				if shape_solid(e.shape, lx, ly) {
					n += 1
				}
			}
		}
	}
	return n
}

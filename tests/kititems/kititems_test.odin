package kit_items_test

// Standalone tests for kit/items (stack-aware slot ops — the deterministic,
// allocation-free procs that run inside predicted commands) and kit/interact
// (dimension-agnostic range/facing gates). No Godot runtime:
//
//   odin test tests/kititems -collection:godot=$PWD

import "core:testing"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"

TORCH :: kitems.Item_Id(1) // stacks to 5
GEM :: kitems.Item_Id(2) // stacks to 99
SWORD :: kitems.Item_Id(3) // unstackable

table :: proc() -> kitems.Table {
	t: kitems.Table
	kitems.items_register(&t, TORCH, "torch", 5)
	kitems.items_register(&t, GEM, "gem", 99)
	kitems.items_register(&t, SWORD, "sword") // max_stack defaults to 1
	return t
}

@(test)
add_tops_up_stacks_before_empties :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)

	slots: [4]kitems.Slot
	slots[1] = {TORCH, 3} // an existing partial stack, not in slot 0

	testing.expect_value(t, kitems.add(&tab, slots[:], TORCH, 4), u16(4))
	testing.expect_value(t, slots[1], kitems.Slot{TORCH, 5}) // topped up first
	testing.expect_value(t, slots[0], kitems.Slot{TORCH, 2}) // spill to first empty
	testing.expect_value(t, kitems.count_of(slots[:], TORCH), 7)

	// Unstackables take a slot each.
	testing.expect_value(t, kitems.add(&tab, slots[:], SWORD, 2), u16(2))
	testing.expect_value(t, slots[2], kitems.Slot{SWORD, 1})
	testing.expect_value(t, slots[3], kitems.Slot{SWORD, 1})
}

@(test)
add_reports_what_fit :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)

	slots: [2]kitems.Slot
	testing.expect_value(t, kitems.add(&tab, slots[:], TORCH, 12), u16(10)) // 2 slots x 5
	testing.expect_value(t, kitems.add(&tab, slots[:], TORCH, 1), u16(0)) // full
	testing.expect_value(t, kitems.add(&tab, slots[:], kitems.ITEM_NONE, 3), u16(0))
}

@(test)
remove_drains_and_normalizes :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)

	slots: [3]kitems.Slot
	_ = kitems.add(&tab, slots[:], TORCH, 8) // {5} {3} {}
	testing.expect_value(t, kitems.remove(slots[:], TORCH, 6), u16(6))
	testing.expect_value(t, kitems.count_of(slots[:], TORCH), 2)
	// The drained slot is EXACTLY the empty value (replication diffs bytes).
	testing.expect_value(t, slots[0], kitems.Slot{})
	testing.expect_value(t, kitems.remove(slots[:], TORCH, 99), u16(2)) // partial
	testing.expect_value(t, kitems.count_of(slots[:], TORCH), 0)
}

@(test)
take_from_one_slot :: proc(t: ^testing.T) {
	slots: [2]kitems.Slot
	slots[0] = {GEM, 10}

	taken := kitems.take(slots[:], 0, 4)
	testing.expect_value(t, taken, kitems.Slot{GEM, 4})
	testing.expect_value(t, slots[0], kitems.Slot{GEM, 6})

	all := kitems.take(slots[:], 0, 99) // more than there is: take what exists
	testing.expect_value(t, all, kitems.Slot{GEM, 6})
	testing.expect_value(t, slots[0], kitems.Slot{}) // normalized empty

	none := kitems.take(slots[:], 1, 1) // empty slot
	testing.expect_value(t, none.count, u16(0))
	oob := kitems.take(slots[:], 7, 1) // out of bounds is a no, not a crash
	testing.expect_value(t, oob.count, u16(0))
}

@(test)
put_respects_slot_and_stack :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)

	slots: [3]kitems.Slot
	slots[1] = {TORCH, 4}
	slots[2] = {GEM, 1}

	testing.expect_value(t, kitems.put(&tab, slots[:], 0, TORCH, 9), u16(5)) // empty slot caps at max_stack
	testing.expect_value(t, kitems.put(&tab, slots[:], 1, TORCH, 3), u16(1)) // tops up to 5
	testing.expect_value(t, kitems.put(&tab, slots[:], 2, TORCH, 1), u16(0)) // occupied by another item
}

@(test)
transfer_never_tears_the_pair :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)

	chest: [1]kitems.Slot = {{GEM, 30}}
	bag: [2]kitems.Slot
	bag[0] = {GEM, 95} // room for 4
	bag[1] = {SWORD, 1} // no room at all

	moved := kitems.transfer(&tab, chest[:], 0, bag[:], 30)
	testing.expect_value(t, moved, u16(4))
	testing.expect_value(t, bag[0], kitems.Slot{GEM, 99})
	// What didn't fit went straight back — 30 gems still exist across the pair.
	testing.expect_value(t, chest[0], kitems.Slot{GEM, 26})

	// Empty source slot moves nothing.
	empty: [1]kitems.Slot
	testing.expect_value(t, kitems.transfer(&tab, empty[:], 0, bag[:], 5), u16(0))
}

@(test)
definitions_are_redeclarable :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)

	kitems.items_register(&tab, TORCH, "torch", 5) // ready() runs every launch
	testing.expect_value(t, kitems.items_name(&tab, TORCH), "torch")
	testing.expect_value(t, kitems.items_name(&tab, kitems.Item_Id(42)), "")
	d, ok := kitems.items_def(&tab, SWORD)
	testing.expect(t, ok && d.max_stack == 1)
}

// ---- kit/interact ---------------------------------------------------------------

@(test)
pick_nearest_within_reach :: proc(t: ^testing.T) {
	cands := []kinter.Candidate {
		{id = 1, pos = {5, 0, 0}},
		{id = 2, pos = {2, 0, 0}},
		{id = 3, pos = {50, 0, 0}},
	}
	best, ok := kinter.pick(cands, {0, 0, 0}, 10)
	testing.expect(t, ok)
	testing.expect_value(t, best.id, u32(2))

	_, any := kinter.pick(cands, {0, 0, 0}, 1) // nothing that close
	testing.expect(t, !any)
	_, none := kinter.pick(nil, {0, 0, 0}, 10)
	testing.expect(t, !none)
}

@(test)
target_radius_extends_reach :: proc(t: ^testing.T) {
	big_chest := []kinter.Candidate{{id = 9, pos = {4, 0, 0}, radius = 2}}
	testing.expect(t, kinter.in_range({0, 0, 0}, {4, 0, 0}, 3) == false)
	_, ok := kinter.pick(big_chest, {0, 0, 0}, 3)
	testing.expect(t, ok, "the chest's own radius makes up the difference")
}

@(test)
facing_cone_filters_behind :: proc(t: ^testing.T) {
	cands := []kinter.Candidate {
		{id = 1, pos = {3, 0, 0}}, // ahead
		{id = 2, pos = {-2, 0, 0}}, // behind, and NEARER
	}
	// Facing +x with a 90° cone: the nearer-but-behind lever must lose.
	best, ok := kinter.pick(cands, {0, 0, 0}, 10, facing = {1, 0, 0}, min_dot = 0.7071)
	testing.expect(t, ok)
	testing.expect_value(t, best.id, u32(1))

	// Omnidirectional (zero facing): nearest wins again.
	best2, _ := kinter.pick(cands, {0, 0, 0}, 10)
	testing.expect_value(t, best2.id, u32(2))
}

@(test)
standing_on_it_always_passes :: proc(t: ^testing.T) {
	testing.expect(t, kinter.facing_ok({1, 1, 0}, {1, 1, 0}, {0, 1, 0}, 0.99))
	on_top := []kinter.Candidate{{id = 5, pos = {1, 1, 0}}}
	_, ok := kinter.pick(on_top, {1, 1, 0}, 0.5, facing = {0, 1, 0}, min_dot = 0.99)
	testing.expect(t, ok)
}

@(test)
gates_are_dimension_agnostic :: proc(t: ^testing.T) {
	// The same procs in 3D: z participates like any other axis.
	testing.expect(t, kinter.in_range({0, 0, 0}, {1, 2, 2}, 3)) // dist 3
	testing.expect(t, !kinter.in_range({0, 0, 0}, {1, 2, 2}, 2.9))
	testing.expect(t, kinter.facing_ok({0, 0, 0}, {0, 0, 5}, {0, 0, 1}, 0.99))
}

// ---- packing: grid inventories where shape is the mechanic ---------------------

RIFLE :: kitems.Item_Id(10) // 3x1
CRATE :: kitems.Item_Id(11) // 2x2
BOOT :: kitems.Item_Id(12) // L-shaped

@(test)
packing_shapes_and_placement :: proc(t: ^testing.T) {
	L := kitems.shape_of("X.", "X.", "XX")
	testing.expect_value(t, L.w, u8(2))
	testing.expect_value(t, L.h, u8(3))
	testing.expect_value(t, size_of(kitems.Packed_Entry), 10) // stays POD-tight

	grid: [8]kitems.Packed_Entry // a 4x4 board
	BW, BH :: 4, 4

	rifle := kitems.shape_of("XXX")
	testing.expect(t, kitems.pack_place(grid[:], BW, BH, RIFLE, 1, rifle, 0, 0))
	// Overlap refused: the L's top cell would land on the rifle's row.
	testing.expect(t, !kitems.pack_place(grid[:], BW, BH, BOOT, 1, L, 2, 0))
	// The L fits below — its EMPTY cells may overhang occupied ones? No:
	// mask cells only collide where SOLID. (1,1) puts its solid column clear.
	testing.expect(t, kitems.pack_place(grid[:], BW, BH, BOOT, 1, L, 1, 1))
	// Out of bounds refused even when cells are free.
	testing.expect(t, !kitems.pack_place(grid[:], BW, BH, CRATE, 1, kitems.shape_of("XX", "XX"), 3, 3))

	// Hit-testing resolves solid cells to their entry — and only solid ones.
	idx, ok := kitems.pack_at(grid[:], 1, 3) // the L's bottom-left
	testing.expect(t, ok)
	testing.expect_value(t, grid[idx].item, BOOT)
	_, hole := kitems.pack_at(grid[:], 2, 1) // inside the L's box but NOT solid
	testing.expect(t, !hole, "mask holes are empty board")

	// Move: revalidates, ignores itself (a one-cell nudge overlaps its own
	// old footprint — that must not count as a collision).
	testing.expect(t, kitems.pack_move(grid[:], BW, BH, idx, 2, 1))
	testing.expect(t, !kitems.pack_move(grid[:], BW, BH, idx, 0, 0), "would hit the rifle")

	// Remove returns the stack and truly clears (delta-diff invariant).
	out := kitems.pack_remove(grid[:], idx)
	testing.expect_value(t, out.item, BOOT)
	testing.expect_value(t, grid[idx], kitems.Packed_Entry{})
}

@(test)
packing_add_stacks_then_packs :: proc(t: ^testing.T) {
	table: kitems.Table
	defer kitems.table_destroy(&table)
	kitems.items_register(&table, GEM, "gem", max_stack = 99) // shapeless: 1x1
	kitems.items_register(&table, CRATE, "crate", max_stack = 1, shape = kitems.shape_of("XX", "XX"))

	grid: [6]kitems.Packed_Entry
	BW, BH :: 3, 3

	// Crates: 2x2 on a 3x3 board — exactly one fits, the second finds no spot.
	testing.expect_value(t, kitems.pack_add(&table, grid[:], BW, BH, CRATE, 2), u16(1))
	// Gems flow around it: stack tops up ONE entry, not one per gem.
	testing.expect_value(t, kitems.pack_add(&table, grid[:], BW, BH, GEM, 30), u16(30))
	testing.expect_value(t, kitems.pack_add(&table, grid[:], BW, BH, GEM, 80), u16(80)) // 99 + 11
	entries := 0
	for e in grid {
		if e.item == GEM {entries += 1}
	}
	testing.expect_value(t, entries, 2) // 99-stack + 11-stack
	testing.expect_value(t, kitems.pack_used_cells(grid[:]), 6) // 4 crate + 2 gem cells

	// find_spot is deterministic (row-major): both peers of a predicted
	// command land the same anchor from the same grid bytes.
	x, y, ok := kitems.pack_find_spot(grid[:], BW, BH, kitems.SHAPE_SINGLE)
	testing.expect(t, ok)
	g2 := grid
	x2, y2, _ := kitems.pack_find_spot(g2[:], BW, BH, kitems.SHAPE_SINGLE)
	testing.expect(t, x == x2 && y == y2)
}

// The Inventory($N) embeddable bundle: the forwarders behave exactly like the raw slot
// ops on `slots[:]` (the bundle is just where the replicated array lives).
@(test)
inventory_bundle :: proc(t: ^testing.T) {
	tab := table()
	defer kitems.table_destroy(&tab)
	inv: kitems.Inventory(4)

	testing.expect_value(t, kitems.inv_add(&tab, &inv, TORCH, 3), u16(3))
	testing.expect_value(t, kitems.inv_count(&inv, TORCH), 3)
	// 3 + 4 = 7: tops the first stack to 5 (TORCH's max), the rest opens a new slot.
	testing.expect_value(t, kitems.inv_add(&tab, &inv, TORCH, 4), u16(4))
	testing.expect_value(t, kitems.inv_count(&inv, TORCH), 7)
	testing.expect_value(t, inv.slots[0].count, u16(5))
	testing.expect_value(t, inv.slots[1].count, u16(2))

	taken := kitems.inv_take(&inv, 0, 2)
	testing.expect_value(t, taken.item, TORCH)
	testing.expect_value(t, taken.count, u16(2))
	testing.expect_value(t, kitems.inv_count(&inv, TORCH), 5)

	testing.expect_value(t, kitems.inv_remove(&inv, TORCH, 100), u16(5)) // drains all remaining
	testing.expect_value(t, kitems.inv_count(&inv, TORCH), 0)
}

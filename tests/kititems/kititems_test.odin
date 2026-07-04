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

package kit_items

// kit/items — item definitions and stack-aware inventories (toolkit phase 3).
//
// THE SHAPE: an inventory is a plain fixed-size array of 4-byte Slot values
// living INSIDE a replicated entity struct —
//
//     Chest :: struct {
//         slots: [8]kitems.Slot `gd:"replicate"`,
//         ...
//     }
//
// — which means inventory replication is already solved: slots ride the
// phase-0 shadow-delta walk like any other POD field, chest state reaches
// every peer without one line of new wire code, and reject-truth snapshots
// carry the whole inventory back when a prediction loses a race.
//
// Every operation here is DETERMINISTIC and ALLOCATION-FREE, because they run
// inside @(gd_command) procs: the predicting client and the host execute the
// same op from byte-identical args and must land on identical slots. Two
// players grabbing the same last item both predict success; the host runs
// them in arrival order, the second op finds the slot empty and rejects, and
// the loser's optimistic state reverts. Conflict resolution costs nothing —
// it IS the intent pipeline.
//
// WHICH OPS TAKE THE TABLE — the rule, not a quirk: ops that can GROW a stack
// consult the defs for max_stack (`add`, `put`, `transfer`); ops that only
// drain or read slots don't (`take`, `remove`, `count_of`). The table-free
// ops are exactly the ones usable inside a @(gd_command) proc, which sees
// only its entity and args — no ambient state, by design. Crediting with
// stacking rules happens where the table lives: the command hook / host code.
//
// Item DEFINITIONS are code, not wire: every peer registers the same table in
// ready() (ids are game constants), so only 4-byte slots ever ship.

import "core:strings"

Item_Id :: distinct u16

// The empty-slot marker. Real items start at 1.
ITEM_NONE :: Item_Id(0)

Item_Def :: struct {
	name:      string, // owned by the table
	max_stack: u16, // 1 = unstackable
	shape:     Shape, // grid footprint (packing.odin); zero = 1x1
}

Table :: struct {
	defs: map[Item_Id]Item_Def,
}

table_destroy :: proc(t: ^Table) {
	for _, d in t.defs {
		delete(d.name)
	}
	delete(t.defs)
	t^ = {}
}

// Declare (or redeclare — safe in ready() every run) an item kind. `shape`
// only matters to packed grids (packing.odin); slot inventories ignore it.
items_register :: proc(t: ^Table, id: Item_Id, name: string, max_stack: u16 = 1, shape := Shape{}) {
	assert(id != ITEM_NONE, "item 0 is the empty-slot marker")
	assert(max_stack >= 1)
	if old, had := t.defs[id]; had {
		delete(old.name)
	}
	t.defs[id] = Item_Def{name = strings.clone(name), max_stack = max_stack, shape = shape}
}

// The item's grid footprint — SHAPE_SINGLE for shapeless/unknown items, so
// packed boards accept plain items without ceremony.
items_shape :: proc(t: ^Table, id: Item_Id) -> Shape {
	if d, ok := t.defs[id]; ok && d.shape.w != 0 && d.shape.h != 0 {
		return d.shape
	}
	return SHAPE_SINGLE
}

items_def :: proc(t: ^Table, id: Item_Id) -> (Item_Def, bool) {
	d, ok := t.defs[id]
	return d, ok
}

// Display name ("" for empty/unknown — UIs render blanks, not crashes).
items_name :: proc(t: ^Table, id: Item_Id) -> string {
	if d, ok := t.defs[id]; ok {
		return d.name
	}
	return ""
}

// One inventory slot: 4 POD bytes. INVARIANT: an empty slot is exactly
// {ITEM_NONE, 0} — every op normalizes on the way out, so slot equality (and
// the replication layer's byte-level diffing) stays meaningful.
Slot :: struct {
	item:  Item_Id,
	count: u16,
}

@(private = "file")
normalize :: proc(s: ^Slot) {
	if s.count == 0 {
		s^ = {}
	}
}

@(private) // package-visible: packing.odin's grow op shares the stacking rule
stack_max :: proc(t: ^Table, item: Item_Id) -> u16 {
	if d, ok := t.defs[item]; ok {
		return d.max_stack
	}
	return 1 // unknown items refuse to stack rather than merge blindly
}

// Add `count` of `item`: tops up existing stacks first, then fills empty
// slots. Returns how many were actually added (0 = inventory full).
add :: proc(t: ^Table, slots: []Slot, item: Item_Id, count: u16) -> (added: u16) {
	if item == ITEM_NONE || count == 0 {
		return 0
	}
	left := count
	max_per := stack_max(t, item)
	for &s in slots {
		if left == 0 {break}
		if s.item == item && s.count < max_per {
			n := min(left, max_per - s.count)
			s.count += n
			left -= n
		}
	}
	for &s in slots {
		if left == 0 {break}
		if s.item == ITEM_NONE {
			n := min(left, max_per)
			s = Slot{item = item, count = n}
			left -= n
		}
	}
	return count - left
}

// Remove up to `count` of `item` from anywhere. Returns how many came out.
remove :: proc(slots: []Slot, item: Item_Id, count: u16) -> (removed: u16) {
	if item == ITEM_NONE || count == 0 {
		return 0
	}
	left := count
	for &s in slots {
		if left == 0 {break}
		if s.item == item {
			n := min(left, s.count)
			s.count -= n
			left -= n
			normalize(&s)
		}
	}
	return count - left
}

count_of :: proc(slots: []Slot, item: Item_Id) -> (total: int) {
	for s in slots {
		if s.item == item {
			total += int(s.count)
		}
	}
	return
}

// Take up to `count` out of one specific slot. Returns what came out
// (ITEM_NONE/0 when the slot was empty — callers check `.count > 0`).
take :: proc(slots: []Slot, idx: int, count: u16) -> (taken: Slot) {
	if idx < 0 || idx >= len(slots) || count == 0 {
		return {}
	}
	s := &slots[idx]
	if s.item == ITEM_NONE {
		return {}
	}
	n := min(count, s.count)
	taken = Slot{item = s.item, count = n}
	s.count -= n
	normalize(s)
	return
}

// Put up to `count` of `item` into one specific slot (empty, or a matching
// stack with room). Returns how many went in.
put :: proc(t: ^Table, slots: []Slot, idx: int, item: Item_Id, count: u16) -> (accepted: u16) {
	if idx < 0 || idx >= len(slots) || item == ITEM_NONE || count == 0 {
		return 0
	}
	s := &slots[idx]
	max_per := stack_max(t, item)
	switch {
	case s.item == ITEM_NONE:
		accepted = min(count, max_per)
		s^ = Slot{item = item, count = accepted}
	case s.item == item && s.count < max_per:
		accepted = min(count, max_per - s.count)
		s.count += accepted
	}
	return
}

// Move up to `count` from one slot of `from` into `to` (stacking rules apply).
// Anything that doesn't fit goes straight back where it came from — the pair
// of inventories is never left torn. Returns how many moved.
transfer :: proc(t: ^Table, from: []Slot, from_idx: int, to: []Slot, count: u16) -> (moved: u16) {
	taken := take(from, from_idx, count)
	if taken.count == 0 {
		return 0
	}
	moved = add(t, to, taken.item, taken.count)
	if leftover := taken.count - moved; leftover > 0 {
		returned := put(t, from, from_idx, taken.item, leftover)
		assert(returned == leftover, "the source slot we just drained must take its own items back")
	}
	return
}

// ---- inventory as an embeddable bundle ---------------------------------------
//
// The `slots: [N]Slot gd:"replicate"` field the module header describes, packaged: embed
// it and the slot array replicates like a flat field (scriptgen recurses the nested
// struct — nested-replicate-fields), while the ops below forward to `slots[:]`. N is the
// slot count, chosen per container:
//
//     Chest :: struct { ..., using inv: kitems.Inventory(8) }
//     kitems.inv_add(&table, &c.inv, WOOD, 3)   // in the host command hook
//
// The ops that can GROW a stack still take the Table (same rule as the raw ops); the
// drain/read ops don't, so they stay usable inside a @(gd_command) proc.
Inventory :: struct($N: int) {
	slots: [N]Slot `gd:"replicate"`,
}

inv_add :: proc(t: ^Table, inv: ^Inventory($N), item: Item_Id, count: u16) -> (added: u16) {
	return add(t, inv.slots[:], item, count)
}

inv_remove :: proc(inv: ^Inventory($N), item: Item_Id, count: u16) -> (removed: u16) {
	return remove(inv.slots[:], item, count)
}

inv_count :: proc(inv: ^Inventory($N), item: Item_Id) -> (total: int) {
	return count_of(inv.slots[:], item)
}

inv_take :: proc(inv: ^Inventory($N), idx: int, count: u16) -> (taken: Slot) {
	return take(inv.slots[:], idx, count)
}

inv_put :: proc(t: ^Table, inv: ^Inventory($N), idx: int, item: Item_Id, count: u16) -> (accepted: u16) {
	return put(t, inv.slots[:], idx, item, count)
}

inv_transfer :: proc(t: ^Table, from: ^Inventory($N), from_idx: int, to: ^Inventory($M), count: u16) -> (moved: u16) {
	return transfer(t, from.slots[:], from_idx, to.slots[:], count)
}

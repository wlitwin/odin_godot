# kit/items — item definitions and stack-aware inventories

Reach for `kit/items` when entities carry things: bags, chests, pickups, loot. It gives you
a 4-byte `Slot`, a definition `Table` (names, stack sizes), and deterministic operations
(add, take, put, transfer) that are safe inside predicted commands.

**Lane compatibility:** inventories normally remain on reliable delta fields
mutated through commands. `Slot` operations are pure and deterministic, so they
are safe inside predicted commands on either lane. `Inventory($N)` has not been
covered by the simulation-descriptor tests; do not put it on the simulation
lane without adding that coverage.

## Mental model

An inventory is a **plain fixed-size array of 4-byte Slot values living inside a replicated
entity struct**:

```odin
Chest :: struct {
	slots: [8]kitems.Slot `gd:"replicate"`,
	...
}
```

Inventory replication comes for free: slots ride the [kit/net](net.md) shadow-delta walk
like any other POD field, so chest state reaches every peer without one line of new wire
code, and reject-truth snapshots carry the whole inventory back when a prediction loses a
race.

Every operation is **deterministic and allocation-free**. They run inside `@(gd_command)`
procs, so the predicting client and the host execute the same op from byte-identical args
and land on identical slots. Two players grabbing the same last item both predict success;
the host runs them in arrival order, the second op finds the slot empty and rejects, and the
loser's optimistic state reverts. Conflict resolution is just the intent pipeline: there is
no separate reconciliation code.

Item **definitions are code, not wire**: every peer registers the same table in `ready()`
(ids are game constants), so only 4-byte slots ever ship.

## Definitions: the Table

```odin
Item_Id :: distinct u16

// The empty-slot marker. Real items start at 1.
ITEM_NONE :: Item_Id(0)

Item_Def :: struct {
	name:      string, // owned by the table
	max_stack: u16, // 1 = unstackable
	shape:     Shape, // grid footprint (packing below); zero = 1x1
}

Table :: struct {
	defs: map[Item_Id]Item_Def,
}

// Declare (or redeclare — safe in ready() every run) an item kind. `shape`
// only matters to packed grids; slot inventories ignore it.
items_register :: proc(t: ^Table, id: Item_Id, name: string, max_stack: u16 = 1, shape := Shape{})

items_def :: proc(t: ^Table, id: Item_Id) -> (Item_Def, bool)

// Display name ("" for empty/unknown — UIs render blanks, not crashes).
items_name :: proc(t: ^Table, id: Item_Id) -> string

table_destroy :: proc(t: ^Table)
```

Cavecrawl registers its table once in `ready()` (`cavecrawl.odin`):

```odin
kitems.items_register(&self.table, GEM, "gem", 99)
kitems.items_register(&self.table, TORCH, "torch", 5)
```

## Slots and operations

```odin
// One inventory slot: 4 POD bytes. INVARIANT: an empty slot is exactly
// {ITEM_NONE, 0} — every op normalizes on the way out, so slot equality (and
// the replication layer's byte-level diffing) stays meaningful.
Slot :: struct {
	item:  Item_Id,
	count: u16,
}

// Add `count` of `item`: tops up existing stacks first, then fills empty
// slots. Returns how many were actually added (0 = inventory full).
add :: proc(t: ^Table, slots: []Slot, item: Item_Id, count: u16) -> (added: u16)

// Remove up to `count` of `item` from anywhere. Returns how many came out.
remove :: proc(slots: []Slot, item: Item_Id, count: u16) -> (removed: u16)

count_of :: proc(slots: []Slot, item: Item_Id) -> (total: int)

// Take up to `count` out of one specific slot. Returns what came out
// (ITEM_NONE/0 when the slot was empty — callers check `.count > 0`).
take :: proc(slots: []Slot, idx: int, count: u16) -> (taken: Slot)

// Put up to `count` of `item` into one specific slot (empty, or a matching
// stack with room). Returns how many went in.
put :: proc(t: ^Table, slots: []Slot, idx: int, item: Item_Id, count: u16) -> (accepted: u16)

// Move up to `count` from one slot of `from` into `to` (stacking rules apply).
// Anything that doesn't fit goes straight back where it came from — the pair
// of inventories is never left torn. Returns how many moved.
transfer :: proc(t: ^Table, from: []Slot, from_idx: int, to: []Slot, count: u16) -> (moved: u16)

// The `slots: [N]Slot gd:"replicate"` field, packaged: embed it (`using inv:
// kitems.Inventory(8)`) and the array replicates like a flat field, while
// inv_add/inv_remove/inv_count/inv_take/inv_put/inv_transfer forward to
// `slots[:]` — growing ops still take the Table, drain/read ops stay command-safe.
Inventory :: struct($N: int) {
	slots: [N]Slot `gd:"replicate"`,
}
```

## Which ops take the Table

Ops that can grow a stack consult the defs for `max_stack`: `add`, `put`, `transfer`. Ops
that only drain or read slots don't: `take`, `remove`, `count_of`.

The table-free ops are exactly the ones usable inside a `@(gd_command)` proc, which sees only
its entity and args, with no ambient state. Crediting with stacking rules happens where the
table lives: the command hook or host code.

## Worked example: looting a chest

The command half is table-free, predicted, and range-gated with the same
[kit/interact](interact.md) gate the prompt uses (`examples/cavecrawl/scripts/chest.odin`):

```odin
@(gd_command = "predict,any_seat")
chest_take :: proc(self: ^Chest, slot: i32, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), 99) // the whole stack
	if taken.count == 0 {return false}
	self.last_take = taken
	return true
}
```

The cross-entity half runs host-only, in the command hook, where the table lives
(`host.odin`):

```odin
cave_credit :: proc(self: ^CaveLobby, player: knet.Player_Id, chest: ^Chest) {
	av, has := self.avatar_of[player]
	if !has {return}
	sp := self.spelunkers[av]
	credited := kitems.add(&self.table, sp.bag[:], chest.last_take.item, chest.last_take.count)
	if leftover := chest.last_take.count - credited; leftover > 0 {
		_ = kitems.add(&self.table, chest.slots[:], chest.last_take.item, leftover)
	}
}
```

`last_take` is a plain field that never rides the wire; it carries what the command took
across to the hook. [kit/ui](ui.md)'s `inv_refresh` renders the bag from the same slots and
table.

## Grid packing (shape as a mechanic)

For inventories where the SHAPE matters (2x3 rifles, 3x3 crates, attaché-case
Tetris), `packing.odin` adds a second board type with the same replication
story: a packed inventory is a fixed array of 10-byte `Packed_Entry` values
inside a replicated struct, and board dimensions are game constants passed to
the ops.

```odin
Stash :: struct {
	grid: [12]kitems.Packed_Entry `gd:"replicate"`,
}

// ready(), every peer:
items_register(&table, RIFLE, "rifle", shape = kitems.shape_of("XXX"))
items_register(&table, BOOT, "boot", shape = kitems.shape_of("X.", "X.", "XX"))
```

Shapes are up to 4x4 with a solid-cell mask (`shape_of` reads row strings), and
each placement is **self-describing** (the entry stores its shape), so the same
table/table-free split holds: `pack_move`, `pack_remove`, `pack_at`, and
`pack_fits` are table-free and command-safe (the drag-to-rearrange command is
one predicted `pack_move`), while the growing ops (`pack_place` with a shape
you looked up, `pack_add` which stacks then auto-places) live host/hook side
with the table. `pack_find_spot` scans row-major, so a predicted command and
the host derive the same anchor from the same grid bytes. Conflicts resolve the
same way: two players dragging into the same corner both predict, the host runs
them in arrival order, the loser reverts.

## Gotchas

- Keep command-side ops deterministic: no table, no allocation, no clocks. They re-run on
  the host from byte-identical args and must land on identical slots.
- An empty slot is exactly `{ITEM_NONE, 0}`; every op normalizes on the way out. Don't
  hand-write slots that break this: replication diffs bytes.
- Unknown (unregistered) items get `max_stack = 1`: they refuse to stack rather than merge
  blindly.
- `items_register` asserts on id 0 (the empty-slot marker), and re-registration is safe:
  call it in `ready()` every run, on every peer, with the same constants.
- Returns are budgets, not booleans: `add` may credit less than asked (inventory full).
  Handle the leftover, as `cave_credit` does by putting it back in the chest.

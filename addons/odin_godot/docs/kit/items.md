# kit/items — item definitions and stack-aware inventories

`kit/items` represents inventories in bags, chests, and pickups. It provides a
4-byte `Slot`, a definition `Table` containing names and stack sizes, and
deterministic add, take, put, and transfer operations. Use table-free
operations inside predicted commands; perform operations that need item
definitions in the authority hook that holds the table.

Inventories normally use reliable delta fields mutated through commands.
Table-free `Slot` operations are pure and deterministic and can run inside
predicted commands on either lane. `Inventory($N)` has not been
covered by the simulation-descriptor tests; do not put it on the simulation
lane without adding that coverage.

<a id="mental-model"></a>

## Replicated inventory state

An inventory stores a fixed-size array of 4-byte Slot values in a replicated
entity struct:

```odin
Chest :: struct {
	slots: [8]kitems.Slot `gd:"replicate"`,
	...
}
```

Tag the inventory as replicated state. [kit/net](net.md) then compares slots
with its stored copy and sends changes as it does for other fixed-layout
fields. When a command predicate rejects a conflicting prediction, the reply
includes authority inventory state for correction.

Operations are deterministic and allocation-free. A predicting client and the
host produce identical slots when given the same starting state and arguments.
Their starting state can differ during contention: two players taking the
last item may both predict success. The host processes their commands in
arrival order; the second finds the slot empty and rejects. The command
pipeline returns the verdict and corrects the rejected prediction.

Every peer registers the same item definitions in `ready()`, using game
constants for IDs. The inventory replicates 4-byte slots containing those IDs
and counts; it does not send the definition table.

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

// Display name ("" for empty or unknown items).
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
// One inventory slot: 4 POD bytes. An empty slot must be exactly
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
// Any remainder returns to the source slot. Both inventories are updated
// together. Returns how many moved.
transfer :: proc(t: ^Table, from: []Slot, from_idx: int, to: []Slot, count: u16) -> (moved: u16)

// The `slots: [N]Slot gd:"replicate"` field, packaged: embed it (`using inv:
// kitems.Inventory(8)`) and the array replicates like a flat field, while
// inv_add/inv_remove/inv_count/inv_take/inv_put/inv_transfer forward to
// `slots[:]` — growing ops still take the Table, drain/read ops stay command-safe.
Inventory :: struct($N: int) {
	slots: [N]Slot `gd:"replicate"`,
}
```

<a id="which-ops-take-the-table"></a>

## Operations that require the Table

Operations that can grow a stack consult the definitions for `max_stack`:
`add`, `put`, and `transfer`. Operations that only remove or read items do not
need the table: `take`, `remove`, and `count_of`.

Use the table-free operations inside a `@(gd_command)` proc, which sees only
its target entity and arguments. Add items with stacking rules in the command
hook or host code that has access to the table.

## Worked example: looting a chest

The command removes items without consulting the table and can therefore be
predicted. It checks range with the same [kit/interact](interact.md) procedure
used by the prompt. The example below shows a local scratch-field approach;
the current `examples/cavecrawl/scripts/chest.odin` returns the taken Slot to
its generated consequence instead:

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
chest_take :: proc(self: ^Chest, slot: i32, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), 99) // the whole stack
	if taken.count == 0 {return false}
	self.last_take = taken
	return true
}
```

Crediting another entity runs only on the host, in a command hook that can
access the table. A `host.odin` handler can apply it as follows:

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

In this example, `last_take` is an unreplicated scratch field that carries the
removed Slot to the hook. [kit/ui](ui.md)'s `inv_refresh` renders the bag from
the same slots and table.

<a id="grid-packing-shape-as-a-mechanic"></a>

## Grid packing

For inventories with spatial footprints, such as 2x3 rifles or 3x3 crates,
`packing.odin` provides a board represented by a fixed array of 10-byte
`Packed_Entry` values inside a replicated struct. Pass board dimensions as
game constants to its operations.

```odin
Stash :: struct {
	grid: [12]kitems.Packed_Entry `gd:"replicate"`,
}

// ready(), every peer:
items_register(&table, RIFLE, "rifle", shape = kitems.shape_of("XXX"))
items_register(&table, BOOT, "boot", shape = kitems.shape_of("X.", "X.", "XX"))
```

Shapes use a solid-cell mask up to 4x4; `shape_of` builds it from row strings.
Each entry stores its shape, allowing `pack_move`, `pack_remove`, `pack_at`,
and `pack_fits` to run without a table inside commands. A drag-to-rearrange
command can use one predicted `pack_move`. Operations that add placements run
in host code or hooks with the table: `pack_place` takes a looked-up shape,
while `pack_add` stacks items and finds space for new entries.

`pack_find_spot` scans in row-major order, so a prediction and the host derive
the same placement anchor from the same grid bytes. If two players predict a
move into the same corner, the host processes them in arrival order and
rejects the conflicting move. The rejected prediction then reverts.

<a id="gotchas"></a>

## Inventory invariants and return values

- Keep command-side operations deterministic: no table, allocation, or clocks.
  Re-execution on the host must produce the same slots from the same state
  and arguments.
- An empty slot is exactly `{ITEM_NONE, 0}`; every op normalizes on the way out. Don't
  hand-write slots that break this: replication diffs bytes.
- Unknown (unregistered) items get `max_stack = 1`: they refuse to stack rather than merge
  blindly.
- `items_register` asserts on id 0 (the empty-slot marker), and re-registration is safe:
  call it in `ready()` every run, on every peer, with the same constants.
- Check returned counts. `add` may credit fewer items than requested when the
  inventory is full. Handle the remainder, as `cave_credit` does by returning
  it to the chest.

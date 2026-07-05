# kit/items — item definitions and stack-aware inventories

Reach for `kit/items` when entities carry things: bags, chests, pickups, loot. It gives you
a 4-byte `Slot`, a definition `Table` (names, stack sizes), and deterministic operations —
add, take, put, transfer — that are safe inside predicted commands.

## Mental model

An inventory is a **plain fixed-size array of 4-byte Slot values living inside a replicated
entity struct**:

```odin
Chest :: struct {
	slots: [8]kitems.Slot `gd:"replicate"`,
	...
}
```

Which means inventory replication is already solved: slots ride the [kit/net](net.md)
shadow-delta walk like any other POD field, chest state reaches every peer without one line
of new wire code, and reject-truth snapshots carry the whole inventory back when a
prediction loses a race.

Every operation is **deterministic and allocation-free**, because they run inside
`@(gd_command)` procs: the predicting client and the host execute the same op from
byte-identical args and must land on identical slots. Two players grabbing the same last
item both predict success; the host runs them in arrival order, the second op finds the
slot empty and rejects, and the loser's optimistic state reverts. Conflict resolution costs
nothing — it *is* the intent pipeline.

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
}

Table :: struct {
	defs: map[Item_Id]Item_Def,
}

// Declare (or redeclare — safe in ready() every run) an item kind.
items_register :: proc(t: ^Table, id: Item_Id, name: string, max_stack: u16 = 1)

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
```

## THE RULE: which ops take the Table

The rule, not a quirk: **ops that can grow a stack consult the defs** for `max_stack`
(`add`, `put`, `transfer`); **ops that only drain or read slots don't** (`take`, `remove`,
`count_of`).

The table-free ops are exactly the ones usable inside a `@(gd_command)` proc, which sees
only its entity and args — no ambient state, by design. Crediting with stacking rules
happens where the table lives: the command hook / host code.

## Worked example: looting a chest

The command half — table-free, predicted, range-gated with the same
[kit/interact](interact.md) gate the prompt uses (`examples/cavecrawl/scripts/chest.odin`):

```odin
@(gd_command = "predict")
chest_take :: proc(self: ^Chest, slot: i32, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), 99) // the whole stack
	if taken.count == 0 {return false}
	self.last_take = taken
	return true
}
```

The cross-entity half — host only, in the command hook, where the table lives
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

`last_take` is an untagged scratch field — never on the wire — carrying what the command
took to the hook. [kit/ui](ui.md)'s `inv_refresh` renders the bag from the same slots and
table.

## Gotchas

- Keep command-side ops deterministic: no table, no allocation, no clocks — they re-run on
  the host from byte-identical args and must land on identical slots.
- An empty slot is exactly `{ITEM_NONE, 0}`; every op normalizes on the way out. Don't
  hand-write slots that break this — replication diffs bytes.
- Unknown (unregistered) items get `max_stack = 1`: they refuse to stack rather than merge
  blindly.
- `items_register` asserts on id 0 (the empty-slot marker) and re-registration is safe —
  call it in `ready()` every run, on every peer, with the same constants.
- Returns are budgets, not booleans: `add` may credit less than asked (inventory full) —
  handle the leftover, like `cave_credit` putting it back in the chest.

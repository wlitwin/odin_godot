# `kit/net`: replication core

`kit/net` implements Kit's engine-independent wire primitives, entity registry,
field descriptors, reliable delta replication, owner streams, interpolation,
and command prediction. It does not import Godot and is covered by headless
tests.

Most game code uses these mechanisms through [kit/session](session.md), which
drives the registry and schedules messages. Import `kit/net` directly for types
such as `Net_Id` and `Player_Id`, wire readers and writers, custom interpolation
procedures, clocks, and low-level tests. [kit/netgd](netgd.md) provides the
Godot transport adapter.

## The mental model

Session replication has two field lanes:

- **Reliable deltas** are selected by `gd:"replicate"`. The host writes shared
  state such as inventory, health, score, and match phase. Changes are delivered
  reliably.
- **Owner streams** are selected by `gd:"owner"`. The current entity owner
  writes freshness-oriented state such as movement and aim. The host checks the
  sender's ownership and relays accepted samples; other peers interpolate them.

The lanes are disjoint in the generated descriptor. A full spawn or resync record
sets their initial values, after which only the selected lane updates each field.
Owner streams trust the owner to provide their values. Use [kit/sim](sim.md) when
the authority must derive contested state from inputs; see
[Choosing an authority model](timelines.md).

### Delta replication

Each registered entity has a shadow copy of its reliable fields. At every
network tick, the registry compares current values with that shadow, writes a
field mask and the changed values for dirty entities, and advances the shadow.
Unchanged entities emit no field data.

Replicated fields must have a bounded, target-independent wire shape. The normal
building blocks are fixed-width scalars (`i32`, not `int`), explicitly based
enums (`enum u8`, not bare `enum`; explicit member values are integer literals),
literal-sized arrays, and recursively valid structs. A raw struct may contain no
compiler-owned interior or tail padding;
reorder its fields, add explicit reserved bytes, or deliberately use
`struct #packed`. Pointers, strings, and dynamic containers do not belong in
replicated fields; send variable-length data with application messages, entity
blobs, or `kit/xfer`.

### Canonical wire ABI

scriptgen recursively validates every Kit-owned raw network value: replicated,
owner-streamed, and predicted fields; input records; player profiles; and typed
app-message payloads. It follows fixed arrays, aliases, distinct types, explicit
enums, nested structs, imported package types, and composed blocks all the way
to their leaves. It rejects `int`, `uint`, `uintptr`, implicit-width enums,
pointers, strings, dynamic or fixed-capacity containers, unresolved types, and
implicit struct padding. Custom field codecs still require a recursively valid
in-memory value and a literal fixed codec size.

The generated guard exposes the canonical contract, its hashes, and one
structured package-level projection:

```odin
NET_SCHEMA_CANONICAL  // readable, deterministic wire metadata
NET_ABI_FINGERPRINT   // hash of that metadata alone
NET_FINGERPRINT       // complete session contract, including the ABI
NET_SCHEMA            // knet.Net_Schema: structured, allocation-free metadata
```

The canonical schema records full field paths, wire kinds, struct and packet
widths, array and protocol bounds, enum bases and values, input-class ids and
admission constraints, message tags, and each action's access, prediction,
argument ceiling, and immediate/tick scheduling. Generated `size_of`,
`align_of`, and field-layout
assertions then pin those expectations in every target compile. The raw ABI is
little-endian; a target with a different layout cannot retain the same accepted
fingerprint.

`NET_SCHEMA` is the tooling/debugging view of that same walk. It contains flat
static tables for entity kinds, recursive type nodes, replicated fields, input
classes and constraints, actions, presentation events, argument layouts,
outcome layouts, profiles, and typed messages. Each action carries its resolved
`Action_Policy`, `.Immediate`/`.Scheduled` model, argument/outcome spans, and
named consequence metadata; each presentation event carries its named anchor and watch-clock
schedule. The schema also carries both fingerprints and the exact canonical
string that produced `NET_ABI_FINGERPRINT`.

Rows with children use `knet.Net_Schema_Span` indexes into the schema's backing
tables, so inspection allocates nothing. Common lookups have helpers:

```odin
assert(knet.net_schema_valid(&NET_SCHEMA))
field, ok := knet.net_schema_field(&NET_SCHEMA, "Runner", "position")
action, ok := knet.net_schema_action(&NET_SCHEMA, "Chest", "open")
if ok {
	args := knet.net_schema_action_args(&NET_SCHEMA, action)
	outcomes := knet.net_schema_action_outcomes(&NET_SCHEMA, action)
	// policy, model, args/outcomes, consequence, widths, and bounds are authoritative.
}
```

Treat generated schema tables as read-only. Executable callbacks and live
entity pointers stay in the runtime descriptors; `NET_SCHEMA` contains stable
protocol facts only, so it is safe to expose to diagnostics, compatibility
tools, and future admission/configuration APIs without creating another
registry.

Use explicit bytes when alignment would otherwise create a hole:

```odin
Stage :: struct {
	run:      u16,
	level:    u8,
	reserved: u8, // protocol data, unlike invisible tail padding
}
```

Formatting and comments do not move the fingerprint. A wire type, bound,
policy, schedule, or codec name/size does. If a custom codec's *meaning* changes
without changing its declared name or size, rename/version it or mix a semantic
contract with `session_mix_fingerprint`; code bodies are not schema data.

### Commands

A command is a proc marked `@(gd_command)` whose return value says whether its
mutation applied. The bare marker is owner-only and waits for authority state.
A typed `Action_Policy` preset enables prediction or widens access. Script
generation creates the decoder, policy descriptor, stable command ID, and typed
`<verb>_cmd` wrapper.

The common policies are:

| Declaration | Access | Client execution |
| --- | --- | --- |
| bare `@(gd_command)` (its resolved policy is `knet.ACTION_OWNER`) | owner | waits for authority state |
| `knet.ACTION_OWNER_PREDICTED` | owner | optimistic |
| `knet.ACTION_ANY_SEAT` | any playing seat | waits for authority state |
| `knet.ACTION_ANY_SEAT_PREDICTED` | any playing seat | optimistic when that peer has a prediction ledger |
| `knet.ACTION_AUTHORITY` | authority only | never crosses client ingress |

Access and prediction are independent of the command predicate. The authority
checks the playing seat and access rule before executing gameplay code. Co-op
and sim actions consume one generated `Action_Desc(Id)` containing the stable
id, execution model, policy, typed argument/outcome metadata, and consequence
metadata. Only the callback differs: `Command_Desc` adds immediate invocation,
while `Sim_Cmd` adds scheduled exec/apply thunks. Moving a verb between models
does not duplicate or reinterpret its declaration.

For a tighter encoded-argument envelope, use the typed literal form. Zero uses
the 4096-byte default; a positive value is enforced before client send and
again at authority ingress:

```odin
@(gd_command = knet.Action_Policy {
	access         = .Any_Seat,
	prediction     = .Optimistic,
	max_args_bytes = 64,
})
```

The old comma strings remain accepted for migration, but new code should use
the typed presets or literal so Odin can catch misspelled policy members.

A successful command may invoke a name-paired `<verb>_then` half for
authority-only cross-entity work such as spawning, crediting a player, or
transferring ownership.

For an optimistic command:

- confirmation retains the optimistic mutation;
- predicate rejection includes authoritative entity state rather than restoring
  a possibly stale local snapshot; admission failures are compact and restore
  the local capture while the ordinary state lane supplies newer truth;
- timeout reverts an action whose result never arrives; and
- an intervening authoritative update unwinds pending predictions, applies truth,
  and replays still-valid commands in issue order.

The generated wrapper takes `^kboot.Boot` so the call site is the same for a
session command and a tick-scheduled simulation command:

```odin
outcome := chest_take_cmd(&game.boot, chest, slot, px, py)
if knet.command_ok(outcome) {show_local_take_feedback()}
if outcome.reason == .Access {show_locked_feedback()}
```

The wrapper returns `Action_Outcome`:

```odin
Action_Outcome :: struct {
	state:  Command_Outcome,       // Applied, Predicted, or Rejected
	reason: Action_Reject_Reason,  // None unless this call refused locally
	seq:    u32,                   // correlates the final callback
	model:  Action_Model,          // Immediate or Scheduled
}
```

For session replication, `.Applied` means the local authority accepted the
command. `.Predicted` means an issue is in flight or scheduled. `.Rejected`
means it did not apply locally. `command_ok` accepts the detailed outcome, so
ordinary call sites remain one condition. Inspect `reason` only where the UI
cares why a synchronous refusal occurred.

The authority's eventual answer is delivered through the generated session
halves. Both immediate and tick-scheduled actions use these same callbacks:

```odin
@(gd_half)
game_command_rejected :: proc(
	self: ^Game,
	seq: knet.Intent_Seq,
	entity: knet.Net_Id,
	cmd: u16,
	reason: knet.Action_Reject_Reason,
	model: knet.Action_Model,
) {
	switch reason {
	case .Access:    show_locked_feedback()
	case .Rate:      show_slow_down_feedback()
	case .Predicate: show_no_longer_available()
	case .Timeout:   show_connection_feedback()
	case:            // Malformed/Stale are normally logged, not player choices.
	}
}
```

`Action_Reject_Reason` is deliberately gameplay-sized:

| Reason | Meaning |
| --- | --- |
| `Access` | The seat or action policy did not allow the request. |
| `Rate` | The shared traffic budget or scheduled-action queue refused it. |
| `Malformed` | Unknown action, invalid/trailing encoding, or argument envelope failure. |
| `Stale` | The target, sequence, or requested scheduling window is no longer current. |
| `Predicate` | The authored command proc returned `false`. |
| `Timeout` | No final authority result arrived before the safety horizon. |

`game_command_confirmed` receives `(seq, entity, cmd, model)`. On the authority,
`game_command_executed` receives `(player, entity, cmd, reason, seq, model)`
for both execution models. These are generated callbacks: gameplay code never
parses a verdict packet or maintains a sequence map. `model` disambiguates the
two sequence/id namespaces when a game uses both. Non-predicted actions keep a
receipt-only entry, so they confirm, reject, and time out through exactly the
same callback path without gaining speculative write privileges.

**Waiting for the authority without language-level async.** A purchase dialog,
transaction prompt, or similar UI may care about the final verdict for one
particular issue. Turn the generated outcome into a session-scoped receipt and
poll it from the frame loop:

```odin
outcome := spelunker_buy_cmd(&game.boot, game.me, ITEM_BOOTS)
receipt := ksess.session_action_receipt(&game.ses, outcome)

// A later frame:
if verdict, ready := ksess.session_action_poll(&game.ses, receipt); ready {
	switch verdict.state {
	case .Accepted:    close_purchase_dialog()
	case .Rejected:    show_purchase_error(verdict.reason)
	case .Unavailable: show_connection_error()
	case .Pending:     // `ready` is false for this state
	}
}
```

Receipts are optional and bounded (`MAX_ACTION_RECEIPTS`, 64 watched asks per
run). A terminal poll consumes its watched slot; call `session_action_forget`
when the owning UI disappears first. They cover both `.Immediate` and
`.Scheduled` actions without aliasing equal raw sequences and preserve the
typed rejection reason. A pending watched receipt becomes `.Unavailable`
across reset/rehost. A small result cache closes the issue/result race for
synchronous in-memory transports.

This is an acknowledgement, not a remote-value return. Durable inventory,
currency, ownership, and world state still come from replicated fields and
their edges. No additional request/response protocol or wire message is
created by a receipt.

Generated command IDs are stable hashes of command names, not declaration
positions. Reordering procedures does not renumber the protocol. Renaming a
command intentionally creates a new ID; collisions within a command set are a
build error. The session's schema fingerprint provides the broader
compatibility gate.

### Reliable presentation events

`@(gd_event)` declares a typed, non-durable occurrence. The author keeps the
presentation body under `_fx`; scriptgen generates the suffix-free announcement
door taking the game's `^Boot`:

```odin
@(gd_event = "audience=everyone,timing=auto")
chest_spark_fx :: proc(g: ^Game, chest: ^Chest, mine: bool, strength: f32) {
	particles_restart(chest, strength)
	if mine {camera_kick(g)}
}

// Authority gameplay code — no Fx/Rpc/send suffix and no role branch.
chest_spark(&g.boot, chest, 0.8)
```

The signature is `(game, entity refs…, mine: bool, wire args…)`, with the game
pointer first. One entity parameter is the inferred anchor; with several,
write `anchor=PARAM`, or `anchor=none` for a world occurrence. Arguments after
`mine` use the command wire primitives. The body returns nothing and is
presentation only—damage, inventory, spawning, and other truth remain commands,
authority steps, and replicated fields.

The policy has two independent axes:

- `audience=everyone` presents on every eligible screen.
- `audience=owner` presents only on the anchor owner's screen and therefore
  requires an anchor.
- `audience=observers` excludes the anchor owner. With no anchor it excludes
  the announcing authority, useful when the source already carries its effect.
- `timing=immediate` presents from the next session-frame drain on receivers.
- `timing=anchored` aligns non-owning screens with the anchor's presentation
  clock; the owning/live screen receives no additional interpolation delay.
- `timing=auto` is accepted only when scriptgen can prove the clock: a
  sim-tracked anchor uses its watch clock, and a cooperative entity with
  continuous `owner` state uses the session interpolation clock. An anchorless
  event in a lane-owning game uses that lane's watch clock. Other static and
  custom clocks must say `immediate` or use the lower-level explicit scheduler.

The anchor also chooses the existing transport implementation. A sim-tracked
anchor lowers onto `SIM_FACT`; a cooperative/static event lowers onto the
session's reliable event frame and presentation queue. Both enter the wire
fingerprint with id, argument schema, anchor, audience, and timing. Neither is
join-replayed. Cooperative/static events are authority-minted; clients ask
through commands. A sim event may also present from the owning live pass, where
it is derived from the same replayable tick rather than an unconfirmed
standalone prediction.

`@(gd_event)` is the sole declared presentation-event form. Tick `_fx`, field `_edge`, command
`_then`, and resimulation `_apply` retain their distinct phase contracts.

### Network tick and interpolation

For session replication, the fixed network tick (20 Hz by default) schedules
deltas and streams; ordinary gameplay may still run at frame rate. Remote owner
streams render at `interp_delay`, normally far enough behind the newest sample
to interpolate between two values. If no newer sample exists, presentation
holds the latest value instead of extrapolating indefinitely.

## Declaring a replicated entity

In a game you tag fields and mark procs; scriptgen emits the descriptor. From
`examples/cavecrawl/scripts/chest.odin`:

```odin
Chest :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	slots:  [8]kitems.Slot `gd:"replicate"`,
}

@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
chest_take :: proc(self: ^Chest, slot: i32, px: f32, py: f32) -> (ok: bool, taken: kitems.Slot) {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false, {}}
	taken = kitems.take(self.slots[:], int(slot), 99) // the whole stack
	return taken.count > 0, taken
}

// Fires on the HOST only, after the take applies: the cross-entity half,
// typed, next to its verb (see "Consequences" below).
@(gd_half)
chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: i32, px: f32, py: f32, taken: kitems.Slot) {
	cave_credit(game, by, self, taken)
}
```

Owner-streamed float/vector/quaternion fields interpolate by default:
`x, y: f32 `gd:"owner"`` (the spelunker's position). Discrete owner fields
snap automatically; write `snap` to opt a float-shaped generation/meter out of
the continuous default. Under the hood these become:

```odin
Field_Desc :: struct {
	offset: uintptr,
	size:   int,
	flags:  Field_Flags,
	lerp:   Lerp_Kind, // how stream sampling blends this field (meaningful with .Interp)
	blend:  Blend_Proc, // required iff lerp == .Custom
	wire:   Wire_Kind, // how the field's bytes are ENCODED in packets (default: raw)
	codec:  Wire_Codec, // required iff wire == .Custom
}

Entity_Desc :: struct {
	fields: []Field_Desc,
}

Action_Policy :: struct {
	access:         Action_Access,
	prediction:     Action_Prediction,
	max_args_bytes: int,
}

Action_Desc :: struct($Id: typeid) {
	name:        string,
	id:          Id,
	model:       Action_Model,
	policy:      Action_Policy,
	arguments:   []Action_Argument_Desc,
	outcomes:    []Action_Outcome_Value_Desc,
	consequence: Action_Consequence_Desc,
}

Command_Desc :: struct {
	using action: Action_Desc(Cmd_Id),
	invoke:       Command_Proc,
}

Command_Set :: struct {
	entity_desc:   ^Entity_Desc,
	commands:      []Command_Desc,
	net_id_offset: int,
}
```

At most `MAX_REPLICATED_FIELDS :: 64` fields per entity (the dirty mask is one u64; a
fixed array counts as one field). `Lerp_Kind` covers `.Snap`, `.F32`, `.F64`, `.Quat`
(nlerp with hemisphere flip), `.Angle` (f32 **radians** blending the shortest arc,
declared `` heading: f32 `gd:"owner,interp=angle"` ``; a raw lerp from `+3.1` to
`-3.1` sweeps the long way around), and `.Custom` with an author-supplied
`Blend_Proc :: proc(dst, a, b: rawptr, alpha: f32)` (declared via
`` tint: [3]f32 `gd:"owner,interp=blend_oklab"` ``).

## Command consequences

A command proc may mutate only its target entity, which is the state covered by
prediction and reconciliation. Put cross-entity work in the name-paired
`<verb>_then` half. Script generation passes it the issuer, command arguments,
and any returned payload after the command applies on the authority. Two
signatures are supported:

```odin
@(gd_half) chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: i32, px: f32, py: f32, taken: kitems.Slot)
@(gd_half) door_toggle_then :: proc(self: ^Door, by: knet.Player_Id)   // entity-local: no game param
```

**Payload returns.** A verb may return `(bool, payloads…)`: results after the
applied bool are in-process values handed straight to the `_then` (they never
cross the wire). Payload types are unconstrained, since the generated call site
lets the compiler hold the `_then` signature to them.

**Reading the issuer.** When the predicate needs the issuing player (a trade
window arbitrating which seat is confirming, a first-come claim recording its
claimant), declare `by: knet.Player_Id` right after the receiver (after the
wielder param in a composed block) and the framework fills it: `ctx.me` on the
issuing peer's optimistic run, the resolved sender on the host; these are the
same values the `_then` gets. It does not ride the wire, so it cannot be forged:
a hostile client can't hand you a `side: u8` it flipped to confirm the *other*
party's half of a trade, because the issuer is never a wire argument (the worked
rewrite is the [trade recipe](session.md#recipes-over-existing-pieces)).
The name is reserved: a wire arg called `by` is a build error. A player the
verb merely *targets* stays ordinary wire data under any other name (`who`,
`target`).

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
trade_confirm :: proc(self: ^Trade, by: knet.Player_Id) -> (ok: bool, sealed: bool)
```

**Delivery.** A consequence fires once per applied command,
including on the host's own issues (the wrapper's authority branch), and never
on a client's optimistic run, a registry replay, a rejection, or a deduped
retransmit. It runs before the result ships and before the tick's delta diff,
so its mutations reach every peer in the same batch as the verb's own. The
`game` parameter is the session game pointer installed through
`session_set_factory`.

**Composed verbs pair on the hoisted name.** A block's command
(`weapon: play.Gun` hoisting `gun_fire` as `runner_weapon_fire`) pairs with
`runner_weapon_fire_then`: the block ships the verb and its state machine,
the game keeps the consequence, and no index keying or entity-classifying
switch ever appears. A composed verb's payload is the block's *offer*
("a live round left the barrel"); a game that doesn't care simply declares no
`_then`.

**Build-time contract.** A mispaired consequence is a scriptgen error, not a
proc that silently never fires: the shape (`[game,] self, by, wire args…,
payload…`) is validated against the verb, and **every half wears `@(gd_half)`**:
the attribute declares that this proc is meant to pair, and a declared half
that pairs with nothing is an error with the class's real pairing names spelled
out beside it: rename it, or drop the attribute if it isn't a half.

The name decides *what* a half pairs with; the attribute declares only that
pairing was intended. Both a wrong prefix (`chest_taek_then`) and a wrong suffix
(`chest_take_after`) are build errors. A proc that merely *ends* in `_then` and
never claimed to be a half is nothing special. A direct verb whose payload
nobody consumes still warns. When something needs to react to commands
*generically* (metrics, receipts, replays), the untyped
[command hook](session.md#command-hooks) remains
underneath: `_then` is generated dispatch over the same authority path.

**Multi-target commands.** A command mutates one entity, not two (a trade
touching both players' bags). Spreading revert capture, reject-truth, and
replay-reconcile across entity boundaries is not supported. Make the transaction
itself the target: the [mediating-entity recipe](session.md#recipes-over-existing-pieces).

## Composing verbs from embedded blocks

Replicated fields compose through an embed: a `gd:"replicate"` field inside a sub-struct
joins its wielder's descriptor via a composed offset, so a building block's state travels with
it. **Its commands compose the same way.** A `@(gd_command)` proc whose receiver is an embedded
sub-struct is hoisted onto whatever entity embeds it, generated onto *that* entity's command
table, the dual of nested-field replication and what turns a plain struct into a true drop-in
gameplay block.

Both import spellings work: `import play "godot:play"` (the idiomatic alias) and a bare
`import "godot:play"`: scriptgen resolves a bare import by reading the target's package
clause, so the embed composes either way.

Declare the verb on the block, embed the block, and the entity gets the command:

```odin
Gun :: struct {
	ammo:      u8 `gd:"replicate"`,
	state:     Gun_State `gd:"replicate"`, // a replicated FSM is a plain enum field + an edge half
	reload_cd: u16 `gd:"replicate"`,
}

// The receiver is `^Gun` (the block), not the entity. An optional SECOND pointer param is the
// WIELDER — scriptgen fills it with the embedding entity, so the block can read/write its holder
// (stats, cooldowns) while staying reusable. A pointer can't ride the wire, so it is never a
// wire arg; the args after it are.
@(gd_command = knet.ACTION_OWNER_PREDICTED)
gun_fire :: proc(g: ^Gun, owner: ^Runner, dx, dy: f32) -> bool { ... }

Runner :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	weapon: Gun,   // -> the entity gets `runner_weapon_fire`
}
```

The entity's generated command is named by the **field path**, so two blocks of the same type
never collide (`weapon: Gun` + `sidearm: Gun` → `runner_weapon_fire` + `runner_sidearm_fire`,
distinct command IDs). Issue it exactly like a direct command
(`runner_weapon_fire_cmd(&boot, self, dx, dy)`); the owner is passed for you, so only the wire
args appear in the wrapper. Prediction reverts and reject-truth snapshots cover the block's
replicated state for free (it's already in the entity's descriptor), and the block's
cross-entity effects (spawning a projectile, applying damage) live in the game's
`runner_weapon_fire_then` [consequence](#command-consequences), exactly as a direct command's
do: the block ships the verb, the game keeps the "and then".

Owner threading is optional and detected by shape: write `^Runner` for a game-specific block, or
`^$E` for a library block reused across entity types. A block imported from another `godot:`
package works identically: the generated file imports and qualifies it (`play.gun_fire`).

`godot:play` provides composed `Gun`, `Ability`, `Channel`, `Health`, and
`Telegraph` blocks. The block owns its replicated state and any declared
command; the game owns cadence, world validation, presentation, and
cross-entity effects where those cannot be generalized. See the
[`godot:play` reference](play.md) and the source headers under `play/` for each
block's exact contract.

**Engine-facing procs compose the same way.** A block's `@(gd_method)` (or `@(gd_rpc)`) hoists
onto the embedding entity's method table under the same path-prefixed name (`gear_level` on a
`gear: Gear` field becomes `robot_gear_level`… registered as `gear_level`), the trampoline routed
into `&self.gear` and threading the owner if it asked. So a block can expose behavior to
GDScript/the editor, not just to the command loop: the whole `//gd:` surface (state, commands,
methods, rpcs) composes through an embed.

## Wire codecs

A field may re-encode its bytes inside packets. The struct-side representation
never changes: shadows, dirty diffing, prediction capture/restore, and stream
rings all hold struct-layout bytes; wire bytes exist only between writer and
reader, decoded at the packet edge. So a codec buys bandwidth (and lets the
wire representation differ from the in-memory one) without touching any of the
comparison/revert machinery.

`` gd:"replicate,...,wire=f16" `` ships f32 elements as half floats: half the
bytes, ~3 significant digits, integers exact to 2048. Cavecrawl's spelunker and
relic positions cross this way. For everything else there's a fixed-size custom
codec, declared like a blend proc:

```odin
hp: i32 `gd:"replicate,wire=spelunker_hp_codec"` // 0..100 has no business in four bytes

spelunker_hp_codec :: knet.Wire_Codec {
	size   = 1,
	encode = proc(wire, field: rawptr) {(^u8)(wire)^ = u8(clamp((^i32)(field)^, 0, 255))},
	decode = proc(field, wire: rawptr) {(^i32)(field)^ = i32((^u8)(wire)^)},
}
```

The wire size is FIXED per field, which is what frees the representation:
quantize, bit-pack, or ship an *index* into a structure both sides grow
deterministically (a shared-seed table means the wire only needs to name an
entry, not carry it). Two rules keep codecs honest: `decode(encode(x))` should
be stable (receivers hold decoded values; an unstable round trip makes confirmed
predictions micro-snap), and dirtiness is still diffed on struct bytes: a change
smaller than the wire precision still sends, so pick a precision at least as fine
as gameplay cares about.

## Dynamic collections

A `[dynamic]T`, slice, or map tagged `gd:"replicate"` is a **build error**. The
delta walk's whole contract is flat POD cells: a shadow memcmp per field, one
bit in a u64 mask, a byte-identical apply on every peer. A dynamic's bytes are a
header whose elements a memcpy would tear, and the deeper problem survives any
encoding: **byte-diffing has no element identity**: insert one element at the
front and every byte after it "changed", so the diff ships the world for a
one-item edit. A variable-length ask is always one of three real shapes, and
each already has first-class machinery:

- **Bounded** → a fixed array + count/sentinel: `bag: [6]kitems.Slot` with
  `ITEM_NONE` empties (cavecrawl). One field, one diff atom, edges and
  struct co-location work, prediction reverts are trivial. The cap is game
  design: a small-session game should choose and enforce its inventory bound.
- **Rare-change, genuinely unbounded** (text, authored bytes) → an
  [entity blob](session.md#entity-blobs): author-dirtied, whole-value,
  reliable, and it rides every snapshot, so late joiners, backups, and saves
  get it free (cavecrawl's floor inscription).
- **A live collection of THINGS** → each element is an **entity**. This is
  the one people reach past: the registry already IS a diffed dynamic
  collection: spawn is insert, despawn is remove, per-element state diffs
  field-by-field, interest management culls it, and late joiners get exactly
  the live set. Cavecrawl's floor pickups are the worked example: not
  `pickups: [dynamic]Pickup` on the level, but a Pickup entity per item on
  the ground, each with its own `x/y/item/count` (and its own typed
  `pickup_spawn`).

The build error spells this fork out at the field. (`gd:"backup"` still
accepts `[dynamic]`/map: the backup codec restores whole values on one
peer; it never diffs across the wire.)

## Field-change edges

Deltas carry values; one-shot reactions (the hurt flash, the goal horn, the
floor fanfare) need the TRANSITION. Declare a plain proc named for the field
(the proc is the subscription, no tag needed), and the session's per-frame pass
hands it the net change:

```odin
// ([game,] self, old, new: <the field's declared type>) — no results
@(gd_half)
gunner_hp_edge :: proc(self: ^Gunner, old, new: i32) {
	if new < old {self.flash_ttl = 0.25}
}
```

The semantics:

- **Net change per frame, never per apply.** A predicting client legitimately
  writes a delta-lane field several times in one frame (optimistic apply,
  reject-truth, the replay reconcile); the half fires once on what actually
  changed since last frame, or not at all when the churn cancels.
- **The diff atom is the FIELD**: a tagged POD struct or fixed array is
  one field. Fields that must edge *together* are co-located into one struct
  and receive one half with the whole old/new value, atomically (speedball's
  `score: Score`: l, r, and won as one value, one half, one fire per goal).
  The grouping knob is the data model, not a framework mode.
- **An EVENT must be bytes: equal values are indistinguishable from no
  event.** The coalescing above means a 1→0→1 pulse inside one frame nets to
  nothing, and "reset to level 1 *from* level 1" changes no bytes at all; an
  edge cannot fire on a non-change. When you catch yourself wanting one to,
  the field is under-modeled: give the event bytes. The house form is a
  **generation counter co-located in the diff atom**:
  `stage: struct { run: u16, level: u8, reserved: u8 }`,
  where a reset bumps `run`, so same-level resets and within-frame round trips both
  land as real transitions (`old.run != new.run` is the cleanup branch), and a
  late joiner's silent seed correctly replays *zero* of them (they see
  `run = 5` as a baseline). It is the same move the kit makes everywhere state
  alone can't carry an occurrence: warp serials, spawn seqs, dedup windows.
  When the occurrence carries payload or must fire exactly-once under resim, it
  has outgrown edges: that's a `_then` consequence, a session event, a
  [Fire announcement](combat.md), or a sim-lane tick payload event.
- **First sight seeds; resync re-seeds silently.** Spawn values are a
  baseline, not an edge; a wholesale catch-up (interest re-entry or a full
  snapshot) is history, not gameplay. Initial presentation belongs in a typed
  `<entity>_born` hook or the `Ev_Spawned` event after fields are applied. The
  census `_spawned` hook runs earlier and is for bookkeeping.
- **The host's own mutations edge the same way**: the hurt flash needs no
  `is_host`, ever. (A host-side pulse within one net tick still never reaches
  clients: edges don't repeal "deltas carry state"; hold state a tick.)
  One timing note for authorities: the automatic pass runs inside
  `session_tick`, so a game tick that mutates AFTER the frame's pump edges a
  frame late. That matters when the half MOVES something the next tick's world
  reads. A coop game that declares its host pass with
  [`@(gd_step = "authority")`](sim.md#discrete-verbs-on-the-lane) never sees
  this: the generated `<snake>_step(self, ticks)` runs the loop and the
  same-frame edge pass together. Hand-driven loops keep the manual fix: the
  pass is idempotent (diff-then-commit), so it is one call after the loop:
  `ksess.session_run_edges(&ses)`.
- **Timing**: the half fires wire-fresh, correct for row 4 of the
  [two-timelines table](#the-two-timelines-presenting-consequences)
  (scoreboards, hp, inventories: never delay these). A row-2 consequence (a
  lid on the render clock) calls `session_present` inside the body.
- **Edges say "it changed"; events say "it happened N times."** Two hits
  coalescing into one net tick were always one delta: they are one edge.
  When multiplicity or arguments matter, use the sim lane's mine-form `_fx`,
  a declared `@(gd_event)`, or a verb's consequence.

Delta lane only, held at build time: an `_edge` on a `predict` field errors
toward the mine-form `_fx` (resims would scrub it), on an `owner` field toward
dress-from-fields (it interpolates every frame). `play/edge` remains for
NON-replicated local state, where this machinery can't see.

## Advanced: registry primitives

Normal games register and mutate entity lifetime through the generated Boot
factory and typed `<type>_*` doors. These procedures are the engine-free
registry layer beneath that surface.

```odin
registry_spawn :: proc(reg: ^Registry, entity: rawptr, set: ^Command_Set, owner := PLAYER_ID_INVALID) -> Net_Id
registry_insert :: proc(reg: ^Registry, id: Net_Id, entity: rawptr, set: ^Command_Set, owner := PLAYER_ID_INVALID)
registry_remove :: proc(reg: ^Registry, id: Net_Id) -> bool
registry_get :: proc(reg: ^Registry, id: Net_Id) -> (^Registry_Entry, bool)
registry_teleport :: proc(reg: ^Registry, id: Net_Id)
```

The authority allocates ids with `registry_spawn`; remote peers mirror with
`registry_insert` under the id from the wire (which also keeps `next_id` ahead so a
migrated host keeps allocating without collisions). Net ids are never reused within a
session. If `Command_Set.net_id_offset` is nonzero, the assigned id is written back into
the entity's `net_id` field so no spawn site ever forgets it. `registry_teleport` declares
a discontinuity in the entity's streamed fields: the warp counter rides every snapshot,
and receivers snap to the far side of the jump instead of interpolating a slide across the
map.

Game code normally keeps `Net_Ref(T)`, a generic POD wrapper around `Net_Id`,
instead of a raw pointer. The generated census constructs it with `<entity>_ref`
and accepts it in `<entity>_of`; the resolver checks liveness and the declared
entity kind before returning `^T`. A replicated field such as
`target: knet.Net_Ref(Player) \`gd:"replicate"\`` therefore carries only the ID
while preventing a Chest reference from being passed to a Player lookup at
compile time. See [Boot entity queries](boot.md#entity-queries) for typed owner
queries and indexed iteration.

## The per-tick walks

Host deltas (reliable channel), and full snapshots for joins/backups:

```odin
registry_write_deltas :: proc(w: ^Writer, reg: ^Registry) -> int
registry_apply_deltas :: proc(r: ^Reader, reg: ^Registry, ctx: ^Command_Ctx = nil) -> int
registry_write_fulls :: proc(w: ^Writer, reg: ^Registry) -> int
registry_apply_fulls :: proc(r: ^Reader, reg: ^Registry, ctx: ^Command_Ctx = nil) -> int
registry_commit_shadows :: proc(reg: ^Registry)
```

Pass the client's `ctx` to the apply procs so entities with in-flight predictions get the
unwind→apply→replay reconcile; `nil` skips it (hosts, hand-driven tests). After applying an
authoritative full snapshot, call `registry_commit_shadows` so the next local diff doesn't
re-flag everything.

Owner streams (unreliable channel), plus the once-per-frame sample:

```odin
registry_write_streams :: proc(w: ^Writer, reg: ^Registry, me: Player_Id, sender_now: f64) -> int
registry_stream_time :: proc(r: ^Reader) -> f64
registry_apply_streams :: proc(r: ^Reader, reg: ^Registry, me: Player_Id, stamp: f64) -> int
registry_sample_streams :: proc(reg: ^Registry, t: f64, me: Player_Id) -> int
```

Call `registry_sample_streams` once per *frame* (not per net tick) with
`t = timeline_now - interp_delay`. Unknown ids in a stream batch are skipped by length
rather than abandoning the batch: the next tick supersedes everything anyway.

## Advanced: the command-loop primitives

Generated `<verb>_cmd` wrappers are the sole gameplay authoring surface. The
procedures below are implementation primitives for a custom session shell; they
do not provide an alternate boolean API.

```odin
command_ctx_make :: proc(allocator := context.allocator) -> Command_Ctx
command_begin :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: Cmd_Id)
command_issue :: proc(ctx: ^Command_Ctx, entity: rawptr, set: ^Command_Set, cmd: Cmd_Id) -> Command_Issue_Result
registry_host_command :: proc(reg: ^Registry, ctx: ^Command_Ctx, by: Player_Id, r: ^Reader, out: ^Writer, admission := Action_Reject_Reason.None) -> Registry_Command_Outcome
registry_client_result :: proc(reg: ^Registry, ctx: ^Command_Ctx, r: ^Reader, me := PLAYER_ID_INVALID) -> Command_Result
registry_expire_pending :: proc(reg: ^Registry, ctx: ^Command_Ctx, max_age_ticks: u64, me := PLAYER_ID_INVALID, out: ^[dynamic]Expired_Command = nil) -> int
```

The generated `<proc>_cmd` wrapper is the normal path
(`chest_take_cmd(&boot, chest, slot, px, py)`), and [kit/session](session.md)
installs the send hook and drives the host/client/expiry paths. Guarantees the loop owns:
`false` really means "no mutation" (declared fields are captured before the run and
restored on any rejection, on both peers; a command can never leave torn replicated
state); a locally-rejected prediction is still *sent* (the client's copy may be stale, only
the host may say no); and the host's per-peer `Dedup_Window` (64-command sliding window
over intent sequences) makes execution exactly-once through retransmits and reconnect
replays.

## Typed app messages

Almost everything is *state, not messages*: replicate a field, predict a
[verb](#the-command-loop), announce a presentation event. But a few things are genuinely
message-shaped: a **directed signal** (a whisper, an emote to one peer), an
**out-of-band request/response**, an **app notification tied to no entity**,
where *"if you weren't there, you don't get it"* is the correct behavior, not a
bug. That is what an app-message is for, and `@(gd_message)` is its declarative
form. Annotate a handler with the `SES_APP` [tag](session.md#app-messages) it
rides (the game owns its tag budget: the kit holds comms 0, xfer 2, sim 3):

```odin
Whisper :: struct { spice: u16, emote, reserved: u8 } // canonical 4-byte payload
TAG_WHISPER :: u8(4)

@(gd_message = "TAG_WHISPER")
game_whisper :: proc(self: ^Game, from: knet.Player_Id, msg: Whisper) {
    // the DECODED payload; `from` is the sender (the host resolves it,
    // PLAYER_ID_INVALID on a client — check on the authority when it matters)
}
```

scriptgen generates the game-owned route, a `game_messages(self, &ses)` you call
once in `ready()` (one line, like `fire_listen`), and two send doors:

```odin
game_whisper_send(&ses, msg, ksess.HOST_PEER)   // to a peer, or ksess.BROADCAST_PEER
game_whisper_send_to(&ses, player, msg)         // to a PLAYER (seat resolved on the host)
```

It is pure sugar over the runtime typed-route API
([`session_app_send_typed`](session.md#app-messages) / `session_app_listen`),
which stays available for hand-rolled routing. The generated payload has a
**canonical raw ABI**: fixed-width, recursively validated, padding-free bytes;
frame strings and other variable data yourself on a bare `session_app_route`.
Its full field layout folds into `NET_FINGERPRINT`, so a build that drifts the
payload shape is refused at the join door like any other wire-contract skew.
The declared tag must resolve to a package-level byte literal such as
`TAG_WHISPER :: u8(4)`; its numeric route, not only the identifier, enters the
schema. cavecrawl's arrival greeting is the worked example.

The counter-rule, because it is the tempting mistake: **don't send state as a
message.** "Player X's score is now 5" shipped as a message is lost to a peer who
joins a second later, and gone forever on a dropped packet. Replicate the score
instead and it is always correct, always caught up. Reach for a message only when you
*want* the opposite of those guarantees: a fire-and-forget signal to whoever is
listening right now.

## Wire, tick, and clocks

`Writer`/`Reader` are a bounds-checked, little-endian, append/cursor pair: fixed-width
fields, u16-length strings, no varints. The error model: a `Reader` that runs past its data
sets a sticky `err` and returns zero values from then on, so callers check `r.err` once
after a decode block. A malformed packet can never read out of bounds or panic, since remote
input is untrusted by default. `read_string`/`read_bytes` return zero-copy views into the
packet; clone anything you keep.

The integer prefix is not the allocation policy. Admission happens before a
decoder loops, clones, or calls game code:

| Envelope | Ceiling |
|---|---:|
| Session packet (`MAX_PACKET_BYTES`) | 1 MiB |
| One length-prefixed string/byte field (`MAX_FIELD_BYTES`) | 65,535 B |
| One counted container (`MAX_CONTAINER_ITEMS`) | 4,096 rows, within the packet ceiling |
| One replicated field / complete entity row | 65,535 B |
| Command arguments | 4 KiB by default; at most 65,535 B with an explicit policy |
| Profile row | 256 B |
| App message / entity blob | 256 KiB |
| Simulation event tuple (`SIM_FACT` wire frame) | 4 KiB |

Outgoing session packets pass the same door, so the authority cannot announce
a packet every receiver would reject. Delta and stream batches stop before the
packet ceiling and leave unsent shadows dirty for a later tick. Use `kit/xfer`
for bulk assets; its 8 KiB chunks remain ordinary bounded messages.
`read_string_limited` and `read_bytes_limited` let a subsystem choose a tighter
semantic bound than the shared field maximum.

```odin
now_s :: proc "contextless" () -> f64            // monotonic seconds
ticker_make :: proc(hz := DEFAULT_TICK_HZ) -> Ticker
ticker_advance :: proc(t: ^Ticker, frame_dt: f64) -> int
clock_sample :: proc(c: ^Clock_Sync, local_send, remote_time, local_recv: f64)
clock_remote_now :: proc(c: ^Clock_Sync, local_now: f64) -> f64
interp_render_time :: proc(c: ^Clock_Sync, local_now: f64, delay: f64) -> f64
```

`ticker_advance` returns the number of network ticks due this frame, capped at
eight so a long stall does not produce an unbounded catch-up burst. `Clock_Sync`
uses an exponentially weighted moving average over ping samples. It feeds owner
stream interpolation and the session's ping stat; it does not model long-term
clock drift. The clock also records smoothed RTT deviation as `jitter`. Read the
per-peer value with `session_clock` for diagnostics or connection-quality UI.

## The two timelines (presenting consequences)

A peer displaying a remote owner stream uses two timelines:

- **Wire time:** reliable deltas, entity lifetime, and command results apply
  when their ordered messages arrive.
- **Render time:** remote owner-streamed fields are displayed at
  `interp_delay`, providing a buffer for interpolation.

This difference matters when reliable state is the consequence of remote
movement. Applying a door-open animation immediately can make the door appear
to open before the delayed remote player reaches it. Apply authoritative state
immediately, but schedule spatial presentation with the cause when appropriate.

`session_present` selects immediate or delayed presentation from one decision
only the game knows: whether the local player's simulation caused the effect.

```odin
ksess.session_present(
	&game.ses,
	id == game.my_claim,
	game,
	present_gem_gone,
	id,
)

present_gem_gone :: proc(user: rawptr, id: knet.Net_Id, a: u64) {
	// hide, burst, sound
}
```

When `mine` is true, the callback runs immediately. Otherwise it runs on the
remote render clock. `knet.Later` is the lower-level scheduler used by this
helper.

An entity or visual state needed by a delayed effect must remain available
until the effect can run. Use a despawn dwell or `session_present`'s `extra`
delay with a reaper callback when necessary.

Every consequence classifies into one of five bins, each with an existing
tool: when something looks mistimed, find its row:

| The consequence's cause | Present it | The tool |
|---|---|---|
| **Local owner simulation** (a local claim or strike) | now | `session_present(mine = true)`, or present directly |
| **A remote moving cause** (a streamed avatar/ball reaching a thing) | at the render clock | `session_present(mine = false)` |
| **A per-peer local visual** (each screen flies its own projectile) | at *my* visual's moment | fx hooks ([kit/fx](fx.md) `On_Hit_Proc`) |
| **No spatial cause** (scoreboards, inventories, objectives) | on arrival | a [`<field>_edge` half](#field-change-edges) |
| **A global transition** (the won byte, the hole index) | after a dwell | edge-outlives-observers: hold state ≥ `interp_delay` |

Classify each consequence independently. A looted chest can update the
inventory UI immediately while delaying the lid animation to match a remote
player's rendered interaction.

Shrinking the gap globally (`interp_delay` down, `tick_hz` up via
`session_configure`) trades smoothness under jitter for freshness: aligning
presentation is almost always the better spend. One `interp_delay` can't be
right for both a LAN and a 120ms link, though: set it for the LAN and remote
motion samples past the last packet on a real link; set it for the link and the
LAN renders needlessly stale. `cfg.interp_adapt` (off by default) makes the
delay toward the worst active link's need (`rtt/2 + 2·jitter`, using the same
clock data as the ping stat), growing promptly for headroom and shrinking
slowly with hysteresis. A configured `interp_delay`
becomes the floor; `session_interp_target` reads where the slew is headed.

### If you drew the cause yourself, you own its clock

Row 3 (*each screen flies its own projectile*) hides a precondition that
`session_present` cannot check for you. `session_present(mine=false)` delays
its callback by `interp_delay` **because the cause is rendered through the
interpolated stream**: the delay is what cancels the stream's transit so the
effect lands on the rendered cause. That cancellation is only correct when the
cause really is on the interpolated timeline.

An entity the game already renders at `now - interp_delay` is already delayed.
Passing its hit or splash through `session_present(mine = false)` delays the
effect a second time. When the game owns the cause's clock, carry a timestamp
and present the consequence on that clock. Use `session_present` for causes
whose delayed rendering is owned by Kit's owner-stream interpolation.

### Projectiles: put a clock in the spawn tuple

The classic row-3 mistake, worth stating outright because it *looks* correct
and desyncs silently: replicating a projectile as a spawn-only tuple
(`{origin, dir, speed}` with **no time in it**) and starting to integrate its
motion from the moment the packet *arrives*. A peer that does this renders the
projectile one network-transit behind **forever** (the error never decays; it
is exactly this peer's ping to the shooter). Two peers at different pings see
the same bullet in *different places*; a burst spawned in one host frame lands
on timelines tens of ms apart. The tuple has no clock, so "when did it spawn"
silently becomes "when did my copy of the packet land."

The fix is one more field and a closed form:

- **Stamp the birth.** Put the host's world-time at spawn (`Birth`) and a
  `DeadAt` stamp *in the tuple* (5 fields, not 3). Evaluate position as a
  closed form of `Birth` (`pos(t) = origin + dir·speed·(t − Birth)`), not by
  integrating from arrival.
- **Draw it in the past, like everything else remote.** Render at
  `now - interp_delay`, where every other remote entity already lives, and the
  bullet is wrong by the *same amount* as the enemy it flies toward, so the
  on-screen *relationship* is right. (Chasing absolute agreement with host-now
  is the wrong target: it renders bullets passing through enemies that haven't
  visibly reacted yet.) Holds flat across every speed and ping.
- **Kill on the `DeadAt` stamp, not on arrival**, and *not* through
  `session_present` (you drew the cause; see above).
- **Bounces** are a re-based tuple (new `origin`/`dir`/`Birth`), plus a
  replicated segment counter whose *edge* is the bounce sound, not a transient
  event, because a transient event leaves a late
  joiner flying the original segment.

Steady-state cost is ~nil (a live projectile is a few bytes of tuple); the
entire cost is the spawn *burst*, so interest-management and `f16` packing
don't help projectile volume: *batching* the spawns does.

Worth knowing where the line is: a **cosmetic** row-3 visual can skip all of
this. cavecrawl's rock tracer ([kit/fx](fx.md) `tracer_add`) is a
naked spawn-tuple integrated from arrival and drawn at `now`, because it is a
*non-authoritative follower*: the rock that actually hurts is a
host-authoritative delta entity with a server-side hit test, and the tracer's
announcement rides the same one-way path as the eventual hp delta, so the two
visually coincide anyway. Per-peer position divergence on a purely cosmetic
tracer is a non-issue. The birth-stamp discipline is for a projectile whose
*position is load-bearing*: anything a peer will read to decide a hit, a
dodge, or a block.

## One package, two lanes

`kit/net` bundles two things under one name. A shared **replication substrate**
(the wire format, the field descriptors and codecs, the interpolation blend
math, the tick and clock) is consumed by both the coop lane described on this
page and by [kit/sim](sim.md), the server-authority resim lane that lives in its
own package. The **coop lane** proper (the command + owned-streams model) is
layered on top of that substrate. [kit/sim](sim.md) calls the shared part the
substrate *layer* of kit/net; this page calls the whole of it the coop
replication core. `Field_Desc` carries sim-only tuning fields (`slack`,
`glide`, `cut`) that only the sim lane reads.

Three code paths share the word *present*: `session_present` queues ONE
consequence for the render clock (see [the two
timelines](#the-two-timelines-presenting-consequences)); `lane_present` is
[kit/sim](sim.md)'s per-frame presentation pump for watched/reconciled entities;
and `kit/sim/present.odin` is the blend/error math that pump drives. They are
distinct: don't conflate them.

## Gotchas

- **A client writing a host-lane field is caught, loudly.** `self.score += 1`
  on a client compiles and looks right locally but never replicates. Every
  client re-purposes its shadow as "the bytes the framework last put here" and
  diffs against it once per net tick (the same memcmp walk the host pays to
  send): a delta-lane field that moved outside the framework asserts, naming
  the class, the field, and the fix (route it through a verb, or compute it on
  the authority). Coop speculation and the sim lane's in-flight verbs are exempt
  while pending: legal optimistic writes never trip it. Two build-time cousins
  guard the same doctrine: a direct call of a `@(gd_command)` proc is a
  scriptgen error pointing at the `<verb>_cmd` wrapper, and a gd-shaped tag
  under a typo'd namespace (`gs:"replicate"`) is named instead of silently
  ignored. The whole runtime walk strips under `-disable-assert`, like every kit
  guardrail.
- **Deltas carry STATE, not events.** The walk memcmps entity-vs-shadow once per net tick;
  a replicated byte pulsed `1 → 0` *within* one tick equals its shadow when the diff runs
  and never ships. Put edge-triggered state on bytes that outlive a tick (cavecrawl's
  `level.won` stays 1 until the next run), or use an explicit reliable message. The
  REACTION side is a [`<field>_edge` half](#field-change-edges):
  the pulse caveat is about what the wire carries, not how you observe it.
- **Owner-streamed fields are never written by network input on the owner's peer.**
  `registry_apply_streams` skips entities owned by `me`; reject-truth, prediction reverts,
  and expiry all pass `skip_owner` for them; `diff_mask` keeps them out of deltas entirely.
  Otherwise every rejected cast would visibly yank a moving owner backwards onto the host's
  lagged echo. (Full snapshots at join/world-seed do write them: that is the seeding.)
- **`registry_get` returns a pointer into the registry**, so mutations land in place with
  no store-back required. It stays valid only until the next insert/remove. Don't hold it
  across a spawn.
- **Channel ordering is load-bearing.** A delta that already contains a command's effect
  must arrive *after* that command's result, and a delta batch must never name an id the
  peer hasn't seen spawn (an unknown id abandons the batch: field sizes come from the
  descriptor the peer doesn't have). The session guarantees both by putting results, state
  batches, and spawn/despawn on the same reliable ordered channel.
- **Canonical fixed-shape values only, 64 fields max.** scriptgen recursively
  rejects platform-width leaves, implicit enum widths, pointers, unsupported
  containers, and hidden interior or tail padding, naming the complete field
  path. Generated target-side layout assertions are a second check. Group
  past-64 field counts into sub-structs (a fixed array is one field).
- **`Intent_Seq` wraparound is not handled**: u32 gives ~4 billion commands per peer per
  session.

See also: [kit/session](session.md) (drives all of this), [kit/netgd](netgd.md)
(transport), [kit/sim](sim.md) (the server-authority resim lane beside these two,
which [timelines](timelines.md) helps you choose), [kit/comms](comms.md), [kit/combat](combat.md),
[kit/save](save.md).

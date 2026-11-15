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

<a id="the-mental-model"></a>

## Replication lanes

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

The generated guard exposes the wire schema, its hashes, and structured
metadata for the package:

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
`align_of`, and field-layout assertions check those expectations in every
target compile. The raw ABI is
little-endian; a target with a different layout cannot retain the same accepted
fingerprint.

`NET_SCHEMA` exposes that metadata to tools and diagnostics. It contains flat
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

<a id="the-command-loop"></a>

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

To set a smaller encoded-argument limit, use the typed literal form. Zero uses
the 4096-byte default; a positive value is enforced before client send and
again at authority ingress:

```odin
@(gd_command = knet.Action_Policy {
	access         = .Any_Seat,
	prediction     = .Optimistic,
	max_args_bytes = 64,
})
```

Quoted command-policy strings are rejected. Use a typed preset or literal so
the compiler can check policy members.

A successful command may invoke a name-paired `<verb>_then` half for
authority-only cross-entity work such as spawning, crediting a player, or
transferring ownership.

For an optimistic command:

- confirmation retains the optimistic mutation;
- predicate rejection includes authoritative entity state rather than restoring
  a possibly stale local snapshot; admission failures send a compact result and
  restore the local capture while ordinary replication supplies newer state;
- timeout reverts an action whose result never arrives; and
- an intervening authoritative update unwinds pending predictions, applies that state,
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

`Action_Reject_Reason` groups failures by the response a game may need to show:

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
for both execution models. The generated callbacks handle verdict decoding and
sequence tracking. `model` disambiguates the two sequence/id namespaces when a
game uses both. Non-predicted actions keep a
receipt-only entry, so they confirm, reject, and time out through exactly the
same callback path without gaining speculative write privileges.

A purchase dialog, transaction prompt, or similar UI may need the final verdict
for one particular action. Turn the generated outcome into a session-scoped
receipt and poll it from the frame loop:

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

Receipts are optional and bounded (`MAX_ACTION_RECEIPTS`, 64 watched actions per
run). Polling a final result releases its watched slot; call `session_action_forget`
when the owning UI disappears first. They cover both `.Immediate` and
`.Scheduled` actions without aliasing equal raw sequences and preserve the
typed rejection reason. A pending watched receipt becomes `.Unavailable`
across reset/rehost. A small result cache closes the issue/result race for
synchronous in-memory transports.

A receipt acknowledges the action's result. Durable inventory, currency,
ownership, and world state still come from replicated fields and their change
callbacks. A receipt uses the existing action result and creates no additional
request/response protocol or wire message.

Generated command IDs are stable hashes of command names, not declaration
positions. Reordering procedures does not renumber the protocol. Renaming a
command intentionally creates a new ID; collisions within a command set are a
build error. The session's schema fingerprint provides the broader
compatibility gate.

### Reliable presentation events

`@(gd_event)` declares a typed, non-durable occurrence. The author keeps the
presentation body under `_fx`; scriptgen generates an announcement procedure
with the suffix removed, taking the game's `^Boot`:

```odin
@(gd_event = "audience=everyone,timing=auto")
chest_spark_fx :: proc(g: ^Game, chest: ^Chest, mine: bool, strength: f32) {
	particles_restart(chest, strength)
	if mine {camera_kick(g)}
}

// Announce the event from authority gameplay code.
chest_spark(&g.boot, chest, 0.8)
```

The signature is `(game, entity refs…, mine: bool, wire args…)`, with the game
pointer first. One entity parameter is the inferred anchor; with several,
write `anchor=PARAM`, or `anchor=none` for a world occurrence. Arguments after
`mine` use the command wire primitives. The body returns nothing and is
presentation only. Use commands, authority steps, and replicated fields for
damage, inventory, spawning, and other durable gameplay state.

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

The anchor also determines which transport implementation carries the event. A
sim-tracked anchor uses `SIM_FACT`; a cooperative/static event uses the
session's reliable event frame and presentation queue. Both enter the wire
fingerprint with id, argument schema, anchor, audience, and timing. Neither is
join-replayed. Cooperative/static events are authority-minted; clients ask
through commands. A sim event may also present from the owning live pass, where
it is derived from the same replayable tick rather than an unconfirmed
standalone prediction.

`@(gd_event)` is the sole declaration for presentation events. Tick `_fx`, field
`_edge`, command `_then`, and resimulation `_apply` callbacks still run in their
respective phases.

### Network tick and interpolation

For session replication, the fixed network tick (20 Hz by default) schedules
deltas and streams; ordinary gameplay may still run at frame rate. Remote owner
streams render at `interp_delay`, normally far enough behind the newest sample
to interpolate between two values. If no newer sample exists, presentation
holds the latest value instead of extrapolating indefinitely.

## Declaring a replicated entity

Tag fields and mark procedures so scriptgen can emit the descriptor. The
`owner: gd.Node2d` field below holds the Godot node; it is separate from the
network entity owner that controls write access. This example comes from
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

// After acceptance, the authority runs this cross-entity consequence.
@(gd_half)
chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: i32, px: f32, py: f32, taken: kitems.Slot) {
	cave_credit(game, by, self, taken)
}
```

Owner-streamed float/vector/quaternion fields interpolate by default:
`x, y: f32 `gd:"owner"`` (the spelunker's position). Discrete owner fields
snap to the received value; write `snap` when a float field, such as a generation
counter or meter, should also update without interpolation. The generated
descriptor uses these types:

```odin
Field_Desc :: struct {
	offset: uintptr,
	size:   int,
	flags:  Field_Flags,
	lerp:   Lerp_Kind, // how stream sampling blends this field (meaningful with .Interp)
	blend:  Blend_Proc, // required iff lerp == .Custom
	wire:   Wire_Kind, // how the field's bytes are encoded in packets (default: raw)
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

A command may return `(bool, payloads…)`. Results after the applied bool are
in-process values passed directly to `_then`; they never cross the wire.
Payload types are unconstrained, and the compiler checks them against the
`_then` signature at the generated call site.

When a predicate needs the issuing player, declare `by: knet.Player_Id` right
after the receiver, or after the wielder parameter in a composed block. The
framework supplies `ctx.me` during the issuing peer's optimistic run and the
resolved sender on the host. `_then` receives the same value.

Use this parameter when a trade needs to identify the confirming player or a
first-come claim needs to record its claimant. The issuer is never a wire
argument, so a client cannot forge it to confirm the other player's part of a
trade by changing a supplied `side: u8` value. See the
[trade recipe](session.md#recipes-over-existing-pieces). The name
is reserved: a wire argument called `by` is a build error. A player the command
targets remains ordinary wire data under another name, such as `who` or
`target`.

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
trade_confirm :: proc(self: ^Trade, by: knet.Player_Id) -> (ok: bool, sealed: bool)
```

A consequence runs once per applied command, including commands issued by the
host through the wrapper's authority branch. It never runs on a client's
optimistic run, a registry replay, a rejection, or a deduped retransmit. It
runs before the result is sent and before the tick's delta comparison,
so its mutations reach every peer in the same batch as the command's own. The
`game` parameter is the session game pointer installed through
`session_set_factory`.

For an embedded block, pair the consequence with the generated command name.
For example, `weapon: play.Gun` exposes `gun_fire` as `runner_weapon_fire`,
which pairs with `runner_weapon_fire_then`. The block implements the target
mutation and its state machine. The game handles accepted cross-entity changes
in `_then`, without dispatching on a block index or entity type. The block can
return a payload describing its result, such as a round being fired. A game
that does not consume the payload declares no `_then`.

Scriptgen validates a consequence's parameters (`[game,] self, by, wire args…,
payload…`) against the command. Every half must carry `@(gd_half)` to declare
that it is intended to pair. If it has no matching command, scriptgen reports
an error and lists the class's valid pairing names. Rename the procedure, or
remove the attribute if it is not intended as a half.

The name decides *what* a half pairs with; the attribute declares only that
pairing was intended. Both a wrong prefix (`chest_taek_then`) and a wrong suffix
(`chest_take_after`) are build errors. A proc that merely *ends* in `_then` and
never claimed to be a half is nothing special. A direct verb whose payload
nobody consumes still produces a warning. For handlers that apply to commands
regardless of their type, such as metrics, receipts, or replays, use the untyped
[command hook](session.md#command-hooks). The generated `_then` dispatch runs
through the same authority path.

A command's prediction and reconciliation cover one target entity. They cannot
capture, restore on rejection, or replay changes across multiple entities, such
as a trade that modifies both players' bags. Make the transaction itself the
target; see the [mediating-entity recipe](session.md#recipes-over-existing-pieces).

## Composing verbs from embedded blocks

An entity can embed a struct containing replicated fields and commands. A
`gd:"replicate"` field inside the embedded struct joins the containing entity's
descriptor at the combined field offset. A `@(gd_command)` procedure whose
receiver is the embedded struct joins that entity's generated command table.
This lets the block define its state and target mutations while each game
defines the cross-entity consequences.

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

// The receiver is the embedded Gun. An optional second pointer parameter
// receives the containing entity for access to its stats or cooldowns.
// This pointer is supplied locally; only the following arguments cross the wire.
@(gd_command = knet.ACTION_OWNER_PREDICTED)
gun_fire :: proc(g: ^Gun, owner: ^Runner, dx, dy: f32) -> bool { ... }

Runner :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	weapon: Gun,   // -> the entity gets `runner_weapon_fire`
}
```

The entity's generated command name includes the field path. Two blocks of the
same type therefore get distinct names and command IDs: `weapon: Gun` and
`sidearm: Gun` become `runner_weapon_fire` and `runner_sidearm_fire`. Issue the
command through `runner_weapon_fire_cmd(&boot, self, dx, dy)`. The generated
call supplies the containing entity, so the wrapper takes only the wire
arguments after `self`.

Prediction rollback and authoritative rejection snapshots cover the block's
replicated state because it is part of the entity's descriptor. Put cross-entity
effects, such as spawning a projectile or applying damage, in the game's
`runner_weapon_fire_then` [consequence](#command-consequences).

A block may optionally take a pointer to its containing entity as its second
parameter. Scriptgen detects this from the signature: use `^Runner` for a
game-specific block or `^$E` for a library block reused across entity types.
For a block imported from another `godot:` package, the generated file imports
that package and qualifies the call, such as `play.gun_fire`.

Here `Runner` names the game's character script. The optional containing-entity
pointer is separate from both its Godot node and its network entity owner.

`godot:play` provides composed `Gun`, `Ability`, `Channel`, `Health`, and
`Telegraph` blocks. The block owns its replicated state and any declared
command; the game owns cadence, world validation, presentation, and
cross-entity effects where those cannot be generalized. See the
[`godot:play` reference](play.md) and the source headers under `play/` for each
block's exact contract.

A block's `@(gd_method)` or `@(gd_rpc)` procedure also joins the containing
entity's method table. For example, `gear_level` on a `gear: Gear` field becomes
`robot_gear_level` in generated code and is registered as `gear_level` with
Godot. The generated trampoline passes `&self.gear` and supplies the containing
entity if the signature requests it. An embedded block can therefore expose
state, commands, methods, and RPCs to the appropriate `//gd:` interfaces,
including GDScript and the editor.

## Wire codecs

A field codec changes the packet representation while preserving the struct's
in-memory representation. Shadows, change detection, prediction capture and
restore, and stream rings all hold struct-layout bytes. The writer encodes
them for transmission, and the reader decodes them before applying state. A
smaller wire representation can reduce bandwidth without changing comparison
or rollback behavior.

`` gd:"replicate,...,wire=f16" `` sends f32 elements as half floats: half the
bytes, ~3 significant digits, integers exact to 2048. Cavecrawl's spelunker and
relic positions use this encoding. For another representation, declare a
fixed-size custom codec as you would a blend procedure:

```odin
hp: i32 `gd:"replicate,wire=spelunker_hp_codec"` // encode the 0..100 range with the declared codec

spelunker_hp_codec :: knet.Wire_Codec {
	size   = 1,
	encode = proc(wire, field: rawptr) {(^u8)(wire)^ = u8(clamp((^i32)(field)^, 0, 255))},
	decode = proc(field, wire: rawptr) {(^i32)(field)^ = i32((^u8)(wire)^)},
}
```

Each field's encoded size must be fixed. Within that size, a codec can quantize
values, pack bits, or send an index into a table that both peers build
deterministically from a shared seed. The receiver can then reconstruct the
entry without receiving its contents.

`decode(encode(x))` should be stable because receivers retain decoded values;
an unstable round trip can produce small corrections when predictions are
confirmed. Change detection still compares struct bytes, so a change smaller
than the wire precision still causes a send. Choose enough precision to
represent changes that affect gameplay.

## Dynamic collections

A `[dynamic]T`, slice, or map tagged `gd:"replicate"` is a build error.
Replication compares each field's bytes with a shadow, records changes in one
bit of a u64 mask, and copies the received bytes into the corresponding field.
A dynamic container's header refers to separately allocated elements, so
copying the header cannot replicate its contents. Byte comparison also has no
element identity: inserting an element at the front of an encoded collection
changes every following position. Choose a representation according to the
collection's size and update pattern:

- For a bounded collection, use a fixed array with a count or sentinel, such as
  cavecrawl's `bag: [6]kitems.Slot` with `ITEM_NONE` for empty slots. The array
  is one replicated field, so change callbacks and prediction rollback cover
  the whole value. Choose and enforce the inventory bound in game code.
- For text or authored bytes that change rarely, use an
  [entity blob](session.md#entity-blobs). Game code marks it dirty, and the
  session reliably sends the whole value and includes it in snapshots. This
  supplies the value to late joiners and to backups and saves that include the
  entity. Cavecrawl's floor inscription is an example.
- For a live collection of independently changing objects, make each element
  an entity. Spawn inserts an element, despawn removes it, and replication
  compares each element's fields. Interest management selects which entities
  a peer receives, and late joiners receive the current relevant set.
  Cavecrawl represents each floor pickup as a Pickup entity with its own
  `x/y/item/count` and typed `pickup_spawn`, rather than storing
  `pickups: [dynamic]Pickup` on the level.

The build error lists these alternatives at the field. (`gd:"backup"` still
accepts `[dynamic]`/map: the backup codec restores whole values on one
peer; it never diffs across the wire.)

## Field-change edges

Deltas carry current values. To react to a change with a hurt flash, goal
horn, or floor fanfare, declare a procedure named for the field and mark it
`@(gd_half)`. The session's per-frame change comparison passes it the old and
new values:

```odin
// ([game,] self, old, new: <the field's declared type>) — no results
@(gd_half)
gunner_hp_edge :: proc(self: ^Gunner, old, new: i32) {
	if new < old {self.flash_ttl = 0.25}
}
```

The change comparison follows these rules:

- A half runs at most once per frame for the net change. A predicting client
  may write a reliable-delta field several times through optimistic execution,
  authoritative rejection state, and reconciliation replay. The half runs
  only if the final value differs from the previous frame's value.
- A tagged POD struct or fixed array counts as one field. Group values in one
  struct when the callback must receive them together. Speedball's
  `score: Score` groups l, r, and won, so one callback receives the complete
  old and new score for each goal.
- Equal values produce no callback. A 1→0→1 pulse inside one frame has no net
  change, and resetting from level 1 to level 1 changes no bytes. To represent
  a reset, include a generation counter in the same field:
  `stage: struct { run: u16, level: u8, reserved: u8 }`. Increment `run` on a
  reset and test `old.run != new.run` for cleanup. This records same-level
  resets and within-frame round trips. A late joiner receives `run = 5` as its
  initial value and replays zero previous resets. Warp serials, spawn sequences,
  and deduplication windows use the same principle of recording an occurrence
  separately from its resulting value. For occurrences that carry payloads or
  require exactly-once presentation under resimulation, use the appropriate
  `_then` consequence, session event, [Fire announcement](combat.md), or
  simulation-lane tick payload event.
- Spawn and resync values establish a baseline without firing edges. This
  includes interest re-entry and full snapshots. Put initial presentation in
  a typed `<entity>_born` hook or the `Ev_Spawned` event, which run after fields
  are applied. The census `_spawned` hook runs earlier for bookkeeping.
- Host mutations use the same change comparison, so a hurt flash needs no
  `is_host` branch. A host-side pulse that ends within one network tick still
  does not reach clients; retain the changed state for a tick. The automatic
  edge pass runs inside `session_tick`. If the authority changes state after
  that frame's session update, its edge runs a frame late, which can matter
  when the callback moves an object read by the next simulation tick. With
  [`@(gd_step = "authority")`](sim.md#discrete-verbs-on-the-lane), the generated
  `<snake>_step(self, ticks)` runs the authority loop and edge pass together in
  the same frame. For a manually driven loop, call
  `ksess.session_run_edges(&ses)` after the loop. Comparing and then committing
  the values makes this pass idempotent.
- Edges run when the changed values are available. This is appropriate for
  scoreboards, hp, and inventories in row 4 of the
  [two-timelines table](#the-two-timelines-presenting-consequences). For spatial
  presentation that follows the render clock, such as a chest lid in row 2,
  call `session_present` inside the callback.
- Edges report a state change, so two hits combined into one network delta
  produce one edge. When the number of occurrences or their arguments matter,
  use the simulation lane's mine-form `_fx`, a declared `@(gd_event)`, or a
  command consequence.

Scriptgen permits `_edge` on reliable-delta fields and discrete owner fields.
An edge on a `predict` field is a build error because resimulation would
overwrite the change; use the mine-form `_fx`. An edge on an interpolated
`owner` field is also a build error because the value interpolates every frame;
derive presentation from the sampled fields instead. Use `play/edge` for
local state that is not replicated.

## Advanced: registry primitives

Game code normally creates and removes entities through the generated Boot
factory and typed `<type>_*` procedures. The engine-independent registry
procedures underlying them are:

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
the entity's `net_id` field. `registry_teleport` declares a discontinuity in the entity's
streamed fields. Every snapshot includes the warp counter, so receivers snap
to the destination rather than interpolating across the map.

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
unwind→apply→replay reconciliation; `nil` skips it (hosts, manually driven tests). After applying an
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
rather than abandoning the batch; later ticks supply fresh samples.

## Advanced: the command-loop primitives

Issue gameplay commands through generated `<verb>_cmd` wrappers. The procedures
below support custom session implementations and do not provide an alternate
boolean API.

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
installs the send hook and handles host execution, client results, and expiry.
The command loop captures declared fields before execution and restores them
on rejection on both peers, so a command returning `false` leaves no partial
mutation in those fields. A locally rejected prediction is still sent: the
client's copy may be stale, and the host decides whether to accept it. The
host's per-peer `Dedup_Window`, a 64-command sliding window over intent
sequences, prevents duplicate execution through retransmits and reconnect
replays.

## Typed app messages

Use replicated fields for persistent state, a [command](#the-command-loop) for
a requested mutation, and a presentation event for an effect. App messages
serve transient communication: a whisper or emote directed to one peer, an
out-of-band request/response, or a notification tied to no entity. They do not
replay for peers that join later.

Declare an app-message handler with `@(gd_message)` and the `SES_APP`
[tag](session.md#app-messages) used to route it. The game assigns its tags
around Kit's reserved routes: comms 0, xfer 2, and sim 3.

```odin
Whisper :: struct { spice: u16, emote, reserved: u8 } // canonical 4-byte payload
TAG_WHISPER :: u8(4)

@(gd_message = "TAG_WHISPER")
game_whisper :: proc(self: ^Game, from: knet.Player_Id, msg: Whisper) {
    // Decoded payload. The authority resolves `from`; clients receive
    // PLAYER_ID_INVALID. Perform sender-dependent validation on the authority.
}
```

Scriptgen generates the route, a `game_messages(self, &ses)` registration
procedure to call once in `ready()` like `fire_listen`, and two send procedures:

```odin
game_whisper_send(&ses, msg, ksess.HOST_PEER)   // to a peer, or ksess.BROADCAST_PEER
game_whisper_send_to(&ses, player, msg)         // to a player; the host resolves its seat
```

It wraps the runtime typed-route API
([`session_app_send_typed`](session.md#app-messages) / `session_app_listen`),
which remains available for custom routing. The generated payload has a
canonical raw ABI: fixed-width, recursively validated, padding-free bytes.
Frame strings and other variable data yourself on a bare `session_app_route`.
The full field layout enters `NET_FINGERPRINT`, so peers reject a join when
the builds disagree on the payload layout or another part of the wire schema.
The declared tag must resolve to a package-level byte literal such as
`TAG_WHISPER :: u8(4)`; its numeric route, not only the identifier, enters the
schema. Cavecrawl's arrival greeting is an example.

A message saying "Player X's score is now 5" does not supply that score to a
peer who joins a second later. A dropped packet can also lose the update if
the message uses unreliable delivery. Replicate the score so a snapshot can
restore its current value. Reserve messages for signals addressed to peers
that are listening when they are sent.

## Wire, tick, and clocks

`Writer`/`Reader` are a bounds-checked, little-endian, append/cursor pair: fixed-width
fields, u16-length strings, no varints. The error model: a `Reader` that runs past its data
sets a sticky `err` and returns zero values from then on, so callers check `r.err` once
after a decode block. A malformed packet can never read out of bounds or panic, since remote
input is untrusted by default. `read_string`/`read_bytes` return zero-copy views into the
packet; clone anything you keep.

Length prefixes describe the encoding; admission limits bound the work a
decoder can perform before looping, cloning data, or calling game code:

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

Outgoing session packets pass the same checks, so the authority cannot send
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

Choose a presentation method according to the consequence's cause:

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

Reducing `interp_delay` or increasing `tick_hz` through `session_configure`
reduces presentation delay but leaves less buffer for jitter. First align
effects with their causes. A delay chosen for a LAN can leave a 120ms link
without a newer motion sample to interpolate toward; a delay chosen for that
link can make LAN presentation unnecessarily late.

`cfg.interp_adapt`, off by default, adjusts toward the delay required by the
worst active link: `rtt/2 + 2·jitter`, using the same clock data as the ping
stat. It grows promptly for headroom and shrinks slowly with hysteresis. The
configured `interp_delay` becomes the floor, and `session_interp_target`
returns the target delay.

<a id="if-you-drew-the-cause-yourself-you-own-its-clock"></a>

### Game-controlled presentation clocks

For row 3, where each screen moves its own projectile, the game must schedule
effects on the projectile's clock. `session_present(mine=false)` delays its
callback by `interp_delay` to align with a cause rendered through the
interpolated stream. That alignment is correct only when the cause uses the
interpolated timeline; `session_present` cannot check this condition.

An entity the game already renders at `now - interp_delay` is already delayed.
Passing its hit or splash through `session_present(mine = false)` delays the
effect a second time. When the game owns the cause's clock, carry a timestamp
and present the consequence on that clock. Use `session_present` for causes
whose delayed rendering is owned by Kit's owner-stream interpolation.

### Projectiles: put a clock in the spawn tuple

If a projectile replicates only a spawn tuple (`{origin, dir, speed}`), each
peer may start integrating motion when its packet arrives. That makes the
local spawn time depend on packet transit. The resulting position offset
persists for the projectile's lifetime: peers with different latency display
the same bullet in different places, and projectiles spawned in one host frame
can appear tens of ms apart.

Include time in the tuple and evaluate position from it:

1. Add the host's world-time at spawn (`Birth`) and a `DeadAt` timestamp,
   producing 5 fields rather than 3. Evaluate
   `pos(t) = origin + dir·speed·(t − Birth)` instead of integrating from arrival.
2. Render at `now - interp_delay` to match the time used for other remote
   entities. Drawing the projectile at host-now while drawing its target in
   the past can make it appear to pass through a target that has not visibly
   reacted.
3. Remove the projectile at `DeadAt` on that clock. Do not add another delay
   through `session_present`.
4. For a bounce, replicate a new `origin`/`dir`/`Birth` tuple and a segment
   counter. Use the counter's edge for the bounce sound. Replicating the
   current segment lets a late joiner reconstruct it; a transient bounce
   event alone would leave that peer on the original segment.

A live projectile needs no continuous motion updates once peers have its
tuple. Spawn bursts dominate traffic in this model, so batch spawns when their
volume becomes a problem. Interest management and `f16` packing do not reduce
the number of spawn operations.

A cosmetic row-3 visual can use a less precise clock. Cavecrawl's rock tracer
([kit/fx](fx.md) `tracer_add`) integrates a spawn tuple from arrival and draws
at `now`. The host keeps the damaging rock in its local `flying` array and
tests hits there. A `Fire` announcement creates the visual; accepted damage
reaches peers through replicated hp. The rock itself is not a replicated
entity, and tracer positions can differ between peers. Use birth timestamps
when a peer relies on the projectile's position to judge a hit, dodge, or block.

<a id="one-package-two-lanes"></a>

## Shared replication and simulation primitives

`kit/net` provides the wire format, field descriptors and codecs, interpolation
math, ticks, and clocks used by both session replication and [kit/sim](sim.md).
Session replication adds commands and owner streams on top of those shared
primitives. `kit/sim` adds server-authoritative simulation and resimulation in
a separate package. Its documentation calls the shared primitives the
substrate layer of `kit/net`. `Field_Desc` also carries simulation-only tuning
fields (`slack`, `glide`, `cut`) that only the simulation lane reads.

Three related names refer to different presentation operations.
`session_present` queues one consequence for the render clock; see
[the two timelines](#the-two-timelines-presenting-consequences).
`lane_present` runs [kit/sim](sim.md)'s per-frame presentation update for
watched and reconciled entities. `kit/sim/present.odin` implements the blending
and error-correction math used by that update.

<a id="gotchas"></a>

## Constraints and failure cases

- A client write to an authority-owned field, such as `self.score += 1`,
  changes the local value without replicating it. The write guard compares
  each client's reliable-delta fields with the values last applied by the
  framework once per network tick. It reports the class, field, and required
  fix: issue a command or compute the value on the authority. Pending
  cooperative predictions and simulation commands are exempt, so permitted
  optimistic writes do not trigger the guard. Scriptgen also rejects direct
  calls to `@(gd_command)` procedures and points to the `<verb>_cmd` wrapper.
  It diagnoses gd-shaped tags under a misspelled namespace, such as
  `gs:"replicate"`, rather than ignoring them. Development builds assert on a
  violation. Under `-disable-assert`, the session retains the comparison and
  increments `session_guard_hits`; native builds
  also log the first violation. See [session](session.md#gotchas).
- Deltas compare entity bytes with their shadow once per network tick. A byte
  pulsed `1 → 0` within one tick can equal its shadow when the comparison runs,
  so no change is sent. Hold state for at least a tick, as cavecrawl does with
  `level.won` staying 1 until the next run, or use an explicit reliable message.
  A [`<field>_edge` half](#field-change-edges) reacts to received changes; it
  cannot recover a pulse that replication did not send.
- **Owner-streamed fields are never written by network input on the owner's peer.**
  `registry_apply_streams` skips entities owned by `me`; reject-truth, prediction reverts,
  and expiry all pass `skip_owner` for them; `diff_mask` keeps them out of deltas entirely.
  This prevents a rejected cast from moving the entity owner back to the host's
  older position sample. Full snapshots at join or world seeding do write
  these fields to establish their initial values.
- **`registry_get` returns a pointer into the registry**, so mutations land in place with
  no store-back required. It stays valid only until the next insert/remove. Don't hold it
  across a spawn.
- Reliable channel ordering is required. A delta that already contains a command's effect
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

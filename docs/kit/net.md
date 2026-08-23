# kit/net — the replication core

`kit/net` is the friendslop toolkit's engine-free replication core: the wire format, the
Net_Id registry, shadow-based delta replication, owner-authoritative streams with
interpolation, and the intent→command→result pipeline with client prediction. It is pure
Odin with no Godot imports, so all of it runs headless in unit tests. Games mostly consume
[kit/session](session.md), which drives these walks for you; you touch `kit/net` directly
for wire read/write in [app messages](session.md#app-messages), custom interpolation blend
procs, `Clock_Sync`, `now_s`, and hand-built descriptors in tests. The engine-facing
transport lives in [kit/netgd](netgd.md).

## The mental model

**Two authorities, disjoint by construction.** This is a command + owned-streams hybrid,
not tick-rollback netcode. When a game needs the tick-rollback kind (contested,
cheat-resistant, twitch-fair), that is [kit/sim](sim.md), a third lane beside these two,
chosen per field rather than a different library ([choosing a model](timelines.md)):

- **Owner-authoritative streams**: state with a personal owner (your movement, your aim)
  is authoritative on its owner and *interpolated* by everyone else, host included. These
  update as unreliable-sequenced snapshots with last-value semantics: a dropped packet is
  superseded by the next one, so there is no loss story at all. There is nothing to
  mispredict and nothing to resimulate.
- **Host-authoritative deltas**: shared discrete state (chests, inventory, AI, damage)
  mutates only on the host, and only through commands. Changes reach everyone via the
  shadow-delta walk on the reliable channel.

Fields flagged `.Owner_Stream` are excluded from the delta diff at the mask level
(`diff_mask` skips them), so streams and deltas can never fight over a field: full
snapshots seed the initial values, streams own them from then on.

**The shadow-delta walk.** Each registered entity owns a shadow copy of its DELTA-LANE
fields (owner-streamed and predicted fields carry their own baselines: the ring, the
ledger). Every net tick the registry memcmps entity-vs-shadow, writes `[net_id][mask][dirty
fields]` for just the dirty entities into one batched message, and commits the shadows.
The mask's bits are delta-subset ordinals, the same mask law the sim codec speaks.
Receivers apply the mask + fields straight into the entity struct. Idle entities cost one
memcmp pass and zero bytes. Replicated fields are POD only (ints/floats/bools/enums/fixed
arrays): raw bytes are compared and copied, and nothing follows pointers. Strings and
dynamic data travel as explicit reliable messages, never as replicated fields.

**Intent → command → result.** A command is a plain proc `proc(self: ^Cls, args…) -> bool`
marked `@(gd_command)` (host-only) or `@(gd_command="predict")` (optimistic). The author
writes single-player-looking mutation code with zero role branches; scriptgen generates a
decode thunk, a `Command_Desc` table, and a typed `<proc>_cmd` issue wrapper holding the
*only* role branch: the authority runs the proc directly (deltas carry the change), a
client serializes the args once, optionally re-runs the *same* proc from those bytes
(prediction: client and host execute from byte-identical input), and ships the command to
the host. Prediction needs no hand-written undo: the declared-field snapshot captured
before the optimistic run is the automatic revert. The verb's cross-entity half (credit
the looter, launch the projectile, hand off ownership) is a second plain proc named
`<verb>_then` ([consequences](#consequences-verb_then), below), which fires on the
authority only, right after the verb applies. Then:

- **Confirm**: header only, since the optimistic state already matches and nothing needs
  to replay.
- **Reject carries truth**: the result carries a full field snapshot of the entity, so a
  stale client snaps to authoritative values instead of restoring a possibly-stale local
  revert.
- **Timeout**: a result that never arrives auto-reverts after `max_age_ticks`
  (`registry_expire_pending`); a silent host must read as "no".
- **Replay reconcile**: authoritative state landing on an entity with in-flight
  predictions is applied as *unwind → apply → replay*: pending reverts are restored
  newest-first, the authoritative delta/full/truth applies, then each pending command
  re-runs oldest-first from its stored wire bytes, recapturing its revert against the
  fresh baseline. A replay whose precondition no longer holds is dropped locally; the
  host's in-flight result has the final word either way.

**The wrapper: one surface on both models.** `<verb>_cmd(b: ^kboot.Boot,
self, args…) -> knet.Command_Outcome` takes the boot as the game's one handle,
and the generated body holds the routing: a coop class's verb rides the session's
command loop, a ticking class's rides the sim lane (tick-scheduled), and
promoting an entity between models leaves every issue site byte-identical.
The return has the SAME meaning on every peer, so the call site needs no
`is_host` branch: `.Applied` (the host accepted it, which is authoritative,
for coop only; a sim verb executes at its stamped tick rather than inline, so
even the authority's own issue reports `.Predicted`), `.Predicted` (in flight
on my screen: optimistically applied if it predicts, otherwise just sent), or
`.Rejected` (the predicate said no on this peer: final on the host, a
reverted local apply on a client). "Did it show on my screen?" is
`knet.command_ok(r)` (`r != .Rejected`); "is it authoritative?" is
`r == .Applied`. (A game not using kit/boot issues through the raw layer below.)

**Command ids are stable name hashes, not positions.** The generated
`<CLASS>_CMD_<VERB>` constants (and both command wires, coop and sim) carry an
FNV-1a hash of the verb's name, so reordering, adding, or removing procs never
renumbers the protocol. A version-skewed peer's unknown id MISSES the receiver's
lookup and rejects cleanly instead of dispatching to whatever now lives at that
position. A renamed verb is a new id: it IS a different verb, and stale clients
get the correct refusal. Same-set collisions are a build error naming both verbs
(rename one). Hand-built `Command_Desc`/`Sim_Cmd` sets pick their own ids, unique
within the set (a single command's zero value is fine).

**The tick paces the wire, not the sim.** The fixed net tick (default 20 Hz) is when
deltas are diffed and streams are sent; gameplay runs at frame rate. Remote entities render
`interp_delay` in the past (~2–3 send intervals) so there is almost always a bracketing
sample pair to lerp between. Past the newest sample, the toolkit clamps and *holds*
rather than extrapolating: a briefly frozen enemy beats one that rockets off on a stale
velocity.

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

@(gd_command = "predict")
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

Owner-streamed, interpolated fields add flags: `x, y: f32 `gd:"owner,interp"``
(the spelunker's position). Under the hood these become:

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

## Consequences (`<verb>_then`)

A command proc may only mutate its **target**, which is what the predict/revert/
reject-truth machinery protects. The verb's *other* half ("…and the items land
in the looter's bag", "…and the rock launches") is host-side code, and it has a
name-paired home: declare a plain proc named after the verb's wrapper plus
`_then`, and scriptgen threads it the issuer, the verb's wire args, and the
verb's returned **payload**, firing it on the AUTHORITY only, right after the
verb applies. Two shapes, detected by the leading param:

```odin
@(gd_half) chest_take_then :: proc(game: ^CaveLobby, self: ^Chest, by: knet.Player_Id, slot: i32, px: f32, py: f32, taken: kitems.Slot)
@(gd_half) door_toggle_then :: proc(self: ^Door, by: knet.Player_Id)   // entity-local: no game param
```

**Payload returns.** A verb may return `(bool, facts…)`: results after the
applied bool are in-process values handed straight to the `_then` (they never
cross the wire). Payload types are unconstrained, since the generated call site
lets the compiler hold the `_then` signature to them.

**The verb can see the issuer too.** When the *predicate* needs WHO (a trade
window arbitrating which seat is confirming, a first-come claim recording its
claimant), declare `by: knet.Player_Id` right after the receiver (after the
wielder param in a composed block) and the framework fills it: `ctx.me` on the
issuing peer's optimistic run, the resolved sender on the host; these are the
same values the `_then` gets. It never rides the wire, so it can't be forged:
a hostile client can't hand you a `side: u8` it flipped to confirm the *other*
party's half of a trade, because WHO is never a wire argument (the worked
rewrite is the [trade recipe](session.md#recipes-over-existing-pieces)).
The name is reserved: a wire arg called `by` is a build error. A player the
verb merely *targets* stays ordinary wire data under any other name (`who`,
`target`).

```odin
@(gd_command = "predict")
trade_confirm :: proc(self: ^Trade, by: knet.Player_Id) -> (ok: bool, sealed: bool)
```

**The guarantees.** A consequence fires exactly once per applied command,
including on the host's own issues (the wrapper's authority branch), and never
on a client's optimistic run, a registry replay, a rejection, or a deduped
retransmit. It runs before the result ships and before the tick's delta diff,
so its mutations reach every peer in the same batch as the verb's own. The
`game` param is the session's one game pointer: the `user` you handed
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
[command hook](session.md#command-hooks-the-generic-layer-under-_then) remains
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
@(gd_command = "predict")
gun_fire :: proc(g: ^Gun, owner: ^Runner, dx, dy: f32) -> bool { ... }

Runner :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	weapon: Gun,   // -> the entity gets `runner_weapon_fire`
}
```

The entity's generated command is named by the **field path**, so two blocks of the same type
never collide (`weapon: Gun` + `sidearm: Gun` → `runner_weapon_fire` + `runner_sidearm_fire`,
distinct wire indices). Issue it exactly like a direct command
(`runner_weapon_fire_cmd(&boot, self, dx, dy)`); the owner is passed for you, so only the wire
args appear in the wrapper. Prediction reverts and reject-truth snapshots cover the block's
replicated state for free (it's already in the entity's descriptor), and the block's
cross-entity effects (spawning a projectile, applying damage) live in the game's
`runner_weapon_fire_then` [consequence](#consequences-verb_then), exactly as a direct command's
do: the block ships the verb, the game keeps the "and then".

Owner threading is optional and detected by shape: write `^Runner` for a game-specific block, or
`^$E` for a library block reused across entity types. A block imported from another `godot:`
package works identically: the generated file imports and qualifies it (`play.gun_fire`).

`godot:play` ships worked ones: **`play.Gun`** (mag + reload + jam, knob-configured by a
`Gun_Def`, host-authoritative and client-predicted through its `gun_fire` verb: embed
`weapon: play.Gun`, `gun_equip` it, pace the trigger, spawn the shot in your hook from the
pull's aim + carried origin — `ox, oy` is the wielder's OWN muzzle, so an owner-streamed
wielder's shot leaves where its screen saw it, not the host's lagged copy; leash it there with
`kcombat.leash` before launching),
**`play.Ability`** (a cooldown-gated cast, the slow lob/cone/buff: embed one per slot,
`ability_arm` it, run the effect in your hook on `ok`; the block owns its cooldown, since a
slow ability's gate dwarfs the round-trip; for casts that spend a resource or slots indexed
at runtime, drop down to `kcombat.Cooldowns`/`ability_try`, the layer underneath: see
[kit/combat](combat.md#health-and-abilities)), and **`play.Channel`** (hold-to-progress, the
revive/capture/cast-bar: OWNER-authored, its `target`/`pct` ride the owner stream so every
screen draws the bar, and its composed plain `claim` carries the target as a wire arg for
your hook to re-check and honor), and **`play.Health`** (hp + max + the per-peer damage
edge, VERB-FREE, because damage is host-internal, never a client intent: a block doesn't
need commands to be worth composing; `health_hurt` returns the dealt/died pair your credit
and death-payout logic branch on, `health_step` drives damage numbers and death cues on
every screen), and **`play.Telegraph`** (a wind-up that lands, the "get out of the circle"
shape, also verb-free: `left` AND `wind` replicate so every peer draws the exact growth
fraction even for a hastened wind-up, `telegraph_tick` lands the host payload once,
`telegraph_step` erupts on every screen in lockstep, and a cancel goes quiet). There is one
block per authority model (host-written command prediction, cooldown gate, owner stream),
plus the verb-free state block. The state machine is the block's; the
effect, the world-gates (alive? in reach?), and for the gun the cadence, stay yours.
They're the reference for the pattern; read `play/gun.odin`, `play/ability.odin`,
`play/channel.odin`, `play/health.odin`.

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

## Collections — the `[dynamic]` stance

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
  design: a friendslop game should own "six slots", not defer it.
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

## Edges (`<class>_<field>_edge`) — presenting delta-lane changes

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
  **generation counter co-located in the diff atom**: `stage: struct { level: u8, run: u16 }`,
  where a reset bumps `run`, so same-level resets and within-frame round trips both
  land as real transitions (`old.run != new.run` is the cleanup branch), and a
  late joiner's silent seed correctly replays *zero* of them (they see
  `run = 5` as a baseline). It is the same move the kit makes everywhere state
  alone can't carry an occurrence: warp serials, spawn seqs, dedup windows.
  When the occurrence carries payload or must fire exactly-once under resim, it
  has outgrown edges: that's a `_then` consequence, a session event, a
  [Fire announcement](combat.md), or a sim-lane fact.
- **First sight seeds; resync re-seeds silently.** Spawn values are a
  baseline, not an edge; a wholesale catch-up (interest re-entry, a snapshot
  over live state) is history, not gameplay. Initial dress (a late joiner's
  3-2 scoreboard) rides `Ev_Spawned`: the event fires with the tuple's
  fields SET; the census `_spawned` hook fires before they apply and is
  bookkeeping only.
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
- **Edges say "it changed"; facts say "it happened N times."** Two hits
  coalescing into one net tick were always one delta: they are one edge.
  When multiplicity or arguments matter, that is a FACT: the sim lane's
  mine-form `_fx`, or a verb's consequence.

Delta lane only, held at build time: an `_edge` on a `predict` field errors
toward the mine-form `_fx` (resims would scrub it), on an `owner` field toward
dress-from-fields (it interpolates every frame). `play/edge` remains for
NON-replicated local state, where this machinery can't see.

## Registering entities

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

## The command loop

```odin
command_ctx_make :: proc(allocator := context.allocator) -> Command_Ctx
command_begin :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: u16)
command_issue :: proc(ctx: ^Command_Ctx, entity: rawptr, set: ^Command_Set, cmd: u16) -> bool
registry_host_command :: proc(reg: ^Registry, ctx: ^Command_Ctx, peer_key: u64, r: ^Reader, out: ^Writer) -> (responded: bool, ok: bool, h: Command_Header)
registry_client_result :: proc(reg: ^Registry, ctx: ^Command_Ctx, r: ^Reader, me := PLAYER_ID_INVALID) -> Command_Result
registry_expire_pending :: proc(reg: ^Registry, ctx: ^Command_Ctx, max_age_ticks: u64, me := PLAYER_ID_INVALID, out: ^[dynamic]Expired_Command = nil) -> int
```

You rarely call these by hand: the generated `<proc>_cmd` wrapper is the whole author
surface (`chest_take_cmd(&boot, chest, slot, px, py)`), and [kit/session](session.md)
installs the send hook and drives the host/client/expiry paths. Guarantees the loop owns:
`false` really means "no mutation" (declared fields are captured before the run and
restored on any rejection, on both peers; a command can never leave torn replicated
state); a locally-rejected prediction is still *sent* (the client's copy may be stale, only
the host may say no); and the host's per-peer `Dedup_Window` (64-command sliding window
over intent sequences) makes execution exactly-once through retransmits and reconnect
replays.

## Typed app-messages (`@(gd_message)`)

Almost everything is *state, not messages*: replicate a field, predict a
[verb](#the-command-loop), broadcast a fact. But a few things are genuinely
message-shaped: a **directed signal** (a whisper, an emote to one peer), an
**out-of-band request/response**, an **app notification tied to no entity**,
where *"if you weren't there, you don't get it"* is the correct behavior, not a
bug. That is what an app-message is for, and `@(gd_message)` is its declarative
form. Annotate a handler with the `SES_APP` [tag](session.md#app-messages) it
rides (the game owns its tag budget: the kit holds comms 0, xfer 2, sim 3):

```odin
Whisper :: struct { emote: u8, spice: u16 }   // a POD payload
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
which stays available for hand-rolled routing. The payload is **POD** (the raw
bytes cross the wire: no strings, slices, or pointers; frame those yourself on a
bare `session_app_route`), and its **field layout folds into `NET_FINGERPRINT`**,
so a build that drifts the payload shape is refused at the join door like any
other wire-contract skew. cavecrawl's arrival greeting is the worked example.

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

```odin
now_s :: proc "contextless" () -> f64            // monotonic seconds — THE toolkit clock
ticker_make :: proc(hz := DEFAULT_TICK_HZ) -> Ticker
ticker_advance :: proc(t: ^Ticker, frame_dt: f64) -> int
clock_sample :: proc(c: ^Clock_Sync, local_send, remote_time, local_recv: f64)
clock_remote_now :: proc(c: ^Clock_Sync, local_now: f64) -> f64
interp_render_time :: proc(c: ^Clock_Sync, local_now: f64, delay: f64) -> f64
```

`ticker_advance` returns how many net ticks fire this frame (capped at 8: a multi-second
stall resumes cleanly instead of bursting a backlog; deltas are last-value, and nothing is
lost). `Clock_Sync` is an EWMA over ping samples (friendslop-grade, no drift modeling)
and feeds both interpolation timelines and the session's automatic ping stat. It also
tracks `jitter` (smoothed |rtt − mean| deviation): the connection-QUALITY number. A
steady 120ms link plays better than one wobbling 40..200ms. Read it per peer via
`session_clock(s, peer)` and surface it however your game likes (a colored dot beats a
number).

## The two timelines (presenting consequences)

A peer watching a remote simulation lives on two clocks, and mixing them up is
the most common way a correct game looks wrong:

- **The wire timeline.** Reliable state (deltas, spawns/despawns, command
  results) applies the moment it arrives: ~one-way latency after it happened.
- **The render timeline.** Remote-owned entities DRAW `interp_delay` in the
  past; that buffer is what turns a 20 Hz stream into smooth motion.

The skew between them is ~`interp_delay`, and it shows up whenever a
consequence of someone else's simulation is applied on arrival: the gem
vanishes before the rendered ball reaches it, the door opens before the
rendered cart docks. This is the structural cost of interpolation netcode:
resim engines collapse to one timeline by re-simulating the past, and pay in
CPU, determinism requirements, and visible correction pops. This toolkit's
model never mispredicts and never pops; in exchange, YOU choose the timeline
each thing presents on. The discipline is three lines:

1. **Your own simulation presents NOW**: the owner's screen is the truth
   everyone else is waiting to see.
2. **Consequences of remote simulations present on the render timeline**:
   both the event and the stream crossed the same wire, so transit cancels:
   delay the *presentation* (never the state) by the interp delay and it lands
   within jitter of the rendered cause. `ksess.session_present` is the whole
   discipline in one call: you state the one fact the kit can't derive
   (did MY simulation cause this?), it presents now or queues for the render
   clock, and one presentation proc holds the whole effect (no verb enums, no
   drain switch, the same one-proc shape that makes `@(gd_command)` pleasant):

   ```odin
   // the taken-edge, ONE place, identical on every peer:
   ksess.session_present(&g.ses, id == g.my_claim, g, present_gem_gone, id)

   present_gem_gone :: proc(user: rawptr, id: knet.Net_Id, a: u64) { /* hide, burst, sound */ }
   ```

   (`knet.Later` underneath stays public for engine-free tests and custom
   clocks.) For spatial events you can be exact instead of statistical: gate
   the visual on the RENDERED entity reaching the spot.
3. **Edges must outlive the slowest observer**: the authority keeps the
   entity/state alive ≥ `interp_delay` past the event (a despawn dwell, a
   sink dwell: `session_present(..., extra = 0.4)` with a reaper proc), or
   there is nothing left on screen to present when the render clock gets
   there.

Every consequence classifies into one of five bins, each with an existing
tool: when something looks mistimed, find its row:

| The consequence's cause | Present it | The tool |
|---|---|---|
| **My own simulation** (I claimed it, I struck it) | now | `session_present(mine = true)`, or just do it |
| **A remote moving cause** (a streamed avatar/ball reaching a thing) | at the render clock | `session_present(mine = false)` |
| **A per-peer local visual** (each screen flies its own projectile) | at *my* visual's moment | fx hooks ([kit/fx](fx.md) `On_Hit_Proc`) |
| **No spatial cause** (scoreboards, inventories, objectives) | wire-fresh | a [`<field>_edge` half](#edges-class_field_edge--presenting-delta-lane-changes), *never* delay these |
| **A global transition** (the won byte, the hole index) | after a dwell | edge-outlives-observers: hold state ≥ `interp_delay` |

The bins are per-CONSEQUENCE, not per-entity: one looted chest updates the
looter's bag UI wire-fresh (row 4) while its lid swings open on the render
clock (row 2). And the timing decision hangs on one fact only the game knows
(*did my simulation cause this?*), which is why `session_present` takes it as
a boolean instead of guessing (a wrong guess here is Unreal's RepNotify
double-fire, imported).

Shrinking the gap globally (`interp_delay` down, `tick_hz` up via
`session_configure`) trades smoothness under jitter for freshness: aligning
presentation is almost always the better spend. One `interp_delay` can't be
right for both a LAN and a 120ms link, though: set it for the LAN and remote
motion samples past the last packet on a real link; set it for the link and the
LAN renders needlessly stale. `cfg.interp_adapt` (off by default) makes the
delay *slew* to the worst active link's need (`rtt/2 + 2·jitter`, over the same
ClockSync the ping stat reads), growing promptly for headroom and shrinking
slowly and hysteretically so it never shrinks into a spike. A set `interp_delay`
becomes the floor; `session_interp_target` reads where the slew is headed.

### If you drew the cause yourself, you own its clock

Row 3 (*each screen flies its own projectile*) hides a precondition that
`session_present` cannot check for you. `session_present(mine=false)` delays
its callback by `interp_delay` **because the cause is rendered through the
interpolated stream**: the delay is what cancels the stream's transit so the
effect lands on the rendered cause. That cancellation is only correct when the
cause really is on the interpolated timeline.

An entity your game **dead-reckons into the past itself** (a spawn-tuple
projectile you draw at `now - interp_delay`) is *already* delayed. Route its
consequence (a hit, a splash) through `session_present` and you delay it a
*second* time: the effect lands `interp_delay` behind a cause that was already
`interp_delay` behind. (Measured on the C# port: a hit routed through Present
landed 71px off vs 19px for stamping the hit instant and killing on the stamp.)
The rule: **if you drew the cause yourself, carry a timestamp and present on it;
don't ask `session_present`.** Present is for consequences of the
kit-interpolated stream (streamed avatars, owner-streamed balls), which is
every row-2 case and most of what you write. Row 3 is the exception, and
row 3 is where you own the clock.

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
  replicated segment counter whose *edge* is the bounce sound, not a
  fact, because a fact leaves a late
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
  REACTION side is a [`<field>_edge` half](#edges-class_field_edge--presenting-delta-lane-changes):
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
- **POD only, 64 fields max.** Syntactic collections (`[dynamic]`, slices, maps) are a
  scriptgen error with [the three-way stance](#collections--the-dynamic-stance) spelled
  out; deeper non-POD (a struct hiding a string) fails the generated `#assert` at the
  consumer compile, naming the field. Group past-64 field counts into sub-structs (a
  fixed array is one field).
- **`Intent_Seq` wraparound is not handled**: u32 gives ~4 billion commands per peer per
  session.

See also: [kit/session](session.md) (drives all of this), [kit/netgd](netgd.md)
(transport), [kit/sim](sim.md) (the server-authority resim lane beside these two,
which [timelines](timelines.md) helps you choose), [kit/comms](comms.md), [kit/combat](combat.md),
[kit/save](save.md).

# kit/net — the replication core

`kit/net` is the friendslop toolkit's engine-free replication core: the wire format, the
Net_Id registry, shadow-based delta replication, owner-authoritative streams with
interpolation, and the intent→command→result pipeline with client prediction. It is pure
Odin — no Godot imports — so all of it runs headless in unit tests. Games mostly consume
[kit/session](session.md), which drives these walks for you; you touch `kit/net` directly
for wire read/write in [app messages](session.md#app-messages), custom interpolation blend
procs, `Clock_Sync`, `now_s`, and hand-built descriptors in tests. The engine-facing
transport lives in [kit/netgd](netgd.md).

## The mental model

**Two authorities, disjoint by construction.** This is a command + owned-streams hybrid,
not tick-rollback netcode:

- **Owner-authoritative streams** — state with a personal owner (your movement, your aim)
  is authoritative on its owner and *interpolated* by everyone else, host included. Sent as
  unreliable-sequenced snapshots with last-value semantics: a dropped packet is superseded
  by the next one, so there is no loss story at all. Nothing to mispredict, nothing to
  resimulate.
- **Host-authoritative deltas** — shared discrete state (chests, inventory, AI, damage)
  mutates only on the host, and only through commands. Changes reach everyone via the
  shadow-delta walk on the reliable channel.

Fields flagged `.Owner_Stream` are excluded from the delta diff at the mask level
(`diff_mask` skips them), so streams and deltas can never fight over a field: full
snapshots seed the initial values, streams own them from then on.

**The shadow-delta walk.** Each registered entity owns a shadow copy of its replicated
fields. Every net tick the registry memcmps entity-vs-shadow, writes `[net_id][mask][dirty
fields]` for just the dirty entities into one batched message, and commits the shadows.
Receivers apply the mask + fields straight into the entity struct. Idle entities cost one
memcmp pass and zero bytes. Replicated fields are POD only (ints/floats/bools/enums/fixed
arrays) — raw bytes are compared and copied, nothing follows pointers. Strings and dynamic
data travel as explicit reliable messages, never as replicated fields.

**Intent → command → result.** A command is a plain proc `proc(self: ^Cls, args…) -> bool`
marked `@(gd_command)` (host-only) or `@(gd_command="predict")` (optimistic). The author
writes single-player-looking mutation code with zero role branches; scriptgen generates a
decode thunk, a `Command_Desc` table, and a typed `<proc>_cmd` issue wrapper holding the
*only* role branch: the authority runs the proc directly (deltas carry the change), a
client serializes the args once, optionally re-runs the *same* proc from those bytes
(prediction — client and host execute from byte-identical input), and ships the command to
the host. Prediction needs no hand-written undo: the declared-field snapshot captured
before the optimistic run is the automatic revert. Then:

- **Confirm** — header only; the optimistic state already matches, nothing replays.
- **Reject carries truth** — a full field snapshot of the entity, so a stale client snaps
  to authoritative values instead of restoring a possibly-stale local revert.
- **Timeout** — a result that never arrives auto-reverts after `max_age_ticks`
  (`registry_expire_pending`): a silent host must read as "no".
- **Replay reconcile** — authoritative state landing on an entity with in-flight
  predictions is applied as *unwind → apply → replay*: pending reverts are restored
  newest-first, the authoritative delta/full/truth applies, then each pending command
  re-runs oldest-first from its stored wire bytes, recapturing its revert against the
  fresh baseline. A replay whose precondition no longer holds is dropped locally; the
  host's in-flight result has the final word either way.

**The tick paces the wire, not the sim.** The fixed net tick (default 20 Hz) is when
deltas are diffed and streams are sent; gameplay runs at frame rate. Remote entities render
`interp_delay` in the past (~2–3 send intervals) so there is almost always a bracketing
sample pair to lerp between — and past the newest sample the toolkit clamps and *holds*,
never extrapolates: a briefly frozen enemy beats one that rockets off on a stale velocity.

## Declaring a replicated entity

In a game you tag fields and mark procs; scriptgen emits the descriptor. From
`examples/cavecrawl/scripts/chest.odin`:

```odin
Chest :: struct {
	owner:     gd.Node2d,
	net_id:    knet.Net_Id,
	x, y:      f32 `gd:"replicate"`,
	slots:     [8]kitems.Slot `gd:"replicate"`,
	last_take: kitems.Slot, // scratch for the command hook — never on the wire
}

@(gd_command = "predict")
chest_take :: proc(self: ^Chest, slot: i32, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), 99) // the whole stack
	if taken.count == 0 {return false}
	self.last_take = taken
	return true
}
```

Owner-streamed, interpolated fields add flags: `x, y: f32 `gd:"replicate,interp,owner"``
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
(nlerp with hemisphere flip), and `.Custom` with an author-supplied
`Blend_Proc :: proc(dst, a, b: rawptr, alpha: f32)` — declared via
`` heading: f32 `gd:"replicate,owner,interp=blend_heading"` ``.

## Composing verbs from embedded blocks

Replicated fields compose through an embed — a `gd:"replicate"` field inside a sub-struct
joins its wielder's descriptor via a composed offset, so a building block's state travels with
it. **Its commands compose the same way.** A `@(gd_command)` proc whose receiver is an embedded
sub-struct is hoisted onto whatever entity embeds it, generated onto *that* entity's command
table — the dual of nested-field replication, and what turns a plain struct into a true drop-in
gameplay block.

Declare the verb on the block, embed the block, and the entity gets the command:

```odin
Gun :: struct {
	ammo:      u8 `gd:"replicate"`,
	fsm:       play.Machine(Gun_State),
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
distinct wire indices). Issue it exactly like a direct command —
`runner_weapon_fire_cmd(ctx, self, dx, dy)` — the owner is passed for you, so only the wire args
appear in the wrapper. Prediction reverts and reject-truth snapshots cover the block's replicated
state for free (it's already in the entity's descriptor), and the block's cross-entity effects
(spawning a projectile, applying damage) stay in the game's command hook, keyed by the composed
index, exactly as a direct command's do.

Owner threading is optional and detected by shape — write `^Runner` for a game-specific block, or
`^$E` for a library block reused across entity types. A block imported from another `godot:`
package works identically: the generated file imports and qualifies it (`play.gun_fire`).

`godot:play` ships a worked one — **`play.Gun`** (mag + reload + jam, knob-configured by a
`Gun_Def`, host-authoritative and client-predicted through its `gun_fire` verb). Embed
`weapon: play.Gun`, `gun_equip` it with your knobs, pace the trigger and spawn the shot in your
hook — the state machine is the block's, the cadence and the effect stay yours. It's the
reference for the pattern; read `play/gun.odin`.

## Wire codecs

A field may re-encode its bytes inside packets. The struct-side representation
never changes — shadows, dirty diffing, prediction capture/restore, and stream
rings all hold struct-layout bytes; wire bytes exist only between writer and
reader, decoded at the packet edge. So a codec buys bandwidth (and lets the
wire representation differ from the in-memory one) without touching any of the
comparison/revert machinery.

`` gd:"replicate,...,wire=f16" `` ships f32 elements as half floats — half the
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

The wire size is FIXED per field — that fixed-size contract is exactly what
frees the representation: quantize, bit-pack, or ship an *index* into a
structure both sides grow deterministically (a shared-seed table means the wire
only needs to name an entry, not carry it). Two rules keep codecs honest:
`decode(encode(x))` should be stable (receivers hold decoded values; an
unstable round trip makes confirmed predictions micro-snap), and dirtiness is
still diffed on struct bytes — a change smaller than the wire precision still
sends, so pick a precision at least as fine as gameplay cares about.
Variable-length state doesn't belong in fields at all: use an entity blob
(kit/session) or an explicit message.

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
a discontinuity in the entity's streamed fields — the warp counter rides every snapshot,
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
rather than abandoning the batch — the next tick supersedes everything anyway.

## The command loop

```odin
command_ctx_make :: proc(allocator := context.allocator) -> Command_Ctx
command_begin :: proc(ctx: ^Command_Ctx, entity: Net_Id, cmd: u16)
command_issue :: proc(ctx: ^Command_Ctx, entity: rawptr, set: ^Command_Set, cmd: u16) -> bool
registry_host_command :: proc(reg: ^Registry, ctx: ^Command_Ctx, peer_key: u64, r: ^Reader, out: ^Writer) -> (responded: bool, ok: bool, h: Command_Header)
registry_client_result :: proc(reg: ^Registry, ctx: ^Command_Ctx, r: ^Reader, me := PLAYER_ID_INVALID) -> Command_Result
registry_expire_pending :: proc(reg: ^Registry, ctx: ^Command_Ctx, max_age_ticks: u64, me := PLAYER_ID_INVALID, out: ^[dynamic]Expired_Command = nil) -> int
```

You rarely call these by hand — the generated `<proc>_cmd` wrapper is the whole author
surface (`chest_take_cmd(ctx, chest, slot, px, py)`), and [kit/session](session.md)
installs the send hook and drives the host/client/expiry paths. Guarantees the loop owns:
`false` really means "no mutation" (declared fields are captured before the run and
restored on any rejection, on both peers — a command can never leave torn replicated
state); a locally-rejected prediction is still *sent* (the client's copy may be stale, only
the host may say no); and the host's per-peer `Dedup_Window` (64-command sliding window
over intent sequences) makes execution exactly-once through retransmits and reconnect
replays.

## Wire, tick, and clocks

`Writer`/`Reader` are a bounds-checked, little-endian, append/cursor pair: fixed-width
fields, u16-length strings, no varints — deliberately boring. The error model: a `Reader`
that runs past its data sets a sticky `err` and returns zero values from then on, so
callers check `r.err` once after a decode block. A malformed packet can never read out of
bounds or panic — remote input is untrusted by default. `read_string`/`read_bytes` return
zero-copy views into the packet; clone anything you keep.

```odin
now_s :: proc "contextless" () -> f64            // monotonic seconds — THE toolkit clock
ticker_make :: proc(hz := DEFAULT_TICK_HZ) -> Ticker
ticker_advance :: proc(t: ^Ticker, frame_dt: f64) -> int
clock_sample :: proc(c: ^Clock_Sync, local_send, remote_time, local_recv: f64)
clock_remote_now :: proc(c: ^Clock_Sync, local_now: f64) -> f64
interp_render_time :: proc(c: ^Clock_Sync, local_now: f64, delay: f64) -> f64
```

`ticker_advance` returns how many net ticks fire this frame (capped at 8 — a multi-second
stall resumes cleanly instead of bursting a backlog; deltas are last-value, nothing is
lost). `Clock_Sync` is an EWMA over ping samples — friendslop-grade, no drift modeling —
and feeds both interpolation timelines and the session's automatic ping stat. It also
tracks `jitter` (smoothed |rtt − mean| deviation): the connection-QUALITY number — a
steady 120ms link plays better than one wobbling 40..200ms. Read it per peer via
`session_clock(s, peer)` and surface it however your game likes (a colored dot beats a
number).

## The two timelines (presenting consequences)

A peer watching a remote simulation lives on two clocks, and mixing them up is
the most common way a correct game looks wrong:

- **The wire timeline.** Reliable state — deltas, spawns/despawns, command
  results — applies the moment it arrives: ~one-way latency after it happened.
- **The render timeline.** Remote-owned entities DRAW `interp_delay` in the
  past; that buffer is what turns a 20 Hz stream into smooth motion.

The skew between them is ~`interp_delay`, and it shows up whenever a
consequence of someone else's simulation is applied on arrival: the gem
vanishes before the rendered ball reaches it, the door opens before the
rendered cart docks. This is the structural cost of interpolation netcode —
resim engines collapse to one timeline by re-simulating the past, and pay in
CPU, determinism requirements, and visible correction pops. This toolkit's
model never mispredicts and never pops; in exchange, YOU choose the timeline
each thing presents on. The discipline is three lines:

1. **Your own simulation presents NOW** — the owner's screen is the truth
   everyone else is waiting to see.
2. **Consequences of remote simulations present on the render timeline** —
   both the event and the stream crossed the same wire, so transit cancels:
   delay the *presentation* (never the state) by the interp delay and it lands
   within jitter of the rendered cause. `ksess.session_present` is the whole
   discipline in one call — you state the one fact the kit can't derive
   (did MY simulation cause this?), it presents now or queues for the render
   clock, and one presentation proc holds the whole effect (no verb enums, no
   drain switch — the same one-proc shape that makes `@(gd_command)` pleasant):

   ```odin
   // the taken-edge, ONE place, identical on every peer:
   ksess.session_present(&g.ses, id == g.my_claim, g, present_gem_gone, id)

   present_gem_gone :: proc(user: rawptr, id: knet.Net_Id, a: u64) { /* hide, burst, sound */ }
   ```

   (`knet.Later` underneath stays public for engine-free tests and custom
   clocks.) For spatial events you can be exact instead of statistical: gate
   the visual on the RENDERED entity reaching the spot.
3. **Edges must outlive the slowest observer** — the authority keeps the
   entity/state alive ≥ `interp_delay` past the event (a despawn dwell, a
   sink dwell — `session_present(..., extra = 0.4)` with a reaper proc), or
   there is nothing left on screen to present when the render clock gets
   there.

Every consequence classifies into one of five bins, each with an existing
tool — when something looks mistimed, find its row:

| The consequence's cause | Present it | The tool |
|---|---|---|
| **My own simulation** (I claimed it, I struck it) | now | `session_present(mine = true)` — or just do it |
| **A remote moving cause** (a streamed avatar/ball reaching a thing) | at the render clock | `session_present(mine = false)` |
| **A per-peer local visual** (each screen flies its own projectile) | at *my* visual's moment | fx hooks ([kit/fx](fx.md) `On_Hit_Proc`) |
| **No spatial cause** (scoreboards, inventories, objectives) | wire-fresh | nothing — *never* delay these |
| **A global transition** (the won byte, the hole index) | after a dwell | edge-outlives-observers: hold state ≥ `interp_delay` |

The bins are per-CONSEQUENCE, not per-entity: one looted chest updates the
looter's bag UI wire-fresh (row 4) while its lid swings open on the render
clock (row 2). And the timing decision hangs on one fact only the game knows —
*did my simulation cause this?* — which is why `session_present` takes it as
a boolean instead of guessing (a wrong guess here is Unreal's RepNotify
double-fire, imported).

Shrinking the gap globally (`interp_delay` down, `tick_hz` up via
`session_configure`) trades smoothness under jitter for freshness — aligning
presentation is almost always the better spend.

## Gotchas

- **Deltas carry STATE, not events.** The walk memcmps entity-vs-shadow once per net tick;
  a replicated byte pulsed `1 → 0` *within* one tick equals its shadow when the diff runs
  and never ships. Put edge-triggered state on bytes that outlive a tick (cavecrawl's
  `level.won` stays 1 until the next run; peers react to the *edge* locally), or use an
  explicit reliable message.
- **Owner-streamed fields are never written by network input on the owner's peer.**
  `registry_apply_streams` skips entities owned by `me`; reject-truth, prediction reverts,
  and expiry all pass `skip_owner` for them; `diff_mask` keeps them out of deltas entirely.
  Otherwise every rejected cast would visibly yank a moving owner backwards onto the host's
  lagged echo. (Full snapshots at join/world-seed do write them — that is the seeding.)
- **`registry_get` returns a pointer into the registry** — mutations land in place, no
  store-back — valid only until the next insert/remove. Don't hold it across a spawn.
- **Channel ordering is load-bearing.** A delta that already contains a command's effect
  must arrive *after* that command's result, and a delta batch must never name an id the
  peer hasn't seen spawn (an unknown id abandons the batch — field sizes come from the
  descriptor the peer doesn't have). The session guarantees both by putting results, state
  batches, and spawn/despawn on the same reliable ordered channel.
- **POD only, 64 fields max.** The generated code `#assert`s the POD rule at compile time;
  group past-64 field counts into sub-structs (a fixed array is one field).
- **`Intent_Seq` wraparound is not handled**, by design: u32 gives ~4 billion commands per
  peer per session.

See also: [kit/session](session.md) (drives all of this), [kit/netgd](netgd.md)
(transport), [kit/comms](comms.md), [kit/combat](combat.md), [kit/save](save.md).

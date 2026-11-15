# Optional whole-world physics in Kit

`kit/sim` remains engine-free and native-free by default. Import
`godot:kit/physics` explicitly to install the optional Box3D participant. The
existing fixed ticker, input sampling/ledger and `run_tick` drive the physics
mode; whole-world correction is the complete-state path beside legacy
field-only `reconcile`. The legacy wire, owner-streamed physics and ordinary
field-only modes retain their existing behavior.

This page describes local complete-state integration. Use
[physics networking](box3d-networking.md) for accepted input, canonical
transfer, and recovery, and [the authored sample](../box3d/multiplayer.md)
for project setup. Kit and Replay retain separate adapters.

## Explicit authoring boundary

- Register fixed **pointer-free value proxies** with `lane_track` before attach.
  Provide `world_field_type(id, Proxy_Type)` for each. Mutable proxy fields must
  be `.Predicted`; other fields and descriptors remain immutable during ticks.
  Proxies are data, not arbitrary Godot node objects or pointer graphs.
- Put all other causal game state in typed `Side`: entity/body/shape/joint maps,
  game generations/alive flags, RNG, counters, timers and previous-input edges.
  `Side` and proxy types reject reference-containing values. World-bound native
  handles are rejected; store `Body_Key`, `Shape_Key` and `Joint_Key` and resolve
  them against the current staged world. Keys are allocation identities, not
  durable gameplay IDs; retain separate game generations/tombstones.
- `Lane.user` is wiring and immutable authored configuration, not a hidden
  mutable solver/game state. Tick/settle code may mutate only registered
  prediction fields, `physics.state(&instance)` and the borrowed staged native
  world through bounded authored commands. These borrows expire when the
  callback returns. Do not retain Side pointers or native handles across ticks.
- Scene/boot operations, external object graphs, direct sends, device reads,
  wall-clock decisions and irreversible effects are outside simulation. Native
  world destruction/stepping and allocator/global-configuration changes belong
  to the provider, not authored tick code. This is a disciplined native API,
  not a sandbox for arbitrary callbacks.
- Alpha proxy tracking/ownership/input-class changes, generated entity tick
  thunks, `step_auth`, scheduled verbs, predicted scene spawns and legacy inline
  field-only lag-comp queries are unsupported while attached. Kit entry points
  reject these before their own mutations, flag the transaction, and return an
  explicit error/invalid result. Do not invoke engine/boot spawn doors during a
  tick: they may allocate presentation objects before reaching the lane guard.
  Dynamic native/game entity spawn/despawn **inside Side** is supported; pooled
  or dynamic scene presentation can follow accepted state after commit.

## Installation and staged tick order

Set the normal `lane_set_sim` sample and world-step callbacks, register proxies,
then call:

```odin
instance: physics.Instance(My_Side)
fields := [?]sim.World_Field_Type{sim.world_field_type(1, My_Proxy)}
error := physics.attach(&instance, &lane, &world, initial_side, fields[:],
    physics.Config{asset_id = MY_PREDECLARED_CONTENT_ID}, settle)
```

The native `world` owner transfers and is cleared only on successful attach.
Attach requires a new lane at tick zero with the build profile's history and
tick rate. Initialize it with `sim.world_lane_config_default()`, then supply
fixed non-watched proxies and a nonzero immutable predeclared asset ID. It
verifies the actual initial dynamic count through the snapshot body cache and
retains that declaration with every image/execution. A completed checkpoint
can later reset/resume another compatible initialized lane. The caller owns
initial native construction and must destroy its world if attachment fails.

The local alpha tick order is:

1. Reserve/admit resources, copy displayed proxy values/input-ledger metadata
   for abort, and open disposable native execution from the complete head.
2. Restore canonical proxy fields and typed Side. Sample local input once for a
   normal tick; replay reads existing stamped input. Run the existing lane tick
   path and authored world pass. No presentation runs speculatively.
3. Check counts/resources before the provider's one solver step at the selected
   rate and substep count. Run `World_Config.settle` afterward to copy poses,
   consume that step's actual physics outputs and derive deterministic Side/events.
4. Capture complete native+Side image and registered field bytes into a bounded
   staging suffix. Check actual resources/counts. An optional commit gate may
   authorize, not mutate, the candidate; a successful mutating gate is rejected.
5. Infallibly select the candidate, publish Side/fields and the registered legacy
   field ledgers with the complete history, release retired owners/execution,
   then dispatch accepted presentation effects.

Call `physics.state` and `physics.world` only inside staged tick/settle callbacks.
`physics.read` returns a copied published Side value outside simulation. For
fallible authored native operations use `physics.require(&instance, status)` and
return immediately on false; it marks the whole candidate failed. Native/game
spawn and despawn, including post-step destruction in settle, are checkpointed
with the solver. Pending future sensor/contact end queues are owned by native
snapshot resource v2/normalized dump v3; completed outputs are not reused as
future events. Decode retired end-event handles structurally with
`shape_key_from_handle` and preserve logical generation/tombstone associations.

## Complete checkpoints, correction and recovery

`sim.lane_world_checkpoint(&lane, tick)` exports an independently owned
`World_Checkpoint`, including native image/Side, packed prediction fields and
local compatibility metadata. Tick zero is valid. Use
`world_checkpoint_clone`/`world_checkpoint_destroy`, never plain owning copies.
The checkpoint survives source Lane/provider object destruction and history
wrap. Its allocator and compiled callback code must remain alive until release;
destroying a caller-owned allocator or unloading its code is a separate lifetime
boundary. No source Lane pointer is retained in clone/release/equality functions.

`sim.lane_world_reconcile(&lane, &authority_checkpoint, gate)` is the complete
correction path. It never uses the legacy pose/field-equality shortcut. It stages
all required ticks and field-history changes before publication; rejected gates,
native import/capture failures, absent input or history, count/resource refusal
leave the published pair, histories and effects untouched. Operational errors
are returned by `World_Result`/`lane_world_status`; hold/resync conditions are
visible through `lane_world_needs_resync`. A frame may commit a prefix of whole
ticks before a later tick fails; the return count and error identify that prefix,
and remaining tick debt is not silently dropped.

Ordinary correction obeys a confirmed frontier:

- Older than confirmed: `Settled`, no rewrite.
- Equal to confirmed: idempotent only when complete normalized solver bytes,
  scalar Side (excluding padding) and exact prediction fields agree. Otherwise
  `Conflict` and explicit recovery is required. No resim occurs for a repeated
  identical acknowledgment.
- Newer than confirmed: matching complete predecessor/input history is required,
  and ordinary correction depth is at most eight. There is no live-world fallback
  for a missing record and no truncated repair.

`lane_world_reset` is explicitly different: it adopts a compatible complete
instant, clears incompatible history/input stamps only after acceptance, and
starts a new presentation epoch (`lane_world_epoch`). It can resume detached
checkpoints into a fresh lane or perform explicit recovery; it is not permission
to ordinary-rewrite settled history. Network authority and complete recovery use the [network integration](box3d-networking.md).

Read-only complete diagnostics and presentation queries need no live source:

```odin
side, error := physics.checkpoint_side(&cp, My_Side)
body, error := physics.checkpoint_body_state(&cp, body_key, My_Side)
required, error := physics.checkpoint_dump(&cp, nil, My_Side) // capacity query
value, error := physics.checkpoint_digests(&cp, My_Side)
equal, error := sim.world_checkpoint_equal(&cp, &other)
```

`checkpoint_dump` uses normalized full solver bytes, not poses. Insufficient
capacity returns `Capacity` without partial writes. Comparisons include Side and
prediction fields separately; the upstream motion digest is diagnostic only.

## Effects, bounds and unsupported wire paths

Use `lane_world_emit(lane, stable_key, fire, user, copied_payload)` inside a tick
or settle. At most 32 effects/tick, each at most 128 bytes, are staged by value.
The callback runs only after accepted state/history. Within an epoch, repeated
`(tick,key)` effects are suppressed during accepted correction; the authoritative
predecessor keeps its already-delivered keys. Capture historical facts in the
payload rather than querying the live solver later. Effect callbacks may present
but must not reenter simulation/registration/commands. Reset starts a new epoch;
consumers retaining effects across resets must explicitly reset or namespace
presentation. Already played cosmetic effects cannot be unplayed by arbitrary
state restoration. Author stable keys must include logical identity/generation
when native allocation numbers can recur.

World counts and byte budgets come from the shared [capacity profile](../box3d/capacities.md).
The native build and Odin modules use matching settings. History and the
prediction/repair ceiling are [timing profile settings](../box3d/timing.md),
defaulting to 128 frames and eight ticks. Input batch size must also fit the
per-message budget for the selected driver codecs.
Asset identity declares immutable content; it does not establish a frame-time
budget for arbitrary geometry and joint topology.

Counts and resources are checked around staged work. The default primitive
reservation scales with the selected snapshot/decode capacities. Shared native,
wrapper, typed Side, history, checkpoint, and declared external ownership must
fit the selected memory allowance. Include caller-owned allocations and queues
through configuration. These are requested-byte accounting rules rather than
an allocator hard cap or process RSS limit. Native allocator exhaustion remains
fatal.

`physics.allocation_stats` records sampled total/staged live peaks, allocation
requests between reserved primitive boundaries and reservation violations.
`physics.observe` reports the current accounted resources. These are requested
bytes, not RSS or one exact combined native/component high-water peak.

The 4 ms normal/correction values are **integration acceptance measurements**.
`lane_world_work_stats` records monotonic elapsed work outside causal state; a
scheduling spike never turns valid input into rejection/resync. It includes
staged core work/retired cleanup, excluding post-commit effects; integrated
render/game/runtime overhead and native/requested-vs-RSS accounting still need
measurement. Deliberately delayed-gate tests prove the diagnostic-only policy.

This mode does not call the legacy snapshot sender or accept its pose-only
packets. A legacy packet/pending batch has no complete attachment and produces
`Missing_Attachment`/resync before applying field-only truth. Scheduled verbs
and scene spawn APIs are rejected rather than silently replayed through their
legacy field/delta patches. Use [the network adapter](box3d-networking.md) for canonical transfer,
accepted input, and late join. Mixed-target physics and P2P are unsupported. Mac/Linux final solver digests previously differed; same-build,
same-target policy remains strict. Linux runs under Podman/Rosetta are executed
function tests, not certified native-hardware throughput.


## Project setup

Use the [Box3D multiplayer guide](../box3d/multiplayer.md) for authored sample
preparation, runtime ownership, and teardown. Read [Support](../box3d/support.md)
for the active integration profile.

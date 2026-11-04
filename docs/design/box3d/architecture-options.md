# Box3D integration boundaries for Kit and Replay

Status: initial architecture assessment, not the final implementation decision.
Recorded on 2026-10-30 against odin_godot `56e4ab3`.
Tracked by task `t_3b5fc9094bcb4795` (P0.0), board
`b_cdde1cdfea104035` (Box 3D Implementation).

Kit and Replay are both targets. Replay already implements full resimulation and
rollback; this project adds a complete Box3D solver world to that machinery.
The shared dependency should provide physics, snapshots and physics diagnostics.
Each sibling keeps its own input, simulation, network, event and session runtime.
The first networked slice retains the original server-authoritative policy.

## Proposed boundary

| Layer | Owns | Does not own |
| --- | --- | --- |
| Shared Box3D backend | Pinned Box3D build, narrow C ABI, explicit stepping, complete solver snapshots, snapshot lifetime, geometry and stable-ID translation | Session roles, accepted-input policy, framework history or audiovisual effects |
| Kit adapter | Solver/side-state history beside Kit's simulation lane, correction entry/exit, coherent shared-body input replay, Kit diagnostics | Replay frames or Replay session ownership |
| Replay adapter | Solver participation in Replay's existing frames, staged revisions, audits, checkpoints, hashes and event reconciliation | A second rollback or networking runtime |
| Godot authoring and presentation | Baked immutable definitions, meshes, interpolation, debug drawing, input/output | Canonical solver state or replay-time device/scene queries |

Godot `PhysicsServer3D` compatibility and custom authoring nodes remain later
work. A backend-only native spike must pass Gate A before either adapter changes
production runtime behavior. The upstream rollback session is reference material;
its peer authority policy is not a substitute for either sibling's runner.

## Current framework contracts

### Kit

[`kit/sim/lane.odin`](../../../kit/sim/lane.odin) funnels ordinary and replayed
ticks through `run_tick`: entity thunks, scheduled commands, the shared world
pass, then the host-only authority pass. The frame loops call `note_all` after
that tick; the host can then broadcast its snapshot. Presentation can modify
entity fields, so the client restores its predicted fields before advancing.

[`reconcile`](../../../kit/sim/reconcile.odin) compares predicted fields with
authority fields, restores tick T and replays T+1 through the head. An entity
without a retained historical field frame can currently fall back to its live
state. None of these operations reconstructs Box3D contacts or solver internals.

The Box3D mode needs additional, explicit invariants:

- The input/gameplay pass applies deterministic commands; Box3D is stepped at
  exactly one defined point before authority adjudication and snapshot capture.
  Applying a world step in both an entity thunk and the world pass is invalid.
- Every captured solver snapshot pairs with the same tick's game side-state,
  entity/body mapping, input edges, counters, RNG and simulation events.
- A correction restores the complete pair before replay. Missing physics history
  requires a defined resync/error; replaying an old tick from the live solver is
  not a valid fallback for this mode.
- A field-equal pose correction cannot skip rollback when solver/side-state
  differs. Shared contacts require a coherent world, not an arbitrary mixture of
  recipient-filtered predicted bodies and watched engine bodies.
- Presentation reads copied poses and never writes them into the canonical
  Box3D world. Existing engine-physics owner streams retain their own contract.

### Replay

[`replay/timeline.odin`](../../../replay/timeline.odin) stores `Frame(State)` by
value, with a committed ring and separate staging records. Initialization calls
[`value_supported`](../../../replay/value.odin), which rejects pointers, slices,
maps, strings and other references recursively. A copied frame must remain a
complete detached simulation value, not a key into a mutable external world.

`advance`, `revise_input(s)` and
[`correct`](../../../replay/correction.odin) stage candidate state and events
before publishing. Rejection or a failed step preserves the published history.
`audit` reruns inputs without publishing. `rewind`, `reset_checkpoint` and
initializing another timeline from a saved frame are additional state boundaries.

There is also a nested transaction:
[`replay/net/model.odin`](../../../replay/net/model.odin) copies `State` and the
event batch before an action, then restores those copies if the action rejects.
A solver mutation made directly by that action would survive this rollback.
`Model.user` is documented as immutable configuration/assets, not mutable
canonical state.

The optional `correct_reusing` path compares predecessor state and input bytes
and may skip simulation. A solver token whose numerical value matches is not
proof that the complete predecessor solver state matches. Ordinary correction
and audit must continue to execute their defined steps.

An isolated Odin probe confirmed three current behaviors: an aborted advance, a
rejected commit gate and a successful audit all preserve the published value
frame while still executing mutations through `ctx.user`. Pointer-bearing State
is rejected. These are consequences of the documented simulation contract, not
new Replay defects. The probe source, command and output are retained in P0.0's
stored report. A Box3D adapter therefore needs explicit snapshot participation;
placing a live Box3D pointer in `ctx.user` is insufficient.

## Replay storage alternatives

| Alternative | Benefit | Constraint / decision |
| --- | --- | --- |
| Bounded snapshot bytes inside `World`, with immutable geometry outside | Preserves existing typed frame-copy and staging semantics | Useful candidate for a small local feasibility experiment. Must bound capacity, define overflow, normalize process-dependent data and measure all frame/staging copies. Canonical schema has field/byte limits; opaque snapshot bytes are not a portable recovery representation. |
| Explicit external-snapshot participation in Replay history | Can retain variable-sized solver snapshots without copying a maximum-size byte array for every field operation | Recommended design direction to investigate, not an implemented API. Requires ownership, clone/export, release, staging/abort/audit and complete-frame read/checkpoint contracts. A bare slot ID in the existing value State silently weakens those contracts. |
| Live world in `ctx.user`, pose fields in `World`, or snapshots indexed only by tick | Small initial change | Reject: hidden mutable dependencies, aliasing across copied/branched frames, stale slot reuse and unrolled-back action/audit side effects. |
| Import the upstream rollback session as Replay's runner | Existing upstream network demo | Reject for this scope: duplicates Replay's existing resimulation/runtime and changes the original authority policy. Physics/snapshot code can be considered separately. |

For the external-snapshot direction, retain existing value-only behavior for
current users. A complete physics checkpoint needs an explicitly owned carrier
or an equally explicit storage extension, with detached clone/release semantics.
Do not make a borrowed token look like an ordinary complete `Frame(State)`.
The P0.5 decision must settle this public boundary before implementation.

## Required snapshot and transaction contract

The original `save/restore/step/hash/discard_after` sketch is a starting point,
not a sufficient transaction or lifetime API. Specify the following operations
and failure behavior before choosing C/Odin signatures:

| Operation | Required behavior |
| --- | --- |
| Capture | Own the entire solver image plus its version/configuration and geometry dependencies; bind it to matching deterministic side-state. Report allocation/capacity failure without publishing a partial frame. |
| Retain / clone / release | Keep historical and staged snapshots alive independently. Detect stale slot generations. A saved complete checkpoint remains usable after ring wrap or original runtime destruction according to its explicit ownership contract. |
| Restore into execution context | Validate compatibility before mutation. Restore identity/mappings, rebind callbacks and rebuild process-local user data. A load failure must not publish a partially restored solver. |
| Begin / stage / commit / abort | Preserve the previous published solver while revised suffixes execute. Publish solver, World, inputs and events together; on failure discard the candidate. Include commit-gate rejection. |
| Nested action savepoint | A rejected action restores its solver mutations as well as World/events, or actions only stage value-owned commands whose application occurs at a specified accepted boundary. The latter changes tick ordering and must be designed explicitly. |
| Audit / branch | Execute from the requested historical solver state and leave the published execution state unchanged. A branch needs independent mutable execution state, not just another reference to the source world. |
| Evict / rewind / reset / destroy | Retire the matching physics and side-state suffix, account for geometry/snapshot memory, and release each resource once. Never destroy a geometry registry while restored shapes still reference it. |
| Compare / hash | Compare all future-affecting logical solver state plus deterministic game side-state. Exclude process addresses and presentation. Record the tested build/target contract. |

The invariant at every published tick is:

```text
complete frame = solver snapshot + deterministic game state + stable mappings
               + tick input/occurrences + versioned immutable asset definitions
```

Tick numbers alone do not identify snapshots: two speculative branches can have
different state at the same tick. Snapshot identities need an owning store and
generation, or detached content with explicit lifetime.

One mutable world with backup/restore is a possible spike strategy only if its
failure recovery is established. A scratch world protects publication more
strongly, but cross-world restore and ID normalization must be proven first.
Neither behavior is provided by Replay's ordinary value transaction on its own.

## Upstream evidence affecting the design

The independent audits use these exact source lines of development:

| Baseline | Revision |
| --- | --- |
| Current standalone `rollback-in-a-box` | `9e1fe882a0ea4eb52e160d5754a752580b4db462` |
| Its Box3D dependency | `d421e45c828f6f853a145f726f0b9425d31146eb` |
| Current `multi-box-3d` | `987f4ca44d0065676f17cab35edad57fcbb63b13` |
| The game's recorded rollback dependency | `91e01dc75e8dfe3fbd890f21361e27b31fa2e994` |
| The game's Box3D dependency | `540ea387b0c02bf714fbfdcc8fb88c039c35fe6f` |

The game and the current standalone core are different reproducibility baselines;
do not upgrade the game's submodule silently or treat its passing tests as proof
of the newer core.

The current
[`rollback_shim.h`](https://github.com/pdaddyo/rollback-in-a-box/blob/9e1fe882a0ea4eb52e160d5754a752580b4db462/core/include/box3d_rollback/rollback_shim.h)
exposes a world-bound context and reusable slots. Its public C surface has no
detached snapshot clone/export/import operation. Registry-backed geometry must
outlive a restored world. The snapshot audit additionally identifies destructive
load behavior and cleared `userData`; verify the exact coverage and probe results
in [snapshot-audit.md](snapshot-audit.md).

The shim itself documents `b3r_world_hash` as transforms and awake velocities.
It is a motion diagnostic, not a complete solver digest. Snapshot bytes also
need a pointer/registry normalization audit before any byte-equality claim.
The Gate A report must distinguish motion-hash agreement from complete
future-affecting state agreement. The original issue #134 warning about repeated
collision geometry is historical context; current registry behavior and retained
geometry growth must be measured at the pinned source.

The focused C audit probe provides concrete counterexamples: changing gravity
does not change the motion hash; a body created after a saved tick can reuse the
same numerical handle after restoration; and future body-move event buffers can
survive a restore. The adapter must restore stable game identity and define when
derived physics outputs are cleared/regenerated before gameplay reads them.
The probe also demonstrates one simple internal cross-world import using a
shared geometry registry and retargeting an application body handle's `world0`
to the destination world; the snapshot image itself was not rewritten. That
is evidence for further investigation, not a supported detached-snapshot API or
proof for every shape/joint/task configuration. See the audit for its exact
source and coverage.

## Networking, recovery and presentation

Reuse each sibling's accepted-input, prediction and correction paths. The server
must retain and distribute enough accepted shared-body input history to correct
guessed remote input. Replay already rewrites predicted remote controls in its
client correction path; audit that behavior against the shared-physics scenario
before adding another protocol.

[`Replay checkpoints`](../../../replay/net/checkpoint.odin) capture a value frame
with session/control/action history and versioned metadata. Their current wire
limit is 1 MiB. Schema defaults limit wire bytes and logical fields as well.
A handle into local snapshot storage cannot resume another process from that
archive. Specify a complete, versioned physics recovery attachment and its asset,
codec, capacity and validation rules; integrate it with existing checkpoint
contracts rather than placing opaque local bytes in an unrelated policy field.
Reconstructing poses alone is not exact solver recovery.

Server authority does not make mismatched client contact caches harmless to
resimulation. Decide which canonical solver internals can be transferred, which
must be rebuilt with a declared correction boundary, and what exactness the
first slice promises. Cross-build recovery remains unproven until exercised.

Replay's integer-schema P2P policy is a separate compatibility gate. Adding a
floating-point backend does not justify weakening that policy or claiming
cross-target determinism from one build's motion hashes.

Use Replay's existing occurrence journal and Kit's existing effect gates.
Simulation commands and contact-derived gameplay events belong in rollback
state; audio, particles and mesh interpolation do not run as irreversible solver
callbacks during a replay. Shared authoring definitions should be immutable and
versioned before play; runtime body handles never become durable asset IDs.

## Evidence required before P0.5 and Gate A

1. P0.1: reproduce each pinned upstream baseline, recording actual builds,
   tests, configuration and motion-hash limitations.
2. P0.2: enumerate serialized and hashed state; probe geometry lifetime,
   user-data reconstruction, handle reuse, detached and cross-world restore,
   malformed-load behavior and complete-state comparison gaps.
3. P0.3/P0.4: separate reusable physics/shim code from networking and authoring
   reference material, verify licenses per source, select a dependency revision
   and name an upgrade owner/process.
4. P0.5: choose the Replay storage/checkpoint carrier, Kit correction hooks,
   accepted-input semantics and snapshot/side-state transaction contract.
   Record the two initial native targets and exact file scopes.
5. Gate A: benchmark 100/500 bodies and random 1–30-tick rewinds, including
   contacts, sleep/wake, spawn/despawn, sensors and a joint. Measure logical
   correctness, snapshot and geometry memory, save/restore/step/replay timing,
   and staged-history costs. Do not infer full-state equality from the upstream
   motion hash.

P0.0 establishes these boundaries and alternatives. It does not select a final
dependency, implement an adapter, or certify physics determinism. P0.5 records
the decision after the audit and Gate A determines whether implementation proceeds.

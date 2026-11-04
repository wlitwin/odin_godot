# Box3D prediction and presentation

P4.2 functional integration is DONE (stored report `r_03e61e9cd6ce4325`). Kit and
Replay now consume the presentation bridges and startup impairment controls in
their separate scenes; bounded actual checks are recorded below. Whole-call
4 ms and the long contested-physics soak remain unmet Gate B requirements.
P4.4 is next; P5 and full-goal completion remain blocked on that gate.

The optional `box3d/presentation` package is a native-free value contract, version
1. It owns no simulation, timeline, transport, clock or event journal. Kit and
Replay keep their separate prediction and correction paths.

## Owned visual values

A `Frame` copies at most 35 rows and records epoch, tick, correction revision and
source (`Predicted`, `Confirmed` or `Observed`). `Binding` pairs an explicit game
`{entity,lifetime}` with a certified world-independent `Body_Key`, asset and
semantic seat. Body allocation keys are not game lifetimes or effect IDs.

`frame_make(epoch,tick,revision,source,bindings,samples)` returns `(Frame,Error)`.
Bindings and body samples must come from the **same owned complete checkpoint**.
A missing key, duplicate entity/key, invalid pose or capacity overflow rejects the
whole result. Copied frames can outlive every source checkpoint, provider and
world. They are visual values, not complete rollback checkpoints or wire data.

`present(^View,^previous,^current,alpha,[]Change)` returns `(required,Error)`.
The fixed map emits Spawn, Update, Rebind and Remove into caller storage; 70
changes cover a complete 35-row epoch replacement. There is no per-body heap
allocation. Short output, stale frame and invalid input preserve both the map
and caller output. `view_clear` has the same output transaction contract.

A visual identity rebinds when its game lifetime, body key or asset changes. A new
presentation token generation prevents a recycled slot from identifying an old
proxy. An epoch change retires all old proxies. A correction revision cuts
interpolation even at the same tick. Interpolation requires consecutive ticks,
the same epoch/revision and the same lifetime/key/asset; quaternion blending uses
a common hemisphere and a normalized result. Alpha is supplied by the existing
adapter's presentation phase, clamped to [0,1], and never advances a solver.

The owner paints ordinary authored Node3D/mesh proxies using the copied changes.
It must retain its current Owner/Data_Lease/realm capabilities while reading a
checkpoint. A Frame retains no raw userdata, allocator, callback, CP or native
resource. If the owner allocates Frame/View/change storage dynamically in the
strict SDK, that storage belongs in its existing retained metered allocator and
host ledger. The helper creates no separate accounting domain.

## Kit bridge

`kit/physics/presentation.odin` provides:

- `presentation_frame(cp,epoch,$Side,project,revision,source)` returning
  `(Frame,presentation.Error,sim.World_Error)`.
- `presentation_status(epoch,head,confirmed,World_Network_Status,World_Work_Stats)`.
- `presentation_effect(epoch,tick,kind,key,game_identity)` returning a validated
  observation only from the actual existing postcommit callback.
- `presentation_impairment(request)` preparing latency/jitter/whole-loss-percent
  arguments for the owner's existing `netgd.wire_set_latency` call.

`World_Checkpoint` has no public epoch field. The caller captures and stores the
explicit epoch alongside that CP; it must never substitute a newer Lane epoch
for an old detached checkpoint. The helper checks available owner/Side/cache
context but does not certify that caller-supplied epoch. It reads
`checkpoint_side` and **one** `checkpoint_body_states` bulk cache, then invokes
`project(Side,[]Binding)->(count,Error)` on that same Side copy. There is no private
Image/Working cast or live-solver fallback.

Status takes copied public metadata obtained under the caller's existing Lane
owner. Accepted batches are not an accepted-tick frontier, so Kit leaves that
frontier explicitly unavailable. Expected checkpoint effects are not newly
delivered effects; only the actual postcommit sink supplies observations.
The current Kit latency adapter has no duplicate/reorder toggle and rounds loss
to whole percent (maximum 95); unsupported requests return `Unsupported` rather
than being silently approximated.

## Replay bridge

NEW `replay/godot/physics_presentation.odin` provides:

- `physics_presentation_frame(cp,project,revision,source)` returning
  `(Frame,presentation.Error,replay.Error)`.
- `physics_presentation_status(session)` under the existing owned-context guard.
- `physics_effect_observation(actual_view_change,project)` preserving the existing
  Begin/Update/Cancel/Confirm phase and confirmed flag.
- `physics_impairment_options(options,request)` copying settings into the existing
  Session receive-delay/fault adapter at normal open.

The frame helper performs **one** public `physics.body_states` read, including
its Owner/realm/identity check, before accessing typed Game from the same owned
CP. A missing historical tick after a canonical reset remains missing; rendering
cannot substitute the live solver or manufacture an older frame. The public CP
supplies Replay's epoch. Existing `scene.session_tick_phase`/`view.Tick_Phase`
supplies alpha; existing view/events/Cue routes remain the effect reconciliation
owner. The original change and its payload still go to that route. The helper
adds no dedup ledger and never promotes a speculative effect to confirmed.

Reorder uses the existing delay adapter's nonzero jitter; requesting reorder
with zero jitter is unsupported. These are logical adapter settings, not an ENet
packet-loss or deployment guarantee. Reliable-channel behavior remains the
existing adapter's responsibility. `replay/godot/physics.odin` is unchanged.

## Diagnostics

`status_text(Status,[]u8)` formats into fixed scratch and leaves a short output
untouched. Unknown frontiers, profile/resources, repair depth, timing and digests
have explicit availability. Complete solver and motion-only digests are separate
and labelled; matching motion does not establish complete equality. A full
network agreement still uses canonical Solver/Game/Side/Observations/Occurrences.

Callers may enrich a copied Status using their already-authorized profile and
shared-ledger observations. Native/wrapper/host/reserved values are tracked
requested bytes, not RSS or Godot/driver memory. CPU values are observations,
never simulation/admission rules. This overlay cannot clear hold/resync/error,
change accepted inputs, publish a correction or mutate the native world.

## Validation and integration status

Tests under `tests/box3d_presentation` exercise actual Kit reconciliation and
Replay revision, rejected candidates, actual journal updates/confirmation,
retained source-free checkpoints, epoch cuts and recycled game lifetimes. Pure
tests cover atomic short outputs, 35-row/70-change bounds and no allocator during
presentation. The `project` fixture paints two authored ordinary Godot mesh
proxies and one label without native linkage. It does not replace either
framework's effect route or prove a network/performance gate.

Both example consumers are integrated. Kit reuses one owned checkpoint and one
public bulk cache for telemetry and copied visual values; settled-effect
observations follow its existing actual-sink match and confirmed-checkpoint gate.
Replay uses its existing Tick_Phase and journal, with public successful-correction
markers cutting visual interpolation. The actual GUI evidence proves Kit Host
input with follower projection and Replay Host/Client ordinary input. Kit's later
capture-error HUD polish was compile-only; screenshots predate impairment label
additions. No extra GUI run is implied.

The component tests passed macOS/Linux Debug and Release, with four native-free
WASM object builds. The separate ordinary-node value fixture ran on both targets;
the actual scene GUI evidence has its own scope above. These runs retain their
recorded source versions and are not relabelled as reruns after later SDK support
changes. The final documentation status update changes this document only, not
the component code or test/binary evidence.

Bounded scene-control checks used actual macOS Godot/ENet small4 Host/Client
pairs with default0 and with 10 ms local receive latency, 1 ms jitter and loss0.
All twenty malformed/bounds/unsupported startup cases rejected before
construction with natural code1 exits and checked zero cleanup. Replay's
original default0 fixed-seat auditor failure remains preserved alongside its
versioned read-only Receipt-policy re-audit, with no physics rerun. The accepted
impaired pair and first two negative passes use source v2; the reject-only parser
fix and seven remaining negatives use v3. Valid pair/default evidence was not
rerun for that reject-only fix. These source qualifications and preserved
failures are part of the evidence, not hidden replacements.

The controls are startup-only, above-ENet local receive settings. The positive
integration check covers only 10 ms/1 ms/loss0, not a positive loss/duplication/
reorder matrix, narrow-link test, long soak or performance certification.
Reliable channel guarantees and adapter-specific limits remain explicit.

See the exact [P4.3 validation report](../../../tests/box3d_presentation/report.json)
for component configurations, GUI/source versions, actual controls, failures and
ownership results, and the immutable [P4.2 report](../../../tests/box3d_slices/report.json)
for its completed functional prerequisite. Whole-call 4 ms, the long two-process
contested-physics soak and P4.4 Gate B remain UNMET; no P5/full-goal pass is claimed.

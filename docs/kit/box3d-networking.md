# Kit complete physics networking

P3.1 implementation, same native build and target only. `kit/sim` remains
native-free. `kit/physics` is the optional Box3D provider and canonical codec;
it imports the pure `replay/schema` utility, never the Replay runtime.
The native recovery catalog currently admits declared Box/Sphere/Capsule assets.
Meshes, hulls and compounds from the earlier local-only profile reject; they are
not removed or converted during recovery.

## Wiring

Create the fixed tracked proxies, input classes, validators and normal
`lane_set_sim` step before attaching `kit/physics.Instance(Side)`. Side and proxy
values contain only explicit fixed-width values and world-independent native
keys. Dynamic native/game entities live in Side's maps and generation counters;
arbitrary scene/lane spawn and scheduled Kit verbs remain unsupported.

Initialize stable `Typed_Codec(T)` owners with `codec_init`. For a registered
proxy pass its exact prediction descriptor; for a control/action class omit it.
The resulting `.value` supplies canonical encode/decode and schema descriptors.
A proxy codec encodes the full typed schema with unregistered fields zeroed and
rejects nonzero wire values outside the prediction subset. Padding and process
`typeid`/`type_info` addresses never enter the wire identity.

Create a native `Recovery_Catalog` using `recovery_config_default()` and a
nonzero profile plus exact immutable primitive definitions. Keep the embedded
native build identity; arbitrary caller build labels reject. Then call:

```odin
network_attach(&network, &instance, &catalog,
    fields, inputs, drivers, effects, verified_game_rules_digest, epoch = 1)
```

`Network(Side)` clones the catalog and owns Side/observation schemas. Field and
input codec contexts are borrowed and must stay at stable addresses until
`network_destroy`. Destroy the network before its instance and typed codecs.
The mandatory rules digest binds verified application/model code and immutable
behavior parameters. A schema alone does not identify game behavior.

`World_Driver{player,class}` is an immutable ordered authorization roster.
Every physics-driving player/class appears, including authority controls.
`World_Wire_Input.prediction` is `Hold` for level controls or `Neutral` for an
action class. Input structs use explicit fixed-width fields. Each class has one
sample per tick and a bounded semantic validator; validators may normalize the
provided input bytes and must not perform external effects. Action IDs and game
entity generations belong in Side. An action's typed fields, acceptance and
sequence are retained in the same ledger as controls.

Each deferred effect has a nonzero stable kind, local post-commit handler and
canonical payload codec in `World_Effect_Def`. `lane_world_emit` rejects an
unregistered handler or incompatible payload before a tick can commit. Raw
callback addresses and user pointers never travel. Empty payloads use
`empty_codec()`. Authors must defer scene, audio, RPC and other irreversible work;
a transaction cannot roll back arbitrary external callbacks.

## Actual session path

The existing Lane route on `SES_APP` carries four optional message kinds:

- `SIM_WORLD_INPUT`: client proposals for its roster entries, with wire revision,
  input-schema digest, epoch, contiguous tick window and per-source sequence.
- `SIM_WORLD_ACCEPTED`: the authority's complete decisions for every driver,
  including explicit held/neutral decisions for absent submissions.
- `SIM_WORLD_CHUNK`: bounded complete welcome/correction/reset transfer chunks.
- `SIM_WORLD_REQUEST`: a seated client's explicit complete recovery request.

The session resolves the sender and rejects unseated sources before routing.
Kit checks authority peer, spectator status, roster ownership, schema, epoch,
sequence, tick bounds, duplicate/conflict and packet/queue limits. A proposal's
stable sequence is its tick; redundant or reordered copies cannot equivocate.
All rows in an input message decode and validate before a ledger changes.
Authority decisions for a simulated tick are immutable: a late proposal never
retroactively replaces a held decision. Its accepted decision is replicated.
The authority emits the trailing eight decision rows each tick; clients emit
only their immutable sampled controls, rather than echoing accepted hold values
back as fresh proposals.

Receive handlers copy/queue bounded bytes only. The game stack's `lane_frame`
decodes, opens disposable native execution and uses the existing `run_tick` and
whole-world transaction. `lane_input` returns exact accepted values first,
including accepted values for the local player. Only unknown inputs may sample
locally or follow the declared prediction rule. Its presence/freshness return
must not be used as a second gameplay truth about acceptance; provenance is
available through `lane_world_accepted_input` for diagnostics.

When accepted input differs from a retained guess, Kit restores the exact
predecessor and replays the complete suffix. An ordinary complete checkpoint
contains the accepted prefix even if it outruns the input stream: Kit replays
from confirmed state, verifies complete native/Side/fields/occurrences at the
authority tick while still staged, then finishes the speculative suffix. Ledger changes, solver, Side,
registered fields, history and deferred effects commit together. Failure leaves
the previously published pair and accepted ledger unchanged. Ordinary repair
and prediction are limited to eight ticks; missing/lapped state or older repair
returns explicit hold/resync. No rewind truncation or live-solver fallback exists.

## Complete state and recovery

`lane_world_send_checkpoint(lane,to,Welcome|Correction|Reset)` is authority-only.
`lane_world_export(lane,tick)` returns owned canonical bytes using the Lane
allocator; the export survives source Lane/provider/world/catalog destruction.
The receiving network must use the same immutable identity and local schema.

The complete envelope is:

1. The native-free diagnostics signature (480 bytes).
2. A little-endian u32 canonical native recovery length and independent recovery
   attachment. Only the native verifier/reconstructor imports this attachment.
3. Signed full logical `Solver` dump-v3 bytes, canonical registered `Game` fields
   plus the complete trailing eight accepted control/action/decision rows (including
   the hold baseline), canonical `Side` (including the initial-body
   declaration), completed `Observations`, and canonical `Occurrences`.

Network captures/clones use atomic native constructors returning the new owner
and `Snapshot_Info` together. The existing constructor validation remains; the
metadata is read before the owner is exposed. Only that coupled immutable
`image_used`/normalized length is cached for internal size queries. Canonical
admission still walks the idle native world with the full semantic, scalar,
asset and byte-size checks; source images remain limited to 2 MiB. Actual dump
fills, recovery writes and restores retain their full validation. Native reads
retain their independent verification and return metadata paired with the newly
validated local owner; no arbitrary caller-provided metadata grants wire trust.

Complete equality uses cached validated normalized lengths and two actual,
fully validated solver dump fills followed by exact byte comparison, together
with typed Side/config/observation checks. Differing cached lengths still check
both resources before returning false or error. Comparisons allocate fallibly,
charge their buffers while owned, and release partial allocations on failure.
The standalone P2 path retains its existing checks. No pose-only or hash-only
comparison is introduced.

The five part lengths/hashes and complete digest come from `bd.sign`. Game
schema identity binds grouped, length-prefixed field, occurrence, rules and Side
catalogs. Input identity binds roster/order, control/action schemas and prediction
semantics. Observation identity binds the ordered completed sensor-key cache.
Native build/target/assets/solver/recovery identity comes from the cloned catalog.
After native recovery, Kit independently compares the reconstructed complete
logical dump with the signed Solver bytes before publication. Dump bytes are
never an import image. These checksums are not authentication; session/transport
authorization remains necessary.

Completed sensors are copied into provider images. Read them through
`sensor_observations`, including before the next native step. Raw native completed
buffers clear when staged execution opens. Future pending sensor/contact ends
remain native resource-v2 state; post-step destruction therefore produces the
next tick's end once, separately from completed observations.

A welcome is accepted only while unready. Ordinary corrections cannot rewrite a
settled frontier: older truth rejects, and repeated equal-confirmed truth is
idempotent only when the entire image, fields, occurrences and accepted baseline
agree. A client requests hard recovery with `lane_world_request_reset`; it waits
for the authority's complete reset and never substitutes a local image.
`lane_world_begin_epoch` is authority-only and stages the current complete state
into a strictly newer protocol/effect epoch. Reset clears old speculative input
stamps and history, seeds the accepted baseline, and does not play old cosmetics.
Generic local checkpoint reset/reconcile is refused while networking is active.

## Bounds, diagnostics and deployment

The default complete envelope is at most 1 MiB including both native recovery
and full diagnostic bytes. Chunks are at most 32 KiB; there is one transfer,
at most 32 chunks, and at most 16 queued control messages / 64 KiB. Reassembly,
DTO/import, output, schemas, ledgers, images and first-trace payloads are charged
against the shared 64 MiB allowance with explicit operation reservation. Canonical
write/query preflights include the native contract's 8 MiB transient allowance
(including DTO); ordinary provider primitives retain their measured 2 MiB
reservation. Both are headroom within the same 64 MiB limit, not extra budgets.
Native read preflights DTO plus 4 MiB staging and receives all external charges. Caller
transport backlogs and other application allocations must be separately bounded
and charged as external ownership; a custom send callback is not an unlimited
free queue. A partial transfer is discarded by an explicit recovery request.
An incompatible/oversized profile rejects rather than broadening these limits.

H=128 and count/age/memory limits are deterministic admission rules. Clocks only
record acceptance measurements; a scheduling spike never rejects valid gameplay.
The earlier mesh-floor measurements do not describe this new primitive profile.
P3's actual counts, timing and staged ownership must be measured independently.
Native engine allocator exhaustion remains the documented fatal upstream
boundary, not a claimed recoverable allocation guarantee.

`lane_world_confirmed_signature` exposes only confirmed state on clients.
`lane_world_network_trace` owns the first settled complete-state conflict with
matching accepted predecessor provenance. Ordinary correctable prediction is
not a desync and does not occupy this slot. Accepted-history conflicts are
protocol conflicts. A trace retains full expected/actual bytes and canonical
accepted/predicted input context; later conflicts never replace it implicitly.

Exact physics is same-build/same-target. Debug/Release or macOS/Linux identity
may differ. No portable/mixed-target physics or P2P policy change is implied.
Actual Godot modules must share one loaded native DSO domain and retain code
that owns typed callbacks; standalone static network tests do not prove module
load/reload deployment.

## Functional proof and remaining performance gate

Phase 3 establishes accepted-input history, complete canonical transport/recovery,
transaction integrity and ownership for this declared profile. It does **not**
establish playable CPU acceptance. The measured whole-call 4 ms correction
requirement remains **UNMET** and is carried into Gate B (`P4.4`); P5 and complete
goal acceptance remain gated on its resolution. No core-only result is a whole
correction pass, and no measured clock result is a gameplay admission rule.

On the frozen FNV/read-info Release candidate, the isolated unchanged 32-initial/
35-peak-body, H128 run passes all eight functional tests. Its 160 normal whole
calls have p95 0.561500 ms and maximum 0.761042 ms. One actual changed-input
8-tick repair takes 3.433375 ms whole. The nineteen actual 8-tick complete
checkpoint prefix corrections have median 4.860584 ms and maximum 8.957208 ms;
all nineteen exceed 4 ms. The corresponding core maximum is 7.676291 ms. No
cause is inferred for the larger samples. Earlier isolated negative baselines
are retained in the stored report; they are not relabeled as accepted.

The measured primitive profile reaches 35 bodies, 35 shapes, 141 allocated
reference contacts and one hinge. Framework admission observations peak at
38,550,012 charged bytes; the conservative sum of separate engine, wrapper and
external component maxima is 41,683,242 bytes. Those are distinct observations,
not an invented simultaneous peak. The 2 MiB primitive reservation and 8 MiB
canonical-write headroom pass within the shared 64 MiB limit; all requested
engine/wrapper/provider/checkpoint ownership returns to zero. The isolated
process reports maximum RSS 106,151,936 bytes and peak memory footprint
49,726,976 bytes separately. Neither RSS nor the difference between these
non-simultaneous observations is presented as exact backend ownership overhead.

The final stored P3.1 report records exact current source, target/archive/manifest,
raw log and first-conflict artifact hashes. Linux results are x86-64 execution
through Podman/Rosetta, not native hardware throughput certification. Independent
impaired multi-process testing belongs to P3.5; actual Godot module deployment
and playable performance remain later required evidence.

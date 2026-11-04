# Complete Box3D state in Replay networking

Replay uses its existing server/client, `Model`, `Timeline`, event journal and recovery transfer. The optional `replay/physics` codec adds complete native checkpoints. Value-only models retain their existing protocol and require no native archive. This does not enable the separate P2P policy or portable physics.

The initial alpha is same-build and same-target. `Recovery_Config` defaults contain the actual native compiler/configuration/target identity; do not replace it with an application label. Debug, Release, macOS and Linux identities differ. Linux validation through Podman/Rosetta establishes functional execution, not native Linux throughput.

## Initialization and ownership

Create a native `Recovery_Catalog` from the declared primitive profile, then initialize `ph.Network_Codec(State, Control, Action, Event, Seats)` using `ph.network_codec_init`. Supply a trusted SHA256 `game_rules` digest covering the actual model code, hold/action/reset semantics and immutable application parameters. A schema digest alone is insufficient. The codec additionally binds canonical provider `Config` values and descriptors, including logical asset IDs, geometry, materials, event flags and the declared initial count. It composes these with State and complete `Occurrence(Net_Event(Event))` descriptors.

Set `Model.complete_state=true` and `Model.complete_codec=codec.value`. Use `net.physics_config_default()` and `net.server_init_complete` with an owned `r.Complete_Checkpoint`. An ordinary Frame cannot initialize a physics authority. The existing `client_init` receives a complete Welcome. Godot authorities use `session_open_complete`; clients use the existing `session_open`. `session_values` is a presentation projection; `session_checkpoint` returns an owned complete checkpoint.

Entering network mode explicitly binds and validates an unbound standalone P2 checkpoint. It does not mutate or consume that owner. Each resulting image and execution retains its own immutable native catalog lease. Every changed record is admitted before capture/publication, checking the live world, scalar/profile limits, assets and exact wire size. A failed candidate preserves published solver state, game values, events and history. Standalone P2 checkpoints remain available without this catalog contract.

The codec must stay at a stable address while server/client or recovery transfer owners use its immutable schema callbacks. `network_codec_destroy` returns `Wrong_Phase` while runtime leases exist and preserves the codec. Detached complete images own their native catalog independently and can clone, restore, query and release after the source server and codec die. Owned byte outputs use `complete_data_destroy`; their budget release callback does not dereference the destroyed concrete codec. Producer module code must remain loaded until its contextless image/byte callbacks are no longer needed.

## Accepted history and correction

The authority records the exact `Batch` used by the existing model callback and versioned decisions: every seat's controls, actions, sequence/rejection/verdict, joins/leaves/fresh bits, view inputs, authority observations and driver binding. History is H128. The client keeps a bounded knowledge ledger alongside the Timeline's existing predicted inputs; it is not another solver or rollback ring.

Input admission validates the transport source, seat, epoch, generation/serial, sequence and tick window before mutation. Exact repeats are idempotent. Conflicting repeats are rejected, including altered control view stamps and changed pending/retained action values. Bounded receipt metadata survives durable recovery. Known accepted values replace predictions. Only unknown remote values use `hold`; unknown remote actions are cleared. Action callbacks use the existing solver/Game/event savepoint path, including actual predicate rejection.

Ordinary prediction and correction are limited to eight ticks, including any later predicted suffix. Missing retained history or a larger correction requests complete resynchronization; it never silently truncates or opens the live solver as a historical substitute. View admission in physical mode uses issued-frame proofs and tick bounds, rather than RTT-derived gameplay bounds. Timing observations never change model input, state or admission identity.

`revise_inputs_checked` uses the existing staged suffix loop. The check runs exactly once at a requested retained tick before publication. It borrows an independent owning complete clone; the callback must not consume, destroy or modify that borrow. It can explicitly clone it to retain another owner. Core destroys its clone. Clone, callback, admission or later suffix failure aborts the whole operation. No operation-local callback context is retained.

## Wire and durable recovery

Complete Welcome/Snapshot envelopes are at most 1 MiB, transported in bounded 32 KiB parts on the existing reliable transport. They contain immutable identity, a 480-byte diagnostic signature, canonical full Game/events/completed observations, normalized solver dump3, and an independent native canonical recovery attachment. Normalized dump bytes are comparison data and are never an import format. Decode verifies all bounds, identity, checksums, canonical values and the decoded native solver against the signed logical solver before publication. Native future sensor/contact end queues are part of solver state; completed same-tick observations remain provider-owned.

An ordinary checkpoint also carries the last eight accepted rows and their occurrences. This lets the client validate/replay the accepted prefix before publishing correction when complete checkpoints arrive ahead of individual facts. A hard Welcome establishes a new baseline and does not replay old effects.

`checkpoint_capture`, `checkpoint_encode_owned`, `checkpoint_decode` and `server_restore` use the existing durable authority metadata plus an explicit physical attachment/receipt section, framed by the existing SC checkpoint envelope. `policy_data` remains application policy data. Restore requires a newer epoch and preserves the explicit pending-action/membership policy. Physical archives disable the legacy Frame-offset delta/shuffle layout; ordinary value archives retain it. The existing recovery Sender/Receiver transport performs the transfer.

Old-authority rejoin captures `Complete_Departing_Host` before closing the old Session, then seeds the existing client with `client_seed_departing_complete`. Destroy that handoff explicitly. The game-only departing seed rejects physical mode.

## Diagnostics and budgets

Confirmed signatures use `box3d/diagnostics` over complete Solver, Game, Side, Observations and Occurrences bytes. Replay Side/registered-field sections are empty because full typed State contains those values. Ordinary accepted-input prediction repair is expected and does not occupy the first-desync trace slot. A same-accepted-history mismatch retains a copied first artifact and stops prediction. `client_physics_trace` encodes it; `client_physics_trace_clear` explicitly releases it.

Trace `from_tick..to_tick` and `depth` describe the full planned correction, including later prediction. The input-context payload records the known accepted/check prefix and the corresponding published prediction. `last_checked_prefix` and `last_executed_steps` report checked-prefix and actual execution separately. A prefix mismatch may execute fewer steps than the planned correction; it is not evidence of a full eight-tick repair.

The measured profile declares 32 initial dynamic bodies and admits at most 35 total bodies/shapes, 147 contacts and one hinge, H128, 60 Hz/four substeps, one caller. The primitive box-floor fixture observed 35/35/141/1; it does not inherit the historical mesh fixture's measurements. Native catalog geometries remain explicitly bounded to declared Box/Sphere/Capsule assets.

The process resource cap remains 64 MiB over engine, wrapper and charged provider/runtime/payload ownership. Reserve before allocating and report requested live bytes, reservation bounds, actual temporary peaks, allocator overhead and RSS separately. Two full 32-body/H128 runtimes need separate process budgets; co-located correctness tests use a smaller declared scene. Transfer budget hooks account raw, compressed, reassembly, decode and workspace owners and keep catalog callback leases alive. Nil hooks preserve native-free transfer behavior. A failed replacement retains the old sender payload and frontiers. Native engine allocator fatal-OOM behavior is not a recovered-allocation guarantee.

The 4 ms ordinary-work and 4 ms full eligible-correction observations are acceptance targets, not gameplay clock gates. Include parse, import, signatures and repair in whole-call timings; core-only timings cannot establish acceptance. The isolated current 32-body/eight-tick run measured 5.170417 ms for the full correction, including 3.589333 ms core repair: the whole-call 4 ms target is **UNMET** and carried to Gate B/P4.4. Functional P3 closure is not performance acceptance. P5 and goal completion remain blocked on the explicit later acceptance gate.

## Validation entry points

`tests/replay_physics_net` contains native-free ledger/envelope tests. `tests/replay_physics_net/native` exercises the actual Box3D archive and existing runner: full canonical join/correction, accepted actions and rejections, H128 wrap under faults, durable transfer/resume, old-authority handoff, catalog/config rejection, detached ownership, a true solver-only trace, and the resource admission boundary. The 32-body source is destroyed before the client fills its own H128 history; retained packets remain charged. `tests/replay_transfer` covers optional budget leases, replacement failure and cleanup while retaining the ordinary transfer suite.

Run native tests with `-define:ODIN_TEST_THREADS=1`, `-collection:godot=REPO`, and `-define:BOX3D_LIBRARY=ACTUAL_COHERENT_ARCHIVE`. Do not reuse a historical archive after native inputs or build identity change. Independent-process fault/recovery acceptance is a separate board gate.

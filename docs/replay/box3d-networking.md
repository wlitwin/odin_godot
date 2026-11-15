# Complete Box3D state in Replay networking

Replay uses its existing server/client, `Model`, `Timeline`, event journal and recovery transfer. The optional `replay/physics` codec adds complete native checkpoints. Core value-only models retain their protocol and need no native archive; the current Godot Session build dependency is documented in [setup](godot.md). This does not enable the separate P2P policy or portable physics.

Exact physics requires the same build and target. `Recovery_Config` defaults contain the actual native compiler/configuration/target identity; do not replace it with an application label. Debug, Release, macOS and Linux identities differ. Linux validation through Podman/Rosetta establishes functional execution, not native Linux throughput.

## Initialization and ownership

Create a native `Recovery_Catalog` from the declared primitive profile, then initialize `ph.Network_Codec(State, Control, Action, Event, Seats)` using `ph.network_codec_init`. Supply a trusted SHA256 `game_rules` digest covering the actual model code, hold/action/reset semantics and immutable application parameters. A schema digest alone is insufficient. The codec additionally binds canonical provider `Config` values and descriptors, including logical asset IDs, geometry, materials, event flags and the declared initial count. It composes these with State and complete `Occurrence(Net_Event(Event))` descriptors.

Set `Model.complete_state=true` and `Model.complete_codec=codec.value`. Use `net.physics_config_default()` and `net.server_init_complete` with an owned `r.Complete_Checkpoint`. An ordinary Frame cannot initialize a physics authority. The existing `client_init` receives a complete Welcome. Godot authorities use `session_open_complete`; clients use the existing `session_open`. `session_values` is a presentation projection; `session_checkpoint` returns an owned complete checkpoint.

Entering network mode explicitly binds and validates an unbound standalone complete checkpoint. It does not mutate or consume that owner. Each resulting image and execution retains its own immutable native catalog lease. Every changed record is admitted before capture/publication, checking the live world, scalar/profile limits, assets and exact wire size. A failed candidate preserves published solver state, game values, events and history. Standalone complete checkpoints remain available without this catalog contract.

The codec must stay at a stable address while server/client or recovery transfer owners use its immutable schema callbacks. `network_codec_destroy` returns `Wrong_Phase` while runtime leases exist and preserves the codec. Detached complete images own their native catalog independently and can clone, restore, query and release after the source server and codec die. Owned byte outputs use `complete_data_destroy`; their budget release callback does not dereference the destroyed concrete codec. Producer module code must remain loaded until its contextless image/byte callbacks are no longer needed.

## Accepted history and correction

The authority records the exact `Batch` used by the existing model callback and versioned decisions: every seat's controls, actions, sequence/rejection/verdict, joins/leaves/fresh bits, view inputs, authority observations and driver binding. History is H128. The client keeps a bounded knowledge ledger alongside the Timeline's existing predicted inputs; it is not another solver or rollback ring.

Input admission validates the transport source, seat, epoch, generation/serial, sequence and tick window before mutation. Exact repeats are idempotent. Conflicting repeats are rejected, including altered control view stamps and changed pending/retained action values. Bounded receipt metadata survives durable recovery. Known accepted values replace predictions. Only unknown remote values use `hold`; unknown remote actions are cleared. Action callbacks use the existing solver/Game/event savepoint path, including actual predicate rejection.

Ordinary prediction and correction are limited to the configured window, `Config.max_prediction` (default `net.PHYSICS_DEFAULT_WINDOW`, 30 ticks or 500 ms; ceiling `net.PHYSICS_WINDOW`, 32), including any later predicted suffix. The window must cover the round trip plus the input arrival reserve: the original eight-tick window was already full on a single machine and could not keep a client's inputs on time past roughly 80 ms of round trip ([network harness](https://github.com/wlitwin/odin_godot/blob/main/tests/replay_dockyard/netsim/README.md)). Missing retained history or a larger correction requests complete resynchronization; it never silently truncates or opens the live solver as a historical substitute. View admission in physical mode uses issued-frame proofs and tick bounds, rather than RTT-derived gameplay bounds. Timing observations never change model input, state or admission identity.

`revise_inputs_checked` uses the existing staged suffix loop, starting at the first tick whose rewritten input is not step-equivalent to the recorded one (`Input_Rewrite.equivalent`; the runner compares every `Batch` field the step, actions and verdicts read). A complete step is a pure function of its predecessor image and input, so an equivalent prefix keeps its records and only has its accepted inputs recorded; when every input matches, nothing executes and the published execution stays. `Result.steps` and `last_executed_steps` count executed ticks; `Stats.reused_correction_ticks` counts the rest, and a confirmation that executes nothing is not a correction. The check runs exactly once at a requested retained tick before publication, on the committed record when that tick lies in the unchanged prefix. It borrows an independent owning complete clone; the callback must not consume, destroy or modify that borrow. It can explicitly clone it to retain another owner. Core destroys its clone. Clone, callback, admission or later suffix failure aborts the whole operation. No operation-local callback context is retained.

## Wire and durable recovery

Wire revision 2 (`PHYSICS_WIRE_VERSION`, carried in every fact header) keeps complete images out of a predicting driver's steady state. Each accepted fact carries the decisions and the signature's 32-byte complete digest, which commits to identity, epoch, tick and every part; the client confirms from facts alone and compares with `physics_signature_match`. The authority signs each tick once for all peers and sends every fact on the reliable channel plus an unreliable copy (when it fits), so one lost packet no longer holds every later fact behind a retransmission. At the `snapshot_every` cadence a driver receives a small reliable `Physics_Status` (authority head, newest received input, settled actions) for the lead controller. Complete images remain for Welcome, an explicit same-history mismatch request, and spectators, who do not predict. A periodic image was tens of KB on the ordered channel: about 3.4 Mbit/s that delayed every fact queued behind it.

Complete Welcome/Snapshot envelopes use the selected capacity profile (32 MiB by default), transported in bounded 32 KiB parts on the existing reliable transport. Reassembly supports the full selected chunk count. They contain immutable identity, a 480-byte diagnostic signature, canonical full Game/events/completed observations, normalized solver dump3, and an independent native canonical recovery attachment. Normalized dump bytes are comparison data and are never an import format. Decode verifies all bounds, identity, checksums, canonical values and the decoded native solver against the signed logical solver before publication. Native future sensor/contact end queues are part of solver state; completed same-tick observations remain provider-owned.

An ordinary checkpoint also carries the last eight accepted rows and their occurrences. This lets the client validate/replay the accepted prefix before publishing correction when complete checkpoints arrive ahead of individual facts. A hard Welcome establishes a new baseline and does not replay old effects.

`checkpoint_capture`, `checkpoint_encode_owned`, `checkpoint_decode` and `server_restore` use the existing durable authority metadata plus an explicit physical attachment/receipt section, framed by the existing SC checkpoint envelope. `policy_data` remains application policy data. Restore requires a newer epoch and preserves the explicit pending-action/membership policy. Physical archives disable the legacy Frame-offset delta/shuffle layout; ordinary value archives retain it. The existing recovery Sender/Receiver transport performs the transfer.

Old-authority rejoin captures `Complete_Departing_Host` before closing the old Session, then seeds the existing client with `client_seed_departing_complete`. Destroy that handoff explicitly. The game-only departing seed rejects physical mode.

## Diagnostics and budgets

Confirmed signatures use `box3d/diagnostics` over complete Solver, Game, Side, Observations and Occurrences bytes. Replay Side/registered-field sections are empty because full typed State contains those values. Ordinary accepted-input prediction repair is expected and does not occupy the first-desync trace slot. A same-accepted-history mismatch retains a copied first artifact and stops prediction. `client_physics_trace` encodes it; `client_physics_trace_clear` explicitly releases it.

Trace `from_tick..to_tick` and `depth` describe the full planned correction, including later prediction. The input-context payload records the known accepted/check prefix and the corresponding published prediction. `last_checked_prefix` and `last_executed_steps` report checked-prefix and actual execution separately. A prefix mismatch, or an unchanged accepted prefix, may execute fewer steps than the planned correction; it is not evidence of a full-window repair.

World counts, captured source images, canonical recovery bytes, complete
transfers, sensor observations, and accounted memory follow the shared
[capacity profile](../box3d/capacities.md). Retained image storage is charged to
the memory allowance; it is separate from canonical wire size. Include native,
wrapper, provider, history, and caller-owned queues in the resource budget.

Transfer budget hooks retain their catalog and callback owners. A failed
replacement preserves the prior sender payload and frontiers. Requested
ownership, temporary reservations, allocator overhead, and RSS are different
measurements. Native allocator exhaustion remains fatal.


## Build and support

Follow [Multiplayer integration](../box3d/multiplayer.md) for a complete authored
project and [Support](../box3d/support.md) for runtime and target limits. Profile
the full correction path with your model and hardware.

# Replay networking implementation notes

M3 is in progress. The initial [server/client runner](../../replay/net/README.md)
now combines schema/codecs, transports, admission, reliable actions, authoritative
facts/snapshots, prediction, correction, and reconnect. Engine-free fault scenarios
and the separate four-process Hello network scene pass. Acknowledged baselines,
delta compression, compact facts, and outbound budgets are now implemented.
Further admission/recovery review remains necessary before M3 is complete.

## Authoritative correction API

`correct(&timeline, truth, events)` accepts a complete authoritative frame plus
its complete occurrence batch. Callers first verify sender authority, epoch,
schema/content, timing, and game invariants. The function validates event identity,
stages the checkpoint and every subsequent replayed input, and commits the whole
operation only if every step succeeds. Its confirmation frontier advances to the
truth tick. Duplicate settled checkpoints are idempotent; conflicting settled
state is rejected.

The generating authority input at the checkpoint is unknown, so that record is
a new replay boundary. `read_input` reports it as unavailable and `audit` cannot
cross it using invented input. Audit from the following tick remains meaningful.

`reset_checkpoint(&timeline, frame, epoch)` is explicit full resync/recovery. It
reuses allocations and discards speculative input/event history. A same-epoch
reset cannot move behind confirmed state; a newer authorized epoch may restore
an older checkpoint. The function does not elect/authenticate the authority.

## Runner design decisions

1. Build an engine-free typed server/client runner around `Transport`, canonical
   schemas, and `Timeline`. Keep the transport callback API usable with both the
   deterministic memory adapter and ENet.
2. Establish a version/content/schema handshake, stable seats, transport-peer
   binding, reconnect credentials, role/admission rules, and bounded work/traffic.
   A wire field naming a player must never substitute for the authenticated
   transport-to-seat mapping.
3. Use tick-stamped redundant control windows and an explicit hold policy.
   Continuous controls may hold; discrete actions need identity/deduplication and
   must not become repeated actions because an input packet was lost.
4. Deliver joins/leaves as tick-stamped system inputs to simulation. This keeps
   entity lifetime in the frame. Send the initial client checkpoint after its
   admission/spawn has been applied, avoiding a welcome that names a nonexistent
   avatar. Do not repeatedly overwrite replayed historical membership from a
   current roster value.
5. Keep authoritative event batches on a reliable ordered path and snapshots on
   an unreliable superseding path. State snapshots need the matching confirmed
   occurrence history before presentation can settle it. Empty tick ranges can
   be represented compactly, but must not be guessed after message loss.
6. On correction, feed authoritative occurrence batches through the settled
   prefix, then reconcile the newly replayed speculative suffix. Simulation and
   presentation confirmation counters remain separate. Preserve authoritative
   snapshot history for remote views rather than treating predicted old frames
   as observed truth.
7. Implement a full resync request for history exhaustion, baseline loss, or
   prolonged blackout. Preserve/retire unacknowledged actions explicitly; resetting
   a timeline alone does not provide reconnect or exactly-once execution.
8. Integrate the runner into the separate Hello project and test actual
   server/client/observer gameplay under recorded network faults.

The first prediction runner may simulate one complete public group with held
remote controls. Prediction of self/contested subgroups and historical boundary
inputs remain M6 work. If private state is omitted from a public projection, a
client cannot automatically predict code that depends on it; require a suitable
public simulation model/projection or reject that configuration explicitly.

## Implemented evidence and remaining work

`tests/replay_net/run.sh` covers initial admission, controls, contested/rejected
actions, retries/deduplication, malformed input and sender binding, loss/jitter,
blackout resync, reconnect, and WASM type-checking. The gameplay gate is now
`examples/replay_hello/network_run.sh`: a real dedicated authority, two predicting
players, and an observer at 120 ms receive delay on every process. It checks local
motion response, one accepted firing action per player, and matching shot/effect
counts. The ENet echo test remains a separate lower-level transport check.

Acknowledged baselines/deltas, compact facts, outbound scheduling, ACK-loss recovery,
and a real jitter/loss/duplication run now pass. Broader hostile/recovery review and
a wider clock/latency matrix remain open M3 work. Richer admission/moderation and deliberate seat replacement
also remain: the initial runner reserves stable seats for the session lifetime.
Bearer reconnect credentials do not supply account identity or transport encryption.

Host migration requires all M5 checkpoint/session/authority-fencing work. No
owner-streamed co-op, deterministic P2P, full-game parity, browser runtime, or
arbitrary-scale claim follows from the initial runner tests.

Public content can use [asset references and exchange](../../replay/assets/README.md)
through the Session application lane. The reusable [blob transfer](../../replay/transfer/README.md)
keeps content outside snapshots and shares transport work/bandwidth budgets.

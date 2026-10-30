# Local diagnostic overlay

Use the opt-in `Debug_Overlay` to inspect runtime counters and audit whether
recent recorded inputs reproduce the retained state and events.
It is a presentation/debugging component, separate from simulation state and wire
schemas. It sends no requests to peers, writes no files, and does not issue game
actions or apply corrected state.

```odin
// In the owning node's ready hook, only when debugging is requested:
debuggd.debug_overlay_init(&debug, owner, true)

// After the application's normal simulation/session pump:
debuggd.debug_timeline_frame(&debug, &timeline) // local value timeline
// or:
debuggd.debug_session_frame(&debug, &session)   // Session facade

// During teardown:
debuggd.debug_overlay_destroy(&debug)
```

F8 hides/shows the panel. F9 audits recent retained history while the panel is
visible. Status refresh is limited to four times per second; disabled/hidden
panels do not format status snapshots. An audit is an explicit synchronous
operation, capped at 120 ticks by the convenience drivers. Large simulations can
still pause visibly during that requested work; use `debug_audit` with a smaller
window when appropriate. It is not a per-frame determinism check.

The local timeline view shows epoch, head, confirmation, retained slots and its
latest replayable window. Session views add role/phase, rejection, local seat or
peer count, traffic totals, correction/replay counts, deferred snapshots and resync
status. Traffic values are lifetime application counters, not bandwidth rates or
measured RTT. No token, bearer credential or hidden peer-state exchange is involved.

## Audit boundaries and ownership

`audit_window` locates the latest bounded replayable suffix and stops at an initial
or authority-corrected checkpoint. The checkpoint's generating input is unknown
locally, so auditing across it would be a false reproducibility test. `audit_recent`
uses that window with the owned capture API. A checkpoint without a replayed suffix
reports `Initial_Frame`; missing input/history is not approximated.

The overlay formats the first captured state/event failure through the canonical
field schema. It reports the failing tick, preceding frame tick, expected/replayed
values and event counts. Display limits are explicit. Unsupported schema types
remain a diagnostic message rather than being coerced into an approximate format.
The captured values are independent copies and are released after formatting; the
panel owns only the resulting text and its UI nodes.

These audits test local reproduction from recorded inputs. They do not prove
cross-machine determinism, undo illegal external side effects or compare a hidden
remote world. Authority data in a local audit should remain in trusted developer
workflows. The panel is not a production player-facing debugging or administration
permission system.

## Integrated examples and acceptance

Replay Hello's local scene and Replay Cavecrawl expose `debug_enabled` in the
inspector. They also accept `REPLAY_DEBUG=1` (or `?debug=1` in a browser launch).
The regular scene defaults leave the overlay unallocated. Original examples and
Kit remain separately available.

```sh
nix develop --command bash tests/replay_debug/run.sh
nix develop --command bash tests/replay_debug/ports_run.sh
```

The first gate injects a deliberately illegal external-state change into a small
fixture, presses F9 and checks the exact `inventory[1]: 7 -> 8` report at tick 2.
Recorded inventory remains 7. It verifies hidden-panel behavior, a subsequent
successful audit, clean teardown and WASM checking. The port gate exercises the
same controls on Hello and real host/client Cavecrawl processes; the client audit
starts after its correction boundary. A rendered panel capture is retained in
[the live diagnostic evidence](../../../docs/replay/results/live-diagnostics-2026-09-07/README.md).

The separate [local history dock](scrubber.md) supports retained-frame inspection,
field editing, original-future resume and explicit branching in Replay Hello.
[Portable recordings](../../diagnostic/recording.md) retain replayable history
windows for later verification. The audit overlay remains read-only; graph views
and richer Room/P2P-specific panels remain additional roadmap work.

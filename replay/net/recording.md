# Replaying recorded network simulation

Use `net.recording_model(&model)` to verify recorded network simulation without
opening a session or replaying transport traffic. The adapter supplies the
engine-free recording verifier with a network
`Model(State, Control, Action, Event, Seats)`. The recorded input type is
`Batch(Control, Action, Seats)` and the event type is `Net_Event(Event)`, matching
the simulation run by server and client timelines.

```odin
archive: d.Recording(World, net.Batch(Control, Action, SEATS), net.Net_Event(Event))
defer d.recording_destroy(&archive)
identity := d.Recording_Context{content = CONTENT, build = MODEL_REVISION, tick_hz = 60}
result := d.recording_capture(&archive, &server.timeline, identity)
// Encode/persist, or decode a file into a fresh recording owner.
model := game.model()
capture: r.Audit_Capture(World, net.Batch(Control, Action, SEATS), net.Net_Event(Event))
defer r.audit_capture_destroy(&capture)
checked := d.recording_verify(&archive, identity, net.recording_model(&model), &capture)
```

Keep `model` and its immutable `user` data alive at a stable address throughout
verification. The adapter preflights all recorded controls, seat masks, prediction
group/seat identifiers, view shapes, action sequences and executable action
payloads before any simulation step. The optional
`Recording_Model.input_check(input, tick, user)` supplies context-aware preflight
without changing existing models that use `input_valid` or neither callback.

Batches already record joins, leaves, fresh-seat resets, controls, aim brackets,
actions, sequence IDs and admission rejections. Verification runs the ordinary
network simulation reducer, including action rollback and result occurrences.
It **does not** rerun admission callbacks, action scheduling, transport, snapshots,
lease checks or presentation. Previously accepted actions remain eligible for
replay even if today's live admission policy would reject them. Recorded rejected
requests remain rejected; their semantically invalid payloads never reach the
game's action predicate. Rejected view hints likewise remain diagnostic data.

Client recordings preserve the replayable prediction suffix after the latest
correction. They may therefore be much shorter than the authority recording.
A captured client value may contain projection defaults in private fields
because the authority never sent their contents. Verify it with the matching
model and prediction policy. The recording cannot recover data absent from
that client's received view.

An archive can be verified after destroying every transport/session object. It
contains simulation evidence, not a restorable network session: credentials,
transport queues, replay authorization, durable admission and coordinator leases
are not reconstructed. Checksums and successful replay do not prove that a file
originated from a trusted authority. Model/build identity remains the application's
explicit compatibility contract.

## Scrapyard integration

With `RSY_DEV=1`, the separate Replay Scrapyard game adds **Export recording**
after Save in its Escape menu. It exports the authority timeline on solo/host/
server, or the local prediction suffix on a client. Ordinary launches add no
recording control. Native output defaults to `user://scrapyard.rplrec` and can be
overridden by `RSY_RECORDING_PATH`; Chrome requests a file download.

The operation is synchronous and does not pause the network game. Complete world
and batch copies make it useful for deliberate debugging, not every-frame capture.
The codec limits remain 16 MiB per file, 1 MiB per chunk and 64 MiB of owned
record values. Export logs include the range, bytes, storage result and elapsed
microseconds. Those timings do not by themselves show that the network game
continued without resynchronization; that behavior needs separate evidence.

```sh
nix develop --command odin run examples/replay_scrapyard/tools/verify_recording \
  -collection:godot="$PWD" -- /absolute/path/scrapyard.rplrec
```

The tool uses the same Scrapyard model, carried catalog/rules and explicit manual
recording revision. It reports complete replay agreement, action verdict counts,
historical-view samples and gameplay counters, or the first mismatch field. The
original Kit game and its save/recovery formats remain independent.

## Large-model WASM verification

Several simultaneous aggregate copies in `recording_verify` formerly generated
77,660 locals for Scrapyard, exceeding V8's limit. Verification now borrows retained
entries and copies complete fixed-value failure frames into disjoint owned storage
with `mem.copy_non_overlapping`. Logical comparison, capture ownership and canonical
file bytes are unchanged; padding is never serialized as gameplay state.

The standalone Scrapyard WASM verifier links Emscripten's math library, including
single-precision sine/cosine, just as the web toolchain supplies those routines.
Its final module has no imported functions; the simulation does not run in a JS
surrogate. `tests/replay_network_recording/targets.sh` builds this target and verifies
actual native/browser exports, corruption, recomputed-checksum state mismatches
and invalid-input preflight. This is evidence for the recorded workloads, not
universal floating-point determinism across operating systems or all scenarios.

## Recording schema changes

A recording binds its state, input and event schemas plus application content and
build identity. Normal decoding requires those current contracts; it does not
silently fill missing authority observations or other fields.

When migrating owned recordings, preserve their base frame, retained expected
frames, input decisions, event IDs/payloads and slice boundaries. Validate the
source, map only explicitly reviewed semantics, then replay the candidate with
the target model. Do not regenerate expected frames or events to hide divergence.
An unknown authority observation remains unknown; a file does not establish
permissions that its original producer never recorded.

Scrapyard's retained native/browser recordings were migrated this way and are
verified by `tests/replay_network_recording/fixtures.sh` in native code and WASM.
Original bytes and [receipts](../../docs/replay/results/usability-legacy-2026-11-16/scrapyard/receipt.json)
remain historical evidence. The current verifier takes only the recording path;
game-specific old models and format-upgrade helpers are no longer shipped.

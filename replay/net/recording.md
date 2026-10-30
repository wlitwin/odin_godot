# Replaying recorded network simulation

Use `net.recording_model(&model)` to verify recorded network simulation without
opening a session or replaying its transport. It adapts a network `Model(State, Control, Action,
Event, Seats)` to the engine-free recording verifier. Use `Batch(Control, Action,
Seats)` as the recorded input and `Net_Event(Event)` as the event type. This is
the same simulation contract used by server and client timelines.

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
The captured complete local value can contain public-projection defaults in
private fields. Use the matching model/prediction policy; a recording does not
recover information that the client never received.

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
The unchanged codec limits are 16 MiB per file, 1 MiB per chunk and 64 MiB of owned
record values. Export logs include the range, bytes, storage result and elapsed
microseconds. Continuation/no-resync evidence is separate from these timings.

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

## Older network recordings

Recorded authority observations add a field to `Batch`. This changes diagnostic
input fingerprints even for models with the authority policy disabled. Gameplay
packet/checkpoint formats remain separate. Normal decode rejects older input
schemas; it does not silently assume missing observations.

For an unchanged model with its authority policy disabled,
`net.recording_upgrade_without_authority` explicitly converts the prior Batch
schema, retaining recording context, complete frames, controls, action decisions
and events. Enabled authority policies are refused because the old data cannot
supply the required observations. Structural conversion does not certify replay
agreement; run the verifier on the resulting file.

Scrapyard provides a bounded converter that requires a new destination:

```sh
nix develop --command odin run examples/replay_scrapyard/tools/upgrade_recording \
  -collection:godot="$PWD" -- old.rplrec converted.rplrec
nix develop --command odin run examples/replay_scrapyard/tools/verify_recording \
  -collection:godot="$PWD" -- converted.rplrec
```

It preserves the source and refuses existing files/symlinks. Publication uses a
same-directory temporary file and hard link. Three earlier native/browser
recordings have been converted and verified against their complete recorded
state/event sequences.

### Scrapyard content 48 recordings

The Scrapyard format-only `upgrade_recording` tool remains specific to content 48.
It adds the formerly absent authority-observation field with an unknown value;
it does not relabel historical gameplay as content 49. Verify its output with:

```sh
/path/to/verify_recording /path/to/converted.rplrec --content48
```

The explicit legacy model retains the old world schema and disabled authority
policy. Its ordinary gameplay callbacks are unchanged between contents 48 and 49;
future gameplay revisions must preserve that historical implementation separately.
Current content-49 recordings use the verifier without this flag. Checkpoint
conversion is a different operation: it seeds the prior authority epoch so future
recovery can apply the new timer policy.

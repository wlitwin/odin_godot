# Portable local gameplay recordings

A `Recording(State, Input, Event)` owns a replayable history window independently
of its source timeline. It stores a complete starting frame, every subsequent
recorded input and expected frame, and each ordered event batch. Capturing does
not run the simulation or mutate its history. Replaying uses an isolated timeline
and returns the first state/event mismatch with an owned `Audit_Capture`.

```odin
import d "godot:replay/diagnostic"

identity := d.Recording_Context{content = GAME_CONTENT, build = MODEL_REVISION, tick_hz = 60}
recording: d.Recording(World, Input, Event)
defer d.recording_destroy(&recording)
result := d.recording_capture(&recording, &timeline, identity)
if result.error == .None {
    bytes, error := d.recording_encode(&recording)
    defer delete(bytes)
    // Persist bytes only when error == .None.
}
```

Capture defaults to the newest 120 replayable ticks. Choose 1..4095 explicitly.
It stops at a correction/checkpoint boundary or retained-history edge and keeps
the preceding full frame. A checkpoint without any generating input produces a
valid zero-step recording. Its earlier committed events are outside the recorded
suffix; it does not invent inputs for authority corrections. Tick zero, nonzero
checkpoints, wrapped retention and the maximum u64 tick are supported.

Destroy owners before reuse; copying the owner aliases its owned arrays. Captured
state/input/event values themselves follow Replay's no-reference value contract.
Capture is a synchronous operation requiring exclusive access to the timeline.
Do not mutate its source concurrently. Busy/reentrant timelines are rejected.

## Decode and verify

```odin
loaded: d.Recording(World, Input, Event)
defer d.recording_destroy(&loaded)
error := d.recording_decode(&loaded, bytes, identity)
if error == .None {
    model := d.Recording_Model(World, Input, Event){
        step = game_step, state_valid = state_valid, input_valid = input_valid,
        user = immutable_assets,
    }
    capture: r.Audit_Capture(World, Input, Event)
    defer r.audit_capture_destroy(&capture)
    result := d.recording_verify(&loaded, identity, model, &capture)
    text := d.audit_text(result.replay, &capture)
    defer delete(text)
}
```

Decode validates exact length, schema fingerprints, context, canonical values,
chronological stamps, contiguous event ranges, event IDs and duplicate IDs before
publishing an owner. Any failure leaves the destination empty. It executes no
model code. Verify preflights all supplied state/input validators before the first
step, then compares every complete state and ordered event batch using the core's
logical equality. Validators may be nil where schema checks suffice. A rejected
model value or aborted step reports its tick without claiming an audit mismatch.
A successful zero-step verification checks the starting value but executes no step.

The first divergent tick retains its preceding frame, input, expected/actual frame
and both event batches. `audit_text` reports field differences, including private
fields. A successful verification neither populates a failure capture nor changes
the recording. Verification does not publish presentation effects, open networking,
restore a game session or advance its confirmation frontier.

## Contract and limits

The caller supplies nonzero content and build/model revision identifiers, plus
1..10000 ticks per second. The frequency is checked metadata; simulation code
still implements the actual timestep. Bump the revision for relevant changes in
code, configuration and immutable assets. The format cannot discover undeclared
external state or reconstruct assets from a pointer. Hello uses explicit manual
revision 1 and its existing network content identifier; source/binary hashes in
acceptance receipts identify the tested build more precisely.

Version 1 uses a checksummed header envelope, a base-frame envelope, then a
checksummed envelope per tick. The header fingerprint includes all state, input,
event and header schemas, including zero-step files. The header declares exact
counts and total byte length; every chunk carries its epoch, content and tick.
All fields use canonical little-endian schemas. No native padding, pointers or
platform-width integers enter a recording.

Files are capped at 16 MiB; an individual envelope payload at 1 MiB; the owned
record values at 64 MiB; a tick at 4096 events. Codec/simulation scratch and schema
metadata add temporary memory. An export that exceeds a limit fails explicitly,
without silently shrinking the selected window. Complete expected frames make
field-level diagnostics straightforward but cost more space than input/hash-only
recordings. Duplicate-event validation is bounded by each event batch. This is an
explicit developer operation, unsuitable for every render frame.

Checksums detect corruption, not malicious edits or origin. The archive includes
complete authority/private state. It is not a network recovery format, durable
transaction log, full-session stream or proof that arbitrary future inputs are
deterministic. Continuous recording and multi-window assembly remain separate work.
The [loaded-recording viewer](playback.md) now inspects these files in Godot.

## Godot export and Hello verifier

`recording_export` captures/encodes then writes via staged native storage, or
requests a browser download. Native storage retains its existing process-crash
boundary, without promising power-loss durability. Browser download requests are
not receipts that the user retained the file. `Debug_Recording` adds an opt-in
button with latched input, status and a tooltip containing the captured range.
Keep it at a stable address until teardown disconnects the callable.

Hello exposes this beside its history controls with `REPLAY_DEBUG=1`. Export
records the original timeline while inspecting; preview edits enter a recording
only after an explicit Branch. Native output defaults to `user://hello.rplrec`;
`REPLAY_RECORDING_PATH` overrides it. Chrome requests `hello.rplrec` as a download.
Ordinary launches create no recording widget or recording allocations.

```sh
nix develop --command odin run examples/replay_hello/tools/verify_recording \
  -collection:godot="$PWD" -- /absolute/path/hello.rplrec
```

The verifier bounds the file before allocating and rejects incomplete/growing
reads. Exit 0 means the complete recorded suffix agrees; 1 reports replay/model
failure, with field details for divergence; 2 reports usage/read/decode failure.
It runs without Godot. Application rules and immutable geometry come from Hello's
shared model, not the file.

## Network models

The [network recording adapter](../net/recording.md) preserves `Batch` inputs and
`Net_Event` outputs, including admission decisions and historical aim data. It is
used by Scrapyard's developer-menu exporter and standalone verifier. Models needing
context-aware input validation can supply `input_check(input, tick, user)`; it runs
with the existing validators before any simulation step.

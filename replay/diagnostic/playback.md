# Inspecting a saved gameplay recording

`Playback(State, Input, Event)` loads a portable recording, verifies it once, and
provides a presentation cursor over copied expected frames. Seeking and playback
do not execute the simulation or deliver old events. The original game stays
independent until its owner explicitly accepts a selected frame as a new branch.

```odin
player: d.Playback(World, Input, Event)
defer d.playback_destroy(&player)
loaded := d.playback_load(&player, bytes, identity, model)
if loaded.accepted {
    frame, ok := d.playback_read(&player)
    d.playback_seek(&player, player.recording.base.tick)
    d.playback_play(&player, true)
    d.playback_advance(&player, render_dt)
    // Paint copied frames. Do not send the recording's old events to effects.
}
```

A successful load starts paused at the first recorded frame. A state/event
mismatch is accepted for inspection, starts at its first divergent tick, and keeps
an owned `Audit_Capture` plus `report` text. `verification` distinguishes agreement
from divergence; accepting a file is not a claim that it reproduces correctly.
Malformed files, context/type mismatch, model-invalid values and aborted replay
steps reject replacement, preserving the old recording, report and cursor.

Playback shows the **recorded expected state**, including at a mismatch. The
report compares expected and replayed values. Full replay of the loaded window
occurs only during load; the cursor never simulates or emits effects. Playback
ends at the recorded head, and Play at the end restarts at its beginning. A
zero-step recording remains stopped. Seek validates u64 ticks without converting
absolute ticks to floating point. Invalid/nonfinite elapsed time does nothing;
a render stall contributes at most 250 ms. Large elapsed steps skip intermediate
visual frames in constant time, retaining the fractional tick between frames.

The owner and its recording/capture allocations must not be copied. Destroy
before its owner leaves scope. Imported immutable asset identifiers still need
the application's matching assets, just as in the [recording contract](recording.md).

## Godot controls

`Debug_Playback(State, Input, Event)` provides Open recording, a native or browser
file chooser, Play/Pause, a relative-tick slider, Details, Return to game, and
Continue from recording. It returns commands; the application owns its clock,
input buffering, rendering and branch operation.

```odin
rgd.debug_playback_init(&viewer, owner)
action := rgd.debug_playback_frame(&viewer, identity, model, render_dt)
switch action {
case .Enter: // Save previous pause, pause the local clock, clear device edges.
case .Leave: // Restore previous pause and gate held input until released.
case .Branch:
    frame, ok := rgd.debug_playback_read(&viewer)
    // Copy first. If accepted, initialize a new local timeline/presentation epoch
    // at frame.tick, then end playback. Never replay the file's historical effects.
case .None:
}
frame, showing := rgd.debug_playback_read(&viewer)
// Paint frame while showing. While owns_pause but no frame is loaded, keep the
// original world paused and visible while the chooser is pending.
rgd.debug_playback_end(&viewer)     // Explicit reset; owner restores its clock.
rgd.debug_playback_destroy(&viewer) // Disconnect callbacks and release imports.
```

Keep the widget at a stable address until destroy. `owns_pause` covers both file
selection and loaded playback. A canceled/failed first import releases that pause;
a failed replacement keeps the old loaded view. Opening a replacement pauses its
playback cursor. The application can read `loads`, `rejections` and `last_load`
for diagnostics. Continue is an explicit branch from the displayed expected frame,
including when the report shows a reproducibility mismatch. It does not repair
that mismatch or change the imported archive.

Hello enables this alongside `REPLAY_DEBUG=1`. Entering the viewer ends a local
history inspection, preserves its prior pause, and temporarily hides the live
history/audit controls. Return restores the original game; Continue resets from
the selected complete frame under a fresh local presentation epoch. Held gameplay
input remains suppressed until released. Restart closes loaded/pending playback.
No Session/Room/P2P runner or network authority is modified.

## File selection and bounds

`File_Import` is the stable owner for a bounded asynchronous selection. Native
Godot uses its filesystem dialog, clamped to the parent window so its buttons
remain reachable in Hello's 640×360 viewport. The `.rplrec` filter helps selection;
codec checks still decide whether a file is valid. Native file bytes are read only
after selection and are bounded before allocation.

Chrome uses an ordinary file input and checks size before `File.arrayBuffer()`.
Each import has an ID; closing it discards the job, removes its DOM input and
fences late completions. At most eight browser selections can exist at once.
Cancellation, failed reads, zero/oversized files and byte-length changes terminate
the request. Return to game can also cancel a pending selection. Teardown clears
both pending jobs and callbacks. No upload to a server occurs.

Files retain the recording codec's 16 MiB limit and content/build/schema checks.
Verification runs synchronously on load and can take time for a large world/window.
This is an opt-in local developer workflow. It is not continuous recording,
multi-window assembly, an editable imported timeline, movie export, or network
recovery. To edit an imported frame in Hello, Continue from it, then use the local
history field editor.

Run [the native/Chrome acceptance](../../tests/replay_recording/README.md) to test
real file selection, presentation, rejection, pause restoration and branching.

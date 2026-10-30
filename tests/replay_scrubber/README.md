# Local history inspection acceptance

```sh
REPLAY_SCRUBBER_OUT=/absolute/fresh/output nix develop --command bash tests/replay_scrubber/run.sh
```

The runner builds an isolated Replay Hello copy, waits for editor builds, then
builds the final native library. It runs the existing Hello/Loot fixtures, new
headless UI checks, a rendered run/capture, the four-process network fixture and WASM checking. It verifies prepared
and framework hashes before executing, retains binary and driver digests, and
requires fresh result directories. The original examples are unchanged.

The new driver exercises real F10 input and the real Branch button, including a
complete press/release before the next frame. It checks that past/head selection
changes views while preserving live state and one-shot counts; Resume preserves
the original future and prior pause; Branch resets to the selected frame with a
new epoch; held device input stays gated until release; a new shot emits once;
wrapped history remains bounded; reset clears a stale selection.

The field-editor extension selects schema paths, rejects model-invalid pool counts
and integer overflow, changes a copied preview, resets it, discards edits on tick
selection/Resume, and branches from an edited player position. The recorded head,
shots and effect count must remain unchanged while editing. `ReplayFieldValue`
identifies the intended LineEdit; the dropdown also contains its own search box.
The Chrome driver selects fields and types values through actual keyboard events,
without asking its bridge to mutate the simulation.

`tests/replay/history_test.odin` separately tests window metadata at zero, a nonzero
checkpoint, wrapped retention, confirmed history, reset, a busy source and `u64`
exhaustion. This is an inspection window rather than an audit/replayable-input window.

Run the browser gate against a completed native fixture:

```sh
nix develop --command bash tests/replay_scrubber/web.sh /absolute/native/output /absolute/fresh/web-output
```

It exports a separate copy and drives real Chrome keyboard, slider and button
input. The test-only bridge reports state and controls only fixture pause/teardown;
it does not edit game values or implement the inspection/branch operations.

The [API guide](../../replay/godot/debug/scrubber.md) describes exclusive local pause,
presentation ownership and remaining boundaries. These controls are not enabled
on Session or P2P games and do not claim network time-travel editing.

The recording extension exports the original history while a preview is edited,
and exports the accepted branch after fresh input. Native and Chrome tests retain
both files and verify them in separate headless processes. Range, epoch, shots and
position must match the original live state at export. Browser success requires a
completed download, not just the library's download-request count. The independent
[recording target gate](../replay_recording/README.md) can replay these same files
in freestanding WASM.

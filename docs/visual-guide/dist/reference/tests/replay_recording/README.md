# Local recording acceptance

```sh
REPLAY_RECORDING_OUT=/absolute/fresh/output nix develop --command bash tests/replay_recording/run.sh [additional.rplrec ...]
```

Runs diagnostic unit tests and WASM checking, builds the Hello verifier and a
headless recording fixture, then replays the same archives in native Odin and
freestanding WASM with no imported runtime functions. It compares range, completed
steps, event count, epoch and final gameplay values. Each target must reject a
corrupted archive. The default corpus includes wrapped retention and an empty
nonzero checkpoint with no player.

Unit cases cover complete owned copies, canonical roundtrip, first state/event
mismatch and field text, all truncations and single-byte corruption, valid-checksum
forgeries of counts/stamps, context/type mismatch (including zero-step files),
model preflight, aborted steps, occupied destinations, correction boundaries,
busy sources and u64 exhaustion. The test runner tracks allocated memory.

`tests/replay_scrubber/run.sh` exports real native headless/rendered originals and
edited branches through the actual Godot button, then verifies each in a fresh
headless process. `tests/replay_scrubber/web.sh` clicks that button in Chrome,
retains the completed downloads and verifies those files with the same CLI.
Pass their `.rplrec` files to this gate for execution in WASM as well.

The [format/API guide](../../replay/diagnostic/recording.md) documents scope,
identity, storage and memory limits. This does not claim full-session recording or
network recovery from a local simulation window.

## Loaded-recording Godot workflow

```sh
REPLAY_PLAYBACK_OUT=/absolute/fresh/output nix develop --command bash tests/replay_recording/playback_run.sh
```

This runs the existing Hello/Loot/history/export/network gates, generates loaded,
corrupt, oversized, deliberate-mismatch and empty-checkpoint files, and drives the
playback viewer in native headless/rendered Godot and Chrome. Native selection
sets a directory/path, selects the matching file-list row, then clicks the actual
Open button. The Chrome driver uses actual file chooser selections. Gameplay
values and playback commands are not assigned through its reporting bridge.

Acceptance covers cancellation, expected-frame playback without effects, seeking,
failed replacement preserving the old view, saved pause/input gates, complete-frame
branching with one fresh effect, mismatch field details, restart and teardown of a
pending import. Chrome additionally checks oversized selection before decode and
an empty checkpoint branch. Native dialog sizing is exercised in the original
640×360 viewport. Captures retain the shown mismatch and exact drivers/inputs.

The engine-free tests also exercise transactional playback replacement, abort/model
rejection, zero-step data and the u64 boundary. `file_import_test.mjs` executes the
actual embedded importer JavaScript against controlled DOM/File objects to check
size-before-read, cancellation, late completion, failed reads and bounded jobs.
Both recording and playback runners are registered in `tests/run_all.sh`.

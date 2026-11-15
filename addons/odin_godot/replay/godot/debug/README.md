# Replay developer tools

Import `debuggd "godot:replay/godot/debug"` for optional Godot inspection tools:
the diagnostic overlay, local history scrubber, copied field editor, recording
export and recording playback. Enable them explicitly from the application's
presentation lifecycle.

The overlay samples runtime counters and runs bounded audits on request. The
scrubber and field editor return inspection/branch commands and detached values;
the application owns pausing and deciding when to branch. Recording export writes
only after an explicit request. Playback validates a recording before presenting
its frames and returning a command to resume gameplay.

Keep tool owners at stable addresses and destroy them before their parent node
exits. Callbacks and imported-file operations borrow their owner. Local tools
depend on the public Session lifecycle, input bindings and storage adapters;
games import each feature they use.

`session_diagnostics_enable` and `session_diagnostics_frame` connect the optional
engine-free telemetry owner to a Session's admitted application lane. Continue
its frame call while gameplay is fenced so stale measurements are cleared.

See [overlay](debug.md), [scrubber](scrubber.md),
[recordings](../../diagnostic/recording.md) and
[playback](../../diagnostic/playback.md). File-selection and persistence owners
live in `storagegd "godot:replay/godot/storage"`.

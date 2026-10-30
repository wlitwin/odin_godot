# Feature scenarios

`replay/testing` runs without Godot and owns/destroys its timelines, checkpoint
buffers and temporary servers. Results include before/after frames and a structured
report (`phase`, failing tick where available, timeline/network error, final
canonical state hash). Only `.Complete` is success; a zero-initialized report fails.

```odin
result := scenario.correction(initial, step, predicted[:], actual[:], first_late_tick)
assert(result.report.phase == .Complete)
assert(result.before.state.health == 8 && result.after.state.health == 10)
```

The two input arrays start at `initial.tick + 1`. The harness runs a predicted and
uninterrupted reference timeline, replaces the corrected suffix once the actual
inputs arrive, audits it, and compares every retained frame and event occurrence.
Choose history large enough to retain the entire scripted scenario. An incorrect
prefix outside the corrected suffix is a visible comparison failure.

```odin
drive: proc(^net.Server(World, Control, Action, Event, SEATS), u64) -> net.Error
result := scenario.takeover(initial, model, config, 20, 70, drive)
assert(result.report.phase == .Complete)
```

Takeover runs to step 20, captures/encodes/decodes a network checkpoint, restores a
new authority epoch, and continues through step 70. The uninterrupted reference
receives the same epoch observation. A drive callback may submit scripted inputs
or actions identically to both owners; nil supplies neutral input. Before/after
frames let the feature assert a remaining wind-up, exactly one hit, or other rules.
It compares continuation frames/events and audits the restored timeline.

This helper uses an in-memory server and a fixed local test credential. It does
not emulate leases, transport loss, authentication, browser storage or live host
failure. Keep tests through the real session/recovery stack for those contracts.
Scrapyard's existing recovery tests remain separate.

`tools/wasm_equal.mjs` executes a self-contained WASM export and compares its u64
hash against one native `hash=...` result. A zero result, unexpected import,
missing/multiple native results, trap or mismatch fails. Build/link each game's
corpus normally; Stormcaller uses Emscripten for the same math implementations.

`tools/peers.py` provides `Peer`, `free_port` and `run` for POSIX local integration:
unique logs, required/error markers, one shared deadline, optional final hash
agreement, and process-group termination/kill on failures. All logs survive a
failure. Free-port selection still has the normal bind race; readiness and network
behavior belong to the test protocol. The helper sends no external messages.

Stormcaller's focused tests now exercise these helpers:

```sh
nix develop --command odin test tests/replay_scenarios -collection:godot=.
REPLAY_STORM_OUT=/absolute/fresh/results \
  nix develop --command bash tests/replay_stormcaller/run.sh
```

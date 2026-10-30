# Network simulation recording acceptance

```sh
REPLAY_NETWORK_RECORDING_OUT=/absolute/fresh/output nix develop --command bash tests/replay_network_recording/all.sh
```

`run.sh` builds an isolated Scrapyard copy, runs host/client processes with 120 ms
receive delay, drives guns and two abilities per player, and submits accepted and
rejected development actions. It clicks the actual developer-menu export control,
requires continued simulation without resync, and verifies both saved recordings
in fresh headless processes. Original data/model rules are unchanged; the existing
migration encounter fixture supplies stationary durable targets.

`web.sh NATIVE_OUTPUT FRESH_WEB_OUTPUT` exports a separate project and drives a
real Chrome solo session through the same network batch reducer. A completed file
download must match its export receipt and pass the native verifier. The test's
casts/grant are explicit statements: GDScript release builds remove assert calls,
so test actions must not be placed inside assertions.

`targets.sh FRESH_OUTPUT RECORDING...` executes each file in native and standalone
WASM, compares reported ranges/workload counts, rejects checksum corruption, and
requires field-level mismatch reports for a recomputed-checksum changed state.
A semantically invalid final control must be rejected before executing any step.
The full game simulation and math routines execute inside WASM; the module has no
imports. Mutated test files/logs are retained per input. Odin object compilation
plus Emscripten linking supplies the math library and normal WASM optimization.

`tests/replay_net/recording_test.odin` independently checks replay after transport
destruction, decision preservation without admission callbacks, and preflight of
seat/group/control/action metadata. Existing diagnostic tests cover ownership and
canonical value handling. See the [adapter contract](../../replay/net/recording.md).

This is not a network crash recording or migration file. It does not establish
full-game parity, public deployment or broader platform determinism. Export is an
explicit synchronous debugging operation; observe its recorded cost before using
it during latency-sensitive play.

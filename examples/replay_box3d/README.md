# Replay Box3D contested physics

This project uses Replay's existing `Session`, server/client runner and complete
Timeline with the shared Box3D backend. Production gameplay comes from
`examples/box3d_common`; the example imports no test fixtures or Kit runtime.

The example supports live keyboard input and scripted intent. Independent official
Godot runs have verified Host + Client, Host + Client + Observer, a dedicated
Server + two Clients, and a separate 32-body/H128 Host + Client case. Confirmed
solver/game/observation/event bytes, accepted action provenance, effects and
requested-resource cleanup are checked. Hard canonical recovery can skip past
effects; those intervals are recorded explicitly. This does not establish the
long soak, impairment quality or performance acceptance. The whole-call 4 ms
Gate B budget remains **unmet**.

The small-scene GUI renders pooled proxies and ordinary keyboard input moves both
players. macOS GL Compatibility launches have also emitted GLES shader startup
errors; these remain recorded and clean renderer acceptance is open.

## Build and launch

Run commands from the repository root in the Nix development environment. Build
one native shared library (macOS shown; Linux uses `libogb3.so`):

```sh
nix develop --command bash build/build_box3d.sh Release /tmp/replay-box3d-native
export BOX3D_NATIVE_LIBRARY=/tmp/replay-box3d-native/build/Release/libogb3.dylib
nix develop --command bash build/build_scripts.sh examples/replay_box3d
```

Then run two terminals with the same build, seed, initial body count and port:

```sh
B3_ROLE=host B3_PORT=49642 B3_SEED=1 B3_BODIES=4 B3_TICKS=240 \
  nix develop --command bash examples/replay_box3d/play.sh
B3_ROLE=client B3_PORT=49642 B3_SEED=1 B3_BODIES=4 B3_TICKS=240 \
  nix develop --command bash examples/replay_box3d/play.sh
```

`play.sh` rebuilds the project; retain `BOX3D_NATIVE_LIBRARY` in the environment
when using it. For an already built project, skip rebuilding:

```sh
B3_ROLE=host B3_TICKS=240 ODIN_SCRIPTS_DLL="$PWD/examples/replay_box3d/bin/libodinscripts.dylib" \
  nix develop --command bash -c 'exec "$GODOT" --path examples/replay_box3d --max-fps 60'
```

Add `--headless` for automated runs. `B3_ADDRESS` defaults to `127.0.0.1`;
`B3_ROLE=host` is semantic player 1, `client` joins an admitted player seat,
`observer` has no driver, and `server` (alias `dedicated`) is a nonplaying authority.
For two clients, use distinct full-width `B3_TOKEN` values and optional diagnostic
labels `B3_ACTOR=client1` / `client2`. Admission assigns their seats; tokens and
ENet peer IDs are transport identities, not gameplay seats. Both use H=128 and an
eight-tick ordinary prediction/repair bound. Initial counts are 4 or 32; the
small case is not a substitute for the separate full envelope or Gate B soak.

The sample uses the supported `snapshot_every=1` configuration so a frozen final
authority tick always has a complete checkpoint. Termination requires the actual
participant-confirmed target signatures over the existing application lane; wall-frame
settling does not count as a completion acknowledgement.

The authority processes zero-intent membership through the existing Session,
then holds until every expected participant has applied complete Welcome and
acknowledged its role. `GO` releases the existing runner. After GO, ordinary
held/neutral/leave rules keep authority simulation live through a disconnect. `READY` records the actual baseline and the
requested target (`baseline + B3_TICKS`). Clocks remain observational; native
physics uses the existing fixed 60 Hz/four-substep operation.

For live play, set `B3_SCRIPTED=0 B3_TICKS=0` on each process. Zero means no
automatic stop. Input is sampled outside the model: physical WASD moves, Space
spawns, Backspace removes, M changes the motor, J sleeps, K wakes, Q queries, and
Escape closes. The render loop reads one owned checkpoint and its bulk pose
cache each frame. A bounded pool of 33 body proxies plus authored floor/sensor
visuals never writes solver poses.

For an observer cohort, all actors use `B3_EXPECT_OBSERVERS=1 B3_END_TICK=300
B3_TICKS=240`, with distinct tokens (for example 101/202/303). Each actual Welcome
baseline must leave at least 240 ticks before the stop tick; invalid settings
reject. The authority waits for every retained confirmed target signature before
closing. `B3_END_TICK` only stops the runner; it does not set simulation state.

Scripted buttons use Replay's existing **Receipt** action timing in every role.
The authority records the actual execution tick, which can differ from the
client's predicted submission tick. Six action kinds repeat every 240 ticks.
The sample explicitly configures snapshots each tick and the existing Link
router at 8 MiB/s, with 1 MiB pump/burst and bounded 256 KiB/128-packet lanes.
`FLOW` records expose actual traffic and backpressure. These settings do not
prove narrow-link behavior or the 4 ms budget.

## Evidence

Set `B3_OUTPUT` to an existing writable directory. `BOX3D_SLICE_FRAME` records
point to immutable `.sig` (480 bytes) and `.part0` through `.part4` files for
Solver, Game, Side, completed Observations and Occurrences. Files are written
before their log record. Empty Side is valid. Comparisons are within the same
build and target; process-local domain cookies are not compared across processes.

`BOX3D_SLICE_INPUT` and `APPLIED` read published accepted history. No candidate
callback prints a successful verdict. `FX` records come from actual
`session_changes` deliveries, with stable epoch/tick/source/key, phase, confirmed flag and
full gameplay event payload. Speculative Begin and later Confirm are separate
journal work, so raw Host/Client delivery counts need not match.

`RESULT` includes cleanup status and requested engine/wrapper/Meter bytes.
`owners_live` is the number of remaining owner-retained Meter contexts in the
example's provider/core categories; `managed_callbacks_live` comes from the
actual stable Core callback table. Fixed Core housekeeping storage is separate.
A startup or teardown failure is explicit and exits unsuccessfully.

All physics runs in Box3D. Visible nodes are render proxies; no Godot RigidBody
acts as hidden solver authority. P4.3 will provide the reusable presentation and
debug bridge. Native allocator OOM, allocator rounding, Godot resources and RSS
remain separately reported limits rather than an implied recoverable hard cap.

Managed physics supports the demonstrated same-authority client reconnect and
complete Welcome/reset. Cross-role takeover and authority-to-client migration
currently reject with `Invalid_Config` before effects or teardown. They require
separate transactional migration acceptance; the reconnect proof does not cover
them. Managed Room, bundle storage, non-ENet transports and Solo mode likewise
reject before startup effects. Native-free and standalone defaults are unchanged.

For the bounded fresh-process rejoin probe, `B3_GENERATION` is a diagnostic launch
ordinal, never a Session incarnation override. An old Client can use
`B3_EXIT_AT` to close after that actual confirmed tick; `SESSION_EXIT` reports
checked cleanup and is not a final target acknowledgement. Launch its replacement
only after authority reports the old generation disconnected. The replacement
uses ordinary Client open with the same `B3_TOKEN`, plus assertions
`B3_EXPECT_TOKEN`, `B3_EXPECT_SEAT`, and `B3_EXPECT_EPOCH` from the old actual READY.
No admitted identity is force-set. All actors share an explicit `B3_END_TICK`,
leaving at least 32 future ticks after the replacement's real Welcome baseline
and satisfying its `B3_TICKS` minimum. First Welcome retires only already-past,
unissued phase thresholds to their next 240-cycle and logs the exact plan indices;
issued sequences and accepted history are unchanged.

## Startup impairment controls

The five settings below are strict decimal startup values. Unset or empty is
zero. Signs, spaces, fractions, exponents, overflow and out-of-range values
reject explicitly before physics or transport construction. There is no clamp,
invalid-to-zero conversion, or retry on a clean link.

| Setting | Unit | Range |
| --- | --- | --- |
| `B3_LATENCY` | local receive delay, milliseconds | 0–10000 |
| `B3_JITTER` | extra local receive jitter, milliseconds | 0–10000 |
| `B3_LOSS` | whole percent | 0–100 |
| `B3_DUPLICATE` | whole percent | 0–100 |
| `B3_REORDER` | explicit jitter/reorder capability request | 0 or 1 |

`B3_REORDER=1` with zero jitter is Unsupported. Zero is not an independent
reorder-disable switch: nonzero jitter may reorder Unreliable messages. Replay
applies these through its existing owned, metered receive Delay before the
ordinary Session open. All-zero defaults leave Delay unallocated. Existing
bounded queues, resource admission and ordinary eight-tick limits remain in use.

The effect is local receive processing above ENet. Loss and duplication affect
only Unreliable messages. Reliable messages remain ordered per sender, with no
modeled loss or duplication; their delay/jitter respects that order. Configuring
both actors applies one receive delay in each direction. This does not model
ENet's lower-level retransmission/congestion behavior or certify a bandwidth,
impairment quality or frame-time budget. Existing decorator seed42 is unchanged.

For example, add `B3_LATENCY=50 B3_JITTER=10 B3_LOSS=2` to a launch environment.
Replay also supports `B3_DUPLICATE=1 B3_REORDER=1` with positive jitter. These
controls are startup-only; rendering never changes the transport. READY includes
nested `impairment.request`, actual installed `impairment.effective` values and
`impairment.channel` scope/capability labels, also shown in the HUD. Effective
loss/duplicate values are explicitly in permyriad; requested values are percent.
Invalid/Unsupported preflight emits the existing ERROR kind and checked cleanup.

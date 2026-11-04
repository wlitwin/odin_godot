# Kit Box3D contested bodies

An authored Godot scene with two player spheres, a shared crate, a hinged box,
one sensor and a dynamically spawned capsule. Physics runs through Kit's
existing accepted-input Session/Lane path and the shared Box3D backend. Meshes
are pooled presentation nodes; there is no Godot rigid-body solver.

The project imports production assets/rules from `examples/box3d_common`, never
test fixtures. The Replay example uses the same rules with its own runtime.

## Build and play

Use the development shell and a verified native **shared** library:

```sh
nix develop
export BOX3D_NATIVE_LIBRARY=/absolute/native/build/Release/libogb3.dylib
bash examples/kit_box3d/run.sh build
bash examples/kit_box3d/run.sh live-host
# A second terminal:
bash examples/kit_box3d/run.sh live-client
```

Linux uses `libogb3.so`. The normal SDK build deploys one shared backend and
checks actual native build/target/domain identity. Do not substitute a static
archive or load a different backend into another module.

Arrow keys move your sphere. Space spawns the capsule; R removes it; M changes
the hinge motor; F sleeps the crate; G wakes it; Q performs a query. The HUD
shows semantic seat, current/confirmed tick and status. Reset requests a complete
authority baseline on clients. Reconnect closes the current Session/runtime and
starts a fresh owned one. Live mode uses `B3_SCRIPTED=0 B3_TICKS=0` and does not
quit on a timed gameplay target; a disconnected/error state holds visibly.

The two non-spectator, non-dedicated Session IDs are frozen as semantic game
seats before physics attachment. ENet peer IDs are separate. Fixed local Kit
proxy ownership enables whole-world prediction on each peer; it grants no game
authority. The observer has no input driver. Server/dedicated mode needs two
clients with distinct tokens.

## Headless roles and diagnostics

```sh
mkdir -p /absolute/case/host /absolute/case/client
B3_ROLE=host B3_PORT=43123 B3_SEED=1 B3_BODIES=4 B3_TICKS=240 \
 B3_OUTPUT=/absolute/case/host "$GODOT" --headless --max-fps 60 --path examples/kit_box3d
B3_ROLE=client B3_PORT=43123 B3_ADDRESS=127.0.0.1 B3_TOKEN=202 \
 B3_SEED=1 B3_BODIES=4 B3_TICKS=240 B3_OUTPUT=/absolute/case/client \
 "$GODOT" --headless --max-fps 60 --path examples/kit_box3d
```

`B3_ROLE` also accepts `observer` (default token303), `server` and `dedicated`
(authority without a player driver). Two dedicated clients must have different
`B3_TOKEN` values. Tokens use full-width Session encoding. For a declared
startup observer cohort, set `B3_EXPECT_OBSERVERS=1` on the authority. The Ready
barrier is on Session app tag4; full Welcome validation is acknowledged before
the authority sends GO. Waiting in the lobby never burns prediction ticks.

`B3_TICKS` requests the minimum run after the actual Welcome baseline.
`B3_END_TICK`, when supplied, is only an absolute stop request and must be at
least baseline plus requested ticks. It never sets a simulation or confirmation
tick. Keep transport pumping at the target until real retained final signatures
are acknowledged by the participating peers. Each runtime generation writes to
its own `gN` directory; interim cleanup is `SESSION_EXIT`, final cleanup `RESULT`.

Client reconnect preserves its Session token and requires the same logical player,
frozen two-player mapping, semantic seat and epoch. The Reconnect button first
destroys the old Lane/Session/provider and checks native, snapshot and Meter bytes
are zero, then makes one attempt with a fresh SDK/Meter context. Its half-second
lobby delay is scheduling only: it does not prove the authority saw departure.
A live-token race, changed identity or incompatible epoch fails explicitly; the
example never changes World_Drivers or retries with a different identity.

The focused test controller in `tests/box3d_slices/kit/rejoin_probe.py` observes
the source client's successful `SESSION_EXIT` and the authority's actual
`PLAYER_LEFT` before launching generation2. `B3_EXIT_AT` requests interim client
cleanup after a real confirmed tick; it does not set a tick. Fresh-process guards
are `B3_GENERATION`, `B3_SOURCE_GEN`, `B3_EXPECT_PLAYER`, `B3_EXPECT_PLAYER1`,
`B3_EXPECT_PLAYER2`, `B3_EXPECT_SEAT` and `B3_EXPECT_EPOCH`. These values can only
reject an admission. The authority keeps its normal held/neutral input rules
while the client is absent. After public Session token reclaim and validated
canonical Welcome acknowledgement, it replaces only that participant's pending
peer receipt and clears its old signature/ACK. Rejoin does not inherit an ACK.
The absolute end tick must leave at least the requested future run after the
actual new Welcome baseline. The focused probe is correctness preparation, not
an independent acceptance or performance result.

JSON records include READY, GO, FRAME, APPLIED, FX, TAIL and RESULT. Each FRAME
names a480-byte `.sig` and `.part0` through `.part4`, obtained through the public
owned confirmed diagnostic API. APPLIED comes from confirmed checkpoint receipts
and the accepted input ledger; FX requires an actual postcommit callback payload
and settles once after confirmation. No staged prediction log is called accepted
gameplay. The renderer reads Game and the bulk body cache from the same owned
checkpoint, and never steps or restores a solver.

Legitimate eight-tick/history holds request a public complete reset once, keep
the published pair intact and wait for a validated authority baseline.
RECOVERY_REQUESTED records the incoming checkpoint/input-window context and
publication-preservation check; RECOVERED reports the actual new baseline.
There is no rewind truncation, fabricated confirmation or clock admission.

The optional Wire uses a retained Meter allocator, exact weak Wire block owner,
separate allocator owner,128-packet/2MiB/8-peer bounds and seed1. Reliable queue
saturation is sticky and stops delivery until explicit connection teardown;
it does not silently discard or reorder reliable packets. RESULT reports actual
engine/wrapper/Meter live bytes and cleanup errors; cleanup errors are not a
measured Core owner count.

With `B3_BODIES=32`, LIMITS records the actual initial body cache and the
unchanged H128/60Hz/four-substep/eight-tick/64MiB configuration. ENVELOPE pairs
that same owned current-head cache with `physics.observe` and records sampled
published-world count maxima. Its provenance is explicitly
`phase=published_cache_and_world_observation`,
`native_scope=published_world_only`: these are not candidate or unsampled
engine high-water counts. A native/cache body-count mismatch is an error.
LEDGER records actual shared-domain live bytes, current reservations, admitted
bytes and the committed peak at published frames, before close and after
cleanup. Sampled reservations are not a claimed reservation high-water mark;
tracked ledger bytes are not process RSS. Existing SDK admission enforces its
own limits independently of these diagnostic observations.

The scene consumes startup-only local-receive impairment settings through the
existing presentation converter and owned Wire. `B3_LATENCY` and `B3_JITTER`
accept decimal milliseconds from0 to10000; `B3_LOSS` and `B3_DUPLICATE` accept
whole decimal percentages from0 to100; `B3_REORDER` accepts0 or1. Unset or empty
values default0. Signs, whitespace, fractions, exponents and out-of-range values
fail explicitly before an SDK context, transport or physics world is created.
Kit reports Unsupported for duplicate>0, explicit reorder1, or loss>95; it never
clamps these requests or retries with a clean link.

For example, add `B3_LATENCY=50 B3_JITTER=10 B3_LOSS=2` to either actor's launch.
The setting affects that actor's receive path above ENet; setting both actors
adds one receive delay in each direction. It is not a lower-level ENet congestion
or retransmission simulation. Stream loss may drop packets and nonzero jitter
may reorder Stream even when `B3_REORDER=0`. Reliable traffic remains FIFO per
sender; modeled loss adds the existing retransmit delay. Reliable queue overflow
remains an explicit fault. The HUD and READY's nested `impairment` record show
requested/effective units, local scope and channel semantics. Zero defaults leave
the original clean receive path active. No cross-framework identical fault trace
or nonzero-setting performance/resource acceptance is implied.

## Acceptance status

The initial four-body independent Host/Client milestone passed240 confirmed
ticks, eight exact five-part anchors, all scripted action kinds, rejected
simultaneous Spawn, matching accepted provenance/effect payloads and zero
teardown. That report is historical for its exact earlier rules/source graph.
Shared movement tuning and the additional observer/dedicated/rejoin cases require
fresh recorded validation. This README does not mark the P4.2 card complete.

The small scene does not replace the separate32-body/H128/eight-tick case.
Whole-call4ms correction remains **UNMET** at GateB/P4.4. Native allocator OOM
boundaries are unchanged; Godot/ENet/RSS/code-image overhead is measured separately.
No mixed-target exact physics or P2P support is claimed. Stop a live runtime before
changing its script/schema; typed cross-realm Runtime migration is not supported.

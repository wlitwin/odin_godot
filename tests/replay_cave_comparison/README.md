# Cavecrawl comparison: Kit, Replay server motion, Replay owner motion

```sh
REPLAY_CAVE_COMPARISON_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_comparison/run.sh
```

The contract is in `contract.json`. Three isolated projects use the actual game
code and a common ordinary-input driver. Both authored floor resources use empty
waves and seed 1337, keeping this a quiet two-player movement/interaction workload.
The host stays away from the door to prevent floor advancement. Different initial
spawns are normalized by walking to common anchors before warmup, not by editing
live state. Endpoint differences within the declared tolerance remain observable.

Three repetitions rotate variant order. Both processes retain a fixed 16-second
measurement window at 60 FPS maximum, 20 Hz networking and 120 ms receive delay.
The client follows common waypoints, takes the three gems, opens the door and returns.
Authority inventory must remain conserved in every sample, and both final views
must settle at three gems. Client-side predicted/partially delivered inventory
totals are recorded separately rather than mistaken for authority corruption.

Contract 2 records visible bag/door changes separately from command-confirmed
completion, and waits for confirmation plus the received result before the next
waypoint. Replay visible inventory comes from the predicted world used by its HUD;
its raw state probe reads authority observations. Kit entity fields may include
local prediction. The earlier contract-1 cohort is retained but superseded because
it mixed those interaction-observation scopes.

The output reports inclusive Odin process-callback wall time, application transmit
bytes, rendered response, host pose observation and both interaction timings.
Cross-process observations use the same machine's system clock and are frame
sampled. No total-process CPU, transport framing/retransmission or Internet latency
claim follows. Probe and GDScript driver work is outside the timed callback.

Both variants copy complete backups at a five-second cadence. Kit's automatic
succession metadata remains in its measured traffic; Replay does not run an external
coordinator in this cohort. This does not compare equivalent migration services.

The Kit copy has one explicit ownership-only overlay: its navigation-map lookup
releases the returned World2D reference. The pristine pilot completes gameplay but
leaks that reference at shutdown. Original Kit and Cavecrawl files are unchanged;
the modified copy and before/after hashes are retained. No navigation algorithm,
movement rule, gameplay authority or callback instrumentation is replaced.

`authoring.py` records mechanical source counts/imports/annotations, with generated
code and framework implementations excluded. Feature sets differ and the common
Replay frontend includes both motion profiles. These counts are not human effort
or ergonomic scores. Full gameplay, presentation, stress, deployment and human
adoption comparisons remain separate roadmap requirements.


`CAVE_COMPARE_PACKETS=1` enables a diagnostic-only transport meter around the
existing router during the measured window. It records counts/bytes by envelope
kind and an independent zero-bitmap size estimate for full Observation bodies.
The meter preserves every transport callback and never changes delivery. Its
extra scanning work makes callback timings diagnostic, not performance evidence.
`CAVE_COMPARE_RAW_OBSERVATIONS=1` disables the optional observation encoding through
Session options before feature negotiation, permitting same-binary A/B runs.

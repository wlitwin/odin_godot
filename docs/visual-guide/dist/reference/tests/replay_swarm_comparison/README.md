# Sustained Scrapyard offensive comparison

```sh
REPLAY_SWARM_OUT=/private/tmp/replay-swarm-new \
  nix develop --command bash tests/replay_swarm_comparison/run.sh
```

Requires the original sibling `../scrapyard`. The output directory must be fresh.
The harness makes separately runnable Kit and Replay project copies with isolated
save names, records the existing baseline ownership cleanup, and builds both with
`-debug -o:speed`. It waits for editor build workers, explicitly rebuilds, and
fingerprints the actual binaries. Original projects and user profiles are preserved.

The [contract](contract.json) specifies two stationary bolter users, seed 1337,
60 Hz and a 60 FPS process cap, with 120 ms receive delay in each process. Shared
resource fixtures disable scrapbot bite damage and set bolter magazine capacity
to 255 and jam probability to zero. This avoids player wipes and reload pauses in
this particular offensive workload. These fixture changes are recorded separately
from the baseline cleanup and read-only measurement adapters.

The host fills forty stock scrapbots, then replenishes toward forty every six
ticks, with at most four spawn requests per batch. Spawn requests and nearest-enemy
aim selection run through existing game development paths inside the timed game
callback. Enemy AI, collisions, projectiles, damage, death/reaping and pickups run
through ordinary gameplay. Both peers arm after a two-second warmup with
settled receive progress and fire for twenty seconds. A shared stop barrier and two-second settle precede final receipts.

Acceptance requires 32–44 living enemies in every captured frame, a time-weighted
mean of at least 36, at least twenty kills, sixty observed enemy identities, twenty
actors with measured travel, and 45–75 shots per player during each window. The
read-only census records IDs, position, HP, kind, combat totals and population on
each process frame. Authority health, kill and loot conservation must hold. Both
peers must converge on the final damage, kills, scrap, loot, health, population,
known spawn count and shots. Every issued host spawn must have been observed.

The default gate requires three pairs in alternating Kit/Replay order, exact
source/binary fingerprints, clean process shutdown and twenty report rejection/
acceptance cases. Raw receipts, callback timings, census cost, measurement-window
RSS, environment and per-run/aggregate statistics remain in the output directory.
`REPLAY_SWARM_PILOT=1` runs one pair with an explicit partial-plan report and a
separate pilot marker; it cannot satisfy the full comparison gate.

Callback timings are inclusive elapsed time for the real game callback, including
its different networking/simulation/presentation work and the spawn/aim adapter.
Census and GDScript observation work are outside that timer but consume process
time and memory. The reported census subtotal ends after enemy enumeration and
authority conservation checks; subsequent counter reads and trace construction
are outside both timers. It is not total instrumentation CPU cost. RSS includes
instrumentation and is sampled only while the measurement marker is active. Application output
counts accepted protocol bytes, including Replay's other router lanes and Kit's
one-byte tag, excluding ENet framing/retransmission. Delay settings are not measured
RTT. Nearest-rank percentiles and median/range across three pairs are descriptive,
not confidence intervals or a framework-only ratio.

The same intent and population bounds do not imply identical transient worlds.
Authority models, spawn scheduling, targets, shots, attribution and presentation
differ. Clients observe different prediction/authority scopes. This is a sustained
offensive workload: movement, player damage, status/ability combinations, changing
waves, network faults, human responsiveness and full-game parity remain separate
requirements. The older peak-and-drain stress gates remain available.

Version 2 makes receive freshness explicit: two warmup seconds and every measured
client observation must keep contiguous facts no more than thirty ticks ahead of
the received authority frame, and prediction depth no more than lead plus thirty.
The host must advance 1,180–1,220 ticks; the Replay client's received authority
frame may advance 1,140–1,260 across the window because its endpoints can fall on
different snapshot delivery phases. Actual advance and lag percentiles/maxima
are reported, and no resync may occur during measurement. Thirty ticks is a
workload acceptance bound, not a responsiveness target for competitive games.
The earlier four-tick warmup bound cannot hold continuously while large reliable
snapshots await acknowledgments. That pacing limitation remains visible.

`REPLAY_SWARM_REUSE=/path/to/previous-run` first prepares new isolated sources,
verifies every compiled source/content hash against the previous copies and checks
shared framework/binary hashes, then copies exact binaries and imported asset
caches. Only the external GDScript driver and isolated project namespace may
differ. The reuse receipt records the source run; build logs belong to that build.

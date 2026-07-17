# Acid-test your game

Every shipped example and real game on this framework lives and dies by the
same test shape, so the addon ships it as a product, not a pattern:
`addons/odin_godot/template/test/` holds a sourceable `harness.sh` and a
`driver.gd` skeleton, and scriptgen **generates the probes** the driver reads
the world through. The reference consumer is `examples/cavecrawl/run.sh` — a
four-act acid (the story, save/resume, match flow + moderation, host
migration under `kill -9`) whose plumbing is entirely the harness.

**The shape.** Launch N *real* headless processes of your *real* main scene
under an injected bad link (`netgd`'s shim, via your `*_LATENCY` /
`*_JITTER` / `*_LOSS` env — a slow wire, a wobbly one, a lossy one). A GDScript
`SceneTree` driver presses the same `@(gd_method)`s your buttons fire — no
mocks anywhere — and prints an UPPERCASE tag for every fact worth asserting.
Your `run.sh` sources the harness, wraps each scenario in an **act**, and
asserts over the **logs**:

```sh
source addons/odin_godot/template/test/harness.sh
fslp_build

duel() {                                  # one act: a self-contained scenario
    local port="$1"
    local hlog="$FSLP_LOGS/h.log" glog="$FSLP_LOGS/g.log"
    local hp gp
    hp=$(fslp_launch host "$hlog" MYGAME_PORT="$port")
    fslp_ready "$hlog" "HOSTING" 10 "$hp" || return 1     # bind receipt or retry
    gp=$(fslp_launch guest "$glog" MYGAME_PORT="$port" MYGAME_LATENCY=120)
    fslp_wait_all 90 "$hp" "$gp"
    expect       "$hlog" "GAME_STARTED"                "the round never started"
    expect_same  "$hlog" "$glog" "SCATTER sum=[0-9]+"  "the worlds diverged"
    expect_count "$glog" "WAVE_CLEARED" 2              "the guest cleared both waves"
    expect_absent "$hlog" "_FAIL"                      "the host driver failed"
}

fslp_act "the duel" 3 duel     # 3 tries, fresh port each — bind races retry
fslp_verdict MYGAME            # MYGAME_OK / MYGAME_FAIL
```

**What the harness owns** (each primitive was a debugging session in some
real game before it moved here):

- `fslp_act NAME TRIES FN` — per-act retries on fresh ports. A bind conflict
  costs a try, not the run; a spent act fails the run but later acts still
  execute (one run, every finding).
- `fslp_ready LOG PATTERN SECS PID` — wait for a receipt before launching
  the next peer, failing fast if the process died (the port-in-use race).
- `fslp_wait_all SECS PIDS...` — drivers exit themselves after
  `ROLE_DONE`/`ROLE_FAIL`; this waits for that, and reaps stragglers only
  past the deadline.
- `fslp_reap [PIDS...]` — TERM, a grace for stdout to flush, then `-9`.
  A raw `kill -9` truncates the log buffer, and a log that lies is worse
  than a hang. (`kill -9` stays *yours* to call when the crash IS the test —
  cavecrawl's migration act kills its host mid-sentence on purpose.)
- `expect` / `expect_same` / `expect_absent` / `expect_count` — the assert
  vocabulary. All of them just flip `FSLP_OK`, so a hand-rolled `grep` for
  an act's odd shape (asserting across two logs at once, exact counts)
  composes freely with them.

**Generated probes.** The mechanical half of every game's hand-written
queries file is now scriptgen's: for every `entity=` kind, the game class
gets registered `@(gd_method)` probes —

```
probe_<kind>_count()           # live entities of the kind, as this peer sees it
probe_my_<kind>()              # my entity's net id (0 = none)
probe_<kind>_<field>(id)       # any replicated SCALAR field; id 0 = mine
```

— so `game.probe_kicker_hp(0)` in `driver.gd` reads what this peer's screen
believes, with zero game code. They read the same replicated state your HUD
renders (on a sim-lane game: presentation truth, after `lane_present`).
Hand-write only the genuinely game-shaped reads — a derived view (predicted
hp overlay), a nearest-scan, a formatted compound — and note a hand-written
proc wearing a probe's name suppresses that probe, census-style.

**Conventions the examples bled for** (each was a real debugging session):

- **Verdicts come from logs, not exit codes** — the launch subshell owns the
  pids; drivers print `ROLE_DONE` / `ROLE_FAIL` instead.
- **Assert each fact on every peer that should observe it**, and
  byte-identical (`expect_same`) where determinism matters — seeds,
  checksums, blob contents.
- **Branch on what the process BECAME, not what you launched** — under
  simultaneous joins, which peer seats as player 2 is a race; role-agnostic
  drivers + asserts over concatenated logs survive it.
- **Edges need dwells**: a flag flipped and cleared within one poll interval
  is invisible — hold state long enough for the slowest poller (and the
  slowest *screen* — see "The two timelines" in [net.md](net.md)).
- **Exact-value asserts on another peer's fluctuating fields are traps**
  (hp mid-regen); assert ranges or your own printed truth.
- **Test above 100ms.** Prediction bugs, edge-order bugs, and feel bugs are
  invisible on localhost; every reference acid injects 120ms+ (and the shim
  does jitter and loss too — a flaky wire is a different acid than a slow
  one).

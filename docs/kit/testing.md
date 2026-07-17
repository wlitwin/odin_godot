# Acid-test your game

Both shipped examples live and die by the same test shape, so the addon ships
it as a template: `addons/odin_godot/template/test/` holds a sourceable
`harness.sh` and a `driver.gd` skeleton.

**The shape.** Launch N *real* headless processes of your *real* main scene
under an injected bad link (`netgd`'s shim, via your `*_LATENCY` /
`*_JITTER` / `*_LOSS` env — a slow wire, a wobbly one, a lossy one). A GDScript
`SceneTree` driver presses the same `@(gd_method)`s your buttons fire — no
mocks anywhere — and prints an UPPERCASE tag for every fact worth asserting.
Your `run.sh` sources the harness and asserts over the **logs**:

```sh
source addons/odin_godot/template/test/harness.sh
fslp_build
hpid=$(fslp_launch host  h.log MYGAME_PORT=4307)
gpid=$(fslp_launch guest g.log MYGAME_PORT=4307)
fslp_wait_all 90 "$hpid" "$gpid"
expect      h.log "GAME_STARTED"                 "the round never started"
expect_same h.log g.log "SCATTER sum=[0-9]+"     "the worlds diverged"
expect_absent h.log "_FAIL"                      "the host driver failed"
fslp_verdict MYGAME   # MYGAME_OK / MYGAME_FAIL
```

**Conventions the examples bled for** (each was a real debugging session):

- **Verdicts come from logs, not exit codes** — the launch subshell owns the
  pids; drivers print `ROLE_DONE` / `ROLE_FAIL` instead.
- **A `queries.odin` of tiny `@(gd_method)`s** is the driver's window into
  the game — ints and bools the phases poll. Grow it alongside features.
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
- **Retry the whole attempt on a fresh port** — first-boot races are real.

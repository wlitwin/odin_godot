# Integration-test your game

The addon ships an integration-test harness in the template:
`addons/odin_godot/template/test/` holds a sourceable `harness.sh` and a
`driver.gd` skeleton. (A repo clone has the same files at
`build/template/test/`, and every example's `run.sh` sources
`build/template/test/harness.sh`.) scriptgen generates the probes the
driver reads the world through. Reach for the harness whenever you need to
prove a multiplayer behavior holds across real processes on a real network.
The reference consumer is `examples/cavecrawl/run.sh`, a four-act test
covering the story, save/resume, match flow plus moderation, and host
migration under `kill -9`. All of its plumbing is the harness.

For framework contributors, `tests/wireabi/run.sh` is the protocol-layout
fixture. It generates one nested schema, executes its exact raw byte vector
natively, and compiles the same fingerprint/layout assertions for web, Linux,
and Windows targets. The native pass queries the generated `NET_SCHEMA` field,
action, argument, type, and message tables; a profile-only package pins that
projection too, while `tests/repgen` covers inputs, constraints, entity ids,
scheduled actions, and presentation events. The fixture also proves a schema drift is denied by the real JOIN
handshake and pins recursive diagnostics across replicated fields, input
records, profiles, and typed messages, including platform-width integers,
implicit enums, pointers, hidden padding, and unsupported containers.

`tests/author_surface/run.sh` guards the authoring language itself. It compiles
negative fixtures for removed event attributes, quoted command policies, and
redundant owner interpolation, then scans production source for retired action
aliases and ID-only census generation. A compatibility spelling cannot return
without making the complete suite fail.

`tests/kitdocs/run.sh` guards the prose around that language. It verifies every
relative link in `docs/kit`, rejects retired symbols, and prevents tutorial
pages from teaching raw session lifecycle or `_net_pump` as the ordinary path.

`tests/kitstress/run.sh` is the optimized scale/operations gate. It prints
three receipts:

- `STRESS`: delta CPU at 0/10/100% dirty, join/world/snapshot bytes, apply and
  resume CPU, and session resident/peak allocation for 100/500/2,000 entities.
- `FANOUT`: per-recipient AOI composition CPU and authority egress at
  2/100, 4/500, and 8/2,000 player/entity shapes.
- `RESIM`: forced eight-tick replay CPU and prediction-history bytes for
  32/128/512 predicted entities.

The generous timing assertions detect complexity regressions, not machine
speed. The supported starting values derived from these fixtures live in
`network_profile_envelope`; [profiles](profiles.md) explains what they do and
do not guarantee.

## The test shape

Launch N *real* headless processes of your *real* main scene under an
injected bad link (`netgd`'s shim, driven by your `*_LATENCY` / `*_JITTER`
/ `*_LOSS` env vars: a slow wire, a wobbly one, a lossy one). A GDScript
`SceneTree` driver presses the same `@(gd_method)`s your buttons fire (no
mocks anywhere) and prints an UPPERCASE tag for every observable worth
asserting. Your `run.sh` sources the harness, wraps each scenario in an
**act**, and asserts over the **logs**:

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

## Harness reference

- `fslp_act NAME TRIES FN` gives per-act retries on fresh ports. A bind
  conflict costs a try, not the run; a spent act fails the run, but later
  acts still execute, so one run reports every finding.
- `fslp_ready LOG PATTERN SECS PID` waits for a receipt before launching
  the next peer, failing fast if the process died (the port-in-use race).
- `fslp_wait_all SECS PIDS...` waits for drivers to exit themselves after
  `ROLE_DONE`/`ROLE_FAIL`, and reaps stragglers only past the deadline.
- `fslp_reap [PIDS...]` sends TERM, allows a grace period for stdout to
  flush, then sends `-9`. A raw `kill -9` truncates the log buffer. Call
  `kill -9` yourself when the crash IS the test: cavecrawl's migration act
  kills its host mid-sentence, because the crash is what it asserts on.
- `expect` / `expect_same` / `expect_absent` / `expect_count` form the
  assert vocabulary. All of them flip `FSLP_OK`, so a hand-rolled `grep`
  for an act's odd shape (asserting across two logs at once, exact counts)
  composes freely with them.

## Generated probes

scriptgen generates the mechanical reads. For every `entity=` kind, the
game class gets registered `@(gd_method)` probes:

```
probe_<kind>_count()           # live entities of the kind, as this peer sees it
probe_my_<kind>()              # my entity's net id (0 = none)
probe_<kind>_<field>(id)       # any replicated SCALAR field; id 0 = mine
```

So `game.probe_kicker_hp(0)` in `driver.gd` reads what this peer's screen
believes, with zero game code. Probes read the same replicated state your
HUD renders (on a sim-lane game: presentation truth, after `lane_present`).
Hand-write only the genuinely game-shaped reads: a derived view (a
predicted-hp overlay), a nearest-scan, a formatted compound. A hand-written
proc that takes a probe's name suppresses the generated probe of that name.

## Writing assertions

- **Verdicts come from logs, not exit codes.** The launch subshell owns
  the pids; drivers print `ROLE_DONE` / `ROLE_FAIL` instead.
- **Assert each event on every peer that should observe it**, and assert
  byte-identical (`expect_same`) where determinism matters: seeds,
  checksums, blob contents.
- **Branch on what the process BECAME, not what you launched.** Under
  simultaneous joins, which peer seats as player 2 is a race; role-agnostic
  drivers plus asserts over concatenated logs survive it.
- **Edges need dwells.** A flag flipped and cleared within one poll
  interval is invisible, so hold state long enough for the slowest poller
  (and the slowest *screen*; see "The two timelines" in [net.md](net.md)).
- **Exact-value asserts on another peer's fluctuating fields are traps**
  (hp mid-regen); assert ranges or your own printed truth.
- **Test above 100ms.** Prediction bugs, edge-order bugs, and feel bugs are
  invisible on localhost; every reference test injects 120ms+ (and the shim
  does jitter and loss too; a flaky wire is a different test than a slow
  one).

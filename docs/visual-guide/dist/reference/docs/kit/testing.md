# Integration-test your game

Use the template's integration harness to check multiplayer behavior across
processes using the game's network transport. Installed addons include
`harness.sh` and a `driver.gd` skeleton in
`addons/odin_godot/template/test/`. Repository examples source the same
harness from `build/template/test/harness.sh` in `build/template/test/`.
Scriptgen generates probes that let the driver inspect replicated state.

`examples/cavecrawl/run.sh` demonstrates four scenarios: story progression,
save/resume, match flow with moderation, and host migration after `kill -9`.
Each uses the shared harness for launch, synchronization, and log assertions.

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

<a id="the-test-shape"></a>

## Process launch and log assertions

Launch N headless processes of the main game scene. Use `netgd`'s link shim
with `*_LATENCY` / `*_JITTER` / `*_LOSS` environment variables to inject
delay, jitter, and packet loss. A GDScript `SceneTree` driver calls the same
`@(gd_method)` procedures as the UI and prints an uppercase log tag for each
observable result. The scenario exercises the scene and transport without
mocking them. In `run.sh`, source the harness, wrap each scenario in an act,
and check its logs:

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

- `fslp_act NAME TRIES FN` retries an act on fresh ports. A bind conflict
  consumes one try. Exhausting retries fails the run, but later acts still
  execute so their results are also reported.
- `fslp_ready LOG PATTERN SECS PID` waits for the expected log receipt before
  launching the next peer. It fails early if the process exits, such as when
  its port is already in use.
- `fslp_wait_all SECS PIDS...` waits for drivers to print
  `ROLE_DONE`/`ROLE_FAIL` and exit, then reaps any remaining processes after
  the deadline.
- `fslp_reap [PIDS...]` sends TERM, allows stdout to flush, then sends `-9`.
  An immediate `kill -9` can truncate buffered logs. Use `kill -9` directly
  when testing a crash, as Cavecrawl's migration act does to its host.
- `expect` / `expect_same` / `expect_absent` / `expect_count` update
  `FSLP_OK` with assertion results. Custom `grep` checks can update the same
  value for assertions spanning logs or requiring other count rules.

## Generated probes

For each `entity=` kind, scriptgen registers `@(gd_method)` probes on the
game class to read counts, local ownership, and replicated scalar fields:

```
probe_<kind>_count()           # live entities of the kind, as this peer sees it
probe_my_<kind>()              # my entity's net id (0 = none)
probe_<kind>_<field>(id)       # any replicated SCALAR field; id 0 = mine
```

For example, `game.probe_kicker_hp(0)` in `driver.gd` reads this peer's local
entity hp through a generated method. Probes read the replicated fields used
for presentation; in a simulation game, those fields contain presentation
values after `lane_present`. Add game-specific probes for derived values such
as a predicted-hp overlay, a nearest-entity search, or formatted compound data.
A hand-written procedure with a probe's name suppresses that generated probe.

## Writing assertions

- **Read verdicts from logs.** The launch subshell owns the process ids, so
  drivers report `ROLE_DONE` / `ROLE_FAIL` for the harness to check.
- **Check each expected observer.** Assert an event on every peer that should
  receive it. Use `expect_same` for byte-identical seeds, checksums, or blob
  contents when determinism matters.
- **Use the identity the session assigned.** With simultaneous joins, which
  peer becomes player 2 depends on arrival order. Drivers that inspect their
  assigned role and assertions over combined logs can handle either order.
- **Hold state long enough to observe it.** A flag set and cleared within one
  polling interval may never be read. Allow for both the slowest driver poll
  and delayed presentation; see "The two timelines" in [net.md](net.md).
- **Use ranges for changing remote fields.** An exact hp assertion during
  regeneration can race an update. Check a range or assert a logged value from
  the process that computed it.
- **Test above 100ms.** Localhost can hide prediction, change-order, and
  presentation problems. Reference tests inject 120ms+ delay. Add jitter and
  loss cases too; delay alone does not exercise irregular or missing packets.

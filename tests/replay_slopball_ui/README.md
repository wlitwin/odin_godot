# Slopball native UI acceptance

```sh
REPLAY_SLOPBALL_UI_OUT=/absolute/fresh/output nix develop --command bash tests/replay_slopball_ui/run.sh
```

The fixture prepares an isolated project, builds/imports/waits/builds, and drives
host/client/observer through the actual scene controls. It checks manual leader
start, named roster/team/ping rows, movement and kick capture while typing, literal
chat, negotiated observer names, a real goal, departed rows, leave/rejoin with the
same seat/score and final disconnect. Fresh processes verify identity/name
persistence and preserved malformed name data. The app is also checked for WASM;
this is not browser gameplay acceptance.

`execute.py OUTPUT LABEL` reuses a prepared build. `RSL_UI_RENDERED=1` renders the
host and captures the scoreboard. `regression.py OUTPUT network` or `fault` adapts
the unchanged original network checker to the prepared app. `migration.py APP_OUTPUT
COORDINATOR_OUTPUT FRESH_RESULTS` reuses the existing planned/crash physics migration
fixture and its momentum/goal/common-tick assertions.

The first UI attempt restored an incorrect ball collision mask and failed with
Invalid_Input after a goal. Final code retains scene-authored layers/masks. Two
intermediate builds exposed the different integer types used by the generated
collision getters and setters; explicit conversions fixed those compile errors.
All failures remain in the result record; no gameplay threshold was relaxed.

## Two-match acceptance

`round_run.sh` builds a fresh app, runs UI/profile/WASM prerequisites, then plays
two complete matches through the scene's Play again button. Set
`REPLAY_SLOPBALL_ROUND_OUT` to retain output. `execute.py OUTPUT LABEL rounds` runs just
that fixture against a prepared build. The renderer flag above remains available.

The test refuses guest/observer restart, retains names/seats/chat, checks cleared
score and actual reset body poses/velocities with fresh authoritative scopes and no
preview, then finishes the second match and exchanges new chat. Model tests also
reject old player/ball samples, stale round requests and exhausted counters, and
compare corrected restart replay with fresh execution.

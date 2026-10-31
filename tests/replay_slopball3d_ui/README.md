# Slopball3D native UI acceptance

```sh
REPLAY_SLOPBALL3D_UI_OUT=/absolute/fresh/output nix develop --command bash tests/replay_slopball3d_ui/run.sh
```

The fixture prepares and builds an isolated project, imports it in Godot, waits
for editor-started compiler jobs, and performs a final build. It then drives host,
client, and observer through the native UI, checking leader Start, names/teams/ping,
movement, typing suppression, literal and named-observer chat, a real goal,
departed rows, same-seat rejoin with score preserved and clean shutdown. Movement
probes report X/Z in millimetres, with a 10 mm stationary tolerance while typing.
Fresh processes test identity/name persistence and preserved malformed name data.
The app is checked for WASM; browser gameplay is not claimed.

`execute.py OUTPUT LABEL` reuses a prepared build. `RS3_UI_RENDERED=1` renders the
host and captures the scoreboard. The driver checks menu rectangles in viewport
coordinates. The final UI scales its layers to the visible viewport; the first
rendered run exposed that the copied 2D layout was undersized for the 3D canvas.

`regression.py OUTPUT network|fault` preserves the established loft/spin/ownership,
settled-position and goal assertions. `migration.py APP_OUTPUT COORDINATOR_OUTPUT
FRESH_RESULTS` preserves exact checkpoint, position/velocity/quaternion seeding,
new-kick/goal and common-tick migration checks.

## Two-match acceptance

`round_run.sh` builds a fresh app, runs UI/profile/WASM prerequisites, then plays
two complete matches through the scene's Play again button. Set
`REPLAY_SLOPBALL3D_ROUND_OUT` to retain output. `execute.py OUTPUT LABEL rounds` runs just
that fixture against a prepared build. The renderer flag above remains available.

The test refuses guest/observer restart, retains names/seats/chat, checks cleared
score and actual reset body poses/velocities with fresh authoritative scopes and no
preview, then finishes the second match and exchanges new chat. Model tests also
reject old player/ball samples, stale round requests and exhausted counters, and
compare corrected restart replay with fresh execution.

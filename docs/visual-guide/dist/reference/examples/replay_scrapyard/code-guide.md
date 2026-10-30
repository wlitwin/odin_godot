# Reading and editing the Scrapyard code

Start with the [visual contributor guide](contributor-guide.md)
for the architecture, a hands-on reading path and an end-to-end feature trace.

## The frame loop

Start at `scripts/scrapyard.odin`. It declares the Godot script's state and its
ready/process/exit callbacks. The process callback shows the frame's order:

```odin
typing := poll_frame_ui(self)
// Return here until the script and a session/room are ready.
poll_frame_services(self, typing)
control := sample_gameplay_input(self, typing)
if !advance_gameplay_session(self, dt, control) {
    return
}
update_prediction_smoothing(self)
dispatch_session_changes(self)
present_session_frame(self, dt)
```

The deferred `finish_frame` runs when the process callback exits. It runs audio,
recording, diagnostics, social/recovery,
screen and feedback hooks even when a frame returns early. Their order is
intentional. Input edges are captured before session advancement; corrections
and event changes are consumed before presentation.

## Find the code for a change

| Responsibility | File |
| --- | --- |
| Input bindings and scene-component setup | `scripts/scene_setup.odin` |
| Network options, identity/resume, initial world and training encounters | `scripts/session_start.odin` |
| Profile declaration and lobby actions | `scripts/lobby_actions.odin` |
| Held controls, overlay guards, discrete actions and development-driver overrides | `scripts/input.odin` |
| Session advancement, correction smoothing and frame completion | `scripts/frame.odin` |
| Event fan-out, action outcomes and diagnostic traces | `scripts/session_events.odin` |
| Observation interpolation and scene presentation | `scripts/drawing.odin` |
| Gameplay status and local save/status messages | `scripts/status_view.odin` |
| Development control methods and test/diagnostic queries | `scripts/development_controls.odin`, `scripts/probes.odin` |
| Simulation tick, roster changes and player motion | `shared/game/game.odin` |
| Cast admission/cooldowns and individual ability effects | `shared/game/abilities.odin`, `shared/game/ability_casts.odin` |
| Enemy target selection and concrete AI routines | `shared/game/brains.odin` |
| Workbench admission, encounter setup, confirmation and updates | `scripts/workbench.odin` |
| Lobby sections, roster, button states and selected loadout | `scripts/muster.odin` |
| Flame reconciliation/collision and arc presentation | `scripts/cast_path_view.odin` |

Files under `scripts/` share one Odin package. Helpers receive the values or
borrowed world references they need. The script owns the session and Godot handles;
the simulation owns gameplay values. Simulation rules remain under `shared/game`, detached
display values under `shared/presentation`, and authored node behavior under
`scripts/views`. The [editor-first guide](editor-first.md) explains that boundary.

`Ability_Cast` holds the resolved inputs for one cast; `Mob_Pursuit` holds one
enemy's selected target, distance and speed. They are temporary inputs to ordinary
functions. Persistent gameplay values belong in `World`. Ability handlers share
the rule that a killing hit cannot also apply a status to that target.

## Code style

Use multiline procedure bodies and control-flow blocks, one statement per line,
and a blank line between meaningful phases. Keep short literals compact. Extract
a helper when it names a responsibility, isolates a lifecycle concern, or removes
nesting; a flat data table need not become many tiny functions.

## Format the code

The project-local `odinfmt.json` uses tabs and a 120-column target. From the
repository root:

```sh
nix develop --command python3 examples/replay_scrapyard/tools/format.py
nix develop --command python3 examples/replay_scrapyard/tools/format.py --check
```

The command covers handwritten Odin in scripts, shared code and tools, excluding
generated bindings and frozen revision definitions. Godot's format-on-save uses
the same configuration. The formatter preserves inline blocks, so write new
control flow across lines explicitly.

Formatting a definition extractor or catalog source changes its provenance hash.
Rebuild, then use `tools/stock.py --project /absolute/path/to/built/project` to
refresh the artifact receipt. Formatting alone must preserve the canonical
catalog digest, schema and semantic content version; it does not justify a new
save revision.

## Check a change

Run the model tests when changing gameplay rules:

```sh
nix develop --command odin test tests/replay_scrapyard \
  -collection:godot=. -out:/tmp/replay-scrapyard-model-tests
```

Use the feature's focused test or workbench when changing an input handler, view,
or authored Resource. Changes to an action or saved state also need correction
and checkpoint-continuation coverage. The contributor guide lists the
[model, Godot, and multiplayer checks](contributor-guide.md#7-run-the-smallest-relevant-check-then-expand)
and explains when each applies.

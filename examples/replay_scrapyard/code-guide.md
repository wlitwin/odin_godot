# Reading and editing the Scrapyard code

New to the project? Start with the [visual contributor guide](contributor-guide.md)
for the architecture, a hands-on reading path and an end-to-end feature trace.

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

The deferred `finish_frame` runs audio, recording, diagnostics, social/recovery,
screen and feedback hooks even when a frame returns early. Their order is
intentional. Input edges are captured before session advancement; corrections
and event changes are consumed before presentation.

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

These are ordinary functions in one Odin package. Helpers receive the values or
borrowed world references they need; the refactor introduces no additional world,
session, or ownership state. Simulation rules remain under `shared/game`, detached
display values under `shared/presentation`, and authored node behavior under
`scripts/views`. The [editor-first guide](editor-first.md) explains that boundary.

`Ability_Cast` holds the resolved inputs for one cast; `Mob_Pursuit` holds one
enemy's selected target, distance and speed. They are temporary inputs to ordinary
functions, not new saved state. Ability handlers share the rule that a killing
hit cannot also apply a status to that target. The Titan's add-spawning helper
still reserves both mobs together, in the original insertion order.

Use multiline procedure bodies and control-flow blocks, one statement per line,
and a blank line between meaningful phases. Keep short literals compact. Extract
a helper when it names a responsibility, isolates a lifecycle concern, or removes
nesting; a flat data table need not become many tiny functions.

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

## Refactor verification, 2026-09-21

The pass reformatted 129 existing Odin files and introduced nine files for the
responsibilities above. `replay_scrapyard_process` went from 146 compressed lines
to 22 lines; `scrapyard.odin` went from 745 to 208. Existing public Godot method
names and script-state fields remain intact. Frozen revision definitions were
excluded from formatting.

Validation passed: 108 game tests, seven turret tests, four Stormcaller tests,
native compilation and the full scripts WASM check, six editor/HUD scene checks,
the turret workbench, dash input through lobby/menu overlays, three real peers at
120 ms configured latency, and occupied host-crash recovery. The native/WASM
turret corpus still hashes to `15191278264882830483`, matching the pre-refactor run.
The catalog digest remains `7605822622581753901`; schema and content51/K are
unchanged. The stock artifact was rebaked to refresh source provenance only.

Logs and before/after source snapshots are retained at
`/private/tmp/scrapyard-refactor-20260921`. Formatting-only files were also compared
as token streams, ignoring comments, separators and formatter-added grouping.
The work does not establish new performance or interactive-browser results.

## Second refactor pass

The next pass focused on mixed responsibilities and nesting in six entry points:

| Entry point | Lines before → after | Extracted responsibility |
| --- | --- | --- |
| `cast_ability` | 143 → 76 | Family-specific effects and shared hit/status handling |
| `mob_brain` | 144 → 22 | Target selection, concrete brains and atomic Titan adds |
| `step_view` | 74 → 34 | Roster changes and player motion |
| `replay_workbench_process` | 118 → 25 | Admission, setup, confirmation and ongoing encounter updates |
| `muster_paint` | 103 → 23 | Sections, roster, actions and loadout display |
| `cast_paths_paint` | 103 → 4 | Flame and arc rendering, with a separate flame collision query |

Long lookup tables and frozen compatibility definitions remain intact. The pass
changes organization without adding persistent fields, changing gameplay content
or altering the stock artifact. Floating-point operations, target tie-breaking,
pool insertion order, action submission order and effect timing are preserved.

The 119 existing model tests pass. A separate before/after trace comparison runs
49 ability/enemy combinations for 240 ticks each and agrees on every complete
world-state and emitted-event trace (11,760 ticks total). Native/WASM turret and
Stormcaller corpora agree; the turret hash remains `15191278264882830483`.
Native compilation and the full scripts WASM check pass. Godot checks cover the
workbench panels/boss/wipe cases, lobby rendering, the four-peer ability encounter
with a late spectator, turret handoff/exhaustion and occupied host-crash recovery.
An initial turret run failed at ENet host creation before gameplay; the same
build passed when retried with a port checked for UDP availability. Both logs are
retained. Logs, trace drivers and the pre-edit source snapshot are at
`/private/tmp/scrapyard-refactor2-20260921`.

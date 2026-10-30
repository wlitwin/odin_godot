# Replay authoring tools

Use the optional Godot editor panel to run a project's authoring commands and
inspect their validation results. The tools require explicit gameplay policy
and operate outside a live match.
Scrapyard is the complete worked example; model, extractors and validation remain
Odin. The small EditorPlugin/preview controls use GDScript for normal Godot UI.

## Installation and project contract

A project opts in with `replay_authoring.json`:

```json
{
  "worker": "res://tools/authoring.py",
  "ability": "res://data/abilities/salvefield.tres",
  "workbench": "res://dev/ability_workbench.tscn"
}
```

The normal `build/build_scripts.sh PROJECT` installs the addon when this file is
present. Enable `res://addons/replay_authoring/plugin.cfg` in project settings
(Scrapyard already does). Installation writes local framework/Python toolchain
paths; re-run it when relocating the project/toolchain. It does not install tools
or send anything to external services. Current process/job helpers target native
macOS/Linux authoring with Python and an Odin build environment. If Odin is not
on PATH, the example worker can enter the framework's Nix environment.

The panel supplies Validate/Bake tools, current/stale content status, clickable
issues, Resource selection, workbench/scenario actions and feature drafts. The
project worker accepts project/framework/Godot/result paths, an action and optional
selection/name/kind/latency arguments. It publishes an atomic JSON result with
`ok`, `running`, `message`, `issues`, optional `stale` and retained log paths.
Issues contain `source`, `path`, `message` and optionally a source line. Source
links open Resources, scenes or scripts through the editor's normal interfaces.

Save & Validate/Bake saves open scenes and the selected saved Resource. Save other
independently edited Resources before running a project-wide action. The worker
builds current Odin code and runs typed checks in a separate bounded process.
Checks that instantiate authored views run in that isolated process; they are not
performed against a live game's World. Actual scene scripts may run their normal
construction/ready code, so choose appropriate leaf view scenes for validation.

`jobs.py` supplies bounded process-group ownership, per-stage logs, cancellation
files and atomic result publication. UI waits are nonblocking. Cancellation and
failure retain logs and prevent incomplete content publication. The existing
artifact exporter still checks source/build provenance before replacing data;
`--check` detects interrupted artifact/receipt replacement. Process cleanup ignores
missing/dead groups but still signals a live owned parent if group signalling fails.

## Isolated previews

`preview_controls.gd` is a reusable CanvasLayer controller for Node2D previews.
A preview implements `preview_refresh`, `preview_apply(phase, fraction, speed)`,
`preview_radius` and optionally `preview_range`, `preview_phase`, `preview_message`
and `preview_can_refresh`. The controller offers idle/attack/charge/hurt/death,
scrubbing, 0–4× playback and radius/range guides. It reloads authored resources
before explicit refresh; live-bound enemy views refuse refresh before reloading.

Scrapyard copies validated gameplay display values. Enemy previews also own a
validated appearance Resource copy, so invalid frame/texture/timing edits preserve
the last valid display. Child charge animation follows the preview playback rate.
These clocks/Resources stay outside World. An ability preview depicts its configured
area/status; actual hits, healing, cooldowns and replay behavior are tested in the
isolated encounter and scenario runner.

## Canonical Scrapyard example

See [the walkthrough](../../examples/replay_scrapyard/editor-workflow.md). It covers
Resource-based status references, shared checked extraction, a complete Salvefield
workflow, authored runner appearances, non-overwriting stable-ID draft scaffolding,
recording verification and real local peers. Actor drafts preserve the game's
existing root binding and compose a generated visual child; rules and feature
assertions remain explicit TODOs. Drafts do not enter the stock catalog automatically.

The UI uses the same commands as CI, including the existing recording verifier and
`replay/testing` correction/takeover helpers. In-memory checkpoint comparison does
not claim to test transport/security/lease failure. The network command runs real
local peers under the chosen latency profile; the framework's separate host-crash
fixture remains available for full migration testing.

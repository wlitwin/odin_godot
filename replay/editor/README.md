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
  "version": 1,
  "actions": [
    {"id": "validate", "label": "Save & Validate Pickup", "kind": "run_scene", "scene": "res://dev/validate.tscn"},
    {"id": "preview", "label": "Open Pickup Preview", "kind": "open_scene", "scene": "res://dev/pickup_preview.tscn"}
  ]
}
```

The normal `build/build_scripts.sh PROJECT` installs the addon when this file is
present. Enable `res://addons/replay_authoring/plugin.cfg` in project settings
(the Replay starter and Scrapyard already do). Installation writes local framework/Python toolchain
paths; re-run it when relocating the project/toolchain. It does not install tools
or send anything to external services. Current process/job helpers target native
macOS/Linux authoring with Python and an Odin compiler. The shared worker uses
the normal saved toolchain selection, so an editor launched outside the development
shell needs no separate compiler configuration or Nix fallback.

The panel shows only declared actions and their inputs. `open_scene` opens a
scene in the editor; `run_scene` builds current Odin code and runs a bounded
headless validation scene. Neither needs a project Python worker. The scene
writes JSON to `REPLAY_AUTHORING_REPORT`, with an `ok` boolean and an `issues`
array. Each issue contains `source`, `path` and `message`, with optional `line`.
The starter's `dev/validate.gd` is a small working example. A missing report,
failed process or engine error cannot report validation success.

For custom operations, declare `worker: "res://tools/authoring.py"` and actions
with `kind: "worker"`. That module implements `run(ctx, action, inputs)` and
returns the same report. `ctx` supplies `project`, `framework`, `godot`, `env`,
`job`, `build()` and `run_scene()`. Keep gameplay policy and artifact publication
there; `jobs.py` owns process bounds, cancellation and retained logs.

Optional `inputs` declare an `id`, `label` and `kind` (`resource`, `file`, `text`
or `choice`). Actions reference the input IDs they use. Defaults, file filters
and choice labels/values belong in the manifest; a choice defaults to its first
value when no default is specified. See Scrapyard's `replay_authoring.json` for
an example with Resource selection, drafts, recordings and network profiles.
Queued actions retain the input values captured when clicked.

Only projects declaring `status_action` receive background status polling. It
must name a worker action with `save:false`. Reports may provide `stale` when
the project has a baked artifact; ordinary validation does not imply one.
Reports may also include `message`, `details`, `outputs` (label/path pairs), and
an explicit `navigate_to` project path. The dock has no game-specific result
formatting. Use **Reload Authoring Actions** after editing the manifest.

For CI, run the shared entry point from the project directory:

```sh
python3 addons/odin_godot/replay/editor/worker.py --action validate --godot "$GODOT"
```

It prints the retained report path and returns a nonzero exit status on failure.
Use `--result` to choose the output, or `--request request.json` for an action
with inputs: `{"action":"validate","inputs":{"definition":"res://data/item.tres"}}`.
`REPLAY_AUTHORING_REQUEST` gives validation scenes the resolved request file.
`--describe` validates and returns the manifest without building or loading the
project's worker. The old Scrapyard-specific manifest and command-line options
are not supported.

Actions save by default (`open_scene` defaults to `save:false`). Saving includes
edited project Resources, their embedded data, open
scenes and script buffers before starting the worker. This includes Resources
you edited earlier and no longer have selected. It waits for a running filesystem
import so discovery can include all loaded project files. Unsaved drafts without
an owner, imported data that cannot be written back, and failed writes block the
action with clickable issues. Save an unnamed draft as a project Resource or
assign it to a saved Resource/open scene, then retry. A failed save preserves
edited state and never starts a validator or publishes an artifact.

The panel uses Godot's native edited flags and follows stored Resource references,
including arrays and dictionaries. Custom editor tools should use the normal
UndoRedo property actions or `EditorInterface.set_object_edited(resource, true)`
when changing Resources programmatically. A script assignment alone does not
mark an editor edit. Unattached drafts are tracked when inspected. Embedded data
is saved with every owner that actually serializes it. An instanced scene's
parent need not embed its inherited resources; their source scene remains the
owner. A built-in script buffer whose
owning scene is closed is identified so you can reopen that scene before saving.

Results describe the saved inputs read by the worker. New editor edits during a
job remain unsaved and are labelled separately; save and rerun to validate them.
The worker builds
current Odin code and runs typed checks in a separate bounded process. View
validation instantiates authored scenes there, outside the live game's World.
Their scripts can still run construction/ready code, so use view scenes whose
initialization is appropriate for isolated validation.

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
workflow, authored player-character appearances, draft scaffolding with stable IDs
that does not replace existing files, recording verification, and local peers.
Actor drafts preserve the game's existing root binding and compose a generated visual child; rules and feature
assertions remain explicit TODOs. Drafts do not enter the stock catalog automatically.

The UI uses the same commands as CI, including the existing recording verifier and
`replay/testing` correction/takeover helpers. In-memory checkpoint comparison does
not claim to test transport/security/lease failure. The network command runs real
local peers under the chosen latency profile; the framework's separate host-crash
fixture remains available for full migration testing.

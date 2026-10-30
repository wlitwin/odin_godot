# Authoring a feature in Godot

Replay Scrapyard now has an optional **Replay** editor dock and an F6 ability
workbench. The first complete example is Salvefield: a placed zone with radius,
duration, pulse timing and a referenced healing status. Its existing rules and
stock balance are preserved; drafts exercise additions without entering the
canonical catalog until reviewed. Baking validates the saved Resources and copies
their gameplay values into the catalog used by runs and headless tests.

## One-time setup

Build/import the project normally. `replay_authoring.json` opts into installation
of the Replay Authoring addon, enabled in this project's `project.godot`.
The worker needs Python plus the Odin development toolchain; Nix is a fallback
when Odin is not on PATH. The editor shows job progress while remaining responsive.
Native authoring/testing jobs target macOS/Linux; they are development tools, not
browser gameplay services.

## The accepted first milestone

1. Open `data/abilities/salvefield.tres` in the Inspector. `status` is now a
   **StatusDef Resource picker**. Choose a status by Resource instead of remembering
   its numeric ID. The bake validates type/path/membership and stores the stable ID.
2. Change radius, duration or pulse timing. **Save & Validate Content** checks the
   typed definitions, cross-references and registered enemy view scenes. Deliberately
   set radius to -1: the dock reports the exact Resource/field, and activating the
   issue opens it. Correct the value and validate again.
3. Open `dev/ability_workbench.tscn` and press F6. **Refresh authored data** reloads
   saved data into the isolated preview. State, progress, playback speed and spatial
   guides make the configured area easy to inspect. Invalid refresh keeps the prior
   validated display. Enemy previews provide the corresponding hurt/death/charge
   behavior and pause their child animation too.
4. **Run isolated encounter** explicitly admits a copied ability definition into a
   new development game. The workbench equips it through a normal Profile action,
   starts through Ready/Start, hurts the player through an admitted development
   action and casts through the normal ability action. It does not edit live World.
5. **Export reproduction** writes `user://workbench.rplrec`. **Verify last
   reproduction** invokes the existing offline recording verifier. **Return to
   preview** closes the encounter and restores its temporary environment settings.
6. **Replay rejected prediction** runs the authored ability with a predicted cast
   that is later corrected away, compares against an uninterrupted reference and
   audits frames/events. **Test checkpoint takeover** captures a mid-ability
   checkpoint, restores a new epoch and compares continuation. Results include
   casts/health, checkpoint/final ticks and a canonical hash.
7. **Run network encounter** launches a real host/client pair at 0, 80 or 150 ms.
   Both equip the selected definition, the host casts, and they must agree on a
   retained public world hash. Jobs have deadlines, cancellation and preserved logs.
8. Back in the editor, **Save & Bake Content** publishes the canonical artifact
   through the same extractor. The dock shows current/stale status. Save other
   independently edited Resources first; the buttons save open scenes and the
   selected saved Resource. Failed validation/baking preserves the last valid files.

The milestone was exercised through the actual editor plugin and running workbench,
not only through equivalent CLI commands. [Acceptance evidence](../../docs/replay/results/editor-workflow-2026-09-21/README.md)
records the exact checks and limits.

## References and shared extraction

Ability `status`, mob `boom_status`, and combo `present`/`incoming`/`output` now
reference StatusDef Resources. Optional missing references bake to ID 0. Required
ones fail validation. Referenced statuses must be catalog resources under
`data/status`; duplicate/missing IDs and invalid values are rejected.

`defs/bake_gun`, `bake_mob`, `bake_status`, `bake_combo` and `bake_ability` contain
one explicit mapping each. Catalog admission, export, validation, preview and
isolated authoring scenarios reuse them. Inspector hints do not define game rules.
The old catalog's canonical bytes are unchanged by this migration.

Runner appearances are now an Inspector array of `ScrapRunnerStyle` Resources,
with stable look IDs and idle/run textures. Swapping or reorganizing styles needs
no Becca/Joe/unknown fields in the view script. The three existing gameplay look
IDs/capacity remain an explicit game contract; duplicate/missing styles reject.

## Create a draft

Choose a source definition, a kind and a lower-case name in the Replay dock, then
**Create Feature Draft**. It creates `scripts/drafts/NAME` as one staged directory,
refuses overwrites/traversal names, and reserves an explicit available stable ID
under a lock. Existing IDs are never regenerated from filename order.

An ability draft contains a duplicated definition, preview scene, isolated
workbench scene, metadata, README and scenario entry point. An actor draft contains
its definition, composed visual script/scene, registration, authored preview and
scenario entry point. It inherits the existing enemy root binding and gives the
new visual component detached display data. New gameplay rules/state and specific
feature assertions are marked TODO; no authority or migration policy is invented.
The worker builds and previews a new draft before reporting success.

Drafts remain outside `data`/`archetypes` discovery. To adopt one, review its rules
and compatibility, move its definition into the appropriate data directory using
Godot's FileSystem tools, update references, add actor registration when applicable,
then validate/bake and add feature-specific assertions. The generic scenario is a
starting check, not evidence for rules that have not been implemented.

## Commands and boundaries

`tools/authoring.py` backs every editor/workbench command and writes structured
results/logs under `.godot/replay_authoring/jobs`. Use it from CI with explicit
`--project`, `--framework`, `--godot`, `--result` and the action. Direct catalog
checks remain `python3 tools/stock.py --check`; rebaking requires Godot and a current
compiled extractor.

The tooling preserves the last valid preview/artifact on rejected edits, keeps
live content admission explicit, and never sends messages to external services.
It adds startup validation and development processes; it makes no frame-time
improvement claim. Kit and the original sibling Scrapyard remain independently
runnable, with their source unchanged.

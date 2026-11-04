# Changing Dockyard

Edit `content/world.tscn` and its `.tres` geometry/joint resources in Godot for
authoritative collision content. The ordinary preparation/build runs the shared
bake. Runtime code retains detached values/catalogs/checkpoints and frees the
authoring tree; do not query scene nodes from a simulation step.

The current profile is 19 bodies/shapes, eight deduplicated geometries and one
hinge. Cosmetic detail belongs in `view.gd`/`feedback.gd`, not new physics bodies.
Simulation, inputs and authored rules live in `modules/dockyard/{model,round,controller}.odin`.
Changes there alter the rules/cohort and need affected complete-state/game checks.

Presentation consumes copied body frames and a bounded FIFO of **confirmed**
`Cue_Route` changes. `feedback.gd` remembers the consumed sequence, so repeated
getter calls, late joins and old snapshots cannot replay earlier sounds or
bursts. A FIFO gap is counted as unavailable; it does not fabricate an event.
The four voices and four 16-instance burst pools are bounded. Keep effects out
of the solver and honor reduced-motion/audio settings.

Generate the original WAVs with
`python3 tests/replay_dockyard/presentation/make_audio.py` and retain their hashes.
See [audio provenance](audio/PROVENANCE.md). All primitive meshes, colors and
cosmetic animation in this example are authored in repository code; no external
art pack is required.

Use F2 for local sound/camera/effects settings, Escape for the crew menu and F3
for actual-data diagnostics. Use the [presentation checks](../../tests/replay_dockyard/presentation/README.md)
for rendered/audio observations, [lifecycle checks](../../tests/replay_dockyard/recovery/README.md)
for network/ownership behavior and the final qualification card for hardware
budgets. An automated controller or screenshot cannot supply human co-op feedback.

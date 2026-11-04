# Dockyard round validation

`run.py` extracts the actual authored scene from a prepared ordinary SDK project,
then uses the current shared baker, builder and reducer with real Native complete
Timelines. It retains the compiled executable and source/library hashes. It is a
standalone rules test, separate from Core quota and network qualification.

The three groups require physical three-load delivery in all three arrangements,
once-only cues/payout/departure/results, source Timeline destruction followed by
complete checkpoint restoration and five-part equality, next-job continuation,
exact150-second deadline, invalid-pose refusal with all five parts preserved,
an actual driven robot fall/recovery, and a Native cargo fall/destruction followed
by retry with a stable gameplay identity and new Native key. The hazard fixture
places one load outside the dock before initial capture; it never sets a lost
flag, score, tick or protocol scope.

```sh
python3 -B tests/replay_dockyard/rounds/run.py \
  --project "$PROJECT" --build-record "$BUILD/report.json" --out "$NEW_RULES" \
  --native-library "$CURRENT_NATIVE" --godot "$GODOT" --odin "$ODIN"
```

`assess_pair.py` checks saved actual producer logs against derived rows, confirmed
results, exact Game bytes/hashes, three latched deliveries, three eligible cues,
payout, real terminal acknowledgement and measured cleanup. Native and browser
cohorts are assessed independently; it does not infer cross-target physics.

```sh
python3 -B tests/replay_dockyard/rounds/assess_pair.py --case "$PAIR" --out "$NEW_ASSESSMENT"
# Add --web for the browser fixture's saved console/binary parts.
```

`retry.py --execute` reuses the existing pair Actor/intake and complete-frame
helpers. Its SceneTree caller emits the real visible NEXT JOB button signal
after the first result. Both actual runtimes must observe round2/layout1, retain
identical complete state, acknowledge the target and clean up. It does not add
packets, assign heads or alter the reducer. Without `--execute` it writes a plan.
`visual.gd` separately checks actual Sphere meshes, bay/clamp surfaces, copied
poses, a GPU viewport screenshot and public checked close.

Physics changes are small and explicit: terrain overlap removes sharp seam
barriers; rounded robots retain their original1.296mass; the barge has working
space and physical guards; a surface-point magnet uses Native forces; and settled
loads become Native kinematic bodies rather than being repositioned every frame.
The new flat body-type API has native static/shared and Wasm regression coverage,
including mesh refusal without leaving the engine world locked.

All earlier failures remain in separate outputs. The original exact-flush ramp
caught the long crate; small overlap at both ends permits the actual physics
transition. The runner's first successful test-body run also exposed Odin's
automatic removal of successful test executables; `-keep-executable` fixes the
artifact receipt. No deadline/delivery/cleanup assertion was removed.

See [report.json](report.json) for actual scoped results. Human feedback, Internet
reachability, foreground browser budgets and the final frozen600-second case
are separate roadmap requirements.

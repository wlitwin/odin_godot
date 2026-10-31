# Scrapyard bridge integration gate

`run.sh` builds an isolated copy, checks the real scripts for WASM, and runs actor,
feedback, contextual audio and three-process combat checks. Choose a fresh absolute
`REPLAY_SCRAP_BRIDGE_OUT`. It also tests detached display projection and handles.
The sibling game and gameplay model remain unchanged.

The checked-in benchmark probe is **test-only**. `bench_build.sh PROJECT LOG_DIR`
adds it to an isolated previous/current project copy. It paints detached frames
with 0/8/32 mixed enemies and matching drops through the actual game paint function,
then verifies the live authority frame did not change. `benchmark.py WORK_DIR`
expects `before/project` and `after/project` and alternates three process pairs per
size. Both binaries must be finished before running it. Default helper builds use
`-debug`; no release-speed claim is implied. Results exclude scene construction
and GPU rendering. Keep both source snapshots when making comparisons.

The ordinary example never imports the benchmark probe. Tests inspect the
mob-root/Body hierarchy and require a fresh engine instance on a new entity lifetime.
Shared frame-hook/contextual-audio coverage also lives in `tests/replay_nodes`.

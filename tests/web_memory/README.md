# Web memory and shutdown qualification

`run.sh` qualifies both export-preset memory modes with actual pickup gameplay,
effects and audio in Chrome. It rejects JavaScript, engine and resource-leak
errors. It does not claim that shutting down the entire Godot Web engine is
error-free.

Run the separate strict shutdown diagnostic with:

```sh
nix develop --command python3 tests/web_memory/run.py /tmp/web-exit-single --engine-exit --modes single
nix develop --command python3 tests/web_memory/run.py /tmp/web-exit-threads --engine-exit --modes threads
```

The diagnostic removes the game scene, waits for its retained audio streams to
retire, then requests engine exit. `browser-result.json` records the observed
exit code, scene cleanup and every error; an engine error still fails the run.

On the tested Godot 4.7.1 single-threaded Web runtime, this reports
`Pages in use exist at exit in PagedAllocator: N16WorkerThreadPool5GroupE`.
The same diagnostic reproduces without Odin using `engine_baseline.gd`, a main
Node and `build/template/replay/effects/pickup.wav`, exported with extension
support enabled and threads disabled. Test by clicking the canvas and observing
Godot's public `onExit` callback. This comparison also returns exit code zero;
that does not make its error-free engine shutdown check pass.

The usability backlog retains the original logs, no-Odin comparison and exact
qualification results. Keep scene/audio teardown evidence separate from this
engine-level limitation. Do not whitelist the message in the strict diagnostic
or infer that all framework allocations are leak-free from the comparison.

The corresponding threaded run on the same host passes the strict orderly
scene/audio cleanup and engine-exit check with exit code zero and no errors.

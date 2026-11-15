# Configurable physics timing

The timing suite exercises build-selected history, repair/prediction windows,
tick rate, and native substeps through the real Kit and Replay adapters. It also
checks rejection of a module compiled for a different timestep.

```sh
nix develop .#capacity --command python3 tests/box3d_timing/run.py \
  --profile tests/box3d_timing/high.json --out /tmp/odin-timing-high
```

Use a fresh output directory. Omit `--profile` for defaults; use `low.json` for
64 retained frames at 30 Hz/two substeps, or `high.json` for 256 frames at
120 Hz/three substeps, Kit repair16 and Replay repair64, with a 2 GiB allowance
for the larger staged correction's stock reservations. The latter exercises
windows beyond the default bounds and a native reciprocal that differs if the
validator uses the wrong float operation order.

`nonpower.json` selects 96 frames to exercise modulo history indexing without
an unnecessary power-of-two restriction.

`--native /absolute/libogb3.a` reuses a matching archive; all compiler settings
then come from its manifest. The suite checks the framework timing setup,
correction boundaries, retained history, canonical welcome/reset, and cleanup.
Native correctness cases are also registered with the backend build.

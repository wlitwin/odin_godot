# Stress aiming origin

```sh
nix develop --command bash tests/replay_scrapyard_aim/run.sh
```

The test invokes the actual Scrapyard script procedure without a Godot process.
It supplies different predicted and authoritative player positions and different
predicted and observed enemy positions. The stress helper must aim from the local
predicted body toward the observed enemy, matching the ordinary input path's local
origin. A host must use its current authoritative body. Neither frame may change.

The original client helper used the older authoritative body and fails this case.
The wrapper regenerates script bindings before compiling, so the staleness guard
still catches code generation errors rather than being disabled for this test.

# Procedural polygon rendering audit

```sh
REPLAY_RENDER_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_render_audit/run.sh
```

The test harness copies the Replay Scrapyard project and stock content to an
isolated directory, adds an ownership probe, builds native and speed WASM, and runs
native view tests followed by the complete three-peer browser UI scenario.
Graphics tracing rejects invalid WebGL operations. The final report verifies
source hashes, all three traces, ownership receipts and common world hashes.
Original Kit and the sibling Scrapyard project remain untouched.

The read-only `trace.mjs` wrapper forwards buffer binds unchanged and never consumes
the GL error queue. Its small Node test verifies forwarding, inheritance and bounded
records. `drive.mjs URL OUTPUT` captures normal solo staging/arena views; the optional
`REPLAY_RENDER_SWARM=1` uses the loaded-migration fixture's existing load command.
It is a diagnostic observer, not a performance-neutral benchmark.

`line_project/` is a Godot-only reproduction with line mutation/transform and
polygon vertex/color/modulate/mesh modes. Export it using Godot's Web preset and
run `line_drive.mjs URL OUTPUT`; `verify_primitives.py OUTPUT` validates conflict
counts and compares captured PNG pixels. Changing Polygon2D vertex color or points
fails; self modulation alone still encounters the path on viewport resize. The
immutable mesh case reports no buffer conflicts. Pixel comparisons permit at most one 8-bit channel
step for vertex-color versus instance-color quantization.

`convert_scrap.gd SOURCE_SCENE OUTPUT_SCENE` reproduces the loot scene's authored
polygons as immutable ArrayMesh resources using Godot's serializer. It is a source
conversion utility, not a startup conversion.

The UI observer reads actual mesh vertex arrays once per mesh identity and caches
at most 1024 entries. Cooldown-dependent cast tests wait for readiness and verify
that the cast count advances; submission alone is not evidence of application.
`verify_report.py OUTPUT` checks rejection of altered result receipts.

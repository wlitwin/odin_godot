# Editor-first Scrapyard gate

`REPLAY_EDITOR_OUT=/absolute/fresh/output nix develop --command bash tests/replay_editor/run.sh`
checks detached display values, component recipes, isolated native/WASM compilation,
standalone edited scene previews, typed binding rejection/retirement, catalog edits
and rejection, real actor/HUD/feedback/audio behavior and combat/revive peers.

`web.sh NATIVE_OUTPUT WEB_OUTPUT` builds a separate actual browser export of the
standalone composed previews. `migration_build.sh OUTPUT` prepares an isolated
coordinator; the existing Scrapyard migration fixture supplies planned/crash and
optional downed-camera checks. The delivery receipts record the exact invocation.

`bench_build.sh PROJECT LOG_DIR previous|composed` adds a test-only render driver.
Use frozen copies from before/after the change, then the existing bridge benchmark
runner. The composed driver advances all new view process callbacks explicitly,
including weapon/equipment children and HUD. This keeps animation work in both
measurements; it does not include Godot callback dispatch or rendered GPU frames.

The authoring fixture changes only isolated Resource instances/files and verifies
that catalog rebaking cannot mutate the running World. It removes its temporary
duplicate definition. No test-only probes or benchmarks ship in the ordinary game.

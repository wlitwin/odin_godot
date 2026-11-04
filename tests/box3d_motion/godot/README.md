Owned schema-2 Godot motion fixture

Run `run.py` with the same explicit --out/--native-library/--godot/--odin
arguments as the P5.1 ordinary SDK fixture. It builds/imports then runs exactly
one headless test_motion.gd process. No Native build or new Core/scriptgen hook.

Each of8 named joint families uses its own two-body/ONE-joint World, actual shared
extraction, .tres/.tscn roundtrip, deterministic IDs across child reorder/rename,
source destruction before Native construction, actual Native joint count1 and
checked cleanup0. Character is copied config/initial POD only; the SDK test makes
one explicit Native fixed-step world-read call after source destruction. Addon
nodes never step, query live during replay or retain runtime state. Initial
Grounding/ground key are zero, not invented. Missing/self refs/nonrigid frames and
character bounds report actual field diagnostics. Runtime maps/keys stay Odin-side.

The actual SDK build, import and functional run pass on the declared macOS
reference. The first failed float-array expectation is retained; the corrected
expectation has identical numeric values. See [report.json](../report.json).
This is separate from the standalone framework rollback/canonical cases and
Native query/mover matrix. Gate C and whole-goal completion remain separate.

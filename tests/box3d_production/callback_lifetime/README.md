# Actual SDK callback lifetime regression

Source-only fixture, uncompiled/unrun until Root grants a case. The identical
criterion runs against an explicitly supplied frozen pre-fix or current
`modules/authoring_demo/` directory. A pre-fix RED remains a failed report; the
runner never promotes an expected failure to PASS.

```sh
python3 tests/box3d_production/callback_lifetime/run.py \
  --framework replay --module-source /absolute/selected/authoring_demo \
  --godot /absolute/Godot --odin /absolute/odin \
  --native-library /absolute/libogb3.so --native-sha256 "$NATIVE_SHA256" \
  --out /absolute/new-output --port 25130
```

Default is a no-job plan. `--execute` performs ordinary shared preparation,
copies the selected authored package exactly, appends one derived-only Odin
probe file, then uses the standard SDK build, ordinary import and one headless
GDScript test. Kit uses the same command with `--framework kit` and its selected
package. No shipping method/file or frozen module is edited. Generated source,
including real method-return wrappers, is preserved and hash-bound. This is an
SDK fixture, not exported deployment evidence.

The real authored Sample opens a Host on its unique port with processing
disabled before it enters the SceneTree. Ready still runs; no Client, GO, frame,
pump, step or reset is manufactured. Kit's pre-roster frontiers may honestly be
null. Kit uses `BOX3D_SAMPLE_SCRIPTED=0`: its scripted close requires a completed
target and terminal ACK, which this pre-GO lifetime fixture does not execute.
Replay retains `BOX3D_SAMPLE_SCRIPTED=1`. Checked-close assertions are unchanged.
Actual public status/presentation Strings and JSON are validated, then
128 warmup pairs precede two identical 10000-pair batches. Returns are discarded
at each GDScript helper-function boundary. Three preallocated counter snapshots
avoid retaining a fresh measurement container after each batch.

The one probe exposes primitive `callback_temp_available`, `callback_temp_used`,
`callback_temp_capacity`, `callback_temp_count` methods in the **same producer
module/TLS**. It first checks the actual context allocator procedure against
`runtime.default_temp_allocator_proc` and nonnil data, then reads that actual
`Default_Temp_Allocator.arena`. False availability / negative counter sentinel
fails setup; it is never recast as an observed zero. No arena/context is replaced
or reset by the probe. Exact `total_used`, `total_capacity` and `temp_count`
restoration is required between all three snapshots. These are arena counters,
not malloc totals, Native quota, Core gdext arena observations or RSS.

Godot `OS.get_static_memory_usage()` anchors must be nonzero, and the second
identical batch may not increase that heap relative to the first. Heap and
producer TLS are reported separately. Frontier equality/no GO/no frame advance,
actual checked public close and freed Node are independent setup/cleanup gates.
Source/module/tool/Native/binary fences and strict engine logs remain required.
No timing, 4 ms, soak, network-recovery or physics correctness claim follows.

# Gate C authoring/export validation

Gate C covers actual exported Host/Client runs of the same authored content
through separate Kit and Replay adapters. A successful export and binary
inspection are prerequisites, not runtime acceptance. Current work keeps each
framework/target result separate in the final report.

All four required cases passed. The [Gate C report](../../../tests/box3d_gate_c/report.json)
binds each normal export to its actual exported Host/Client run, raw logs,
complete five-part bytes, remote controls, loaded Native image and measured
cleanup. These are target120 functional checks; production hardening remains
in Phase 6.

| Required case | Execution scope | Acceptance evidence |
| --- | --- | --- |
| Kit / macOS arm64 | Native arm64 SDK and Native modules; official universal Godot launcher | PASS: export, inspection, exported pair |
| Replay / macOS arm64 | Same architecture boundary | PASS: separate export and exported pair |
| Kit / Linux x86-64 | ELF64 x86-64 userspace translated by Rosetta on the available Linux arm64 VM | PASS: Native matrix, export, exported pair |
| Replay / Linux x86-64 | Same translated functional scope | PASS: separate export and exported pair |

Translated Linux execution is not native x86 hardware performance evidence.
The universal macOS launcher is not a claim that arm64-only SDK modules support
Intel. No cross-target deterministic equality is inferred by comparing separate
same-build Host/Client cases. Existing simulation/profile bounds and ownership
contracts remain unchanged.


## Normal export preset setup

The two authored examples provide the same exact preset names: `macOS arm64`
(`macOS`, Godot launcher selector `universal`, ARM64 SDK/runtime scope) and
`Linux x86_64` (`Linux`, architecture `x86_64`).
macOS declares minimum11.0, unique `org.odingodot.box3d.kitauthoring` and
`org.odingodot.box3d.replayauthoring` bundle identifiers, Godot built-in ad-hoc
signing and notarization disabled. These are local test bundles, not signed
release/notarized/uploaded distribution. Actual bundle architecture/minimumOS and
library loading still require inspection of the exported files.

The matching official macOS template contains only the normal universal Godot
launcher. It is exported unchanged through the ordinary exporter: no custom
PCK/template patch or lipo thinning. The preset display name `macOS arm64`
denotes the SDK Core/scripts/modules/shared Native consumers and actual test
execution, which remain ARM64. Export inspection requires the launcher's actual
architecture list to contain ARM64 and records that list, while every SDK/Native
consumer must still be ARM64. This does not claim a universal SDK, Intel
execution or Intel compatibility. Actual binary inspection/runtime evidence,
not the preset label, establishes those facts.

Use `examples/box3d_authoring_shared/prepare.py` in a NEW task output with the
correct target's explicit verified shared Native library/SHA. It already copies
`export_presets.cfg` unchanged with the ordinary project; no special staging or
packer is added. Build the standard SDK Core/scripts/modules, import with the
matching official Godot/templates, then invoke the normal exporter, for example:

```sh
python3 examples/box3d_authoring_shared/prepare.py --framework kit \
  --out "$WORK/kit" --native-library "$NATIVE" --native-sha256 "$NATIVE_SHA" \
  --odin "$ODIN" --godot "$GODOT" --build
# Exporter's ordinary optimized build subprocess also needs the selected SDK/Native.
export ROOT="$SDK_ROOT" ODIN_GODOT_ROOT="$SDK_ROOT" BOX3D_NATIVE_LIBRARY="$NATIVE"
"$GODOT" --headless --editor --path "$WORK/kit/project" --quit-after 120
"$GODOT" --headless --path "$WORK/kit/project" \
  --export-release "macOS arm64" "$WORK/exports/KitBox3DAuthoring.app"
```

Use `--framework replay`/`ReplayBox3DAuthoring.app` for Replay. Linux uses its
verified Linux x86_64 shared `.so`, the same ordinary plugin/build flow and
`--export-release "Linux x86_64" .../kit-box3d-authoring.x86_64` (or Replay).
Do not use a macOS library in the Linux export. `ODIN` must identify the intended
target-capable compiler; export flags/target selection belong to the ordinary SDK
export plugin, not per-scene glue. Keep all output PCK/shared objects/modules and
adjacent metadata together. No manual PCK or `ODIN_SCRIPTS_DLL` override is part of
exported execution.

Both presets use `all_resources` plus explicit normal `.odin`, GDScript,
`.tres`, `.tscn`, `.gdextension`, JSON/config inclusion, so helper/module sources
and authored resources remain available to the supported export pipeline. Native
and module deployment remains the normal GDExtension/Odin export-plugin job;
there is no static engine duplication. The configuration-only reader
`tests/box3d_gate_c/presets/validate.py` checks names/arch/signing/source-inclusion
and identical shared content, without running Godot. Its result is not an export
or runtime pass.

Root/p/q own actual platform exports, file/loader inspection and record creation.
A record marked PASS means actual export and file inspection only; Root's
separate exported Host/Client controller must still prove state/inputs/final ACK,
natural cleanup and one Native image. Linux Rosetta execution is translated
functional evidence, not native x86 performance or cross-target determinism.
Final Gate C classification and its report remain Root-owned.

## Reproduced build limits

The original Linux task container reached its 1536 MiB limit and recorded two
OOM kills while Godot invoked Odin during export. One compiler thread alone did
not resolve the failed exports. The passing setup used a 6144 MiB VM, a 4096 MiB
task container and export-only `SCRIPT_BUILD_FLAGS=-thread-count:1`, retaining
the normal `-o:speed` optimization. SDK and product memory limits were unchanged.
Godot can return exit0 after reporting a failed script compilation, so the
Linux harness also rejects error and leak messages in import/export logs.

The first Linux CTest supervisor stopped collecting a zombie test process.
That attempt is retained as incomplete supervision, without a product verdict.
The replacement queried the actual CTest registration and ran every registered
command with the same arguments, working directory, properties and dependency
order, using file logs and direct waits. All 12 commands passed in Debug and
Release, including another complete run after the memory change. These records
explicitly say `actual_ctest_run_pass:false`. The SDK profile verifies their
source/binary identity, registration and logs rather than inventing a CTest PASS.

The report preserves failed attempts and the controlled VM resource change.
Only two idle containers belonging to this goal were stopped and restored;
user container states and the default connection were preserved. The recorded
rollback is for safe goal cleanup after checking for newly active user work.

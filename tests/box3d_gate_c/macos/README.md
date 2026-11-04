One ordinary macOS arm64 export workflow for either authored sibling. Root owns
all execution. Run inside the normal SDK toolchain shell:

```sh
nix develop --command python3 tests/box3d_gate_c/macos/export.py \
  --framework kit --out /tmp/kit-gate-c-export-v1 --execute
```

Use `--framework replay` and a fresh output for the other case. Defaults bind the
official `/Applications/Godot.app/Contents/MacOS/Godot`, its installed matching
4.7.1 templates, and the frozen motion NativeV2 Release dylib. Explicit `--godot`,
`--odin`, `--native-library`, `--native-sha256` options are available. Only preset
`macOS arm64` is accepted. Without `--execute`, a NEW output receives a plan and
source hashes only; no compiler, Godot or Native metadata execution occurs.
An execution uses a separate fresh output, preserving every staged/failed attempt.

Pipeline: existing sample prepare.py with `--build`; normal Godot editor import;
actual Godot `--export-release "macOS arm64" <app>` through OdinExportPlugin;
then actual Info.plist/executable/SDK module/shared Native/rpath/ABI/ad-hoc
signature inspection. It never invokes a manual packer, copies a template into a
fake export, substitutes project execution, signs/publishes remotely, retries or
changes production/build/export source. Any actual failure stops and is retained.

The normal official macOS template supplies a universal Godot launcher. The
preset named `macOS arm64` therefore selects `binary_format/architecture=universal`
for that launcher only. Inspection requires its actual architecture list to
contain arm64 and records the full list. Core, scripts, every module and Native
must still be exact arm64; execution is selected on native macOS arm64. This is
neither a universal SDK nor Intel execution evidence. No template patch, manual
PCK or lipo thinning is used.

`export-record.json` matches Root's record contract: result/framework/target,
actual bundle_root/executable/export_argv/native_identity, relative-file SHA256
artifacts and source_fence_unchanged. It also retains exact commands/PIDs/logs,
SDK build record, template/engine/source/native fences and actual binary loader
metadata. PASS qualifies a completed inspected export only. Root's separate
exported Host/Client runner must execute the recorded binary directly, with no
`--path` or ODIN_SCRIPTS_DLL override, and prove the unchanged full-five/control/
natural-cleanup/one-Native sample contract. Gate C and runtime PASS are not inferred
from this harness's export exit status.

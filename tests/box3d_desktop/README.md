This is one on-target desktop orchestration CLI. It reuses the completed Gate C
normal exporters and unchanged exported-pair controller; it is not a packer,
toolchain installer, VM launcher or replacement test definition. Earlier Gate C
reports and task VM t9y are untouched.

Plan first, with explicitly selected installed inputs and a NEW output outside
the checkout. Planning performs no processes and can describe unavailable tools:

```sh
python3 -B tests/box3d_desktop/run.py \
  --target macos-arm64 --framework kit \
  --godot /Applications/Godot.app/Contents/MacOS/Godot --odin /absolute/bin/odin \
  --native-library /verified/Release/libogb3.dylib --native-sha256 EXACT64HEX \
  --out /new/scratch/mac-kit-plan --port 45300 --ticks 120
```

Use a separate fresh output and append `--execute` for actual normal SDK build,
Godot import/export and the existing Host/Client proof. Use framework `replay`
for its distinct case. `plan.json` lists exact commands. `report.json` is written
only for execution, binds helper records/hashes and tool/Native inputs, and can
PASS only after the exact selected target/framework/mode export and unchanged
runtime helper pass. Source/bundle/actual-input fences remain required. No plan,
cached archive or export-only result qualifies as a runtime PASS.

Linux must run INSIDE the selected Linux x86_64 userspace. Supply explicit
`--execution-mode native` or `translated-linux-x86_64`, plus
`--toolchain-report /absolute/preflight/report.json`. The existing Gate C Linux
pipeline defaults to its historical translated mode, while this new CLI requires
an explicit Linux choice. The preflight must actually be PASS, with
`elf.odin`/`elf.godot` machine62/class64/little-endian SHA256 matching the current
explicit tools. A translated report must state `native_x86_hardware:false` and
translated execution. Native mode instead needs `execution_mode:"native"`,
`native_x86_hardware:true` and actual `kernel_uname` Linux/x86_64 observations.
An operator-provisioned native preflight must come from real installed-tool/ELF/
version/dependency checks equivalent to the Gate C toolchain preflight, not a
handwritten PASS. A translated report cannot qualify native hardware. No
performance or cross-target deterministic equality claim is made by either mode.

The macOS helper uses the verified official4.7.1 universal launcher; SDK Core,
scripts/modules and Native stay ARM64, with native ARM64 selected execution.
Linux preserves the official x86_64 launcher and exact verified shared `.so`.
The CLI takes an explicit verified Native Release input; it does not rebuild or
silently replace it. Normal SDK preparation validates its producer/source/API/
target metadata. Existing full5/control/ACK/one-image/cleanup checks are unchanged.

Pure checks (synthetic plans, metadata and tiny cache TARs only):

```sh
python3 -B -m unittest discover -s tests/box3d_desktop -p '*_test.py' -v
```

The existing Native workflow now triggers all registered12 test source roots,
uses q's verified archive-only `build/box3d_ci.py`, and always runs the ordinary
Native configure/build/tests. `actions/cache` stores ONLY
`box3d-source-archives/sha256/<archiveSHA>/{box3d.tar,identity.json}`. Exact content
key, commit/tree/URL and checksums are checked on restore; corrupt/wrong-pin cache
errors fail instead of being overwritten. MISS allows the normal driver to fetch
and verify its pinned input; only a verified archive is stored afterward. No
objects, DSOs, Native manifests or test verdicts are cached.

`box3d-desktop.yml` is manual `workflow_dispatch`, with four distinct cases. It
requires explicitly provisioned self-hosted labels:

- macOS: `self-hosted, macOS, ARM64, box3d-desktop`;
- Linux: `self-hosted, Linux, X64, box3d-desktop`.

Repository variables `BOX3D_MACOS_ODIN`, `BOX3D_MACOS_GODOT`,
`BOX3D_LINUX_ODIN`, `BOX3D_LINUX_GODOT` are absolute executable paths. Matching
official Godot4.7.1/a13da4feb export templates, Python3.9+, Clang/CMake and target
inspection/signing tools must already be installed. Linux additionally requires
`BOX3D_LINUX_TOOLCHAIN_REPORT`, the actual native preflight bound as described
above; the old translated Gate C preflight is deliberately rejected for that job.
The desktop job rebuilds/tests Native Release before passing its actual library
and SHA to this same CLI. Runtime jobs must be isolated from other use of their
selected loopback ports. Checkout/upload actions retain existing pinned commits.

These workflows are checked-in configuration, UNEXECUTED remotely in this local
implementation session. No GitHub push/job, Windows qualification, native-x86
performance or expanded platform support is inferred. Root records actual local
new-orchestrator executions separately and owns the card's final classification.

# Gate C Linux x86_64 lane

Root grants execution after reading this source checkpoint. The host VM is
Linux aarch64; its enabled `/proc/sys/fs/binfmt_misc/rosetta` entry executes
ELF machine62 userspace. The selected cached Debian image is actually amd64.
This is **translated functional execution**, not native x86 hardware, performance
certification or a cross-target determinism comparison. No cross-compile-only
result substitutes for the actual Native tests and exported Host/Client runs.

The new image/container and scratch/output paths are task-owned. User database
containers, images and volumes remain unchanged. The two idle goal containers
were stopped and restored for the recorded VM memory change.
The shared repo and pinned dependency tar mount read-only; `pipeline.py` copies
source into a new isolated work directory before any compilation/generation.
Native source/driver/12-test fences are distinct from Root's disjoint SDK/export
source work. SDK/export phases snapshot and fence their full copied source.

`toolchain.py` verifies official release bytes for Odin dev-2026-04 and
Godot4.7.1/a13da4feb, installs the matching Linux export templates, checks actual
ELF machine62 for Python/compiler/editor/templates, and records versions, SHA256,
linker dependencies and actual argv. LLVM/clang/CMake/Python package versions
are observed from the new Debian image. Downloads, partials and failures remain
in isolated scratch. No toolchain PASS exists before those actual commands run.

`pipeline.py native` invokes the unchanged `build/build_box3d.sh` sequentially
for Debug and Release, with clang, two jobs and the same source pins/assertion/FP
policy. Each must execute the exact registered12-test matrix. It records actual
manifests/domain identity and ELF ABI; it stops at the first concrete failure.
It does not edit Native, SDK, caps, pins or assertions. The first CTest execution
was cancelled with incomplete supervision. `direct_tests.py` instead queries
the real CTest registration and executes all 12 exact commands with preserved
properties, dependency order, file logs and direct waits. Its source/binary
fences and actual exits are checked by the SDK profile's explicit direct-test
evidence format; it never labels this an actual CTest run. Debug and Release
both passed, including revalidation after the VM memory change.

Only after Root accepts Native/toolchain results does `pipeline.py export`
prepare the normal authored sample, run the standard SDK build, actual official
Godot import and `--export-release "Linux x86_64"`. Its per-framework
`export-record.json` uses Root's contract: actual bundle/executable, export argv,
Native identity reference, complete artifact hashes and source fence. This
record is export/file-inspection proof, not runtime PASS. It requires the shared
Native `.so` to be present unchanged through the normal exporter; it never
manually packs a PCK or copies missing deployment files to conceal a failure.
Import/export error and leak logs fail even when Godot exits0. The successful
export environment used export-only `SCRIPT_BUILD_FLAGS=-thread-count:1` and
the unchanged default `-o:speed`, with a 6144 MiB VM and 4096 MiB task-container
limit. Earlier 1536 MiB attempts and their OOM counters remain preserved.

Root's `tests/box3d_gate_c/run_exported.py` then runs the actual exported binary
as separate Host and Client, with `--headless` and no `--path` or scripts-DLL
override. Reuse its unchanged target120/full5/actual-controls/ACK/natural-exit/
intake/Native-image/cleanup checks. Kit and Replay receive separate records and
runtime outputs. Root owns final classification.

Both exported pairs passed. See [the Gate C report](../report.json) for exact
artifacts, target scopes, raw logs, five-part comparison, controls and cleanup.

The exact proposed image/create/start/toolchain/Native argv are saved in the
task scratch `command-plan-v1.json` and sent for Root's explicit command grant.
There is no automatic SDK/export/runtime phase or retry after a failure.

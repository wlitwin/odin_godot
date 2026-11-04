# Optional Box3D SDK runtime

Current desktop deployment/export scope is recorded in
[desktop-compatibility.md](desktop-compatibility.md) and the actual four-case
[Gate C report](../../../tests/box3d_gate_c/report.json). Native macOS ARM64 and
translated Linux x86_64 are separate functional records; neither certifies native
x86 hardware CI, Windows, web/mobile or mixed-target deterministic equality.
P4.1's earlier ownership matrix and [network-validation.md](network-validation.md)
remain historical evidence for their exact artifacts.

## Shared native image

Build the native backend with `build/build_box3d.sh`. Set
`BOX3D_NATIVE_LIBRARY` to the verified build's shared `libogb3.dylib` or
`libogb3.so` when invoking `build/build_scripts.sh`.

The SDK verifies the adjacent build manifest, archive and native domain identity,
then copies one backend beside the core. Gameplay modules import that shared
image. macOS uses `@rpath/libogb3.dylib`, an ad hoc signature for the deployment
copy, and loader-relative search paths. Linux uses `libogb3.so` and `$ORIGIN`.
Installed addons can place the core outside the consumer's scripts folder;
consumer search paths also name that controlled relative core directory.
Export builds place the backend beside the exported core and script modules.

The deployed image is reused without rewriting it when its build and target
identity match. A changed native build requires stopping Godot and explicitly
setting `BOX3D_REPLACE_RUNTIME=1`. Script reload is supported; changing the
native backend while it owns worlds or snapshots is not a script reload.

SDK script builds require a domain handshake, including when a script
accidentally imports a static backend. An opted-in core additionally verifies
the module's native domain cookie and compiled expected build/target identities.
Compiler digest arguments use `sha256:<hex>` to avoid Odin interpreting a digest
starting with `9e41` as a number. A consumer defining raw `ogb3_*` C symbols is
rejected before the build publishes that module. An opted-in Core also inspects
the candidate binary before loading it, on initial load and reload. Embedded
`ogb3_*` definitions and alternate native dependencies are rejected before module
initializers execute. This protects the process even when a manually compiled
module bypasses the build helper. The existing ABI, domain-cookie and expected
identity handshake still runs before boot. Standalone archive tests keep
their explicit static configuration; ordinary native-free SDK builds do not
load the backend.

This opted-in desktop profile has a closed direct dependency list: the canonical
backend plus Cocoa/libSystem on macOS, or libm/libc/the platform loader on the
tested Linux target. Other direct native dependencies require an explicit
admission extension and are currently rejected. A renamed backend cannot
bypass admission by also importing the canonical one. This restriction applies
to the opted-in Core; ordinary native-free Core behavior is unchanged. Binary
inspection is a deployment check for cooperating SDK builds, not a sandbox for
arbitrary native code.

## Producer and context ownership

The pure `box3d/godot` protocol carries fixed C-shaped owner and capsule records.
Importing those records does not load native physics. Typed Kit/Replay ownership
operations require their originating realm and an active Core execution scope.
Foreign modules use origin capsules or canonical conversion; they cannot cast
another producer's checkpoint, allocator, slices or type metadata.

Core's existing script-generation references and reload gate keep producer code
resident. An origin capsule invokes the entire operation under stable Core code,
including allocator cleanup and return from the producer. Dropping only an image
reference or leaving a gate in a producer-local wrapper is insufficient.

`ODIN_RELOAD_GENERATION_LOADER_RELEASED` means the SDK removed its generation
bookkeeping and successfully released the platform loader reference. It does not
assert physical unmapping. macOS can retain Odin script images containing TLS,
and their dependencies, after a successful `dlclose`; Apple's
[dyld implementation](https://github.com/apple-oss-distributions/dyld/blob/main/common/MachOAnalyzer.cpp#L2677-L2700)
marks TLS images as never unloadable. Independent plain-C TLS/no-TLS controls
reproduce this behavior. Code and data leases remain necessary to prevent calls
through dead ownership even on a loader that retains executable pages. Script
TLS and the existing threaded callback contract are preserved. Before-load
admission prevents a rejected script from mapping another native backend; the
one-native-image check is separate from script mapping retention. Repeated reload
memory and platform loader limits remain part of the later soak/deployment work.

Code residency and data ownership are separate. A nonnull borrowed allocator or
callback user is rejected unless its actual context is explicitly retained.
Weak instance contexts prevent execution after source destruction; independent
retained contexts allow the documented detached operations. The SDK Meter tracks
actual allocations and cumulative successful requests, including later freed or
resized work. An allocation block lease retains a specific block and an explicitly
declared user alias; allocation membership alone does not retain that block.

The native ledger sums requested engine and snapshot bytes once, plus all
producer host live bytes and remaining reservations. One producer publishes its
aggregate atomically. Nested covered operations share a promise; cumulative
requests consume it, rather than net live growth. Cross-producer nested allocation
budgets return Unsupported; cached cross-producer reads remain available. A
legacy native codec's explicit staging reserve is counted once. RSS, allocator
headers, static storage and engine runtime overhead are reported separately.

## First editor import

The unmodified tested Godot 4.7.1 can crash after discovering an extension during
an initially unprepared headless import. The observed null documentation state
matches upstream [issue 111645](https://github.com/godotengine/godot/issues/111645)
and [issue 111048](https://github.com/godotengine/godot/issues/111048). The proposed
[upstream fix](https://github.com/godotengine/godot/pull/123658) was open when checked.

An opted-in SDK build prepares `.godot/extension_list.cfg` before the editor's
first startup. It preserves existing entries, discovers visible project extension
manifests and respects `.gdignore` directories. This declarative startup preload
avoids the late-discovery path without creating a documentation cache or modifying
the engine. Tests retain the unprepared failing control separately from the
prepared first-import success. Neither a warm-cache run nor this preparation is
reported as an upstream engine fix.

## Historical P4.1 runtime evidence (retained)

The final actual Godot matrix passes on macOS arm64 and Linux x86-64, each with
Debug and Release native builds: 144 successful build/run/control steps and 80
Godot process lifetimes, all bound to the same 513 source hashes. Linux uses
Podman/Rosetta and does not certify native Linux throughput. The report and
compressed raw logs are in [report.json](../../../tests/box3d_modules/report.json).

The matrix covers shared-world access across two producers, a native-free module
in the opted-in Core, the fully native-free default, box/sphere/capsule shapes,
sensor events and restored pending ends, AABB/ray queries and a motorized hinge.
Kit and Replay each pass actual source destruction, detached checkpoint
clone/read, and producer reload while another module retains the checkpoint.
Replay's native-only restore test explicitly does not restore game side-state.
Static, duplicate and renamed backend candidates are rejected before their
initializers execute, on initial load and live reload. Rejected replacements
preserve the old live world and checkpoint. Wrong script build identities and
wrong Core build/target identities reject before publication.

Separate frozen helper matrices cover retained allocator/user/FX/codec
contexts, detached archives and transfer buffers. Actual two-module global quota
checks reach exactly 64 MiB, reject an additional byte and a new capture without
changing either world, and resume after another producer releases its bytes.
The strict Kit 32-body/H128/eight-tick helper profile records live bytes,
remaining reservations and admitted totals separately; its local correction
timing does not include full network import. These were P4.1-specific results: Session integration, whole-call CPU, playable
presentation and exports were still later work at that time. They are not
retrospectively relabelled as the newer suites.

## Current completed gates and deployment limits

Required Session ownership forwarding now exists and still rejects missing
metadata. [Gate B](../../../tests/box3d_soak/gate-b-report.json) records an actual
bounded macOS reference pass, including declared whole-call4ms samples; the older
Dense8.894ms failure remains failed/causeUNKNOWN. That CPU scope is not a claim
for every later Native feature build or workload. [Authoring](../../../tests/box3d_authoring/report.json),
[motion](../../../tests/box3d_motion/report.json), [editor](../../../tests/box3d_editor/report.json)
and [samples](../../../tests/box3d_samples/report.json) retain separate source and
runtime records. [Gate C](../../../tests/box3d_gate_c/report.json) binds actual
Kit+Replay exported pairs on macOS and translated Linux, complete5/finalACK,
nonzero remote inputs, one Native image and observed cleanup. No headless result
claims manual pixels or whole-goal completion.

The official macOS launcher is universal; SDK/Native consumers and tested
execution are ARM64. Actual consumer Mach-O inspection records minos14.0/SDK14.4,
although the launcher plist says11.0; the whole bundle is not qualified on11..13.
Use the actual export architecture/rpath/domain/hash inspection, not a preset
label. Source library hashes and ad-hoc-signed deployment hashes may differ and
must be bound explicitly. Linux keeps the normal `$ORIGIN` deployment and actual
ELF x86_64 files; current runs used Rosetta in a Linux aarch64 VM.

Retain exact module runtime-copy paths/PIDs/hashes and only the observed known
stale-copy sweep; do not normalize PIDs or waive source fences. CI configuration
without a job record is unexecuted CI. Backend replacement and saved-state/content
migration follow [upgrade.md](upgrade.md); new release/soak/security/platform work
remains independently scoped.

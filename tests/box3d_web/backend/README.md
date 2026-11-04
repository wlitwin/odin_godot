# Complete Box3D WebAssembly backend

The engine and local snapshot/recovery layer compile to one PIC wasm32 archive.
The existing native driver accepts explicit web configurations:

```sh
nix develop --command bash build/build_box3d.sh WebSIMD /absolute/new-cache
# Alternate, separately identified scalar implementation:
nix develop --command bash build/build_box3d.sh WebScalar /absolute/new-cache
```

The printed archive and adjacent manifest are content-keyed by verified source,
compiler and target flags. Source preparation is shared with the native builder;
exact archive/inventory/patch/preimage checks remain active. Builds retain strict
FP, assertions, validation and the four-wide simulation profile. `-pthread`
provides the shared-memory-compatible ABI; simulation still has one caller.
Archives contain no diagnostic observer or test hooks by default. A builder
receipt says `ARCHIVE_BUILT_TESTS_NOT_RUN`; it is not a runtime verdict.

Run the existing C guarantees as actual Wasm programs under installed Node:

```sh
nix develop --command python3 -B tests/box3d_web/backend/run.py \
  --variant WebSIMD --cache /absolute/cache --out /absolute/new-output --execute
```

Without `--execute`, this runner writes only a plan. Its instrumented archive
supports the unchanged failure/mutation corpus. Eight C groups cover the public
API/domain, changed solver fields, canonical/malformed recovery, snapshot
lifecycle, geometry authoring and all motion families. An independent Python
reader checks the actual produced canonical bytes. Desktop shared-DSO/dlopen
tests remain separate; one AOT domain across Core/scripts belongs to W2.

The production control compiles a second archive with no test hooks and runs
the same program in Node and actual Chrome:

```sh
nix develop --command python3 -B tests/box3d_web/backend/production.py \
  --cache /absolute/cache --out /absolute/new-output
```

It uses the installed Chrome/Puppeteer from `tests/web`, a fresh browser profile
and an owned localhost server with COOP/COEP. Both scalar and SIMD programs test
wasm32 layout, malformed-load preservation, canonical reencoding, source-free
restoration/continuation and zero live Native/wrapper allocation. All256 samples
per variant are retained. The timed composite includes input impulse when due,
fixed step, history release/capture and public world admission for21 bodies.
This is C-backend CPU work in headless Chrome, not the Odin adapter, rendering,
networking or a final browser budget result. No relaxed SIMD or mixed-target
snapshot admission is enabled.

The selected initial web profile is SIMD. Scalar remains an explicitly different
build/target; it is not an automatically interchangeable peer. The initial
comparison retains SIMD's larger maximum sample as well as its lower median.
Actual browser multiplayer/full-five-part compatibility and final game costs
are later milestones. See [report.json](report.json) and the declared
[execution contract](../contract.json).

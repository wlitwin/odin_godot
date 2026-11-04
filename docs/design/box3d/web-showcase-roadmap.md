# Box3D Web and Replay Showcase Roadmap

Prepare a new implementation goal that makes the shared Box3D backend usable in
Odin Godot web exports and delivers **Dockyard Duo**, a playable two-player
Replay physics heist. Preserve the current native integrations and give Kit a
small web compatibility case over the same backend. The user selected cooperative
physics heist gameplay and permits a Box3D fork or focused patches when useful.
See the [game proposal](replay-showcase-game.md).

The implementation goal is active. W0 has promoted the October engine baseline
with [bounded native evidence](../../../tests/box3d_upgrade/report.json); earlier
desktop qualifications remain build-specific. S0 fixes the first execution
contract below. The [earlier web evaluation](web-mobile-evaluation.md) records
what was known before this goal, rather than a current browser-physics result.

## Selected execution contract (S0)

The machine-readable [v1 contract](../../../tests/box3d_web/contract.json) is
**declared, not qualified**. The reference is the current Apple M3 Mac15,13 with
24 GiB RAM, a 1280×720 foreground view and device scale1. Actual browser/tool/GPU
versions and timer resolution must be recorded at qualification. Installed
Chrome156 and Firefox158 are the initial required browser matrix. Safari27 is
an explicit evaluation target; actual Safari results are required for admission.
An automated WebKit build is not silently reported as Safari.

Normal whole-entry work targets p95≤4 ms, p99≤6 ms and max≤10 ms over at least
1,000 samples. Eight-tick correction targets p95≤16 ms and max≤25 ms over at
least128 real corrections. Presentation frame intervals target p95≤20 ms and
p99≤33.4 ms on the reference foreground GPU path. Headless/software-WebGL runs
prove functionality rather than those rendering budgets. Retain cold, error and
outlier samples; report timer resolution and operation boundaries, without
subtracting phases. A cold local load targets≤20 s and the compressed initial
download≤25 MiB. Linear Wasm memory is bounded at512 MiB; the actual backend
admission limit remains64 MiB. Process RSS is a separate diagnostic.

Keep60 Hz/four substeps/one simulation worker and one same-build browser cohort.
Compare scalar and upstream-supported Wasm SIMD once at W1; identify the selected
build. Link the backend once into the existing AOT extension, expose the actual
service/domain to Core and scripts, and preserve code/data/allocator/resource
checks. The extension-enabled Godot build still needs HTTPS and cross-origin
isolation headers; single-worker simulation does not remove them.

The game starts within35 bodies/shapes,32 initial dynamics,eight geometries and
one joint, targeting roughly24 bodies. Native canonical bytes stay≤512 KiB and
complete transfer≤1 MiB. A final600-second foreground pair and fixed recovery/
network/game cases qualify the frozen candidate. We do not repeat a long gate
for each UI or authoring edit. Previous native timing/long reports do not qualify
this different build or browser profile.

Use existing Party/Room/WebRTC for two browsers. Host loss produces a truthful
round-ended/rehost flow, without claiming seamless physics authority migration.
Reconnect, late observer and >H128 canonical recovery are included. Ship a
reproducible deployment package and serving guide by default. Demonstrate real
direct/relay connectivity before claiming Internet multiplayer; a live public
URL, new credentials or paid infrastructure is a separate concrete deployment
choice. Native and browser cohorts remain separate until cross-target state
compatibility is independently proved. Fork policy stays a small pinned patch
series first, with regression, ownership and version evidence.

## Refresh the engine before extending it

At goal planning on November 2, 2026, our manifest pinned
[`d421e45c`](https://github.com/erincatto/box3d/commit/d421e45c828f6f853a145f726f0b9425d31146eb)
from July 13. The checked upstream HEAD was
[`33626332`](https://github.com/erincatto/box3d/commit/336263320469e5e9febfe18697ab562488f7e97a)
from October 28, 30 commits ahead. The
[comparison](https://github.com/erincatto/box3d/compare/d421e45c828f6f853a145f726f0b9425d31146eb...336263320469e5e9febfe18697ab562488f7e97a)
includes solver/SIMD work, recording and serialization fixes, CMake changes and a
dynamic mover. The [freshness record](web-showcase-upstream.json) freezes that
comparison; recheck upstream when the implementation goal begins.

Evaluate the October candidate in a separate source/build cache first. Audit its
private snapshot/solver layouts against our complete-state walker and recovery
codec. Recheck each of our three engine patches: allocator alignment, compound
geometry alignment and broadphase rebuilding. Retain a regression when dropping
a patch that upstream has made unnecessary. Do not blindly apply old hunks.

Promote the candidate after the affected Native snapshot/canonical/ownership
tests and short Kit/Replay regressions pass. Give changed build, target and
schema contracts their correct identities; old images must not be silently
interpreted as new state. Keep the validated July artifacts and runnable demos
as the comparison baseline. An upstream feature claim does not transfer our
snapshot qualification to the new private ABI.

## The starting point

Box3D itself already documents Emscripten builds at
[our pinned revision](https://github.com/erincatto/box3d/blob/d421e45c828f6f853a145f726f0b9425d31146eb/README.md#building-for-web).
Its CMake supports a WebAssembly SIMD route and scalar selection. The current
gap is our complete snapshot/recovery layer and its integration into the
Odin/Godot build, service and export path, rather than evidence that the engine
needs a wholesale rewrite.

The previous evaluation established wasm32 public-header layout, Kit/Replay
physics type checking and native-free protocol vectors. It did **not** execute
our complete Box3D backend in a browser. In particular, the pointer-bearing
asset descriptor is 64 bytes/alignment 4 on wasm32, versus 72/alignment 8 in the
tested 64-bit builds. Use actual C/Odin layout and calling checks throughout.

Reuse existing assets and APIs:

- `build/build_web.sh` already combines SDK Core, scripts and modules into one
  AOT Emscripten extension module.
- `box3d/native/` owns the C boundary, snapshots and canonical recovery.
- `replay/physics`, `replay/net` and `replay/godot` already own complete-state
  transactions and multiplayer. They must continue to do so.
- Replay Scrapyard's [Party menu](../../../examples/replay_scrapyard/online.md),
  [browser flow](../../../examples/replay_scrapyard/browser.md) and existing
  [ICE/TURN integration](../../../replay/godot/transport/ice-deployment.md) are
  references for rooms, invitations and connectivity. Reuse the shared helpers
  while keeping the new game independent of Scrapyard's combat and progression.

## Proposed web architecture

Prefer linking the selected Box3D C archive and our shim **once into the existing
Odin/Godot AOT web extension**. Core and all gameplay modules use that backend's
actual service/domain. Each game instance has its own world and memory domain;
different browsers do not share raw pointers or handles.

Emscripten supports linking archives into a module. Its dynamic-linking design
also requires compatible memory/table and runtime imports, so verify the exact
Godot template, Emscripten and Odin tuple instead of imitating desktop `dlopen`.
[Emscripten linking documentation](https://emscripten.org/docs/compiling/Dynamic-Linking.html)

Add a web service binding for the actual statically linked backend, with explicit
allocator, code/data ownership and shutdown semantics. AOT code can have a
non-unloadable lifetime; it still needs real domain and resource checks. Do not
disable ownership validation to get a green startup. Exercise C-to-Odin callbacks
and cleanup as well as direct calls. Keep u64 IDs/ticks out of JavaScript Number
conversions; use direct Wasm calls or exact byte/string representations.

Start with one simulation worker. Make one bounded scalar versus upstream
supported SIMD comparison, then select and identify one supported profile.
Preserve strict FP settings and avoid relaxed SIMD until separately justified.
Do not import native CPU feature dispatch into a browser compatibility promise.
[Emscripten SIMD guidance](https://emscripten.org/docs/porting/simd.html)

Use Godot's Compatibility renderer. The current extension export path needs Web
Extension Support and appropriate cross-origin isolation headers even when the
simulation uses one worker. Validate HTTPS, module loading, MIME types, headers
and asset fetches from the actual deployment.
[Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

If this composition cannot satisfy the required memory/callback ABI, compare one
separate shared backend module and a custom engine-template route before adding
more loader workarounds. Record the chosen design and its tradeoffs. A custom
Godot template or Godot fork is not the default starting requirement.

## Multiplayer and compatibility

Use Replay's current server-authoritative model with a browser hosting the first
cooperative cohort and other browsers joining through existing WebRTC/Party
facilities. The same shipped Wasm artifact removes an unnecessary native/web
compatibility variable; it does not by itself prove browser-to-browser equality.
Check complete state on actual Chromium, Firefox and Safari participants before
admitting a browser to the supported matrix.

Keep native development builds of the game. Do not promise native host/browser
client cross-play while canonical images deliberately reject different target
identities. A native authority would require a tested compatible state-transfer
contract or execution of the same qualified Wasm simulation; simply relaxing
the identity check is not a solution.

Give background tabs, visibility loss, rejoin and host disappearance explicit
behavior. Reuse complete Welcome/resync and the existing action/outcome model.
Do not equate a sent packet or local frame with an authority ACK. If authority
migration is included, prove complete solver/asset/owner transfer through Room;
value-only Scrapyard handoff evidence is not automatically physics evidence.

## Milestones and visible deliverables

The web and game tracks can progress together. The native carrying prototype
should become playable before all browser networking and release work finishes.

| Card | Work | Concrete completion | Dependencies |
| --- | --- | --- | --- |
| W0 | Select the fresh engine baseline | Candidate comparison, reviewed patch set, full-state Native/ownership results and explicit compatibility decision | Existing desktop baseline |
| S0 | Freeze the first game and web contract | One-arena/two-player scope, reference machines/browsers, hosting choice and pre-qualification performance budgets | This proposal |
| W1 | Build the complete web backend | Real C engine plus snapshot/recovery shim runs under Wasm; capture/restore/continuation, malformed-load preservation and cleanup work | W0, S0 |
| G1 | Make the native heist fun | Two distinct robots, one awkward cargo puzzle, magnets and a meaningful shared objective; human play feedback | S0; prototype may use preserved native baseline |
| W2 | Integrate the backend into a Godot web export | One actual backend/domain across Core and scripts, verified C/Odin layout/callbacks/lifetimes, a visible authored physics scene | W1 |
| W3 | Connect Replay across real browsers | Separate player controls, prediction/correction, direct full-five-part comparisons and real canonical recovery | W2 |
| G2 | Complete a small game | Timed jobs, cargo scoring, hazards, recovery, retry and native/web shared model/content | G1, W0; finish web behavior with W3 |
| N1 | Make joining work for friends | Existing Party/Room invitations, HTTPS/WSS, measured direct and relay-only connectivity on the intended deployment | W3, G2 |
| R1 | Finish recovery and spectators | Returning teammate, late observer, background-tab gaps and the selected host-loss policy preserve complete state and eligible effects | N1 |
| P1 | Polish the showcase | Readable art/camera, sound, onboarding, settings, results and optional truthful developer overlay | G2; can overlap N1/R1 |
| Q1 | Qualify the chosen browser game profile | Actual browser matrix, full-state/resource checks, declared frame/correction budgets, retained raw samples and targeted native/Kit regressions | W2/W3, G2, N1, R1, P1 |
| D1 | Package the public example | Reproducible build/export, code/authoring guide, notices/patch provenance and a reviewed deployment package or approved live URL | Q1 |

Set budgets before qualification. Target 60 Hz simulation and smooth 60 FPS
presentation on named reference hardware, with a measured allocation of frame
time to normal work, correction and rendering. The old native 4 ms corpus is
neither a web claim nor a reason to choose new web thresholds after a failure.
Measure cold loading, Wasm/browser memory, snapshot size and actual whole-entry
cost early enough to choose content and architecture sensibly.

Keep the initial game inside its selected body/geometry/joint profile. If it
needs a different profile, make that an explicit measured contract change while
preserving the previous profile's tests. Browser timer resolution and foreground
state belong beside timing data; a Node result is not browser frame performance.

## Patches and fork policy

Begin with the selected upstream commit plus a recorded patch series. The July baseline used three tracked engine patches. W0 retired them after
upstream fixes/redesign and retained their regressions. The current
[dependency.json](../../../box3d/dependency.json) records the exact engine and
tracked shim adaptation.
The user permits a fork if it makes this integration easier; do not treat the
current pin or private snapshot implementation as untouchable.

Prefer local build/bridge changes for platform selection, linking and service
installation. Engine patch candidates are demonstrated alignment/wasm issues,
small platform/build hooks, or cleaner snapshot/allocator/geometry interfaces.
Put generic engine changes in focused commits/patches with their regressions;
keep Godot, networking and game rules outside Box3D.

Use a maintained fork when several useful generic changes need to move together
or a stable snapshot interface substantially reduces private-layout coupling.
Record the base, patch ownership, rebasing process, ABI changes and merge policy.
Do not maintain two independent physics implementations for native and web.
Upstream submissions can follow the project's contribution process separately;
external review need not block our integration. No remote fork or upstream
message is created by this planning work.

## Validation without an endless gate loop

- Prove each new boundary with the smallest real case first: backend execution,
  then the Godot module, then one pair, then game/recovery and deployment.
- A type check, header compile, native-free vector or screenshot cannot close a
  complete-physics runtime milestone. Use all five canonical parts where the
  adapter promises a complete frame.
- Run the shared backend corpus once per frozen candidate; do not duplicate it
  for every UI feature or for both sibling adapters. Retest affected boundaries
  after changes and reserve the final game soak for the final candidate.
- Keep a fixed final browser checklist: clean game round, impaired transport,
  interrupted rejoin/resync, spectator, selected host-loss behavior and a bounded
  sustained session. Exercise actual browser processes; public reachability
  needs evidence beyond localhost.
- Preserve error attempts, outliers and failed reports. An unchanged failure is
  not a reason for an automatic retry. Repeated narrow fixes trigger a focused
  comparison of simpler architectures, as [AGENTS.md](../../../AGENTS.md) requires.
- Use manual two-person play feedback for fun and usability. Automated state
  checks and UI screenshots cannot supply that judgment.

## Scope of the next goal

The next implementation goal should use this objective:

> Deliver a reusable, explicitly qualified Box3D web backend in Odin Godot and
> a polished two-player Replay cooperative physics heist, Dockyard Duo, with
> native development and browser play from the same game model/content. Refresh
> the engine baseline first, allow focused engine patches or a maintained fork,
> preserve existing native Kit/Replay behavior, and demonstrate real browser
> multiplayer, complete-state recovery, ownership and measured game performance.

The game direction is selected; final branding and hosting are still choices.
Mobile native ports, broad cross-target physics compatibility, four-player play
and a general sandbox are outside this first goal. Public publication requires
a concrete hosting/configuration decision; planning does not deploy a service.

The [associated task board](web-showcase-board.json), **Replay Box3D Web
Showcase**, contains 12 queued cards and is paused. Starting implementation should
resume that board and create the goal explicitly; no implementation worker or
long-running goal is started by this roadmap preparation.

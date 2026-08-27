# Odin/Godot integration follow-up

This backlog turns the integration review into verifiable work. Items are ordered by
correctness risk first, then developer ergonomics and build/runtime efficiency.

Status: `[ ]` pending, `[~]` in progress, `[x]` complete.

## P0 — reload and runtime safety

- [x] Validate every scripts DLL before executing its boot function.
  - Initial load and hot reload use the same required-symbol, ABI, and Odin compiler checks.
  - A rejected DLL is unloaded and its temporary reload copy is removed.
  - ABI and compiler mismatches produce actionable editor errors.
- [ ] Define and enforce the instance/reload threading contract.
  - Either all instance create/free/rebind operations are main-thread-only, or the live
    instance registry pins each entry while a reload snapshot is in use.
  - Script lookup/cache access follows the same synchronization rule.
  - Add a stress test covering reload during instance churn before unloading old DLLs.
- [~] Replace the fixed 256-class registry, or make the bound a generated/build-time limit.
  - Until the fixed bound is removed, overflow must fail loudly and never silently omit a
    class from the manifest.

## P1 — reload correctness and lifecycle

- [x] Reconcile `_process` and `_physics_process` after a class descriptor is rebound.
  - Adding either callback enables the corresponding Godot notification on live nodes.
  - Removing either callback disables it.
- [x] Make source fingerprints deterministic and path-aware.
  - Directory entries are sorted before hashing.
  - Relative paths as well as file contents participate in the hash, so moves/renames are
    detected even when bytes are unchanged.
- [ ] Make script identity path-based instead of depending on unique class/base inference.
  - Generate a manifest entry for every authored source path.
  - Keep `//gd:class` genuinely optional, including two scripts with the same base type.
  - Report duplicate explicit class names with both source paths.
- [x] Complete extension shutdown cleanup.
  - Unregister saver, loader, and language services in reverse registration order.
  - Release their owned objects and dynamic metadata without leaving baseline ObjectDB
    leaks in the headless integration test.
- [x] Make create/delete coalescing transactional.
  - A source deleted while an earlier build is running cannot compile stale generated code.
  - The regression test asserts successful final generation and swap, not only file removal.

## P2 — efficiency and ergonomics

- [x] Cache the `scriptgen` tool between builds.
  - Cache keys include the exact Odin compiler, scriptgen sources, and generator dependencies.
  - Unix and PowerShell build paths share the same invalidation behavior.
- [ ] Move source scanning/hashing off the editor main thread.
  - Save handling only queues dirty paths/modules; filesystem reads and hashing run on the
    existing build worker.
  - Bursts remain coalesced and a completed build is never labeled with a newer fingerprint.
- [ ] Bound native DLL generations retained by hot reload.
  - Do not unload a generation while proc pointers or instances can still reference it.
  - Once generation ownership is explicit, unload retired generations; until then, surface a
    restart recommendation after a configurable count/byte estimate.
- [ ] Avoid recompiling unaffected modules.
  - Map changed paths to module roots without walking and hashing every module on each save.
  - Keep a periodic full reconciliation for external filesystem changes and deletions.
- [ ] Reduce toolchain coupling at the native boundary.
  - Audit ABI-visible types and allocator ownership, document the exact compiler constraint,
    and evaluate a narrower C ABI so compatible scripts do not require compiler lockstep.

## Verification gates

- [x] Reflection/registration unit suite passes, including registry overflow coverage.
- [x] Phase 4 lifecycle/reload suite passes with no integration-owned shutdown leaks.
- [~] Reload/export verification covers every guarded transition.
  - [x] ABI rejection, lifecycle transitions, and create/delete coalescing without an
    intermediate failed build.
  - [ ] Add a doctored compiler-version rejection fixture.
- [ ] macOS/Linux and Windows build helpers have equivalent cache and cleanup semantics.

# Odin/Godot integration follow-up

This backlog turns the integration review into verifiable work. Items are ordered by
correctness risk first, then developer ergonomics and build/runtime efficiency.

Status: `[ ]` pending, `[~]` in progress, `[x]` complete.

## P0 — reload and runtime safety

- [x] Validate every scripts DLL before executing its boot function.
  - Initial load and hot reload use the same required-symbol, ABI, and Odin compiler checks.
  - A rejected DLL is unloaded and its temporary reload copy is removed.
  - ABI and compiler mismatches produce actionable editor errors.
- [x] Define and enforce the instance/reload threading contract.
  - A writer-preferring execution gate drains in-flight script callbacks before a native
    DLL is published and blocks new descriptor/cache/user access until rebind completes.
  - Reload snapshots pin each live entry; a synchronous free from a reload hook retires the
    instance immediately but defers destruction until the walk releases its pin.
  - Class-cache and ScriptInstance-vtable initialization are serialized without adding a
    lock to the steady-state method/property lookup fast paths.
  - The Phase 4 stress probe holds an old-generation call on a worker while reloading and
    destroys another instance re-entrantly from its reload hook.
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
- [x] Move source scanning/hashing off the editor main thread.
  - Save handling resolves only Godot-backed settings and queues an owned request; recursive
    source reads, module enumeration, orphan detection, fingerprints, and command assembly
    run on the serialized build worker.
  - Save bursts remain latest-request coalesced, manual force requests retain priority, and
    periodic probes cannot replace a pending real save or flicker the compiler-busy status.
  - A completed build remains paired with the hashes/modules selected by that worker job.
- [~] Bound native DLL generations retained by hot reload.
  - Do not unload a generation while proc pointers or instances can still reference it.
  - The execution gate now proves no old trampoline is on an engine callback stack at the
    swap point; remaining work is explicit ownership for removed-class instances, returned
    property metadata, and user-cached raw proc pointers.
  - A configurable retained-generation interval now surfaces the running generation count,
    approximate mapped bytes, and a restart recommendation (`0` disables the warning).
  - Once the remaining ownership is explicit, unload retired generations at the gate instead
    of relying on the operational warning.
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
  - [x] ABI rejection, lifecycle transitions, create/delete coalescing, worker-call drain,
    and a re-entrant instance free without an intermediate failed build.
  - [ ] Add a doctored compiler-version rejection fixture.
- [ ] macOS/Linux and Windows build helpers have equivalent cache and cleanup semantics.

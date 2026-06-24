# Spike R — in-process hot reload of an Odin scripts dll

Validates the architectural keystone behind "stable CORE dll + swappable SCRIPTS dll"
(PLAN.md §2) and the Phase-4 hot-reload loop.

Run (from repo root, in the nix shell):
```sh
nix develop --command examples/reload-spike/run.sh
```

## Result: ✅ `RELOAD_OK`
```
auto_init_on_dlopen=true
v1: marker=0xBEEF bump=101,102 behavior=1
v2: bump=101 behavior=2
```

## What it proves
1. **`@(init)` procs run automatically on `dlopen`** (`auto_init_on_dlopen=true`). This is the
   mechanism the codegen-preprocessor relies on: each compiled script's generated
   `@(init) register()` self-registers its `ClassDesc` into the core the moment the scripts
   dll loads — no explicit host call required. (We still export a `script_boot` fallback in
   case a future platform/target doesn't auto-run dll initializers.)
2. **In-process unload → load of a rebuilt dll works** — the host loads `script_v1`, calls in,
   `unload_library`, then loads a separately-rebuilt `script_v2` in the same process.
3. **Fresh per-load state** — `v2 bump=101` (not continuing from v1's 102), so a reload starts
   with clean globals.
4. **Rebuilt behavior is picked up** — `behavior` goes 1 → 2 across the swap.

## Notes / caveats for the real core
- The host here is itself Odin (loading an Odin dll), so two Odin runtimes coexist — the same
  shape as Godot→core(Odin dll)→scripts(Odin dll). Each dll owns its globals (good isolation).
- This validates the *dll mechanics* only. Preserving/migrating **live node state** across a
  reload is a higher-level core concern (Phase 4): re-instantiate live instances and re-apply
  their serialized property state after the swap.
- macOS `dlclose` doesn't always physically unload, but the fresh-state + new-behavior result
  confirms v2's code is what executed after the swap.
- Built with `-build-mode:dll -define:VERSION=N`; host uses `core:dynlib.initialize_symbols`.

# Spike R — in-process hot reload of an Odin scripts dll

This early experiment tested the two-library design in PLAN.md §2 and the
Phase-4 hot-reload plan: retain the core dll while replacing a scripts dll in
the same process. The results below describe library loading and fresh globals,
not migration of live Godot node state.

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

<a id="what-it-proves"></a>

## Recorded checks

1. **`@(init)` runs on `dlopen`.** The fixture records
   `auto_init_on_dlopen=true`. The Phase-4 design proposed generated
   `@(init) register()` procedures registering `ClassDesc` values during load.
   The spike also exports `script_boot` as a fallback for targets that do not
   run initializers automatically.
2. **A process can replace a loaded library.** The host loads `script_v1`,
   calls it, invokes `unload_library`, then loads a separately built `script_v2`.
3. **Globals start fresh after replacement.** `v2 bump=101` starts a new
   sequence rather than continuing from v1's 102.
4. **Calls use the rebuilt behavior.** `behavior` changes from 1 → 2.

The current native core explicitly calls `odin_scripts_boot` and reads
`odin_scripts_manifest`; the spike's registration description records the
earlier design. See the current [module guide](../../docs/modules.md).

<a id="notes--caveats-for-the-real-core"></a>

## Scope of the experiment

- An Odin host loads an Odin dll, so two Odin runtimes coexist, as in
  Godot→core(Odin dll)→scripts(Odin dll). Each dll has its own package globals.
- The fixture covers library mechanics only. Phase 4's node-state work required
  re-instantiating live script instances and reapplying their serialized
  properties after a swap.
- macOS `dlclose` may retain the old mapping. Fresh globals and changed behavior
  show that calls nevertheless executed v2 after the swap.
- Builds use `-build-mode:dll -define:VERSION=N`; the host calls
  `core:dynlib.initialize_symbols`.

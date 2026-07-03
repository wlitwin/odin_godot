# odin_godot documentation

Write Godot scripts in compiled Odin. These docs are organized as a path: **learn → build →
use → ship.**

## Start here

- **[Getting Started](getting-started.md)** — install the Nix toolchain, build the extension,
  add it to a Godot project, and write + attach your first `.odin` script (a Node that moves
  on `_process`). A real, copy-pasteable hello-world.

## Reference

- **[Authoring Guide](authoring-guide.md)** — the complete feature reference for writing Odin
  scripts:
  - the script struct convention (`owner` first field) and `//gd:` markers
    (`class` / `extends` / `tool` / `icon` / `signal`)
  - `@export` — every Variant type, hint tags (`range` / `enum` / `multiline` / `file` /
    `resource`), groups, defaults, getters/setters
  - lifecycle procs, custom methods (`@(gd_method)`), signals, `@(gd_connect)`, `@onready`
  - multiplayer RPCs (`@(gd_rpc)`)
  - custom resources, global class names, typed cross-script references, autoloads
  - the full `gd.*` ergonomic-helper catalog (a task → one-liner table)
  - editor tooling: `@tool`, `gd.is_editor()`, custom icons, EditorPlugin

## Use it day-to-day

- **[Workflow](workflow.md)** — the dev loop and editor experience:
  - building (`build/build_scripts.sh`) and the project layout it expects
  - live editing: recompile-and-reload on save, plus the manual `script.reload(true)` fallback
  - editor DX: live error squiggles (`_validate`), autocomplete (`ols`), syntax highlighting
  - debugging: `gd.print` / `gd.error`, `lldb`, reading crash backtraces
  - **the honest AOT limitations** (no in-editor breakpoints, recompile-on-save latency, …)
- **[Debugging](debugging.md)** — the deep `lldb` + crash-backtrace reference (what Workflow
  summarizes).
- **[Pure-Odin Events](events.md)** — `events.Event(T)`: typed one-to-many dispatch at
  direct-call cost for scripts in the same dll (the C#-events-vs-Godot-signals split).
  When to use it vs an engine signal vs batching, the module-boundary rule, and the
  hot-reload resubscribe pattern.
- **[Script Modules](modules.md)** — the opt-in scaling tool for large projects: split
  scripts into `res://modules/<name>/` packages, one dll each, rebuilt + hot-swapped
  independently on save. Covers the cost model (when NOT to use them), the no-cross-imports
  rule and why, cross-module communication patterns, reload/collision semantics, and export.

## Learn from the examples

- **[examples/survivors](../examples/survivors/README.md)** — the headline single-player
  example: a complete survivors-like in pure Odin, with a per-file feature map. Its co-op
  layer is retained as the **host-authoritative** variant + regression tests.
- **[examples/coop_arena](../examples/coop_arena/README.md)** — the canonical
  **peer-authoritative co-op** reference: one codebase, three modes (single-player, native
  ENet, browser WebRTC with a room-code lobby).
- `tests/showcase/` — the smallest "everything wired" pure-Odin scene (coin collector).

## Ship it

- **[Exporting](exporting.md)** — native desktop export (the `OdinExportPlugin`) and web/WASM
  export (the Emscripten SIDE_MODULE + COOP/COEP serving).
- **[Distribution](distribution.md)** — building the drop-in addon with `nix build`,
  cross-compiling the core for Linux/Windows, the consumer install workflow, and the honest
  per-platform build-vs-runtime status.
- **[Publishing](publishing.md)** — the Godot Asset Library runbook: the `release` branch
  (`build/release.sh`), the submission form values, and consumer-facing quirks.

## Design history & internals

These are *not* on the learning path — they record how the engine is built and what was
verified, for contributors:

- [PLAN.md](../PLAN.md) — the original architecture and phased delivery plan.
- [design/script-language-api.md](design/script-language-api.md) — the
  `ScriptLanguageExtension` / `ScriptExtension` / instance-vtable surface, method by method.
- [design/export-internals.md](design/export-internals.md) — how the export plugin compiles +
  bundles scripts per platform.
- [design/web-internals.md](design/web-internals.md) — the `when WEB` split, the five wasm
  blockers found and fixed, in-browser verification.
- [design/wasm-spike.md](design/wasm-spike.md) — the original Odin → Emscripten SIDE_MODULE
  proof-of-concept.
</content>

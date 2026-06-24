# odin_godot — Odin as a first-class Godot scripting language

A **Godot 4.x GDExtension** that implements the full `ScriptLanguageExtension`
API so that `.odin` files are first-class Godot scripts — attach a `.odin` file to
a Node, and its lifecycle (`_ready`, `_process`, signals, exported vars…) runs in
compiled Odin. The goal is to **fully replace GDScript**, with **native + WASM**
compilation, made reproducible with **Nix flakes**.

Modeled on the sibling project `~/data/code/ocaml/miniml_godot` (a `ScriptLanguageExtension`
that embeds the MiniML interpreter). This document is the implementation plan.

### Locked decisions (2026-06-22)
- **Godot pin:** **4.6.2 stable** (matches the installed `/Applications/Godot.app`).
  Its web build uses **emscripten 4.0.11** (per miniml's lesson) — pin that exactly.
- **Script declaration:** a **codegen preprocessor** (Godin-style) is the primary authoring
  surface — scripts use struct tags / attributes and the tool generates the registration
  boilerplate (see §3). The `@(init)` self-registration form remains the underlying
  mechanism the codegen emits into.
- **Binding layer:** **vendor** the relevant generator code from
  `dresswithpockets/odin-godot` (not a tracking fork) — our repo will diverge substantially,
  so we copy what we need and own it outright (respect its license/attribution).
- **`compatibility_minimum`:** 4.6.

---

## 1. The core insight: Odin ≠ MiniML

`miniml_godot` had it easy in one respect: MiniML ships an **interpreter**, so the
dev loop could *interpret* `.mml` source per-node (fast iteration, hot reload, `eval`),
and only *optionally* compile for export. **Odin has no interpreter** — it is a
statically-typed, ahead-of-time, LLVM-backed native language. That single fact drives
the whole architecture:

| Concern | miniml_godot | odin_godot |
|---|---|---|
| Dev iteration | interpret source per node | **compile** scripts → shared lib, `dlopen` |
| Hot reload | re-eval into live env | **recompile** scripts lib, swap via `dlclose`/`dlopen`, re-instantiate |
| `eval`/REPL | yes (interpreter) | **no** — not possible; honest gap vs GDScript |
| Engine→script dispatch | stringly-typed `mml_embed_call_*` | **typed proc pointers** in a registry |
| Script→engine calls | `Godot.*` string wrappers | **typed `godot` binding** generated from `extension_api.json` |
| Export | compile mode (optional) | compile mode (the *only* mode) |

So odin_godot is essentially **"miniml_godot's compiled-mode, everywhere"** — but with
a *typed* API on both sides of the boundary, because Odin speaks the GDExtension C ABI
natively (`foreign import` to call in, `@(export) -build-mode:dll` to be called).

### Honest scope note — what "fully replace GDScript" can and can't mean
Achievable: `extends <any class>`, lifecycle hooks, custom methods (callable from
GDScript and cross-script), `@export` vars in the Inspector, signals (declare/connect/emit
with typed multi-arg payloads), tool scripts, the full engine API surface. **Not**
achievable with AOT Odin: runtime `eval`/`expression` evaluation, and *instant* in-editor
hot-reload (we get *fast recompile-and-swap* reload instead, on the order of an Odin build).
These gaps are inherent to a compiled language and will be documented, not hidden.

---

## 2. Architecture overview

```
                    .gdextension  (entry_symbol = odin_godot_init)
                          │
          ┌───────────────┴────────────────┐
          │   CORE dll  (stable, prebuilt)  │     ← written in Odin, -build-mode:dll
          │   - odin_godot_init entry       │
          │   - OdinLanguage   (ScriptLanguageExtension)
          │   - OdinScript     (ScriptExtension)
          │   - script instance (ScriptInstanceInfo3)
          │   - OdinLoader/Saver (ResourceFormat*)
          │   - OdinExportPlugin (EditorExportPlugin)
          │   - Class REGISTRY  ◄──────────────┐
          └───────────────┬───────────────────┼──┘
                          │ dlopen / dlclose   │ @(init) self-registration
          ┌───────────────┴───────────────────┴──┐
          │  SCRIPTS dll  (swappable, recompiled) │  ← all res://**/*.odin, -build-mode:dll
          │  each script: a struct + procs + an   │
          │  @(init) that registers a ClassDesc   │
          └───────────────┬───────────────────────┘
                          │ typed calls
          ┌───────────────┴───────────────────────┐
          │  godot  binding package (generated)    │  ← from extension_api.json
          │  Variant, builtins, every class+method │     shared by CORE and SCRIPTS
          └────────────────────────────────────────┘
```

Two dlls on desktop: a **stable core** and a **swappable scripts** lib. Keeping them
separate is what makes hot reload tractable — the core stays loaded and holds engine
handles while the scripts lib is swapped underneath it. On **web**, hot reload is
irrelevant, so core+scripts are linked together (or declared as two Emscripten
`SIDE_MODULE`s at link time) and shipped AOT.

### Components (map to subdirectories)
- **`flake.nix`** — pins Odin, LLVM (Odin's backend), Emscripten (emsdk, version matched
  to Godot's web build), a Godot 4.x binary, clang/lld/binutils. `nix develop` shell +
  `nix build` of the extension. Mirrors `~/data/code/ocaml/interpreter/flake.nix`.
- **`bindgen/`** — generates the typed `godot` Odin package from `extension_api.json`.
  Start by **vendoring/forking `dresswithpockets/odin-godot`'s bindgen** (verify license),
  which already covers all enums/classes/utility-fns/singletons/native-structs.
- **`godot/`** — the *generated* binding package (typed Variant + builtins + every class).
  This is the "full API" surface; checked-in generated output + a regen command.
- **`core/`** — the extension core (Odin, `-build-mode:dll`). The bulk of novel work:
  `ScriptLanguageExtension`, `ScriptExtension`, script-instance dispatch, resource
  loader/saver, export plugin, the class registry.
- **`runtime/`** — small shared package imported by *both* core and scripts: the
  `ClassDesc` registry types, the registration entry points, the `@export`/signal/method
  descriptors, and ergonomic helpers scripts use to declare a class.
- **`scripts/`** — user `.odin` scripts (and the showcase's scripts).
- **`build/`** — the compose+compile pipeline (compile all scripts → one dll / wasm obj).
- **`tests/`** — headless GDScript drivers (`test_*.gd`) + a `Makefile`, mirroring miniml.
- **`showcase/`** — a playable coin-collector scene written purely in Odin (no GDScript).
- **`docs/`** — design notes, the script-authoring guide, the WASM/reload spike writeups.

---

## 3. How an `.odin` script declares a "class" (the key ergonomic decision)

Odin has no classes and no macro-style compile-time reflection, so we need a convention
to express `extends`, `@export`, `signal`, and lifecycle. **Chosen approach: a codegen
preprocessor** (Godin-style) reads struct tags + attributes and emits the registration
boilerplate. The author writes:

```odin
package player
import gd "godot"

Player :: struct {
    using _: gd.CharacterBody2D,   // `extends CharacterBody2D`
    speed:   f32 `gd:"export"`,    // Inspector-exported tunable
    score:   int,
}

@(gd_lifecycle) ready   :: proc(self: ^Player) { gd.set_position(self, {100, 50}) }
@(gd_lifecycle) process :: proc(self: ^Player, delta: f64) { /* ... */ }
@(gd_signal_handler) on_body_entered :: proc(self: ^Player, body: ^gd.Node) { self.score += 1 }
// signals declared via a struct tag or a `@(gd_signal)` marker; codegen collects them.
```

…and the preprocessor generates the `@(init) register()` shown below. The codegen is a
thin layer over the underlying mechanism, which is **`@(init)` self-registration** — what
the generator emits and what the core consumes:

```odin
package player
import gd "godot"
import rt "runtime"

Player :: struct {
    using _: gd.CharacterBody2D,   // `extends CharacterBody2D`
    speed:   f32,                  // exported below
    score:   int,
}

ready :: proc(self: ^Player) {
    gd.set_position(self, {100, 50})
}

process :: proc(self: ^Player, delta: f64) {
    dir := gd.get_axis("ui_left", "ui_right")
    gd.translate(self, {f32(dir) * self.speed * f32(delta), 0})
}

on_body_entered :: proc(self: ^Player, body: ^gd.Node) { self.score += 1 }

@(init)  // runs when the scripts dll loads
register :: proc() {
    rt.class("Player", gd.CharacterBody2D, size_of(Player), align_of(Player),
        lifecycle = { ready = ready, process = process },
        exports   = { rt.export_f32("speed", &Player{}.speed, default = 200) },
        signals   = { rt.signal("hit", {.OBJECT}) },
        methods   = { rt.method("on_body_entered", on_body_entered) },
    )
}
```

The core's registry maps `"Player"` → a `ClassDesc` with typed proc pointers; engine
lifecycle/method/signal calls are dispatched through it with the node pointer + typed
args — **no per-call string marshalling**. `@(init)` procs run automatically on dll load,
so loading the scripts lib populates the registry for free.

The core's registry maps `"Player"` → a `ClassDesc` with typed proc pointers; engine
lifecycle/method/signal calls are dispatched through it. The codegen preprocessor lives in
`bindgen/` (or a sibling `scriptgen/`), runs as a pre-build step over `res://**/*.odin`,
and emits one generated `*_gen.odin` per script plus the composed registration unit.

---

## 4. The boundary, concretely

**Engine → script** (in the script-instance `call`): the engine hands us a method name +
`Variant*` args. The registry resolves the name to a typed proc pointer; we convert each
`Variant` to the Odin parameter type once (cached constructors, as miniml does) and call.
Lifecycle (`_ready`, `_process(delta)`, `_physics_process`, `_enter_tree`, …), signal
handlers (all payload args forwarded), and custom methods all route here.

**Script → engine** (`godot.*`): direct typed calls through the generated binding, which
holds the cached GDExtension interface function pointers and `StringName`/method-bind
handles. No string wrappers like miniml's `Godot.call_s` — the binding exposes
`set_position(node, Vector2)` etc. with real types.

**`@export` / properties:** `OdinScript._get_script_property_list` reports the exports from
the `ClassDesc`; the instance `get`/`set` read/write the field at its offset in the node's
Odin struct (offsets captured at registration). Inspector-configurable, scene-serialized.

**Signals:** declared in `ClassDesc`; `_get_script_signal_list` reports them; connect routes
a signal into a registered method, forwarding **all** typed payload args (miniml's multi-arg
signal behavior is the bar). Emit via the typed binding.

---

## 5. Build & toolchain (Nix flake)

`nix develop` provides: `odin`, `llvm`/`lld`, `emscripten` (pinned to Godot's version —
critical, see miniml's `-sSUPPORT_LONGJMP=wasm` lesson), `godot`, `clang`, `make`.

- **Core dll:** `odin build core -build-mode:dll -out:libodin_godot.<ext>`
- **Scripts dll (desktop):** compose `res://**/*.odin` into a package →
  `odin build … -build-mode:dll -out:libodinscripts.<ext>`
- **Scripts → web:** `odin build … -build-mode:obj -target:freestanding_wasm32` → `.wasm.o`,
  then `emcc script.wasm.o -sSIDE_MODULE=1 -sSUPPORT_LONGJMP=wasm -O2 -o libodinscripts.wasm`,
  emscripten version == Godot's. (Highest-risk path — Phase-0 spike de-risks it first.)
- **`.gdextension`:** `entry_symbol = "odin_godot_init"`; per-platform library entries
  (`macos.*`, `linux.*`, `windows.*`, `web.*.wasm32`); export plugin rewrites paths.
- **Regenerate inputs from the pinned engine:**
  `godot --headless --dump-gdextension-interface` and `--dump-extension-api` →
  `gdextension_interface.h` + `extension_api.json` feed `bindgen`.

`nix build` produces the extension as a reproducible artifact; `tests/Makefile` mirrors
miniml's headless `make test-*` targets.

---

## 6. Phased delivery (risk-front-loaded)

Each phase ends in a **headless-verifiable milestone**, like miniml's tracks.

### Phase 0 — Foundations & spikes (de-risk before building)
- `flake.nix` pinning Odin + LLVM + emscripten + Godot; `nix develop` works.
- Dump `gdextension_interface.h` + `extension_api.json` from the pinned Godot.
- Vendor/fork the `odin-godot` bindgen; generate the `godot` package; build a trivial
  **Odin-authored GDExtension class** registered & callable from GDScript (proves the
  Odin→GDExtension ABI end-to-end). *Milestone: GDScript calls an Odin method, headless.*
- **Spike W (WASM):** compile a trivial Odin proc to a Godot-loadable `SIDE_MODULE` and
  call it from an actual web export. *This is the single biggest risk — prove it early.*
- **Spike R (reload):** `dlopen`/`dlclose` an Odin scripts dll, swap it, re-resolve the
  registry — confirm Odin global/`context` init survives a reload cycle.

### Phase 1 — ScriptLanguageExtension skeleton
- Register the **"Odin"** language; `.odin` recognized (extension, reserved words,
  comment delimiters). `OdinScript` resource + `OdinLoader` so `load("res://x.odin")` works.
- Attach a `.odin` script to a Node in a `.tscn`; `_can_instantiate`, `_get_language`,
  `_has_method` wired; `_ready` is a stub. *Milestone: a `.odin` script attaches and the
  editor/scene-tree recognizes it.*

### Phase 2 — Compiled dispatch (the heart)
- The `runtime` registry + `@(init)` convention (§3); compose+compile the scripts dll.
- Script-instance `call` routes `_ready`/`_process(delta)`/`_physics_process` into Odin
  procs with `self` + `delta`; scripts drive their node via the typed `godot` API.
  *Milestone: the showcase player **moves** under keyboard input, pure Odin, headless-verified.*

### Phase 3 — Full GDScript-parity surface
- `@export` vars: property list + Inspector get/set + scene serialization.
- Signals: declare + connect (multi-arg typed payloads forwarded) + emit.
- Custom methods callable from GDScript and cross-script; `extends` any base; tool scripts.
- Per-instance state (each node its own struct instance). Autoload/`class_name` modules.
  *Milestone: coin collector fully playable — collect + score + HUD + exported tunables +
  signals — with **no GDScript glue** (miniml's showcase bar).*

### Phase 4 — Hot-reload dev loop
- Core watches `res://**/*.odin`; on change shells `odin build`, `dlclose`/`dlopen` the
  scripts dll, repopulates the registry, re-instantiates live nodes preserving state.
  *Milestone: edit a `.odin`, see the running scene pick up the new behavior after a rebuild.*

### Phase 5 — Export pipeline (native + WASM)
- `OdinExportPlugin`: compile all scripts per target desktop platform (`-build-mode:dll`
  cross-targets) and **web** (`-build-mode:obj` → `emcc -sSIDE_MODULE`), rewrite the
  `.gdextension`, bundle into the export. *Milestone: an exported desktop build **and** a
  web build of the showcase both run the Odin scripts.*

### Phase 6 — Polish & showcase
- Pure-Odin coin-collector `showcase.tscn`; full `tests/` headless E2E suite (script,
  signal, reload, autoload, export, web-smoke); editor diagnostics via `odin check` in
  `_validate`; README + authoring guide. *Milestone: `make test-*` green; web demo plays.*

---

## 7. Top risks & mitigations
1. **Odin→WASM side-module compatibility w/ Godot's Emscripten** (longjmp mode, runtime
   `context` init, version match, possibly a 2nd `SIDE_MODULE` for scripts). → Phase-0 Spike W.
2. **Native hot reload safety** (`dlclose` of live code, preserving node state, Odin global
   re-init). → Phase-0 Spike R; keep core/scripts as separate dlls.
3. **Script-class ergonomics without reflection** (the `@(init)`/`ClassDesc` convention is
   pleasant or it isn't). → validate in Phase 2; optional codegen sugar later.
4. **Off-main-thread resource loading** (Odin `context` per thread; don't call scripts off
   the loader thread — miniml's constraint). → loader builds the resource only; instantiate
   on main thread.
5. **`bindgen` coverage/upkeep** vs writing our own. → start from `odin-godot`, own the fork.

## 8. Decisions to confirm
- **Script declaration:** `@(init)` self-registration (recommended) vs codegen preprocessor.
- **Binding layer:** fork `dresswithpockets/odin-godot`'s bindgen (faster) vs slim in-house.
- **dll split:** stable core + swappable scripts dll (recommended, enables reload) vs one dll.
- **Godot version target:** pin which 4.x (suggest matching the installed `/Applications/Godot.app`).

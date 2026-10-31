<a id="odin_godot--odin-as-a-first-class-godot-scripting-language"></a>

# odin_godot — original scripting-language implementation plan

The original goal was a Godot 4.x GDExtension implementing the full
`ScriptLanguageExtension` API. Attaching an `.odin` file to a Node would run its
lifecycle (`_ready`, `_process`, signals, exported vars…) in compiled Odin. The
plan aimed to replace GDScript within the compiled-language limits below, with
native + WASM compilation and a reproducible Nix-flake toolchain.

This is the original implementation plan, with decisions recorded on 2026-06-22.
It preserves the intended architecture and milestones rather than describing the
current support contract. Use [the documentation index](docs/index.md) for current
setup and APIs. The plan draws on the sibling `~/data/code/ocaml/miniml_godot`
project, a `ScriptLanguageExtension` that embeds the MiniML interpreter.

### Locked decisions (2026-06-22)
- **Godot pin:** **4.7.1 stable** (matches the installed `/Applications/Godot.app`).
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

<a id="1-the-core-insight-odin--miniml"></a>

## 1. Compilation and iteration model

MiniML's interpreter let `miniml_godot` interpret `.mml` source per node during
development, supporting reload and `eval`, with optional compilation for export.
Odin is statically typed and compiles ahead of time through LLVM. The plan
therefore required compilation during development as well as export:

| Concern | miniml_godot | odin_godot |
|---|---|---|
| Dev iteration | interpret source per node | **compile** scripts → shared lib, `dlopen` |
| Hot reload | re-eval into live env | **recompile** scripts lib, swap via `dlclose`/`dlopen`, re-instantiate |
| `eval`/REPL | yes (interpreter) | no; Odin requires compiled code |
| Engine→script dispatch | stringly-typed `mml_embed_call_*` | **typed proc pointers** in a registry |
| Script→engine calls | `Godot.*` string wrappers | **typed `godot` binding** generated from `extension_api.json` |
| Export | compile mode (optional) | compile mode (the *only* mode) |

The planned SDK used typed calls in both directions across the GDExtension C
ABI: `foreign import` for engine calls and `@(export) -build-mode:dll` for entry
points the engine could call.

<a id="honest-scope-note--what-fully-replace-gdscript-can-and-cant-mean"></a>

### Scope limits of ahead-of-time compilation
Achievable: `extends <any class>`, lifecycle hooks, custom methods (callable from
GDScript and cross-script), `@export` vars in the Inspector, signals (declare/connect/emit
with typed multi-arg payloads), tool scripts, the full engine API surface. **Not**
achievable with AOT Odin: runtime `eval`/`expression` evaluation, and *instant* in-editor
hot-reload (we get *fast recompile-and-swap* reload instead, on the order of an Odin build).
These compiled-language limits were part of the planned documentation scope.

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
separate lets the core retain engine handles while the scripts library is
reloaded. The web proposal linked core+scripts together, or declared two
Emscripten `SIDE_MODULE`s at link time, for ahead-of-time delivery without hot reload.

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

<a id="3-how-an-odin-script-declares-a-class-the-key-ergonomic-decision"></a>

## 3. Script declarations and generated registration

The plan selected a code-generation preprocessor to express `extends`,
`@export`, `signal`, and lifecycle in Odin structs and procedures. It would read
struct tags and attributes and emit registration code. The following examples
are the original proposed syntax, not current authoring instructions:

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

The preprocessor would generate the `@(init) register()` below. This proposal
used `@(init)` self-registration as the underlying mechanism consumed by the core:

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

The proposed registry mapped `"Player"` to a `ClassDesc` containing typed
procedure pointers. Engine lifecycle/method/signal calls would dispatch with a
node pointer and typed arguments without per-call string marshalling. `@(init)`
procedures would populate the registry when the scripts library loaded. The
pre-build generator was planned for `bindgen/` or a sibling `scriptgen/`, reading
`res://**/*.odin` and emitting one `*_gen.odin` per script plus a registration unit.

---

<a id="4-the-boundary-concretely"></a>

## 4. Engine/script calls and properties

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

<a id="6-phased-delivery-risk-front-loaded"></a>

## 6. Phased implementation and validation

Each planned phase required a milestone verifiable through a headless test.

<a id="phase-0--foundations--spikes-de-risk-before-building"></a>

### Phase 0 — Toolchain, ABI, web, and reload validation
- `flake.nix` pinning Odin + LLVM + emscripten + Godot; `nix develop` works.
- Dump `gdextension_interface.h` + `extension_api.json` from the pinned Godot.
- Vendor/fork the `odin-godot` bindgen; generate the `godot` package; build a trivial
  **Odin-authored GDExtension class** registered & callable from GDScript (proves the
  Odin→GDExtension ABI end-to-end). *Milestone: GDScript calls an Odin method, headless.*
- **Spike W (WASM):** compile a trivial Odin proc to a Godot-loadable `SIDE_MODULE` and
  call it from an actual web export. *Verify this compatibility before building the rest of the web path.*
- **Spike R (reload):** `dlopen`/`dlclose` an Odin scripts dll, swap it, re-resolve the
  registry — confirm Odin global/`context` init survives a reload cycle.

### Phase 1 — ScriptLanguageExtension skeleton
- Register the **"Odin"** language; `.odin` recognized (extension, reserved words,
  comment delimiters). `OdinScript` resource + `OdinLoader` so `load("res://x.odin")` works.
- Attach a `.odin` script to a Node in a `.tscn`; `_can_instantiate`, `_get_language`,
  `_has_method` wired; `_ready` is a stub. *Milestone: a `.odin` script attaches and the
  editor/scene-tree recognizes it.*

<a id="phase-2--compiled-dispatch-the-heart"></a>

### Phase 2 — Compiled dispatch
- The `runtime` registry + `@(init)` convention (§3); compose+compile the scripts dll.
- Script-instance `call` routes `_ready`/`_process(delta)`/`_physics_process` into Odin
  procs with `self` + `delta`; scripts drive their node via the typed `godot` API.
  *Milestone: the showcase player **moves** under keyboard input, pure Odin, headless-verified.*

<a id="phase-3--full-gdscript-parity-surface"></a>

### Phase 3 — Properties, signals, and methods
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
  `_validate`; README + authoring guide. *Milestone: `make test-*` passes and the web demo runs.*

---

## 7. Top risks & mitigations
1. **Odin→WASM side-module compatibility w/ Godot's Emscripten** (longjmp mode, runtime
   `context` init, version match, possibly a 2nd `SIDE_MODULE` for scripts). → Phase-0 Spike W.
2. **Native hot reload safety** (`dlclose` of live code, preserving node state, Odin global
   re-init). → Phase-0 Spike R; keep core/scripts as separate dlls.
3. **Script-class ergonomics without reflection** (the `@(init)`/`ClassDesc` convention needs practical
   authoring validation). → validate in Phase 2; optional generated syntax later.
4. **Off-main-thread resource loading** (Odin `context` per thread; don't call scripts off
   the loader thread — miniml's constraint). → loader builds the resource only; instantiate
   on main thread.
5. **`bindgen` coverage/upkeep** vs writing our own. → start from `odin-godot`, own the fork.

<a id="8-decisions-to-confirm"></a>

## 8. Original decision checklist
- **Script declaration:** `@(init)` self-registration (recommended) vs codegen preprocessor.
- **Binding layer:** fork `dresswithpockets/odin-godot`'s bindgen (faster) vs slim in-house.
- **dll split:** stable core + swappable scripts dll (recommended, enables reload) vs one dll.
- **Godot version target:** pin which 4.x (suggest matching the installed `/Applications/Godot.app`).

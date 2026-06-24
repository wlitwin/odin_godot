# Web / WASM target — Odin scripts in the browser

## Verdict: 🟢 GREEN

The **full** odin_godot extension (core `ScriptLanguageExtension` + the generated
`godot`/`gdext` binding + a project's compiled `.odin` scripts) builds into **one
Emscripten `SIDE_MODULE` wasm**, Godot 4.6.2's headless web export bundles it, and an
Odin script's `_ready` **verifiably runs in a real browser** — it prints `WEB_RAN` +
`WEB_ASSERT_OK` (the latter from calling an Odin `@(gd_method)` `add(2,3)==5`) to the JS
console, captured by a headless-Chrome driver.

Reproduce (inside `nix develop`):

```sh
nix develop --command bash -c 'bash tests/web/run.sh'    # -> PHASEWEB_OK
```

This builds the wasm, web-exports `tests/web/`, serves it with COOP/COEP, drives headless
Chrome, and asserts the sentinels. Native desktop is untouched: `tests/phase{2,3,35,4,5}`
still print `PHASE*_OK`.

---

## The web/native split (`when WEB` design)

Native ships a stable **core** dll that `dlopen`s a swappable **scripts** dll (Phase-2
manifest/boot handshake + Phase-4 hot reload) and an editor **export** pipeline. None of
that exists in the browser: there is no `dlopen`, no compiler, no editor, and the whole
program is one wasm module sharing one linear memory with the engine.

A build switch `WEB :: #config(ODIN_GODOT_WEB, false)` (`-define:ODIN_GODOT_WEB=true`)
plus **arch-gated files** (`#+build` tags) split the two worlds. The native path is
entirely unchanged under `when !WEB` / `#+build darwin, linux, windows`.

| Concern | Native | Web |
| --- | --- | --- |
| Scripts location | separate `libodinscripts` dll, `dlopen`ed | linked INTO the same module (`@(require) import "godot:core"` from the scripts package, wasm32-only) |
| `@(init)` self-registration | runs on `dlopen` | a SIDE_MODULE has no CRT/entry, so `odin_godot_init` calls `runtime._startup_runtime()` itself (`web_startup`) |
| Class manifest | dlsym `odin_scripts_manifest`, after `odin_scripts_boot` | call `rt.odin_scripts_manifest()` directly (same module, shared globals — no boot) |
| Hot reload | copy+`dlopen`+rebind | n/a (returns false) |
| Export plugin | `EditorExportPlugin` (os/libc/fmt) | excluded (`export_plugin.odin` is `#+build darwin, linux, windows`) |
| Core bookkeeping allocator | Odin heap allocator | alignment-correct wrapper over the engine allocator (see below) |

Files: `core/web.odin` (switch + allocator), `core/scripts.odin` (shared indexing),
`core/scripts_native.odin` (`#+build darwin, linux, windows`), `core/scripts_web.odin`
(`#+build wasm32, wasm64p32`), guards in `core/main.odin`, tag on
`core/export_plugin.odin`. The compose file is generated into the scripts dir as
`odin_godot_web_wasm32.odin` by `build/build_web.sh`.

## Build command sequence (`build/build_web.sh`)

```sh
# 1. scriptgen -> *.gen.odin + res:// stubs   2. emit the wasm32-only compose file
# 3. Odin -> wasm object: freestanding wasm32, PIC, obj, no entry, ODIN_GODOT_WEB
odin build <project>/scripts -collection:godot=<root> \
    -target:freestanding_wasm32 -build-mode:obj -no-entry-point -reloc-mode:pic \
    -define:ODIN_GODOT_WEB=true -custom-attribute:gd_method -out:libodin_godot.wasm.o
# 4. object -> Emscripten SIDE_MODULE (entry_symbol odin_godot_init via Odin @(export))
emcc libodin_godot.wasm.o -sSIDE_MODULE=1 -sSUPPORT_LONGJMP=wasm -O2 -o libodin_godot.wasm
```

The `.gdextension` points `web.{debug,release}.wasm32` at `res://bin/libodin_godot.wasm`.
Godot web export needs `variant/extensions_support=true` (selects the dlink runtime).

## The five blockers found and fixed (all wasm-strictness latent on native)

1. **PIC.** `SIDE_MODULE` data relocations require `-reloc-mode:pic`. Spike W's leaf
   module had no mutable globals so never hit this.
2. **`@(init)` never ran.** With `-no-entry-point` the Odin startup is dead-code
   eliminated. Fix: `odin_godot_init` calls `runtime._startup_runtime()` (`__$startup_runtime`)
   itself.
3. **`function signature mismatch` (the real "version mismatch").** `gdext.Variant_Type`
   was `enum u64`, but the C `GDExtensionVariantType` is `int` (i32) — every other gdext
   enum is already `enum c.int`. Benign on 64-bit native (the C ABI ignores the high
   word, and 8-byte struct fields are absorbed by padding before 8-aligned pointers); on
   wasm it is a hard `call_indirect` type trap (and a 4-byte-pointer struct-layout break).
   Fix: `Variant_Type :: enum c.int` (`gdext/lib.odin`) — correct on **both** targets.
4. **`fd_write` abort / detached ArrayBuffer.** Odin's `default_wasm_allocator` grows the
   shared linear memory via raw `memory.grow`, colliding with Emscripten's arena and
   detaching its cached HEAP views. Fix: route Odin allocations through the **engine**
   allocator (`gdext mem_alloc`), wrapped to honor alignment (Odin maps assert 64-byte
   cache-line alignment with low bits free for tagging) — `core/web.odin`
   `web_aligned_allocator`.
5. **`abort()` on free — non-zeroed `new`.** The Godot allocator's `.Alloc` does not zero
   (it just wraps `mem_alloc`), violating Odin's contract that `new`/`make` return zeroed
   memory. Native happened to get zero pages; web's malloc returns reused memory, so
   `new(OdinScript)` had garbage `source_utf8`/`base_type`/`class_name` and the first
   `delete` freed a garbage pointer. Fix: explicit zeroing of the script struct
   (`script.odin`) and the per-instance user struct (`instance.odin`), and routing the
   owned-string alloc+free through one stable allocator (`core_allocator`).

## Emscripten version

Godot 4.6.2's web templates were built with emscripten **4.0.20**. The module was built
and **runs in the browser** both with the dev shell's **5.0.6** and with a manual
**emsdk 4.0.20** install — so the exact match is *not* required here: `-sSUPPORT_LONGJMP=wasm`
keeps the longjmp ABI self-contained and the dylink format is cross-compatible. The
earlier "must relink under 4.0.20" concern was a red herring (the true blocker was #3
above). To pin anyway: `EMCC=/path/to/emsdk/.../emcc bash build/build_web.sh`.

## In-browser verification

`tests/web/` is a minimal project (a `Main` node with an attached `.odin` script).
`tests/web/serve.sh` serves the export with `Cross-Origin-Opener-Policy: same-origin` +
`Cross-Origin-Embedder-Policy: require-corp` (Godot web needs SharedArrayBuffer), using
Node (the macOS system `python3` is a stub that fails inside `nix develop`).
`tests/web/drive.mjs` drives headless Chrome via `puppeteer-core` (uses the system
Chrome, software WebGL2 via SwiftShader) and asserts `WEB_RAN` + `WEB_ASSERT_OK` appear
in the console. `tests/web/run.sh` wires the whole thing and prints `PHASEWEB_OK`.

Constraint note: blocker #3's one-line fix is in `gdext/lib.odin` (normally a generated/
off-limits file). It was the single blocking correctness bug, brings `Variant_Type` in
line with every other enum in that file, is verified native-safe (all phase tests pass),
and is correct on every target — so it was applied rather than left as a remaining step.

---

## The FULL showcase game loop in the browser (`tests/web_showcase/`)

`tests/web/` only proves a trivial `_ready`. `tests/web_showcase/` proves the **real**
pure-Odin coin-collector loop runs in a browser: a GDScript `driver.gd` (the export's main
scene) moves the Player onto a Coin and steps **physics**, so the Area2D's `body_entered`
fires naturally → Odin `collect` → `game_state_add` increments the **shared** score →
script-declared `collected` signal emits → coin `queue_free`d → the cross-script HUD Label
reflects the new score. The driver prints `SHOWCASE_WEB_OK score=<n> value=<v>`; the
console shows e.g. `physics-collected coin; shared get_score()=5; listener value=5;
cross-script HUD='Score: 5'`. No simulated keyboard input is needed — the physics-collide
path is fully driveable programmatically. Run: `bash tests/web_showcase/run.sh` →
`PHASEWEBSHOWCASE_OK`. Wired into `tests/run_all.sh` as the browser-gated `web_showcase`.

To make the **editor** "Export → Web" work for a project, two things are required and now
automated:

* The project `.gdextension` keeps its **native** `macos.*` entries AND adds
  `web.{debug,release}.wasm32 = "res://bin/libodin_godot.wasm"`. The native entry is what
  loads the extension **on the macOS export host** so its `OdinResourceFormatLoader`
  recognizes the authored `.odin` files and **packs them** — without it the sources are
  excluded from the pck and the scripts' base types cannot be resolved in the browser.
* `core/export_plugin.odin`'s `_export_begin`, on the `web` feature, now **builds** the
  SIDE_MODULE by shelling `build/build_web.sh <project>` (inheriting the editor's nix PATH
  so `odin`/`emcc` resolve), so the `res://bin/libodin_godot.wasm` the `.gdextension`
  references actually exists at export. Godot's GDExtension export handling then bundles it
  automatically (like the macOS dylib). Verified: `--export-release "Web"` bundles
  `libodin_godot.wasm` + `index.side.wasm` with **no** `No "wasm32" library found` warning.

## Blocker #6 — script `context` had no usable allocator on web

The generated trampolines (lifecycle wrappers + `@(gd_method)` trampolines) ran their
user-proc bodies under `context = runtime.default_context()`. On `freestanding_wasm32`
that context is **unusable for allocating scripts**: `ODIN_OS == .Freestanding` forces
`NO_DEFAULT_TEMP_ALLOCATOR`, so `temp_allocator` is **nil** — any `core:fmt`/temp
allocation silently yields `""` (the HUD's `fmt.ctprintf("Score: %d", …)` produced an
empty Label) — and the main allocator is Odin's own wasm allocator (the unsafe
`memory.grow` path from blocker #4). Benign on native (heap-backed default context); only
the showcase's HUD was the first web script to actually allocate.

Fix (one indirection, native unchanged): scriptgen now emits `context = rt.script_context()`
instead of `runtime.default_context()`. `runtime/context.odin` defines `script_context()` —
on native a settable hook is nil so it returns `runtime.default_context()` byte-for-byte;
on web the core installs the hook (`core/scripts_web.odin` `web_script_context`) returning a
context whose `allocator` **and** `temp_allocator` are the engine-backed, alignment-correct
`web_aligned_allocator`. Files: `runtime/context.odin` (new), `scriptgen/generate.odin`,
`core/scripts_web.odin`. All native phase tests stay green (the hook is nil there).

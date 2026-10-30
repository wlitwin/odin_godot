# Spike W — Odin → Emscripten SIDE_MODULE → Godot 4.6.2 Web

## Verdict: 🟡 YELLOW

The full compile + link + dynamic-linking ABI path is **proven**, and Godot 4.6.2's
web exporter **accepts and bundles** an Odin-produced wasm SIDE_MODULE as a
GDExtension. No fundamental blocker found. Two explicit, named steps remain before
🟢 GREEN (an actual extension loading and running in a browser):

1. **Emscripten version reconciliation.** The spike was linked with emscripten **5.0.6**
   (current dev shell). Godot 4.6.2's web templates were built with emscripten **4.0.20**.
   The link step must be redone under 4.0.20 so the dynamic-linking / longjmp ABI matches
   the engine's `godot.side.wasm` main module.
2. **In-browser load test.** Export, serve over HTTP with COOP/COEP headers, and confirm
   the extension's `entry_symbol` is invoked at runtime. This needs a browser; it cannot
   be done headless. (The spike used a leaf `add()` module; the real binding must also
   compile the full `godot/` package to `freestanding_wasm32` and export `*_init`.)

**Single most important finding:** Godot 4.6.2's headless web export, with
`variant/extensions_support=true`, automatically uses the **dlink** web runtime template
(`godot.side.wasm`, 41 MB) and copies the Odin `web.release.wasm32` wasm into the output
unchanged. The GDExtension web pipeline exists and accepts our artifact today.

---

## 1. Godot 4.6.2's emscripten version: **4.0.20** (authoritative)

Source — the *installed* export template, not hearsay:

- `~/Library/Application Support/Godot/export_templates/4.6.2.stable/web_dlink_release.zip`
  → `godot.js` contains literally:
  `const emscriptenVersionPtr=GodotRuntime.allocString("4.0.20");`
- Corroboration: the 4.6 branch `platform/web/detect.py` only enforces a **minimum** of
  4.0.0 (LTO-thin ≥ 4.0.9, closure ≥ 4.0.11). The exact build version lives in the binary,
  and that is **4.0.20**.

The previous note claiming **4.0.11** (in `flake.nix` and `PLAN.md`) was **wrong**;
4.0.11 is merely the closure-compiler threshold from `detect.py`, not the build version.

Installed templates present for 4.6.2.stable include the GDExtension-capable dlink set:
`web_dlink_release.zip`, `web_dlink_debug.zip`, `web_dlink_nothreads_*`. So no
multi-hundred-MB download is needed for step 4 on this machine.

## 2. Emscripten pin resolution

**Time-boxed out** (per the spike brief). nixpkgs's `emscripten` derivation is coupled to
a specific bundled LLVM/binaryen; overriding just `emscripten.version` does not work
(source hash + toolchain mismatch). The dev shell ships 5.0.6.

**Recommendation for a future pass:** pin emscripten **4.0.20** via an **emsdk-based**
derivation (emsdk fetches the matching prebuilt LLVM for the exact version), or add a
second `nixpkgs` flake input pinned to a rev that shipped 4.0.20 and take `emscripten`
from it. `flake.nix` has been updated with the corrected version + this recommendation.
The spike's compile/link *mechanics* are version-independent; only the final link for a
real browser load must move to 4.0.20.

## 3. Working compile + link command sequence (proven)

Run inside the Nix dev shell. See `examples/wasm-spike/build.sh` (the canonical script).

```sh
# (a) Odin source -> wasm object. Freestanding, object mode, no entry point.
odin build src \
    -target:freestanding_wasm32 \
    -build-mode:obj \
    -no-entry-point \
    -out:spike.wasm.o

# (b) Object -> Emscripten SIDE_MODULE wasm.
emcc spike.wasm.o \
    -sSIDE_MODULE=1 \
    -sSUPPORT_LONGJMP=wasm \
    -O2 \
    -o spike.wasm
```

Result: `spike.wasm` is a valid wasm module whose **first custom section is `dylink.0`**
— the Emscripten marker that identifies a true SIDE_MODULE (this is what Godot's web
runtime reads to dynamically link it). Its imports are minimal
(`env.memory`, `env.__memory_base`, `env.__stack_pointer`) and it exports our procs
(`add`, `sum_to`) plus a few Odin runtime helpers (`memcpy`, `__ashlti3`, …).

### ABI smoke test (standalone instantiation)

`examples/wasm-spike/inspect.mjs` instantiates the side module under Node with the
minimal dynamic-linking imports (shared memory/table, zeroed `__memory_base` /
`__table_base` / `GOT.*`) and calls the exports:

```
add(2,3)   = 5
sum_to(5)  = 15
RESULT: PASS
```

This de-risks the SIDE_MODULE ABI: Odin codegen links and runs correctly through the
emscripten side-module relocation model.

## 4. Freestanding-wasm runtime shim details

For a **leaf** module (no setjmp/longjmp, no OS/syscalls) **no shim was needed**:

- `-target:freestanding_wasm32` + `-build-mode:obj` + `-no-entry-point` — no `_start`,
  no CRT, no `main`. Odin still emits its runtime helpers (`memset`/`memcpy`/`__*ti3`),
  which emcc keeps as exports; they are self-contained.
- Export procs are declared `proc "c"` with `@(export, link_name=...)` so the wasm
  export name is unmangled and stable.
- No Odin `context` is required as long as exported procs are `"c"`/`"contextless"` and
  avoid the default allocator/`fmt`. The real binding already uses
  `context = gdext.godot_context()` at its `"c"` entry points (see
  `examples/hello/src/main.odin`); that pattern carries over.
- `-sSUPPORT_LONGJMP=wasm` is **required by the real binding** (its setjmp/longjmp use
  lowers to `invoke_*` — the miniml_godot "undefined symbol `invoke_ji`" lesson). It is
  a no-op for this leaf module but is kept in the command for fidelity.

Open item for the full binding: compiling the entire `godot/` package to
`freestanding_wasm32` may surface missing libc/runtime symbols; resolve by importing them
from the Godot main module (they exist in `godot.side.wasm`'s environment) rather than
shimming. Not exercised here (the `godot/` package is being regenerated concurrently).

## 5. Godot-web export integration (proven as far as headless allows)

`examples/wasm-spike/web-export-test.sh` builds a throwaway Godot project whose
`.gdextension` has only web entries:

```ini
[libraries]
web.debug.wasm32   = "res://bin/spike.wasm"
web.release.wasm32 = "res://bin/spike.wasm"
```

and a Web export preset with `variant/extensions_support=true`, then runs:

```sh
"$GODOT" --headless --path "$PROJ" --export-release "Web"
```

Output (`out/`) contains **both**:

- `spike.wasm` (3188 B) — our Odin SIDE_MODULE, bundled verbatim from the
  `web.release.wasm32` entry, and
- `index.side.wasm` (41 MB) — the engine's **dlink** runtime (= `godot.side.wasm`),
  selected automatically because extension support was enabled.

The desktop editor logs `No GDExtension library found for ... macos.arm64` — **expected
and non-fatal** for a web-only `.gdextension`; it does **not** block the web export. Note
the exporter does **not** validate the wasm's exports at export time (it just bundles);
the `entry_symbol` is resolved at runtime in the browser.

### Precise remaining steps for 🟢 GREEN

1. Re-link `spike.wasm` (and eventually the full binding) under **emscripten 4.0.20**
   (see §2).
2. Build a real GDExtension wasm: compile `godot/` + the example to
   `freestanding_wasm32`, exporting a Godot `entry_symbol` (e.g. `odin_*_init`) instead
   of `add`. Point `web.{debug,release}.wasm32` at it.
3. `Godot --headless --export-release "Web"` (templates already installed).
4. Serve `out/` over HTTP **with COOP/COEP headers** (Godot web requires
   `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`
   for SharedArrayBuffer):
   ```sh
   # e.g. a tiny server that sets the two headers, then open index.html
   ```
5. In the browser, confirm the extension's `entry_symbol` runs and the Odin class is
   usable (e.g. `OdinHello.new().add(2,3) == 5`).

## Reproduce

```sh
cd /Users/walter/data/code/odin/odin_godot
nix develop . --command bash examples/wasm-spike/build.sh          # §3 + ABI test
nix develop . --command bash examples/wasm-spike/web-export-test.sh # §5 export accept
```

# Workflow — the dev loop, editor DX, and debugging

This is the day-to-day guide: how you build, iterate, get editor help, and debug. Read the
honest limitations first — they shape everything else.

## The one thing to internalize: Odin is AOT-compiled

Your `.odin` scripts compile to a native shared library (`.dylib` / `.so` / `.dll`) that the
engine loads through the GDExtension boundary. **There is no interpreter.** GDScript is
interpreted; Odin is not. That single fact decides what works and what doesn't:

| Capability | Odin scripts | Why |
|---|---|---|
| `_ready` / `_process` / signals / `@export` / methods | ✅ Full GDScript parity | dispatched through a typed registry |
| Hot reload on save | ✅ **Recompile** + swap (a few seconds) | not instant like interpreted reload, but live |
| `eval` / `expression` / a REPL | ❌ Impossible | nothing to evaluate source at runtime |
| In-editor breakpoints / step / pause / expression-eval in the debugger panel | ❌ No | the GDScript VM never sees your compiled proc — use `lldb` |
| New `@export` appearing instantly on save | ⚠️ Needs a recompile | the export lives in the compiled dll; the editor rebuilds for you (a moment's latency) |
| Editor remote scene tree / live property edit | ✅ Yes | engine-side, not script-line |
| `lldb` breakpoints, `bt`, memory inspection | ✅ Full power | a script dll is a native C library — debug it as one |

These are inherent to a compiled language. Everything below is built around them.

## Building

**In the editor:** **Project → Tools → Build Odin Scripts** compiles the current project's
scripts dll (the same background build as save-on-reload), with progress in the Output panel —
no terminal needed. Saving a script rebuilds automatically too. The command line below is for
CI, headless builds, or working from the source repo.

`build/build_scripts.sh [PROJECT_DIR] [SCRIPTS_DIR]` runs the full pipeline:

1. builds the `scriptgen` preprocessor,
2. runs it over the scripts dir to emit `*.gen.odin` build artifacts beside your sources (you
   never edit these; the loader ignores them as attachable scripts),
3. builds the scripts dll (`odin build <scriptsdir> -build-mode:dll` with
   `-custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc` — those
   flags let the Odin compiler accept the marker attributes), and
4. builds the core dll.

```sh
nix develop --command bash -c 'bash build/build_scripts.sh examples/survivors'
# -> examples/survivors/bin/{libodinscripts.dylib, libodin_godot.dylib}
```

Defaults target `tests/phase35`; pass your project dir as the first argument. The repo root
(for the `godot` collection) is derived from the script's own location, overridable with
`ODIN_GODOT_ROOT`. If `odin` is not on `PATH`, pass it explicitly as `ODIN=/abs/path/to/odin`.

If the project has [script modules](modules.md) (`res://modules/<name>/`), the same command
also builds one `libodinscripts_<name>.<ext>` per module (`BUILD_MODULES=0` opts out).

## Live editing (show-on-save)

GDScript is interpreted, so a new `@export` appears in the Inspector the instant you save. An
Odin `@export` lives in the **compiled** scripts dll, so it doesn't exist until that dll is
**rebuilt**. To give you the same "save → it appears" loop, the editor recompiles and reloads
the scripts dll for you:

1. **On save**, the editor (and only the editor — a running/exported game never recompiles)
   kicks a **background** rebuild of the scripts dll on a worker thread, so the UI never
   freezes while `odin build` runs (a few seconds). Rapid saves coalesce into one rebuild.
2. **When the build finishes**, on the next editor frame the dll is hot-swapped in place: live
   instances re-bind and **keep their state**, and the Inspector's property lists refresh — so
   a freshly-added `@export` appears **without restarting the editor**.

**Format on save.** When `odinfmt` is reachable (it ships with ols; also the
`odin_godot/odinfmt_bin` setting), saving a script writes **formatted** code to disk and
updates the open buffer in place — one undo step, caret preserved, no unsaved dot. A
project-root `odinfmt.json` is honored. Sources that don't parse yet save unformatted
(never blocked); disable with the `odin_godot/format_on_save` project setting.

**You can always see where the build is.** A status badge in the editor's **top toolbar**
shows *Odin: building…* while a rebuild runs, flashes green *live ✓ (X.Xs)* when the swap
lands, and turns a sticky red *build FAILED* after a broken save (the actual compiler
errors are in the Output panel). It hides when idle.

**Play waits for the build.** Pressing Play while a rebuild is in flight blocks (briefly)
until it finishes, and **refuses to launch on a failed build** — otherwise save-then-Play
would silently run your *previous* dll. This uses the editor's `EditorPlugin._build` hook,
the same mechanism C# uses to compile before launch; a red error in the Output explains
the refusal.

**Per-module rebuilds.** In a project using [script modules](modules.md), the rebuild is
scoped: the coordinator hashes each module's sources and rebuilds + swaps **only the
module(s) whose sources changed** — a save in `res://modules/enemies/` recompiles that one
dll, leaving the main module and every other module's dll (instances, package globals, all
of it) untouched. That's what keeps save latency flat in large projects; the swapped
module's own package globals reset (fresh dll). Details in [Script Modules](modules.md).

**Finding the compiler.** The editor often has no `odin` on its `PATH` (e.g. launched from the
macOS app, not a shell). Point it at the binary with the **`odin_godot/odin_bin`** project
setting, or set the `ODIN` environment variable, or launch the editor from the Nix shell. If
none resolves, reload-on-save warns once and is skipped (the editor keeps working). The scripts
package defaults to `res://scripts`; override with **`odin_godot/scripts_dir`**.

**Manual trigger.** If save detection misses (or you changed something outside the saved
file), force the rebuild+reload+refresh by reloading the script — e.g.
`load("res://scripts/your_script.odin").reload(true)` from a tool script or the editor's
script-reload affordance. This runs the exact same path as save.

**Caveats.**
- Adding/removing/reordering struct fields changes the layout: exported values are preserved
  **by name** across the swap, but non-exported private fields reset (the same reload caveat
  GDScript has).
- The live Inspector *panel* repaint after a swap is a visual editor behavior; the property
  list it reads is updated immediately in-process (verified headless), but eyeballing the panel
  repaint needs a display.
- This is a dev-loop convenience. The reload also has two known follow-ups: each reload leaks
  the previous dll image (a bounded temp-dir is a TODO), and an edit that *newly* adds a
  `_process` lifecycle (nil → non-nil) does not yet re-call `set_process` on rebind.

## Editor DX (validation, autocomplete, highlighting)

Three editor-only features make `.odin` feel like a real scripting language in Godot. All are
native-only (the web build stubs them) and all degrade gracefully — if a tool binary is
missing they warn once and the editor keeps working.

### Live error squiggles (`_validate`)

The editor surfaces real **Odin compiler** errors as inline squiggles + Errors-panel entries
as you type. Because a single `.odin` file isn't a compile unit, it type-checks the file's
**package**: it copies the package to a temp overlay, overwrites the one edited file with your
unsaved buffer, runs `odin check`, and maps `‹file›(‹line›:‹col›) Error: ‹msg›` back to the
editor. It runs on a **background worker** with a result cache, so it never freezes the UI
(first-call latency ~0.03 ms; the check itself completes a moment later and the squiggles
update on the next debounce). The `godot` collection root resolves `odin_godot/root` setting →
`ODIN_GODOT_ROOT` env → **auto-derived from the installed addon's own location** — so a normal
`addons/odin_godot/` install needs no configuration; set `odin_godot/root` only if you keep the
collection somewhere non-standard.

> **Scope:** `_validate` shows squiggles for the **file you're editing**. An error your edit
> causes in a *sibling* file of the same package isn't shown as a live squiggle there (the
> engine only validates the open file) — but it **does** surface in the Output when the
> rebuild-on-save build runs, so cross-file breakage isn't silent, just deferred to save.

### Autocomplete (`_complete_code`, backed by `ols`)

Typing offers completions from the `ols` Odin language server (so `gd.node2d_set_p` →
`node2d_set_position`, etc.). One **long-lived** `ols` subprocess is kept alive for the editor
session over real stdio pipes, so completions are warm (~17–19 ms) instead of re-spawning and
re-indexing the whole binding each keystroke (~0.5–1.25 s). If `ols` can't start or dies, the
editor transparently falls back to a fresh spawn, then restarts the session. Each row shows the
symbol's **type/signature** inline (from ols) next to its name. Point at the binary with
**`odin_godot/ols_bin`** (or the `OLS` env var, or `PATH`); `ols` ships in the Nix shell.

### Syntax highlighting

`.odin` files are token-colored in the Script panel (keywords, comments, strings, numbers,
PascalCase types, proc calls). It's registered on the first editor frame and touches only the
Script editor. Limitation: block comments are highlighted per-line — a `/* … */` spanning
lines isn't tracked across them.

### Icons

A script class gets a custom icon via the **`//gd:icon <res-path>`** marker (shown in the Scene
/ FileSystem docks and Create-Node dialog, like a GDScript `@icon`). A script that sets **no**
`//gd:icon` falls back to a bundled **Odin mark** (`res://addons/odin_godot/icon.svg`), so
`.odin` scripts are recognizable rather than showing the generic script glyph. Override the
default per project with the **`odin_godot/default_icon`** setting (point it at your own icon,
or `""` to use the engine generic). The default is existence-checked, so a non-standard install
without the icon simply shows the generic one.

### Find in Files

The script editor's **Find in Files** (Ctrl/Cmd+Shift+F) searches `.odin` files. Godot builds
that search's file-type list from a hardcoded set (`gd`, `cs`, `gdshader`) with no hook for a
GDExtension scripting language, so the Odin editor plugin appends `odin` to the
`editor/script/search_in_file_extensions` project setting when it loads. The value is applied
in-memory each session (your `project.godot` is left untouched), and the search dialog re-reads
it every time it opens — so the `*.odin` filter checkbox is there and checked by default.

One known gap remains, functionality-irrelevant: documentation tooltips for `@export`s/methods
in the Inspector aren't wired (autocomplete *does* show type signatures — see above).

### Generated files are hidden in the FileSystem dock

The build writes a `*.gen.odin` registration file next to each script (they must live inside
the script's package directory — Odin packages are single-directory). They aren't attachable
or openable in the editor, so the Odin plugin **hides them from the FileSystem dock**. This is
widget-level hiding: Godot's filesystem scan admits files by extension only (`.gen.odin` ends
in `.odin`) and the engine has no per-file exclusion hook, so the plugin re-hides them after
every dock rebuild. They remain real files on disk — external editors, git, and the engine's
Find in Files (which is also extension-based) still see them.

To show them (e.g. when inspecting what scriptgen emits), set the
**`odin_godot/show_generated_files`** project setting to `true` — it takes effect at the next
dock rebuild (toggling a file save or reopening the project is enough).

<a name="editor-settings"></a>
### Editor settings reference

Set these as **project settings** (they also have env fallbacks for shell-launched editors):

| Setting | Env fallback | Purpose |
|---|---|---|
| `odin_godot/odin_bin` | `ODIN` | absolute path to the `odin` compiler (reload-on-save, validation) |
| `odin_godot/ols_bin` | `OLS` | absolute path to the `ols` language server (autocomplete) |
| `odin_godot/emcc_bin` | `EMCC` | absolute path to Emscripten's `emcc` (**web export** only) |
| `odin_godot/root` | `ODIN_GODOT_ROOT` | the odin_godot checkout, for the `-collection:godot` root |
| `odin_godot/scripts_dir` | — | the scripts package (default `res://scripts`) |
| `odin_godot/export_optimization` | `ODIN_EXPORT_OPT` | Odin `-o:` level for **exported** builds: `none`/`minimal`/`size`/`speed`/`aggressive` (default `speed`) |
| `odin_godot/default_icon` | — | editor icon for `.odin` scripts with no `//gd:icon` (default `res://addons/odin_godot/icon.svg`; `""` = engine generic) |
| `odin_godot/show_generated_files` | — | `true` shows `*.gen.odin` build artifacts in the FileSystem dock (hidden by default) |

> **Dev builds vs. exports.** The editor's rebuild-on-save loop compiles at `-o:none` so saves
> stay fast. **Exports** (desktop and web) compile at `odin_godot/export_optimization` (default
> `speed`) so shipped games are optimized — the two are independent. For a maximally lean
> release, append `-no-bounds-check -disable-assert` via the `SCRIPT_BUILD_FLAGS` env when
> running the export build script directly.

## Debugging

Because a script dll is a native library, the workflow is **logging + `lldb` + reading crash
backtraces** — exactly like debugging a C library. The full reference (with verified
transcripts) is in **[Debugging](debugging.md)**; the essentials:

### Logging: `gd.print` / `gd.error` / `gd.warn`

```odin
import gd "godot:godot"

gd.print("player ready")        // -> stdout + the editor Output panel
gd.print_int(score)             // i64 (also print_float / print_bool / print_value)
gd.warn("coin value was 0")     // yellow, non-fatal (push_warning)
gd.error("Hud node missing")    // RED in Output/Debugger, with context (push_error)
```

The helpers are tiny and `contextless` (they don't pull in `core:fmt`, keeping the wasm
footprint small). For formatted output, format with Odin's `fmt` first:

```odin
import "core:fmt"
gd.print(fmt.ctprintf("score=%d", score))   // ctprintf -> temp cstring, what gd.print wants
gd.print_str(fmt.tprintf("hp=%d/%d", hp, max_hp))
```

### Native debugging with `lldb`

Zero-setup from the editor: **Project > Tools > Debug Game (LLDB)** opens a terminal
running the game under lldb, and **Debug Game (Break at Cursor)** halts it on the script
line the caret is on; **Generate VS Code Debug Config** wires the same thing into VS
Code/CodeLLDB (F5, clickable breakpoints in `.odin` files). From a shell, the same
launcher (it handles the macOS gotchas — SIP re-sign, lldb's `::` mis-parse):

```sh
build/debug_game.sh --break player.odin:51 tests/showcase
```

The dlls carry full DWARF (`-debug -use-single-module`): file:line breakpoints, stepping,
and `frame variable` with typed args — `frame variable *self` prints the live script
struct, and the auto-loaded `godot_lldb.py` summaries render `godot.String`/`String_Name`/
`Variant` values. A script `panic` freezes the session at the panic site. See
[debugging.md](debugging.md) for the full tour.

### Other editors and IDEs

**Project > Tools > Generate ols.json (IDE Completion)** writes an `ols.json` at the
project root: ols-based editors (Neovim, Zed, Sublime, Helix) get completion for your
scripts + the `godot` collection immediately, and JetBrains IDEs import it via the
[Odin Support plugin](https://plugins.jetbrains.com/plugin/22933-odin-support)
(right-click the file). Rider edits great but cannot debug native code (plugin
limitation on Rider ≥ 2025.2) — CLion/IDEA Ultimate can, pointed at the debuggable
Godot copy; details in [debugging.md](debugging.md#jetbrains-ides-rider-clion-idea-ultimate-).

### Crashes and panics are reported automatically

A crash or panic in script code is **no longer silent**: an Odin `panic`/`assert` pushes a red
`ODIN_SCRIPT_PANIC <message> (file:line)` error to the **editor Output**, and a raw fatal
signal (SIGSEGV etc., e.g. an engine call on a nil handle — macOS/Linux) prints an
`ODIN_GODOT_CRASH` report to stderr with the **faulting Odin proc symbolized**, pushes a
one-line error toward the editor, and still chains to Godot's own crash handler. See the
"What you see when the game crashes" section of [Debugging](debugging.md).

For deeper digging: run the crashing scenario under `lldb` (it stops at the fault) and `bt`,
or read the native backtrace printed to stderr (grep it for your package name). On macOS the
same backtrace is in the `.ips` report under `~/Library/Logs/DiagnosticReports/`.

> A `_debug_get_current_stack_info` virtual is wired and produces a correct native Odin
> backtrace **when invoked**, but Godot only calls it during an active remote-debug session, so
> it does **not** automatically surface a script-line stack on a plain error. Use `lldb` for
> your day-to-day stack view. See [Debugging](debugging.md) for the full honest account.

### Web / wasm

In the browser there's no `dlopen`, no native stack, and no `lldb`. Debug with **logging**
(`gd.print` → the JS console) and browser devtools. See [Exporting](exporting.md).
</content>

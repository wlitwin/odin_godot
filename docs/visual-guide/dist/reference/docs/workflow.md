<a id="workflow--the-dev-loop-editor-dx-and-debugging"></a>

# Workflow: builds, editor tools, and debugging

This guide covers script builds, reloads, editor tools, and debugging. The
scripts compile into native code, which determines how the editor updates
properties and how you inspect a running game.

## Odin scripts are AOT-compiled

Your `.odin` scripts compile ahead of time into a native shared library
(`.dylib` / `.so` / `.dll`) loaded through GDExtension. Godot executes the
compiled procedures, so source changes require a build and library reload:

| Capability | Odin scripts | Why |
|---|---|---|
| `_ready` / `_process` / signals / `@export` / methods | ✅ Supported | dispatched through a typed registry |
| Hot reload on save | ✅ Recompile + swap (a few seconds) | the library must be rebuilt before it can be loaded |
| `eval` / `expression` / a REPL | ❌ Impossible | nothing to evaluate source at runtime |
| In-editor breakpoints / step / pause / expression-eval in the debugger panel | ❌ No | the GDScript VM never sees your compiled proc — use `lldb` |
| New `@export` appearing instantly on save | ⚠️ Needs a recompile | the export lives in the compiled dll; the editor rebuilds for you (a moment's latency) |
| Editor remote scene tree / live property edit | ✅ Yes | engine-side, not script-line |
| `lldb` breakpoints, `bt`, memory inspection | ✅ Supported | a script dll is a native C library — debug it as one |

Use the editor tools for builds and property inspection, and a native
debugger for procedure-level execution.

## Building

In the editor, **Project → Tools → Build Odin Scripts** starts a background
build of the project's scripts library and reports progress in the Output
panel. Saving a script triggers the same build. Use the command line for CI,
headless builds, or work from the source repository.

`build/build_scripts.sh [PROJECT_DIR] [SCRIPTS_DIR]` runs the full pipeline:

1. builds the `scriptgen` preprocessor,
2. runs it over the scripts dir to emit the `*.gen.odin` build artifacts beside your sources
   (you never edit these; the loader ignores them as attachable scripts). There are three
   kinds: `odin_godot_scripts.gen.odin`, one per package directory, holding the registration
   code for every script in that directory; `odin_godot_boot.gen.odin`, the init shim; and
   `odin_godot_guard.gen.odin`, the staleness guard, a compile-time `#load_hash` assert per
   authored source. A build path that skips this step (a bare `odin build` against
   yesterday's `*.gen.odin`) fails at compile time, naming the drifted file instead of
   silently compiling stale descriptors,
3. builds the scripts dll (`odin build <scriptsdir> -build-mode:dll` with
   `-custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc
   -custom-attribute:gd_command -custom-attribute:gd_tick -custom-attribute:gd_input -custom-attribute:gd_sample
   -custom-attribute:gd_step -custom-attribute:gd_event -custom-attribute:gd_half
   -custom-attribute:gd_message`, which let
   the Odin compiler accept the marker attributes), and
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

Adding an Odin `@export` changes the compiled registration code. The property
becomes available after the scripts library is rebuilt and reloaded. The
editor runs that sequence when you save:

1. On save, the editor starts a rebuild on a worker thread while the UI keeps
   processing. `odin build` takes a few seconds, and rapid saves coalesce into
   one rebuild. Running and exported games do not recompile themselves.
2. After a successful build, the next editor frame swaps in the library,
   rebinds live instances, and refreshes Inspector property lists without an
   editor restart. State preservation depends on the layout and callback
   conditions listed below.

**Format on save.** When `odinfmt` is reachable (it ships with ols; also the
`odin_godot/odinfmt_bin` setting), saving a script writes **formatted** code to disk and
updates the open buffer in place. The change is a single undo step, the caret position is
preserved, and no unsaved dot appears. A project-root `odinfmt.json` is honored. Sources that
don't parse yet save unformatted (never blocked); disable with the `odin_godot/format_on_save`
project setting.

A top-toolbar status badge shows *Odin: building…* during a rebuild and
flashes green *live ✓ (X.Xs)* after a swap. A failed build leaves a red
*build FAILED* badge; read the compiler errors in the Output panel. The badge
hides when idle.

Pressing Play during a rebuild waits for it to finish. A failed build blocks
launch and reports an error in Output so the game cannot run the previous
library after a failed save. This uses `EditorPlugin._build`, the hook also
used by C# to compile before launch.

In a project using [script modules](modules.md), the saved resource path
identifies the module to rebuild. The worker skips unrelated module trees,
and coalesced saves retain all affected roots. Saving under
`res://modules/enemies/` rebuilds that library while retaining the other
modules' libraries, instances, and globals. The replaced library's own package
globals reset. A slower background check catches external edits and deletions
that did not trigger a save callback.

Saving under `res://shared/` rebuilds every module because each can import
that [read-only shared tree](modules.md#shared). See
[Script Modules](modules.md) for details.

**Finding the compiler.** The editor often has no `odin` on its `PATH` (e.g. launched from the
macOS app, not a shell). Point it at the binary with the **`odin_godot/odin_bin`** project
setting, or set the `ODIN` environment variable, or launch the editor from the Nix shell. If
none resolves, reload-on-save warns once and is skipped (the editor keeps working). The scripts
package defaults to `res://scripts`; override with **`odin_godot/scripts_dir`**.

**Manual trigger.** If save detection misses (or you changed something outside the saved
file), force the rebuild+reload+refresh by reloading the script, for example with
`load("res://scripts/your_script.odin").reload(true)` from a tool script or the editor's
script-reload affordance. This runs the exact same path as save.

**Caveats.**
- Adding/removing/reordering struct fields changes the layout: exported values are preserved
  **by name** across the swap, but non-exported private fields reset (the same reload caveat
  GDScript has).
- The live Inspector *panel* repaint after a swap is a visual editor behavior; the property
  list it reads is updated immediately in-process (verified headless), but eyeballing the panel
  repaint needs a display.
- Native DLL generations are ownership-bounded. Ordinary live instances transfer to the new
  generation, and the old image unloads at the closed execution gate. A live instance whose
  class was removed keeps only its exact old generation until that instance is freed.
- Procedure-bearing state (including nested `events.Event` and `flow.Action` containers) is
  detected recursively. Define `<struct>_reload` and rebuild that state there. Without the
  hook, the instance deliberately remains on its coherent old code and emits an actionable
  warning; intermediate generations still unload. Returned Inspector property lists hold a
  separate core-cache lease and never pin executable code.

<a id="editor-dx-validation-autocomplete-highlighting"></a>

## Editor validation, autocomplete, and highlighting

Validation, completion, and highlighting run in native editor builds. The web
build stubs these tools. If a required binary is missing, the feature warns
once and the editor continues running.

### Live error squiggles (`_validate`)

The editor displays Odin compiler errors as inline squiggles and Errors-panel
entries. Syntax checking uses the compiler's parser in-process. A missing
brace or incomplete expression is reported on the first debounce, and a
buffer with syntax errors does not proceed to type checking. The recorded
parser time is ~0.1 ms.

Type checking runs on the package because a single `.odin` file is not a
compilation unit. The worker copies the package and its relative imports to
a temporary overlay, replaces the edited file with the unsaved buffer, and
runs `odin check`. It maps `‹file›(‹line›:‹col›) Error: ‹msg›` diagnostics back
to the editor. A result cache lets the editor return while the background
check runs. Recorded first-call latency is ~0.03 ms; the warm package check
is ~0.5 s on a game-sized package. Squiggles update on the next debounce
after completion.

The `godot` collection root resolves in this order: `odin_godot/root` setting,
`ODIN_GODOT_ROOT` environment variable, then the installed addon's location.
A standard `addons/odin_godot/` install needs no root override. Set
`odin_godot/root` for a collection stored elsewhere.

> `_validate` reports squiggles for the open file. If its edit causes an error
> in a sibling file, that error appears in Output during rebuild-on-save
> rather than as a live squiggle in the sibling.

### Autocomplete (`_complete_code`, backed by `ols`)

The `ols` Odin language server provides completions such as
`gd.node2d_set_p` → `node2d_set_position`, with each symbol's type or signature
beside its name. The editor retains one `ols` subprocess over stdio for the
session. Recorded warm completion time is ~17–19 ms, compared with
~0.5–1.25 s for spawning and indexing on each request. If that process cannot
start or exits, the editor falls back to a fresh spawn and then restarts the
session. Select the binary with `odin_godot/ols_bin`, the `OLS` environment
variable, or `PATH`. The Nix shell includes `ols`.

### Syntax highlighting

`.odin` files are token-colored in the Script panel (keywords, comments, strings, numbers,
PascalCase types, proc calls). It's registered on the first editor frame and touches only the
Script editor. Limitation: block comments are highlighted per-line, so a `/* … */` spanning
lines isn't tracked across them.

### Icons

A script class gets a custom icon via the **`//gd:icon <res-path>`** marker (shown in the Scene
/ FileSystem docks and Create-Node dialog, like a GDScript `@icon`). A script that sets **no**
`//gd:icon` falls back to a bundled **Odin mark** (`res://addons/odin_godot/icon.svg`), so
`.odin` scripts are recognizable rather than showing the generic script glyph. Override the
default per project with the **`odin_godot/default_icon`** setting (point it at your own icon,
or `""` to use the engine generic). The default is existence-checked, so a non-standard install
without the icon shows the generic one.

### Find in Files

The script editor's **Find in Files** (Ctrl/Cmd+Shift+F) searches `.odin` files. Godot's
search file-type list is a hardcoded set (`gd`, `cs`, `gdshader`) with no hook for a
GDExtension scripting language, so on load the Odin editor plugin appends `odin` to the
`editor/script/search_in_file_extensions` project setting. The value is applied in-memory each session (your `project.godot` is left untouched),
and the search dialog re-reads it every time it opens, so the `*.odin` filter checkbox is
there and checked by default.

The Inspector does not provide documentation tooltips for `@export` fields or
methods. Autocomplete shows type signatures as described above.

### Generated files are hidden in the FileSystem dock

The build writes one `odin_godot_scripts.gen.odin` registration file per
scripts directory, plus the boot shim and staleness guard. Each must live in
its package directory because Odin packages use one directory.

Generated files cannot be attached or opened as scripts in the editor. The
plugin hides them from the FileSystem dock after each dock rebuild. Godot's
filesystem scan selects by extension, so it still sees `.gen.odin` as `.odin`
and provides no per-file exclusion hook. The files remain on disk and remain
visible to external editors, git, and extension-based Find in Files.

To show them (e.g. when inspecting what scriptgen emits), set the
**`odin_godot/show_generated_files`** project setting to `true`; it takes effect at the next
dock rebuild (toggling a file save or reopening the project is enough).

Any `*.gen.odin` a build does not produce is deleted by the next one, printing
`scriptgen: removed stale <path> (not generated by this run)`. That covers a deleted script's
leftovers and, on the first build after upgrading odin_godot, the older layout's per-source
`<name>.gen.odin` files.

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
> `speed`) so shipped games are optimized. The two are independent. To remove bounds checks and assertions,
> append `-no-bounds-check -disable-assert` through `SCRIPT_BUILD_FLAGS` when
> running the export build script directly.

## Debugging

Use logging, `lldb`, and native crash backtraces to debug the scripts library.
[Debugging](debugging.md) contains the full reference and verified transcripts.
The main entry points are below.

### Logging: `gd.print` / `gd.error` / `gd.warn`

```odin
import gd "godot:godot"

gd.print("player ready")        // -> stdout + the editor Output panel
gd.print_int(score)             // i64 (also print_float / print_bool / print_value)
gd.warn("coin value was 0")     // yellow, non-fatal (push_warning)
gd.error("Hud node missing")    // RED in Output/Debugger, with context (push_error)
```

The logging helpers are `contextless` and do not import `core:fmt`, avoiding
that dependency in the wasm build. For formatted output, use Odin's `fmt`
before calling them:

```odin
import "core:fmt"
gd.print(fmt.ctprintf("score=%d", score))   // ctprintf -> temp cstring, what gd.print wants
gd.print_str(fmt.tprintf("hp=%d/%d", hp, max_hp))
```

### Native debugging with `lldb`

**Project > Tools > Debug Game (LLDB)** opens a terminal running the game under
lldb. **Debug Game (Break at Cursor)** sets a breakpoint on the script line
at the caret. **Generate VS Code Debug Config** configures VS Code/CodeLLDB
for F5 launch and clickable breakpoints in `.odin` files. The shell launcher
uses the same setup, including macOS SIP re-signing and handling lldb's `::`
parsing issue:

```sh
build/debug_game.sh --break player.odin:51 tests/showcase
```

The dlls carry full DWARF (`-debug -use-single-module`): file:line breakpoints, stepping,
and `frame variable` with typed args. `frame variable *self` prints the live script
struct, and the auto-loaded `godot_lldb.py` summaries render `godot.String`/`String_Name`/
`Variant` values. A script `panic` freezes the session at the panic site. See
[debugging.md](debugging.md) for the full tour.

### Other editors and IDEs

**Project > Tools > Generate ols.json (IDE Completion)** writes an `ols.json` at the
project root: ols-based editors (Neovim, Zed, Sublime, Helix) get completion for your
scripts + the `godot` collection immediately, and JetBrains IDEs import it via the
[Odin Support plugin](https://plugins.jetbrains.com/plugin/22933-odin-support)
(right-click the file). Rider supports editing but cannot debug native code
with the plugin on Rider ≥ 2025.2. CLion/IDEA Ultimate can, pointed at the debuggable
Godot copy. See [debugging.md](debugging.md#jetbrains-ides-rider-clion-idea-ultimate-)
for details.

### Crashes and panics are reported automatically

A crash or panic in script code is reported: an Odin `panic`/`assert` pushes a red
`ODIN_SCRIPT_PANIC <message> (file:line)` error to the **editor Output**, and a raw fatal
signal (SIGSEGV etc., e.g. an engine call on a nil handle, on macOS/Linux) prints an
`ODIN_GODOT_CRASH` report to stderr with the **faulting Odin proc symbolized**, pushes a
one-line error toward the editor, and still chains to Godot's own crash handler. See the
"What you see when the game crashes" section of [Debugging](debugging.md).

To inspect the fault, run the crashing scenario under `lldb` and use `bt`,
or read the native backtrace printed to stderr (grep it for your package name). On macOS the
same backtrace is in the `.ips` report under `~/Library/Logs/DiagnosticReports/`.

> A `_debug_get_current_stack_info` virtual is wired and produces a correct native Odin
> backtrace **when invoked**, but Godot only calls it during an active remote-debug session, so
> it does **not** automatically surface a script-line stack on a plain error. Use `lldb` for
> your day-to-day stack view. See [Debugging](debugging.md) for the full account.

### Web / wasm

In the browser there's no `dlopen`, no native stack, and no `lldb`. Debug with **logging**
(`gd.print` → the JS console) and browser devtools. See [Exporting](exporting.md).

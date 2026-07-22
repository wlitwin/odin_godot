# Script modules — splitting a project into per-module dlls

By default all of a project's Odin scripts are **one package** (`res://scripts/`) compiled
into **one scripts dll**, and for most projects that is the right shape. **Script modules**
are the opt-in scaling tool for when it stops being right: split scripts into
`res://modules/<name>/` directories, each its own Odin package compiled into its **own dll**
(`libodinscripts_<name>.dylib` / `.so` / `.dll`), loaded beside the main dll and
**hot-swapped independently**: a save recompiles only the module you edited, so
rebuild-on-save latency stays flat as the project grows.

Modules buy that flat save latency with slower full builds and a hard isolation rule. Read
the cost model first. **Most projects should not start with modules.**

## When to use modules

Every scripts dll pays a fixed compile floor of roughly **0.85 s**, because the Odin front-end
type-checks the full `godot` binding once *per dll*, no matter how few scripts the
dll holds. That floor shapes the trade:

| Project size | Modules? | Why |
|---|---|---|
| < ~50–100 scripts | **No**: pure overhead | A single-dll save is already near the floor; each module you add puts another ~0.85 s floor on every *full* build (≈2× slower at 10 modules) and buys nothing on save. |
| ~50–100+ scripts, save latency starting to hurt | Maybe | Split along real seams (enemies, UI, world-gen…) only when the single-dll save time actually bothers you. |
| Hundreds of scripts | **Yes**: this is what modules are for | Measured at 300 method-heavy scripts: a save went **4.5 s → 0.79 s (5.7×)** after splitting, and the per-save cost stays flat as the project keeps growing (you only ever rebuild the module you touched). |

(Numbers measured on the Apple-silicon macOS dev machine with the editor's `-o:none` dev
builds; your absolute times will differ, the shape won't.)

A project without a `modules/` dir loads, builds, and exports exactly as a single-dll
project. Nothing about modules is loaded, built, or exported until you create one.

## Layout and naming rules

```
your_project/
  scripts/                 -> bin/libodinscripts.dylib            (the MAIN module — always)
  modules/
    enemies/               -> bin/libodinscripts_enemies.dylib    (one dll per module)
    ui/                    -> bin/libodinscripts_ui.dylib
```

- **`res://scripts/` is the main module and always exists.** Modules are additions, not a
  replacement: a good default is gameplay glue + autoloads in `scripts/`, big subsystems in
  modules.
- **Each module is its own Odin package** with its **own package name** (`package
  game_enemies`, not a copy of the main package's name). Package names must be unique across
  the project: the web export links every module into one wasm, where two packages with the
  same name won't compile.
- **Module directory names must be dot-free.** The runtime discovers module dlls as
  `libodinscripts_<name>.<ext>` siblings of the main scripts dll and skips any `<name>`
  containing a dot (dots mark hot-reload copies). A dotted `res://modules/<name>` is an
  export error telling you to rename it.
- **Class names must be unique across all modules** (see [Collisions](#class-name-collisions)).
- **Attachable scripts live flat in the module dir** (an Odin package is one directory,
  same as `scripts/`). Subdirectories are fine as *helper packages* the module imports
  relatively; an edit anywhere under `res://modules/<name>/` counts as an edit to that
  module for rebuild-on-save. A `//gd:`-marked file in a subdirectory is never attachable.
  `scriptgen` warns about it instead of silently skipping it.
- A module dir with no `.odin` sources is skipped at build time, loudly:
  `build_scripts: skipping module '<name>' (no .odin sources)`.

### Creating a module

There is no template machinery for modules. **Project → Tools → Set Up Odin Scripts**
creates only the main `res://scripts/`. A module is a directory with a script in it, about
five lines of boilerplate, so a starter dir would be overkill. Make the directory and drop
in a script:

```sh
mkdir -p modules/enemies
```

```odin
// modules/enemies/enemy.odin
//gd:extends Node
//gd:class Enemy
package game_enemies      // the module's OWN package name — unique in the project

import gd "godot:godot"

Enemy :: struct {
	owner: gd.Node,
	hp:    gd.Int `gd:"export"`,
}

enemy_ready :: proc(self: ^Enemy) {
	if self.hp == 0 { self.hp = 10 }
}
```

Then build (`build/build_scripts.sh <project>` builds the main module *and* every module,
or just save in the editor). The required boot shim (`odin_godot_boot.gen.odin`) is
generated per module by `scriptgen`, like the main module's; there is no extra boilerplate.
Attach `res://modules/enemies/enemy.odin` to a node exactly like any other Odin script.

## No imports between script modules

A script module must not import another script module (or `scripts/`). A package linked into
two dlls gets **its package globals duplicated per dll**: each dll carries its own copy, so
writes from one module never reach the other and "shared" state forks silently. The build
rejects cross-module imports two ways: `scriptgen` checks every file's import declarations
structurally (an absolute-path import, or any relative import that resolves outside the
module's directory, is a hard error), and a fast grep for `..`-relative imports backstops it
(`check_module_isolation` in `build/common.sh`, shared by `build_scripts.sh` and
`build_export_scripts.sh`, ported in `build_scripts.ps1`):

```
build_scripts: ILLEGAL cross-module import in '<dir>':
  ...
  Script modules are ISOLATED packages: a package imported by two script dlls
  duplicates its globals per dll (shared state would silently fork). Talk to
  other modules through the engine (signals / methods / autoloads) instead,
  or move the shared state into exactly one module.
```

Odin itself would compile a cross-module `import "../enemies"` without objection. The
isolation is a build-tooling rule (scriptgen plus `build_scripts`), not a language one, so
the check is explicit and loud rather than a compiler error.

The consequences, stated plainly:

- Modules cannot share Odin types, procs, or package globals with each other.
- Cross-module communication is **engine-mediated and name-based**: signals, method calls
  by name (`gd.object_call`), autoloads.
- `rt.script_of`'s typed access **stops at the module boundary** (see below).
- Shared mutable state lives in **exactly one module** (its package globals), or in an
  **autoload**, never in a package two modules both import.

## Cross-module communication

Modules communicate through the engine. The following pair mirrors `tests/modules_spike/`
(which verifies it headless): `Player` in the main module attacks an `Enemy` from the
enemies module.

```odin
// scripts/player.odin — the MAIN module
//gd:extends Node
//gd:class Player
package game_main

import gd "godot:godot"

Player :: struct {
	owner: gd.Node,
}

// Enemy's type lives in res://modules/enemies — this module CANNOT import it.
// Call it by NAME through the engine instead (dynamic, no shared types):
@(gd_method)
player_attack :: proc(self: ^Player, target: gd.Node, amount: gd.Int) {
	amt := amount
	v := gd.variant_from_int(&amt)
	_ = gd.object_call(cast(gd.Object)target, gd.sname("take_hit"), v)
}
```

```odin
// modules/enemies/enemy.odin — the `enemies` module
//gd:extends Node
//gd:class Enemy
package game_enemies

import gd "godot:godot"

Enemy :: struct {
	owner: gd.Node,
	hp:    gd.Int `gd:"export"`,
}

// The cross-module entry point: any module (or GDScript) reaches it by name.
@(gd_method)
enemy_take_hit :: proc(self: ^Enemy, amount: gd.Int) {
	self.hp -= amount
}
```

Pick the tool by what you need:

| Need | Tool |
|---|---|
| Notify whoever cares, decoupled | **Signals**: declare in one module, `gd.connect_to(emitter, "sig", target, "method")` from anywhere; connections are engine-side and cross modules freely |
| Call a specific node's method | **Name-based call**: `gd.object_call(obj, gd.sname("take_hit"), args…)` (the `Object::call` path GDScript uses) |
| Shared game state / services | **An autoload** (see the [Authoring Guide](authoring-guide.md#autoload-singletons)): one real node at `/root/Name` every module reaches by path, or package globals in exactly ONE module fronted by its `@(gd_method)`s |
| Typed struct access | **`rt.script_of`: module-local only** (below) |

### `rt.script_of` across modules

Within a module, `rt.script_of(obj, T)` is a zero-overhead typed path. Across modules it
returns `nil`: with no cross-module imports you cannot name another module's struct type,
and the core's class check returns nil for a same-name type from another module (a node
carrying the enemies module's `Enemy` is never a non-nil `^YourEnemy`). Treat `script_of` as
"typed access to *my* module's scripts"; everything else goes through the engine. (Verified
from both sides in `tests/modules_spike/`.)

## Reload: per-module rebuild and swap

Saving a script in the editor rebuilds **only the module containing the saved file**: the
reload coordinator keeps a content hash per module and kicks one scoped build per *changed*
module, then hot-swaps just that dll. The other dlls are not rebuilt, not reloaded, not
touched. The ~0.85 s floor is paid once per save, for one module, no matter how big the rest
of the project is.

Semantics of a module swap (all asserted by `tests/modules_spike/`):

- **The swapped module:** live instances keep their state (same-layout fast path, or exported
  values preserved by name otherwise, per the normal [reload rules](workflow.md#live-editing-show-on-save)),
  and its `reload` hook fires on each instance with the new code. But the module's
  **package globals RESET**: it is a fresh dll, so its globals reinitialize.
- **Every other module:** instances keep state *and* package globals, keep running, and
  never see a reload hook. The main module's blackboard survives an enemies-module swap
  untouched.

If a module keeps meaningful state in package globals, expect it to reset when *that* module
reloads. State that must survive its owner's edit-save loop belongs on instances (exported
fields) or in an autoload in a module you aren't editing.

A compile error in a module's rebuild-on-save surfaces in the editor **Output** panel
exactly like a main-module error (the actual `path(line:col) Error: …` lines), and the old
dll stays live until a build succeeds. Editor validation squiggles and autocomplete work
per-module with no configuration: the checker overlays the edited file's own package dir,
which *is* the module.

In a running game, `load("res://modules/enemies/enemy.odin").reload(true)` swaps only the
module owning that script (the path decides: `res://modules/<name>/…` → that module,
anything else → the main module).

## Class-name collisions

Class names (`//gd:class`) must be unique across the whole project: the class map, script
attachment, and name-based calls all key on them. Collisions are never silent:

- **Native, module vs. module:** the colliding module is **rejected at load** with an error
  naming both sides, and the first module's class keeps working:

  ```
  odin_godot: script class 'Player' is defined in BOTH script module 'main (res://scripts)'
  and script module 'rogue' — class names must be unique across modules; module 'rogue' was
  NOT loaded.
  ```

  A reload that would *introduce* a collision is refused the same way, keeping the old code:
  `odin_godot: reload rejected — class 'X' in script module 'a' collides with script module
  'b' (old code kept).`

- **Within one registry (all targets):** a duplicate registration keeps the **first** and
  drops the later one, with a loud error naming the class. On **web** (where every module
  links into one wasm and shares one registry), this check *is* the cross-module check. The
  error can't attribute modules there (registration runs before module identity exists), so
  it points you at the places to look:

  ```
  duplicate class registration — this class name is already registered; the LATER
  registration is DROPPED (first wins). In one module this means two structs claim the same
  class name; on web (all script modules share one registry) it can also be a cross-module
  collision (module names are not known here — check scripts/ and each modules/<name>/)
  ```

## Exporting with modules

Nothing extra to do: at export the plugin builds **one optimized dll per module** (same
`odin_godot/export_optimization` level as the main dll) and bundles each beside the main
scripts dll (`add_shared_object`: macOS `Contents/Frameworks`, sibling of the executable
elsewhere), which is exactly where the exported game's runtime scans for
`libodinscripts_<name>.<ext>` siblings. The export log shows one line per module:
`odin export: bundled module 'enemies' (…)`.

Failures are loud, never silent:

- A module whose dll didn't get built **fails the export with an error naming it**, since an
  exported game must never silently ship without a module's classes:
  `odin export: script module 'enemies' dll missing (…) — the exported game would ship
  WITHOUT this module's classes`
- A dotted module dir name is an export error (rename it; the runtime would never discover
  its dll).

**Web** export composes the main module *and* every script module into the single
Emscripten SIDE_MODULE wasm (this is why package names must be unique). Cross-module
behavior is the same (engine-mediated calls, keep-first collisions), verified in a real
browser by `tests/modules_web/`.

### `BUILD_MODULES=0` — building without modules

Setting the `BUILD_MODULES=0` environment variable skips modules in `build_scripts.sh` /
`build_export_scripts.sh` **and** in the export plugin's bundling, loudly, since the result
lacks the module classes:

```
odin export: BUILD_MODULES=0 — script modules NOT built or bundled; the exported game will
only have the main res://scripts classes
```

It exists for scoped builds (the per-module reload rebuild uses it to build exactly one
dir), CI subsets, and bisecting, not as a shipping configuration.

## Platform support

Verified means the code path has actually been run on that platform:

| Platform | Status |
|---|---|
| macOS | ✅ **Runtime-verified**: native run, cross-module calls, per-module reload, and export all asserted headless (`tests/modules_spike/`) |
| Web | ✅ **Browser-verified**: multi-module wasm composition, cross-module call, and the keep-first collision error asserted in headless Chrome (`tests/modules_web/`) |
| Linux | Expected working (the same POSIX build/runtime code path as macOS) but **not runtime-verified** on a Linux host |
| Windows | Build + per-module reload support is present (`build/build_scripts.ps1` mirrors the bash pipeline step for step) but **unverified on Windows**: the dev machine has no PowerShell to run it |

## Troubleshooting

The messages you'll actually see, and what they mean:

| Message (abridged) | Meaning / fix |
|---|---|
| `build_scripts: ILLEGAL cross-module import in '<dir>': …` (or `scriptgen: error: … ILLEGAL cross-module import …`) | A module imports another module (any import that resolves outside the module's own directory, `..`-relative or absolute). Remove it; communicate through the engine or move the shared state into one module. |
| `odin_godot: script class 'X' is defined in BOTH script module '…' and script module '…' — … module '…' was NOT loaded.` | Class-name collision at load; the later module was rejected whole. Rename one `//gd:class`. |
| `odin_godot: reload rejected — class 'X' in script module '…' collides with script module '…' (old code kept).` | A rebuild introduced a collision; the swap was refused and the old code stays live. |
| `… duplicate class registration — … the LATER registration is DROPPED (first wins) …` | Two structs claim one class name in a single registry: same module on any target, or cross-module on web (check `scripts/` and each `modules/<name>/`). |
| `odin export: script module 'X' has a dot in its name — …` | Rename `res://modules/<X>` dot-free; the runtime only discovers dot-free module dlls. |
| `odin export: script module 'X' dll missing (…) — the exported game would ship WITHOUT this module's classes` | The module's export build failed or was skipped. Check the export log above it for the compile error. |
| `odin export: BUILD_MODULES=0 — script modules NOT built or bundled; …` | You (or a script) set `BUILD_MODULES=0`; unset it to ship modules. |
| `build_scripts: skipping module 'X' (no .odin sources)` | The `modules/X/` dir is empty: add a script or delete it. |
| A save's compile error in the editor Output | It surfaces the same way as a main-module error: fix it, and the module's old dll stays live meanwhile. |

# Script modules — splitting a project into per-module dlls

By default all of a project's Odin scripts belong to **one script module**, `res://scripts/`,
compiled into **one scripts dll**, and for most projects that is the right shape. **Script
modules** are the opt-in scaling tool for when it stops being right: split scripts into
`res://modules/<name>/` directories, each its own Odin package compiled into its **own dll**
(`libodinscripts_<name>.dylib` / `.so` / `.dll`), loaded beside the main dll and
**hot-swapped independently**: a save recompiles only the module you edited, so
rebuild-on-save latency stays flat as the project grows.

Modules buy that flat save latency with slower full builds and a hard isolation rule. Read
the cost model first. **Most projects should not start with modules.**

Two things on this page are not about splitting into dlls and apply to every project,
including one that never creates a module: [script subpackages](#script-subpackages)
(organizing one module's scripts into subfolders, still one dll) and
[`res://shared/`](#shared) (read-only packages every module may import).

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
    ui/                    -> (a subpackage of the main module: same dll)
  modules/
    enemies/               -> bin/libodinscripts_enemies.dylib    (one dll per module)
    worldgen/              -> bin/libodinscripts_worldgen.dylib
  shared/                  -> (read-only packages every module may import; no dll of its own)
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
- **A module is a tree of packages, not one flat directory.** Every subdirectory holding
  authored `.odin` sources is its own Odin package, and an engine-native script class may
  live there and be attached from there (`res://scripts/ui/hud.odin`). Kit-coupled
  declarations stay in the module root. See [Script subpackages](#script-subpackages) for
  the full rules. An edit anywhere under `res://modules/<name>/` counts as an edit to that
  module for rebuild-on-save.
- A module dir with no `.odin` sources is skipped at build time, loudly:
  `build_scripts: skipping module '<name>' (no .odin sources)`.

### Generated files

`scriptgen` writes, per module:

| File | Where | What it is |
|---|---|---|
| `odin_godot_scripts.gen.odin` | in **each package directory that has annotated scripts** (the module root, and each script subpackage) | the registration boilerplate for every script in that directory, one banner-marked section per source |
| `odin_godot_guard.gen.odin` | the module root only | the staleness guard (one compile-time `#load_hash` per authored source in the whole tree) plus the import manifest that links the script subpackages |
| `odin_godot_boot.gen.odin` | the module root only | the `odin_scripts_boot` export the core calls after it loads the dll |

You never write or edit these, and the loader ignores `*.gen.odin` as attachable scripts.
Anything else matching `*.gen.odin` under a module is swept on the next build, which is also
how a project built before the consolidated layout migrates: its old per-source
`<name>.gen.odin` files are simply deleted the first time the new `scriptgen` runs.

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
or just save in the editor). `scriptgen` generates the module's own boot shim and staleness
guard, like the main module's; there is no extra boilerplate. Attach
`res://modules/enemies/enemy.odin` to a node exactly like any other Odin script.

## Script subpackages

A module's scripts do not have to sit in one flat directory. **Every subdirectory of a module
that holds authored `.odin` sources is its own Odin package**, at any depth, and an
engine-native script class may live there:

```
scripts/                    package game_main       (the module root)
  game.odin
  ui/                       package game_ui         (a script subpackage)
    hud.odin                -> attach res://scripts/ui/hud.odin
  util/                     package game_util       (a plain helper subpackage)
    util.odin
```

This is organization, not splitting: **one dll per module, unchanged.** The root's generated
guard file carries an `import _ "ui"` manifest line per script subpackage, which is what
links each subpackage's generated registration into the module's dll. Build commands, the
`.gdextension`, and export are all untouched. It does not move the wire contract either:
`NET_FINGERPRINT` folds in the class names of the whole tree, root and subpackages alike, so
moving a class between the root and a subfolder leaves the hash — and therefore the join
door — exactly where it was.

**What a subpackage class gets.** The whole engine-native surface: `//gd:extends` /
`//gd:class` / `//gd:tool` / `//gd:icon`, lifecycle procs, `@(gd_method)`, `@(gd_connect)`,
`@(gd_rpc)`, typed signal fields with their generated emitters, `gd:"export"` fields and
their hints, and `gd:"onready=…"` references. A subdirectory with no annotated scripts is
just a helper package as before, and gets no generated file at all.

**What must stay in the module root.** Every **kit** declaration: `gd:"replicate"`,
`gd:"owner"`, `gd:"predict"`, `gd:"backup"` and `gd:"profile="` field tags, `entity=` scene
fields, a `net_id` field, `@(gd_command)`, `@(gd_tick)`, `@(gd_sample)`, `@(gd_step)`,
`@(gd_message)`, `@(gd_fact)`, session and succession halves, the sim lane's input class, and
a `kboot.Boot` field. The reason is the wire contract: a module's kit surface (replicated
field order, verb ids, entity type ids, the one tick input struct, the fact tuples) folds
into `NET_FINGERPRINT`, which two peers compare at the join door, and it is resolved
package-wide in the module root. A lane or a verb hiding in a subfolder would leave the
fingerprint silently short of it, so `scriptgen` refuses it by name:

```
scriptgen: error: scripts/ui/hud.odin: Hud declares a gd:"replicate" field tag in the script
subpackage "ui" — kit wiring is part of the MODULE's wire contract (fingerprint, lanes, input
struct) and is game-coupled; move this file to the module root (…). Subfolders like ui/ hold
engine-native script classes: extends/class, methods, signals, exports, onready, rpc
```

**A subpackage may not import the module root.** The root already imports every script
subpackage through its manifest, so an import back up is always a cycle. Rather than let Odin
report the cycle from inside generated code, `scriptgen` names it and the ways out:

```
scriptgen: error: scripts/ui/hud.odin:6: a subfolder script package cannot import the module
root (".." resolves to …/scripts) — the root's generated import manifest already imports every
script subpackage, so this is an import CYCLE
  Subfolders hold engine-native script classes and helpers; they are LEAVES of the
  module. Anything that needs the module root's types or state is game-coupled and
  belongs in the module root itself. To share the other way, move the shared code
  DOWN into a subpackage both the root and the subfolder import (sibling subpackage
  imports are legal), or pass what it needs in as an argument.
```

**Uniqueness.** Every package in a module tree needs its own `package` name (on web export
they all link into one wasm side module, where the package name is the symbol prefix), and
`//gd:class` names must be unique across the whole tree, since the runtime registry is keyed
by name alone and keeps the first registration. Both are build-time errors naming both
declaring locations:

```
scriptgen: error: duplicate package name "game_main" — declared in both ".../scripts" and
".../scripts/ui"; every package in a module tree needs its OWN name (on web export they all
link into one wasm side module, where the package name is the symbol prefix)

scriptgen: error: .../scripts/ui/hud.odin: duplicate //gd:class "Game" (also declared in
".../scripts/game.odin")
```

**Typed access still works inside the module.** All the packages of one module share a dll,
so the root can `import "ui"` and read a subpackage's script struct directly:
`rt.script_of(node, ui.Hud)` returns a typed `^ui.Hud`. The boundary that returns `nil` is
the *module* boundary, not the package boundary (see
[`rt.script_of` across modules](#rtscript_of-across-modules)).

Note what the import binds. Odin names a relative import after the **last element of its
path**, not after the package's declared name: `import "ui"` binds `ui` even though the
package above declares itself `package game_ui`, and `import "defs"` binds `defs`. Give it
whatever name you want with an alias — `import d "defs"`.

**When to reach for a subpackage.** Use one when a group of classes is self-contained and the
module root does not need to name their types: HUD widgets, menus, editor tools, effects.
Keep everything else flat. A subpackage is not a scaling tool (the save still rebuilds the
whole module dll); the scaling tool is a module.

`tests/subpkg_spike/` is the worked example, including the four refusals above.

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
  For types, constants and pure procs — a vocabulary with no state to fork —
  put the package under '<project>/shared' instead: any module may import it, and
  scriptgen verifies that tree stays state-free.
```

Odin itself would compile a cross-module `import "../enemies"` without objection. The
isolation is a build-tooling rule (scriptgen plus `build_scripts`), not a language one, so
the check is explicit and loud rather than a compiler error.

The consequences, stated plainly:

- Modules cannot share Odin types, procs, or package globals with each other, except through
  the [`res://shared/`](#shared) tree, which is verified to hold no state.
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
| Shared types, constants, pure procs | **A [`res://shared/`](#shared) package**: imported directly by every module, verified state-free |
| Typed struct access | **`rt.script_of`: module-local only** (below) |

### `rt.script_of` across modules

Within a module, `rt.script_of(obj, T)` is a zero-overhead typed path, and that includes the
module's [subpackages](#script-subpackages), which share its dll: the root can
`import "ui"` and call `rt.script_of(node, ui.Hud)`. Across modules it returns `nil`: with no
cross-module imports you cannot name another module's struct type, and the core's class check
returns nil for a same-name type from another module (a node carrying the enemies module's
`Enemy` is never a non-nil `^YourEnemy`). Treat `script_of` as "typed access to *my* module's
scripts"; everything else goes through the engine. (Verified from both sides in
`tests/modules_spike/`.)

<a name="shared"></a>
## `res://shared/` — vocabulary every module can import

The isolation rule exists for one hazard: a package linked into two dlls gets its own copy of
every **mutable package global**, so a write through one module's copy is invisible to the
other. Duplicated types, constants and pure procs carry no such hazard. Two copies of an enum,
a payload struct or a `clamp01` proc are indistinguishable.

So one tree is exempt. **Any package under `<project>/shared/` may be imported by any script
module**, the main one or a `modules/<name>` one, from the module root or from a subpackage,
at any depth. It is an ordinary relative import; what matters is where it resolves, not how
many `..` segments it takes:

```
your_project/
  shared/
    ids/ids.odin            package shared_ids
  scripts/
    game.odin               import ids "../shared/ids"
    ui/hud.odin             import ids "../../shared/ids"
  modules/
    enemies/enemy.odin      import ids "../../shared/ids"
```

```odin
// shared/ids/ids.odin — read-only vocabulary: types, constants, pure procs.
package shared_ids

Kind :: enum u8 {None = 0, Player = 1, Enemy = 2}

STEP :: 7

Payload :: struct {
	kind:   Kind,
	amount: i32,
}

brand :: proc(k: Kind) -> int {return int(k) * 100 + STEP}
```

There is no dll for `shared/`. Each module that imports a shared package compiles its own copy
into its own dll, which is exactly why the tree must stay state-free.

### The rules, and what refuses them

`scriptgen` parses every shared package a module actually imports (following shared-to-shared
imports transitively, so a package nothing imports is nobody's business) and refuses these,
naming the file, the line, and the reason:

| Not allowed in `shared/` | Why | The refusal (abridged) |
|---|---|---|
| a file-scope mutable variable (`x := …`, `x: T`, including `@(thread_local)`) | it is the per-dll copy the isolation rule exists for | `declares the file-scope variable "counter" — every module that links this package gets its OWN copy of it, so writes from one module never reach the other and the state silently forks. Constants (counter :: …), types and pure procs are fine here` |
| an `@(static)` local | package state with a proc-local spelling | `declares an @(static) local — that is package STATE with a proc-local spelling, and every module that links this package gets its own copy` |
| `@(init)` / `@(fini)` | it would run once **per dll** | `declares the @(init) proc "setup" — it would run ONCE PER DLL (every module that links this package runs it again, over that dll's own copy of the package)` |
| a `//gd:` marker or an `@(gd_*)` proc | an attachable class belongs to a module; `shared/` is engine-agnostic | `carries the script marker "//gd:class Sneaky" — an attachable script class belongs to a MODULE (res://scripts or res://modules/<name>), never to res://shared/` |
| importing anything but a collection (`godot:` / `core:` / `base:` / `vendor:`) or another `shared/` package | importing a module from here IS the forked-globals hazard: that module's package would link into every dll | `imports "../../modules/other", which resolves to "…/modules/other" OUTSIDE the shared tree (…)` |

Every one of them ends with the same explanation:

```
  res://shared/ is READ-ONLY VOCABULARY: types, constants (X :: …) and pure procs.
  It is linked into EVERY module that imports it, and each dll gets its own copy of
  any package state — so mutable globals there would silently fork per module. Keep
  state in exactly one module (or behind an autoload the modules reach through the
  engine); keep the vocabulary they agree on here.
```

One more limitation, refused loudly rather than silently: a struct carrying `gd:"…"` tags
cannot be embedded from `shared/`. `scriptgen` resolves tagged bundles inside the module's own
package tree and in `godot:` collection packages only, so tags on a shared struct's fields
would never register. An untagged plain-data struct from `shared/` is fine.

### Reload: one shared edit rebuilds every module

The shared tree belongs to no module, so its content hash is folded into **every** module's:
saving a file under `res://shared/` rebuilds and hot-swaps **every** module dll, each firing
its own `reload` hooks and resetting its own package globals. That is correct (any module may
be compiled against what you changed) and it is the cost of putting something there: the flat
per-save latency modules buy you does not apply to a shared edit. A project with no `shared/`
directory behaves exactly as before.

### Choosing between `shared/`, an autoload, and one module's globals

| You need | Use |
|---|---|
| types, enums, constants, pure functions that several modules must agree on | **a `shared/` package**: a direct import, no engine round trip, no runtime cost |
| mutable state several modules read and write | **an autoload** (a real node at `/root/Name`, reached by name through the engine), or **package globals in exactly one module** fronted by its `@(gd_method)`s |
| state, types and helpers only one module uses | **that module's own package**, or a plain helper subpackage inside it |

The dividing line is state. If it can be written at runtime, it does not belong in `shared/`,
and `scriptgen` will say so at build time rather than let two dlls disagree at play time.
`tests/shared_spike/` is the worked example: two dlls, one vocabulary, plus each refusal above.

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

The one edit that is not scoped to a single module is an edit under
[`res://shared/`](#shared): it rebuilds and swaps every module, because any of them may be
compiled against it.

A compile error in a module's rebuild-on-save surfaces in the editor **Output** panel
exactly like a main-module error (the actual `path(line:col) Error: …` lines), and the old
dll stays live until a build succeeds. Editor validation squiggles and autocomplete work with
no configuration for every file in the tree: a module root, a subpackage, and a `shared/`
package all diagnose against the packages they really import.

In a running game, `load("res://modules/enemies/enemy.odin").reload(true)` swaps only the
module owning that script (the path decides: `res://modules/<name>/…` → that module,
anything else → the main module).

## Class-name collisions

Class names (`//gd:class`) must be unique across the whole project: the class map, script
attachment, and name-based calls all key on them. Collisions are never silent:

- **Within one module (build time):** `scriptgen` refuses two identical `//gd:class` names
  anywhere in a module's tree, root and subpackages together, naming both files:
  `scriptgen: error: …/ui/hud.odin: duplicate //gd:class "Game" (also declared in
  ".../scripts/game.odin")`.
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
Emscripten SIDE_MODULE wasm, subpackages and imported `shared/` packages included (this is
why package names must be unique across the whole project, not just per module). Cross-module
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
| macOS | ✅ **Runtime-verified**: native run, cross-module calls, per-module reload, and export all asserted headless (`tests/modules_spike/`); script subpackages (`tests/subpkg_spike/`) and the shared tree, including the rebuild-every-module edit (`tests/shared_spike/`), likewise |
| Web | ✅ **Browser-verified**: multi-module wasm composition, cross-module call, and the keep-first collision error asserted in headless Chrome (`tests/modules_web/`) |
| Linux | Expected working (the same POSIX build/runtime code path as macOS) but **not runtime-verified** on a Linux host |
| Windows | Build + per-module reload support is present (`build/build_scripts.ps1` mirrors the bash pipeline step for step) but **unverified on Windows**: the dev machine has no PowerShell to run it |

## Troubleshooting

The messages you'll actually see, and what they mean:

| Message (abridged) | Meaning / fix |
|---|---|
| `build_scripts: ILLEGAL cross-module import in '<dir>': …` (or `scriptgen: error: … ILLEGAL cross-module import …`) | A module imports another module (any import that resolves outside the module's own directory and outside `shared/`, `..`-relative or absolute). Remove it; communicate through the engine, move the shared state into one module, or, if it is only types/constants/pure procs, move the package under [`res://shared/`](#shared). |
| `scriptgen: error: …: <Class> declares <what> in the script subpackage "<dir>" — kit wiring is part of the MODULE's wire contract …` | A kit declaration (a lane tag, `@(gd_command)`, `@(gd_tick)`, an `entity=` field, a half, …) sits in a subfolder. Move that file to the module root; subfolders hold engine-native classes only. |
| `scriptgen: error: …: a subfolder script package cannot import the module root (…) — … this is an import CYCLE` | A script subpackage imports `..`. Move the shared code down into a subpackage both sides import (sibling imports are legal), or pass what it needs in as an argument. |
| `scriptgen: error: duplicate package name "X" — declared in both "…" and "…"` | Two directories in one module tree declare the same `package` name. Give each its own. |
| `scriptgen: error: …: duplicate //gd:class "X" (also declared in "…")` | Two scripts in one module tree claim one class name (the root and a subpackage count as one tree). Rename one. |
| `scriptgen: error: …: the shared package file <f> declares the file-scope variable "x" …` (also `@(static)`, `@(init)`/`@(fini)`, a `//gd:` marker, an `@(gd_*)` proc) | A package under `res://shared/` carries state or a script. Keep state in exactly one module or an autoload; `shared/` is types, constants and pure procs. See [`res://shared/`](#shared). |
| `scriptgen: error: …: the shared package file <f> imports "…", which resolves to "…" OUTSIDE the shared tree (…)` | A shared package imports a module (or any other outside package). It may import collections and other `shared/` packages only. |
| `scriptgen: error: …: X.y: "…" comes from the SHARED package "…" — … scriptgen does not resolve gd:"…"-tagged BUNDLES across it` | A `gd:`-tagged struct was embedded from `shared/`. Move the tagged bundle into the module (or a `godot:` collection package); untagged plain data from `shared/` is fine. |
| `scriptgen: error: …: odin_scripts_boot is declared in the subpackage "…" — the boot export is ONE per dll …` | A hand-written boot shim ended up in a subfolder. Move it to the module root. |
| `odin_godot: script class 'X' is defined in BOTH script module '…' and script module '…' — … module '…' was NOT loaded.` | Class-name collision at load; the later module was rejected whole. Rename one `//gd:class`. |
| `odin_godot: reload rejected — class 'X' in script module '…' collides with script module '…' (old code kept).` | A rebuild introduced a collision; the swap was refused and the old code stays live. |
| `… duplicate class registration — … the LATER registration is DROPPED (first wins) …` | Two structs claim one class name in a single registry: same module on any target, or cross-module on web (check `scripts/` and each `modules/<name>/`). |
| `odin export: script module 'X' has a dot in its name — …` | Rename `res://modules/<X>` dot-free; the runtime only discovers dot-free module dlls. |
| `odin export: script module 'X' dll missing (…) — the exported game would ship WITHOUT this module's classes` | The module's export build failed or was skipped. Check the export log above it for the compile error. |
| `odin export: BUILD_MODULES=0 — script modules NOT built or bundled; …` | You (or a script) set `BUILD_MODULES=0`; unset it to ship modules. |
| `build_scripts: skipping module 'X' (no .odin sources)` | The `modules/X/` dir is empty: add a script or delete it. |
| A save's compile error in the editor Output | It surfaces the same way as a main-module error: fix it, and the module's old dll stays live meanwhile. |

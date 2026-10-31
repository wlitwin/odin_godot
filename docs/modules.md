# Script modules — splitting a project into per-module dlls

By default, a project's Odin scripts compile into one library from
`res://scripts/`. If rebuilding it becomes too slow, split subsystems into
`res://modules/<name>/` directories. Each module compiles into a separate
`libodinscripts_<name>.dylib` / `.so` / `.dll`, loaded beside the main scripts
dll. Saving a script recompiles and hot-swaps its module independently.

Modules reduce scoped rebuild time but add full-build work and prohibit direct
imports between modules. Keep one scripts dll until measured save latency
justifies that tradeoff. The cost model below explains when splitting helps.

For organization within one dll, use [script subpackages](#script-subpackages).
For types, constants, and pure procedures several modules can import, use
[`res://shared/`](#shared). Both are available without creating extra modules.

## When to use modules

The measured minimum compile time is roughly 0.85 s per scripts dll. Odin
checks the full `godot` binding separately for each dll even when it contains
few scripts. Additional modules therefore add work to full builds:

| Project size | Modules? | Why |
|---|---|---|
| < ~50–100 scripts | Usually keep one dll | A single-dll save is already near the minimum. Each extra module adds ~0.85 s to a full build (≈2× slower at 10 modules in the measured case), with little save-time benefit. |
| ~50–100+ scripts, save latency starting to hurt | Measure before splitting | Group related scripts, such as enemies, UI, or world generation, when single-dll save latency becomes a problem. |
| Hundreds of scripts | A split can reduce save latency | With 300 method-heavy scripts, measured save time fell from 4.5 s → 0.79 s (5.7×) after splitting. A scoped save rebuilds the edited module, so its cost depends on that module rather than the rest of the project. |

These measurements used the Apple-silicon macOS development machine and the
editor's `-o:none` builds. Measure your project and machine before choosing
module boundaries.

A project without a `modules/` directory retains single-dll loading, builds,
and export. Additional module work begins only after a module is created.

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

- **Keep `res://scripts/` as the main module.** Additional modules supplement it.
  Keep game coordination and autoloads in `scripts/` and move large subsystems
  into their own modules when needed.
- **Each module has a root Odin package** with its own package name (`package
  game_enemies`, not a copy of the main package's name). Package names must be unique across
  the project: the web export links every module into one wasm, where two packages with the
  same name won't compile.
- **Module directory names must be dot-free.** The runtime discovers module dlls as
  `libodinscripts_<name>.<ext>` siblings of the main scripts dll and skips any `<name>`
  containing a dot (dots mark hot-reload copies). A dotted `res://modules/<name>` is an
  export error telling you to rename it.
- **Authored source paths are runtime identity.** Only explicit `//gd:class` global aliases
  must be unique across modules (see [Collisions](#global-class-alias-collisions)).
- **A module is a tree of packages, not one flat directory.** Every subdirectory holding
  authored `.odin` sources is its own Odin package, and an engine-native script class may
  live there and be attached from there (`res://scripts/ui/hud.odin`). Kit-coupled
  declarations stay in the module root. See [Script subpackages](#script-subpackages) for
  the full rules. An edit anywhere under `res://modules/<name>/` counts as an edit to that
  module for rebuild-on-save.
- An empty module directory is skipped during the build with this message:
  `build_scripts: skipping module '<name>' (no .odin sources)`.

### Generated files

`scriptgen` writes, per module:

| File | Where | What it is |
|---|---|---|
| `odin_godot_scripts.gen.odin` | in **each package directory that has annotated scripts** (the module root, and each script subpackage) | the registration boilerplate for every script in that directory, one banner-marked section per source |
| `odin_godot_guard.gen.odin` | the module root only | the staleness guard (one compile-time `#load_hash` per authored source in the whole tree) plus the import manifest that links the script subpackages |
| `odin_godot_boot.gen.odin` | the module root only | the `odin_scripts_boot` export the core calls after it loads the dll |

The build owns these files, and the loader ignores `*.gen.odin` as attachable
scripts. Each build removes other `*.gen.odin` files under the module, including
obsolete per-source `<name>.gen.odin` outputs. Keep authored source outside this
filename pattern.

### Creating a module

**Project → Tools → Set Up Odin Scripts** creates the main `res://scripts/`
directory. To add a module, create its directory and write a script with its
own package name:

```sh
mkdir -p modules/enemies
```

```odin
// modules/enemies/enemy.odin
//gd:extends Node
//gd:class Enemy
package game_enemies      // package name must be unique within the project

import gd "godot:godot"

Enemy :: struct {
	owner: gd.Node,
	hp:    gd.Int `gd:"export"`,
}

enemy_ready :: proc(self: ^Enemy) {
	if self.hp == 0 { self.hp = 10 }
}
```

Run `build/build_scripts.sh <project>` to build the main module and additional
modules, or save in the editor. `scriptgen` generates each module's boot shim
and staleness guard. Attach `res://modules/enemies/enemy.odin` to a node as you
would any other Odin script.

## Script subpackages

Organize a module into subpackages by placing authored `.odin` files in
subdirectories. Each source directory is an Odin package at any depth, and may
declare engine-native script classes:

```
scripts/                    package game_main       (the module root)
  game.odin
  ui/                       package game_ui         (a script subpackage)
    hud.odin                -> attach res://scripts/ui/hud.odin
  util/                     package game_util       (a plain helper subpackage)
    util.odin
```

Subpackages still compile into their module's single dll. The root's generated
guard file contains an import manifest, with entries such as `import _ "ui"`,
that links each script subpackage's generated registration. Build commands,
the `.gdextension`, and export remain the same.

`NET_FINGERPRINT` includes class names from the whole tree. Moving a class
between the root and a subfolder therefore leaves its contribution to the
fingerprint unchanged, preserving network compatibility for that move.

**Supported subpackage declarations.** Engine-native classes can use: `//gd:extends` /
`//gd:class` / `//gd:tool` / `//gd:icon`, lifecycle procs, `@(gd_method)`, `@(gd_connect)`,
`@(gd_rpc)`, typed signal fields with their generated emitters, `gd:"export"` fields and
their hints, and `gd:"onready=…"` references. A subdirectory with no annotated scripts is
a helper package and receives no generated registration file.

**What must stay in the module root.** Every **kit** declaration: `gd:"replicate"`,
`gd:"owner"`, `gd:"predict"`, `gd:"backup"` and `gd:"profile="` field tags, `entity=` scene
fields, a `net_id` field, `@(gd_command)`, `@(gd_tick)`, `@(gd_input)`, `@(gd_sample)`, `@(gd_step)`,
`@(gd_message)`, `@(gd_event)`, session and succession halves, the sim lane's input class, and
a `kboot.Boot` field. Scriptgen resolves Kit declarations in the module root
to construct `NET_FINGERPRINT`, including replicated field order, command ids,
entity type ids, tick input structs, and event tuples. Peers compare that
fingerprint during admission. A Kit declaration in a subfolder would fall
outside that resolution, so `scriptgen` rejects it with the class and field
or attribute name:

```
scriptgen: error: scripts/ui/hud.odin: Hud declares a gd:"replicate" field tag in the script
subpackage "ui" — kit wiring is part of the MODULE's wire contract (fingerprint, lanes, input
struct) and is game-coupled; move this file to the module root (…). Subfolders like ui/ hold
engine-native script classes: extends/class, methods, signals, exports, onready, rpc
```

**A subpackage may not import the module root.** The root's generated manifest
already imports every script subpackage, so a reverse import creates a cycle.
`scriptgen` reports the authored import and suggests moving shared code to a
sibling subpackage or passing data as an argument:

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
explicit `//gd:class` aliases must be unique across the whole tree because they opt into
Godot's project-wide global type namespace. Marker-less scripts are keyed by their
`res://` paths and need no name uniqueness. Both package-name and explicit-alias conflicts
are build-time errors naming both declaring locations:

```
scriptgen: error: duplicate package name "game_main" — declared in both ".../scripts" and
".../scripts/ui"; every package in a module tree needs its OWN name (on web export they all
link into one wasm side module, where the package name is the symbol prefix)

scriptgen: error: .../scripts/ui/hud.odin: duplicate explicit //gd:class "Game" in
".../scripts/game.odin" and ".../scripts/ui/hud.odin"
```

**Typed access still works inside the module.** All the packages of one module share a dll,
so the root can `import "ui"` and read a subpackage's script struct directly:
`rt.script_of(node, ui.Hud)` returns a typed `^ui.Hud`. The boundary that returns `nil` is
the *module* boundary, not the package boundary (see
[`rt.script_of` across modules](#rtscript_of-across-modules)).

Odin binds a relative import using the last path element. `import "ui"`
therefore binds `ui` even when the imported package declares `package game_ui`;
`import "defs"` binds `defs`. Choose another binding with an explicit alias,
such as `import d "defs"`.

**When to use a subpackage.** Group related engine-native classes such as HUD
widgets, menus, editor tools, and effects. A save still rebuilds the whole
module dll. Use a separate module when the goal is to reduce the amount of
code rebuilt on save.

`tests/subpkg_spike/` is the worked example, including the four refusals above.

## No imports between script modules

A script module must not import another script module or `scripts/`. Linking
a package into two dlls duplicates its package globals, so a write through one
dll is invisible through the other.

The build checks imports in two places. `scriptgen` examines declarations and
rejects absolute or relative imports resolving outside the module's allowed
directories. A `..`-relative import scan provides an additional check through
`check_module_isolation` in `build/common.sh`, used by `build_scripts.sh` and
`build_export_scripts.sh` and ported to `build_scripts.ps1`:

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

Odin permits imports such as `import "../enemies"`. The SDK's `scriptgen`
and `build_scripts` enforce module isolation to prevent duplicated state.
Follow these rules:

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
// scripts/player.odin — the main module
//gd:extends Node
//gd:class Player
package game_main

import gd "godot:godot"

Player :: struct {
	owner: gd.Node,
}

// Enemy's type lives in res://modules/enemies and cannot be imported here.
// Use a dynamic engine call by method name without importing its type:
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

Choose a communication mechanism according to the data being exchanged:

| Need | Tool |
|---|---|
| Notify subscribed receivers | **Signals**: declare in one module, `gd.connect_to(emitter, "sig", target, "method")` from anywhere; connections are engine-side and cross modules freely |
| Call a specific node's method | **Name-based call**: `gd.object_call(obj, gd.sname("take_hit"), args…)` (the `Object::call` path GDScript uses) |
| Shared game state / services | **An autoload** (see the [Authoring Guide](authoring-guide.md#autoload-singletons)): one real node at `/root/Name` every module reaches by path, or package globals in exactly one module fronted by its `@(gd_method)`s |
| Shared types, constants, pure procs | **A [`res://shared/`](#shared) package**: imported directly by every module, verified state-free |
| Typed struct access | **`rt.script_of`: module-local only** (below) |

### `rt.script_of` across modules

Use `rt.script_of(obj, T)` for typed access without dispatch overhead within
one module, including its [subpackages](#script-subpackages). The root can `import "ui"` and call
`rt.script_of(node, ui.Hud)` because both packages share the dll.

Across modules, `script_of` returns `nil` when the core's class check finds a
same-name type from another module. A node with the enemies module's `Enemy` cannot resolve as
`^YourEnemy` from another module, and import isolation prevents directly naming
the original type. Use engine calls across that boundary. `tests/modules_spike/`
verifies the refusal from both modules.

<a name="shared"></a>
<a id="resshared--vocabulary-every-module-can-import"></a>

## `res://shared/` — types, constants, and pure procedures

Several modules can safely compile separate copies of types, constants, and
pure procedures because those declarations contain no mutable package state.
For example, copies of an enum, payload struct, or `clamp01` procedure do not
need to exchange runtime writes.

Put those declarations under `<project>/shared/`. The main module and any
`modules/<name>` module may import shared packages, including from nested
subpackages. Use an ordinary relative import; scriptgen checks its resolved
path regardless of the number of `..` segments:

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
// shared/ids/ids.odin — shared types, constants, and pure procs.
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

<a id="the-rules-and-what-refuses-them"></a>

### Shared-package restrictions and diagnostics

`scriptgen` validates shared packages imported by a module, following imports
between shared packages transitively. Unimported packages are not checked.
Each prohibited declaration produces a file, line, and reason:

| Not allowed in `shared/` | Why | The refusal (abridged) |
|---|---|---|
| a file-scope mutable variable (`x := …`, `x: T`, including `@(thread_local)`) | each dll would receive a separate mutable variable | `declares the file-scope variable "counter" — every module that links this package gets its OWN copy of it, so writes from one module never reach the other and the state silently forks. Constants (counter :: …), types and pure procs are fine here` |
| an `@(static)` local | a persistent local is mutable package state | `declares an @(static) local — that is package STATE with a proc-local spelling, and every module that links this package gets its own copy` |
| `@(init)` / `@(fini)` | it would run once **per dll** | `declares the @(init) proc "setup" — it would run ONCE PER DLL (every module that links this package runs it again, over that dll's own copy of the package)` |
| a `//gd:` marker or an `@(gd_*)` proc | an attachable class belongs to a module; `shared/` is engine-agnostic | `carries the script marker "//gd:class Sneaky" — an attachable script class belongs to a MODULE (res://scripts or res://modules/<name>), never to res://shared/` |
| importing anything but a collection (`godot:` / `core:` / `base:` / `vendor:`) or another `shared/` package | an outside module package would be linked into every importing dll | `imports "../../modules/other", which resolves to "…/modules/other" OUTSIDE the shared tree (…)` |

Every one of them ends with the same explanation:

```
  res://shared/ is READ-ONLY VOCABULARY: types, constants (X :: …) and pure procs.
  It is linked into EVERY module that imports it, and each dll gets its own copy of
  any package state — so mutable globals there would silently fork per module. Keep
  state in exactly one module (or behind an autoload the modules reach through the
  engine); keep the vocabulary they agree on here.
```

A struct with `gd:"…"` field tags cannot be embedded from `shared/`.
`scriptgen` resolves tagged bundles only within the module's package tree and
`godot:` collection packages. Tags from a shared struct would not register,
so the generator rejects them. Untagged plain-data structs are supported.

Plain shared types may also be aliases, including generic runtime owners such as
`Timeline :: replay.Timeline(World, Input, Event)`. Scriptgen follows the named
shape and its inline fields before deciding that no Godot metadata would be lost.
Generic arguments retain the package/import context where they were supplied;
aliases cannot hide tagged fields, typed signals or composed methods/ticks. Cyclic,
unresolved or over-budget shapes keep the existing refusal. An engine-import
normalization context that collides with a user package named `gd` is also refused
conservatively; use an unambiguous import alias. The proof is bounded
to 64 nested resolutions and 4,096 visited type expressions per candidate.
Pointer/container/callback boundaries retain the existing opaque composition
policy; this does not add automatic hoisting through arrays or pointers.

Accepting a runtime-owner alias does not make that owner copyable or serializable.
For example, Replay Timeline allocations still have one owner and must be used by
pointer. The pure shared package remains subject to the same no-globals/no-script
rules. See [focused and application acceptance](../tests/replay_shared_alias/README.md).


### Reload: one shared edit rebuilds every module

Every module's content hash includes the shared tree. Saving a file under
`res://shared/` therefore rebuilds and hot-swaps every module dll, calls each
module's `reload` hooks, and resets each module's package globals. A shared
edit pays the full rebuild cost because any module may depend on the changed
declarations. Projects without a `shared/` directory retain ordinary scoped
reload behavior.

### Choosing between `shared/`, an autoload, and one module's globals

| You need | Use |
|---|---|
| types, enums, constants, pure functions that several modules must agree on | **a `shared/` package**: declarations compile directly into each importing dll |
| mutable state several modules read and write | **an autoload** (a real node at `/root/Name`, reached by name through the engine), or **package globals in exactly one module** fronted by its `@(gd_method)`s |
| state, types and helpers only one module uses | **that module's own package**, or a plain helper subpackage inside it |

Keep mutable package state outside `shared/`; `scriptgen` rejects it during
the build. `tests/shared_spike/` demonstrates two dlls using shared declarations
and exercises each refusal above.

## Reload: per-module rebuild and swap

On an editor save, the reload coordinator maps the resource path to its module
root, hashes that root, and starts a scoped build if its content changed. It
then hot-swaps that dll while other modules continue running. A background
probe establishes initial hashes; less frequent full checks detect edits and
deletions made outside the editor. An ordinary save pays the ~0.85 s minimum
compile cost for one module, plus the cost of that module's scripts.

Semantics of a module swap (all asserted by `tests/modules_spike/`):

- **The swapped module:** live instances keep their state (same-layout fast path, or exported
  values preserved by name otherwise, per the normal [reload rules](workflow.md#live-editing-show-on-save)),
  and its `reload` hook fires on each instance with the new code. But the module's
  package globals reset because loading a fresh dll reinitializes them.
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

## Global-class alias collisions

Script attachment, typed access, and reload key on canonical `res://` paths, so ordinary
scripts do not need globally unique names. An explicit `//gd:class` opts into Godot's
project-wide global type namespace and therefore must be unique. Collision
handling depends on where it is detected:

- **Within one module (build time):** `scriptgen` refuses two identical `//gd:class` names
  anywhere in a module's tree, root and subpackages together, naming both files:
  `scriptgen: error: …/ui/hud.odin: duplicate explicit //gd:class "Game" in
  ".../scripts/game.odin" and ".../scripts/ui/hud.odin"`.
- **Native, module vs. module:** the colliding module is **rejected at load** with an error
  naming both sides, and the first module's class keeps working:

  ```
  odin_godot: duplicate explicit //gd:class 'Player' in 'res://scripts/player.odin' and
  'res://modules/rogue/rogue.odin' (script modules 'main (res://scripts)' and 'rogue');
  module 'rogue' was NOT loaded.
  ```

  A reload that would *introduce* a collision is refused the same way, keeping the old code:
  `odin_godot: reload rejected — explicit //gd:class 'X' in 'res://modules/a/x.odin'
  collides with 'res://modules/b/x.odin' from script module 'b' (old code kept).`

- **Web composed manifest:** all modules share one manifest. Both descriptors remain
  independently path-addressable, but the duplicate global alias is refused with both
  canonical paths:

  ```
  odin_godot: duplicate explicit //gd:class 'Contested' in
  'res://modules/enemies/contested.odin' and 'res://scripts/contested.odin'; both scripts
  remain path-addressable, but the global alias is ambiguous.
  ```

## Exporting with modules

During export, the plugin builds one optimized dll per module using the main
dll's `odin_godot/export_optimization` setting. It bundles each with
`add_shared_object` beside the main scripts dll: in macOS `Contents/Frameworks`
or beside the executable on other platforms. The runtime scans that location
for `libodinscripts_<name>.<ext>`. Each bundled module produces a log line:
`odin export: bundled module 'enemies' (…)`.

The plugin rejects incomplete module exports:

- A module whose dll didn't get built **fails the export with an error naming it**, since an
  exported game must never silently ship without a module's classes:
  `odin export: script module 'enemies' dll missing (…) — the exported game would ship
  WITHOUT this module's classes`
- A dotted module dir name is an export error (rename it; the runtime would never discover
  its dll).

**Web** export composes the main module *and* every script module into the single
Emscripten SIDE_MODULE wasm, subpackages and imported `shared/` packages included (this is
why package names must be unique across the whole project, not just per module). Cross-module
behavior is the same (engine-mediated calls, keep-first collisions), verified
in a browser by `tests/modules_web/`.

### `BUILD_MODULES=0` — building without modules

Setting the `BUILD_MODULES=0` environment variable skips modules in `build_scripts.sh` /
`build_export_scripts.sh` and disables module bundling in the export plugin.
The log warns that module classes are absent:

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
| Windows | Build + per-module reload support is present. `tests/build_helpers/` executes the real PowerShell pipeline and verifies parity with Bash for modules, cache invalidation, cleanup, failure recovery, flags, and concurrent publication; native MSVC/runtime execution still needs a Windows host |

## Troubleshooting

Use the diagnostic text to identify the source declaration or build setting:

| Message (abridged) | Meaning / fix |
|---|---|
| `build_scripts: ILLEGAL cross-module import in '<dir>': …` (or `scriptgen: error: … ILLEGAL cross-module import …`) | A module imports another module (any import that resolves outside the module's own directory and outside `shared/`, `..`-relative or absolute). Remove it; communicate through the engine, move the shared state into one module, or, if it is only types/constants/pure procs, move the package under [`res://shared/`](#shared). |
| `scriptgen: error: …: <Class> declares <what> in the script subpackage "<dir>" — kit wiring is part of the MODULE's wire contract …` | A kit declaration (a lane tag, `@(gd_command)`, `@(gd_tick)`, an `entity=` field, a half, …) sits in a subfolder. Move that file to the module root; subfolders hold engine-native classes only. |
| `scriptgen: error: …: a subfolder script package cannot import the module root (…) — … this is an import CYCLE` | A script subpackage imports `..`. Move the shared code down into a subpackage both sides import (sibling imports are legal), or pass what it needs in as an argument. |
| `scriptgen: error: duplicate package name "X" — declared in both "…" and "…"` | Two directories in one module tree declare the same `package` name. Give each its own. |
| `scriptgen: error: …: duplicate explicit //gd:class "X" in "…" and "…"` | Two scripts in one module tree claim one optional global alias. Rename or remove one marker; both scripts otherwise bind by path. |
| `scriptgen: error: …: the shared package file <f> declares the file-scope variable "x" …` (also `@(static)`, `@(init)`/`@(fini)`, a `//gd:` marker, an `@(gd_*)` proc) | A package under `res://shared/` carries state or a script. Keep state in exactly one module or an autoload; `shared/` is types, constants and pure procs. See [`res://shared/`](#shared). |
| `scriptgen: error: …: the shared package file <f> imports "…", which resolves to "…" OUTSIDE the shared tree (…)` | A shared package imports a module (or any other outside package). It may import collections and other `shared/` packages only. |
| `scriptgen: error: …: X.y: "…" comes from the SHARED package "…" — … scriptgen does not resolve gd:"…"-tagged BUNDLES across it` | A `gd:`-tagged struct was embedded from `shared/`. Move the tagged bundle into the module (or a `godot:` collection package); untagged plain data from `shared/` is fine. |
| `scriptgen: error: …: odin_scripts_boot is declared in the subpackage "…" — the boot export is ONE per dll …` | A hand-written boot shim ended up in a subfolder. Move it to the module root. |
| `odin_godot: duplicate explicit //gd:class 'X' in 'res://…' and 'res://…' — … module '…' was NOT loaded.` | Global-alias collision at native module load; the later module was rejected whole. Rename or remove one marker. |
| `odin_godot: reload rejected — explicit //gd:class 'X' in 'res://…' collides with 'res://…' …` | A rebuild introduced a global-alias collision; the swap was refused and old code stays live. |
| `… duplicate explicit //gd:class 'X' in 'res://…' and 'res://…'; both scripts remain path-addressable …` | Web found an ambiguous global alias. Both path identities work; rename or remove one marker. |
| `odin export: script module 'X' has a dot in its name — …` | Rename `res://modules/<X>` dot-free; the runtime only discovers dot-free module dlls. |
| `odin export: script module 'X' dll missing (…) — the exported game would ship WITHOUT this module's classes` | The module's export build failed or was skipped. Check the export log above it for the compile error. |
| `odin export: BUILD_MODULES=0 — script modules NOT built or bundled; …` | You (or a script) set `BUILD_MODULES=0`; unset it to ship modules. |
| `build_scripts: skipping module 'X' (no .odin sources)` | The `modules/X/` dir is empty: add a script or delete it. |
| A save's compile error in the editor Output | It surfaces the same way as a main-module error: fix it, and the module's old dll stays live meanwhile. |

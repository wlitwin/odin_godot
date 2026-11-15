<a id="1--what-if-your-scripts-were-compiled"></a>

# 1 · Writing compiled Godot scripts

odin_godot lets you attach an `.odin` script to a Godot node and run it as
compiled native code. Scenes, Inspector properties, and engine callbacks remain
part of the Godot workflow. The script layout, build step, and debugger change.

<a id="what-stays"></a>

## Godot editor integration

- **Scenes, nodes, the Inspector, the scene tree.** Your game is still built
  from `.tscn` files in the editor. Odin scripts attach to nodes exactly like
  GDScript does: the `.odin` file *is* the script resource, with no wrapper
  stub.
- **`@export` variables** show up in the Inspector with defaults, ranges, enum
  dropdowns, resource slots.
- **Signals** connect in code or the editor.
- **The play button.** Saving an `.odin` file triggers a rebuild and editor
  reload. Use the play button to run the updated game.
- **GDScript itself.** Odin scripts can coexist with GDScript. You can keep
  existing UI or editor scripts and migrate gameplay one script at a time.

<a id="what-changes"></a>

## Script data and procedures

A GDScript class becomes a plain struct and plain procedures:

```gdscript
# GDScript
extends Node2D
class_name Mover

@export var speed: float = 120.0

func _ready() -> void:
    print("Mover ready!")

func _process(delta: float) -> void:
    position.x += speed * delta
```

```odin
//gd:extends Node2D
//gd:class Mover
package my_game_scripts

import gd "godot:godot"

Mover :: struct {
	owner: gd.Node2d,
	speed: f32 `gd:"export,default=120"`,
}

mover_ready :: proc(self: ^Mover) {
	gd.print("Mover ready!")
}

mover_process :: proc(self: ^Mover, delta: f64) {
	pos := gd.node2d_get_position(self.owner)
	pos.x += self.speed * f32(delta)
	gd.node2d_set_position(self.owner, pos)
}
```

The examples express the same behavior, with three structural differences:

1. **State lives in a struct.** Fields are declared and typed, with a layout
   that generated code can inspect. Tags on fields (`gd:"export"`) replace
   annotations on variables.
2. **Procedures implement behavior.** `mover_ready` and `mover_process` are free
   functions taking `^Mover`. The script uses an explicit `self` parameter
   rather than a class with inheritance. Post 2 explains composition and
   cross-script calls.
3. **The struct holds the node.** `self.owner` is the Godot node to which the
   script is attached. Pass that handle to engine APIs and `self` to
   procedures that read or change script data.

A code generator (`scriptgen`, run by the build) reads your file and emits the
registration and argument-conversion code in a sibling `.gen.odin` file. Edit
the authored script; the build regenerates that file.

<a id="why-bother"></a>

## Native execution and explicit state

The compile step and fixed data layout affect both execution and framework integration:

**Gameplay procedures compile to native code.** Arrays and structs have explicit
layouts, so loops over gameplay state do not require an interpreter. The
Survivors example shows this style of per-frame entity processing; measure your
own workload before choosing a language for performance.

**State has an explicit layout.** Odin provides procedures, structs, slices, and
explicit memory management, with no classes or garbage collector. Positions,
health, and timers can live together in value types that your code controls.

**Kit uses that layout for replication.** Kit is the SDK's entity-based
multiplayer framework. Its generated field descriptors let a session compare
state, build snapshots, and send changes to peers. Tag a field `gd:"replicate"`
to include it in authority-written state:

```odin
Chest :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	gold:   u16 `gd:"replicate"`,
}
```

The tag declares the field's replication policy. A configured Kit session uses
it for networking and snapshots; posts 3–6 show how commands, identity, and
session setup add prediction, drop-in joins, reconnects, saves, and migration.

<a id="the-honest-costs"></a>

## Build and debugging requirements

- **A compile step.** Save-to-reload is a compile (a second or two, kept warm),
  rather than an instant re-parse. Type errors are reported before the new
  library loads.
- **No in-editor breakpoints.** Use logging and the native `lldb` debugger.
  Crashes give you symbolized
  native backtraces naming your Odin proc ([Debugging](../debugging.md)).
- **A new language.** Odin uses explicit types, pointers, and memory ownership.
  Its compiler catches invalid field access and type mismatches, while runtime
  behavior still needs testing.
- **A toolchain.** Everything is pinned in a Nix flake; setup is
  [one page](../getting-started.md).

<a id="do-this-now"></a>

## Build a first script

Work through [Getting Started](../getting-started.md): toolchain, project
wiring, and the `Mover` above, attached and moving. When it runs, continue to
post 2 for composition, cross-script access, and the distinction between the
script struct and its node.

*Next: [Thinking in structs →](02-thinking-in-structs.md)*

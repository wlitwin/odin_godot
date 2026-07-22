# 1 · What if your scripts were compiled?

You open your project, add a `Node2D`, attach a script, press play. The script
is not GDScript. It is compiled, native machine code, and everything else
about your day is unchanged.

That's the whole pitch of odin_godot at the surface level, and it's worth
being precise about it, because "replace GDScript" usually means "abandon the
editor workflow," and this doesn't.

## What stays

- **Scenes, nodes, the Inspector, the scene tree.** Your game is still built
  from `.tscn` files in the editor. Odin scripts attach to nodes exactly like
  GDScript does: the `.odin` file *is* the script resource, with no wrapper
  stub.
- **`@export` variables** show up in the Inspector with defaults, ranges, enum
  dropdowns, resource slots.
- **Signals** connect in code or the editor.
- **The play button.** Save an `.odin` file and the extension recompiles and
  hot-reloads it, so the edit → run loop survives.
- **GDScript itself.** Mixing is fine. Plenty of projects keep GDScript for UI
  glue and one-off editor tools and write the game in Odin. You migrate a
  script at a time, not a project at a time.

## What changes

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

The two files are the same length and express the same ideas, with three
structural differences:

1. **Your state is a struct.** Every field is declared, typed, and laid out in
   memory exactly as written. Tags on fields (`gd:"export"`) replace
   annotations on variables.
2. **Your behavior is procs.** `mover_ready` and `mover_process` are free
   functions taking `^Mover`. There is no class, no inheritance, and no
   implicit `self`. Post 2 is entirely about what replaces those reflexes.
3. **The node is a field.** `self.owner` is the engine node this script rides
   on. GDScript blurs your script and its node into one `self`; Odin keeps
   them separate, and that distinction ends up mattering a lot.

A code generator (`scriptgen`, run by the build) reads your file and emits the
registration/marshalling boilerplate as a sibling `.gen.odin` you never edit.
You write the two files above levels of ceremony apart from raw GDExtension.

## Why bother

The honest answer comes in three tiers, from smallest to largest:

**Performance is the obvious one, and the least interesting.** Compiled Odin
runs your per-frame logic at native speed with real arrays and real structs.
The survivors-like example in this repo pushes entity counts GDScript can't.
If that's all you need, you could also reach for C#. Keep reading.

**The language fits gameplay code.** Odin is a small systems language:
procedures, structs, slices, explicit everything. It has no classes, no
exceptions, and no GC pauses. Value semantics and fixed layouts mean the shape
of your data is a decision you make, not one the runtime makes for you.
Gameplay state (a thousand things with positions and hit points and timers)
is exactly the workload it's shaped for.

**The layout is the payoff.** Because a script's state is a struct with a
known memory layout, the extension can do things to your state that a dynamic
language can't promise. Diff it. Snapshot it. Ship it over a network and
reconstruct it bit-for-bit on another machine. Tag a field `gd:"replicate"`
and it is synchronized to every player, automatically, every tick:

```odin
Chest :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate"`,
	gold:   u16 `gd:"replicate"`,
}
```

That's not a serialization library you call. It's a property of the field. The
multiplayer framework built on it (posts 3–6) gives you client prediction,
drop-in joins, reconnects, saves, and host migration as consequences of your
structs being structs. This is the part that has no GDScript or C# equivalent.

## The honest costs

- **A compile step.** Save-to-reload is a compile (a second or two, kept warm),
  not an instant re-parse. You feel it; you also stop shipping typo crashes.
- **No in-editor breakpoints.** Debugging is prints plus `lldb`, a real
  native debugger, but not the one in the editor. Crashes give you symbolized
  native backtraces naming your Odin proc ([Debugging](../debugging.md)).
- **A new language.** Odin is genuinely small (if you've written any C-family
  code, the snippets above already read fine), but it is a new language, and
  its compiler will say no to things GDScript happily lets slide, catching at
  build time what GDScript would surface as a runtime crash.
- **A toolchain.** Everything is pinned in a Nix flake; setup is
  [one page](../getting-started.md).

## Do this now

Work through [Getting Started](../getting-started.md): toolchain, project
wiring, and the exact `Mover` above, attached and walking. It takes fifteen
minutes if Nix is already installed. When the node moves, come back for post
2: unlearning the class hierarchy.

*Next: [Thinking in structs →](02-thinking-in-structs.md)*

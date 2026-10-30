# 2 · Thinking in structs

Godot scripting assumes a class: you inherit a node, override its methods, and
`self` is everything. Odin scripts have no classes. A script is three separate
things instead, and this page maps each GDScript reflex to its Odin form.

The shape to internalize first:

> **A script is a struct (your state) plus free procs (your behavior), riding
> on an engine node (`self.owner`).**

GDScript fuses those three into one `self`. Keeping them apart means your state
is just a struct: diffable, shippable, and predictable. That is the property
the multiplayer toolkit in posts 3–6 relies on.

## The reflex map

| The GDScript reflex | The Odin form |
| --- | --- |
| `extends CharacterBody2D` | `//gd:extends CharacterBody2D` marker; `owner: gd.Character_Body2d` first field |
| `class_name Enemy` | Optional `//gd:class Enemy`; omit it when no global alias is needed |
| `@export var speed := 120.0` | ``speed: f32 `gd:"export,default=120"` `` |
| `@export_range(0, 100) var hp` | ``hp: f32 `gd:"export,range=0:100"` `` |
| `@onready var sprite = $Sprite` | ``sprite: gd.Node2d `gd:"onready=Sprite"` `` |
| `signal health_changed(value)` | ``health_changed: gd.Signal1(int) `gd:"args=value"` `` |
| `health_changed.emit(5)` | `enemy_emit_health_changed(self, 5)` (generated, typed) |
| `func _ready():` | `enemy_ready :: proc(self: ^Enemy) {}` |
| `func _process(delta):` | `enemy_process :: proc(self: ^Enemy, delta: f64) {}` |
| a method GDScript can call | `@(gd_method)` on the proc |
| connect in `_ready` | `gd.connect(self.owner, "body_entered", "on_body")` |
| or declaratively | `@(gd_method, gd_connect = "body_entered")` |
| `var scratch = {}` (private state) | an untagged struct field |
| `position.x += 1` | `gd.node2d_set_position(self.owner, ...)` |

Two naming rules carry the whole scheme: every proc is prefixed with its
struct's snake_case name (`enemy_ready`; all scripts share one package, so
prefixes prevent collisions), and the prefix is *stripped* for the
Godot-facing name (`enemy_take_damage` is `take_damage` to a signal, an
animation track, or GDScript).

## `self` is not the node

In GDScript, `self` *is* the node. In Odin, `self` is your struct, and the
node is `self.owner`:

```odin
gd.add_child(self.owner, node)     // ✓ the engine node
gd.add_child(self, node)           // ✗ hands the engine your struct — segfault
```

Both compile, because engine handles are raw pointers. The build refuses the
second form outright:

```
scriptgen: error: scripts/powerup.odin:31: gd.add_child: `self` is the
^Powerup script struct, not an engine object — pass self.owner
```

When an engine API wants an object (`add_child`, `connect_to`, `queue_free`,
a Callable target), pass `self.owner`. When your own code wants your state,
pass `self`.

## Replacing inheritance

You keep extending *engine* classes: `//gd:extends CharacterBody2D` gives you
everything the node is. What Odin has no equivalent for is
script-extends-script: there is no `class_name Enemy extends Actor` with
overridden methods. The replacements, in the order you'll reach for them:

**Shared data → a shared struct field.** The GDScript base class holding
`hp`, `speed`, `faction` becomes a plain struct embedded in each script:

```odin
Vitals :: struct { hp, hp_max: f32, faction: u8 }

Enemy  :: struct { owner: gd.Node2d, vitals: Vitals, /* ... */ }
Player :: struct { owner: gd.Node2d, vitals: Vitals, /* ... */ }
```

**Shared behavior → a proc taking the shared struct.** `damage(v: ^Vitals,
amount: f32)` works on anything with vitals. There is no virtual dispatch: you
pass the piece it needs.

**"Is this thing an X?" → `rt.script_of`.** This is the typed cross-script lookup:

```odin
player := rt.script_of(body, Player)   // ^Player, or nil if body isn't one
if player != nil {
	player_take_damage(player, CONTACT_DAMAGE)
}
```

Because all scripts compile into one package, `Player` in one file is the
same type in every file: cross-script calls are direct, typed calls, not
`get("hp")` string lookups.

If you're coming from C#, this is composition over inheritance. Most gameplay
hierarchies are one level deep and exist to share three fields; a struct
member does that without the fragile-base problems.

## Replacing autoloads

An autoload is two things in one: a *node* that's always in the tree, and a
*global* everyone can reach. Odin splits them:

- Need the node (timers, `_process`, signals)? Make an autoload as usual:
  an Odin script on an autoloaded node works fine, and `rt.script_of` reaches
  its struct from anywhere.
- Need only the global? Package-level state in a plain `.odin` file is
  visible to every script in the package, and no node is required. For typed
  one-to-many "somebody should react to this" without engine signals, the
  extension ships a pure-Odin event system ([Events](../events.md)) at
  direct-call cost.

## What the compiler checks

The reflex map is mechanical, and after a week you won't consult it. What the
compiler gives you instead:

- A typo'd field is a compile error, not a runtime `Nil` five playtests later.
- A signal payload is typed: emit with an `int` where a `Node2d` is declared
  and it doesn't build.
- Refactors are grep-able and checked: rename a field, the compiler lists
  every use site.
- The Inspector, the scene, and your code can't drift apart silently:
  scriptgen validates tags at build time and errors in the same
  `path:line:` format your editor already jumps to.

In the next post, a field tag makes state *network-synchronized*. The
compiler-checked struct layout is what makes that possible.

*Next: [State, not messages →](03-state-not-messages.md)*

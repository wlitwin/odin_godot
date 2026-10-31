# 2 · Thinking in structs

An Odin node script stores state in a struct and implements behavior in free
procedures. Its `self.owner` field holds the Godot node. This page maps
GDScript features to those three parts.

The struct's fixed layout lets generated code locate its fields. Kit, the
multiplayer framework in posts 3–6, uses field descriptors to replicate and
snapshot selected state.

<a id="the-reflex-map"></a>

## GDScript-to-Odin equivalents

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

Two naming rules distinguish scripts in a package: prefix each procedure with its
struct's snake_case name (`enemy_ready`; all scripts share one package, so
prefixes prevent collisions), and the prefix is *stripped* for the
Godot-facing name (`enemy_take_damage` is `take_damage` to a signal, an
animation track, or GDScript).

## `self` is not the node

In GDScript, `self` *is* the node. In Odin, `self` is your struct, and the
node is `self.owner`:

```odin
gd.add_child(self.owner, node)     // ✓ the engine node
gd.add_child(self, node)           // ✗ rejected: this is script data, not a node handle
```

Engine handles are distinct types, so the compiler rejects the second form.
Scriptgen also reports the script/node mix-up at build time:

```
scriptgen: error: scripts/powerup.odin:31: gd.add_child: `self` is the
^Powerup script struct, not an engine object — pass self.owner
```

When an engine API wants an object (`add_child`, `connect_to`, `queue_free`,
a Callable target), pass `self.owner`. When your own code wants your state,
pass `self`.

## Replacing inheritance

The Godot base still determines the node's engine behavior:
`//gd:extends CharacterBody2D` attaches the script to that engine class.
Odin has no script-to-script inheritance such as
`class_name Enemy extends Actor` with overridden methods. Share data and
behavior through structs and procedures:

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

Use `rt.script_of` to resolve a Godot object to a particular script type:

```odin
player := rt.script_of(body, Player)   // ^Player, or nil if body isn't one
if player != nil {
	player_take_damage(player, CONTACT_DAMAGE)
}
```

Because all scripts compile into one package, `Player` in one file is the
same type in every file: cross-script calls are direct, typed calls, not
`get("hp")` string lookups.

This is composition: embed shared data and pass it to shared procedures.
Changing that data does not require a script inheritance hierarchy.

<a id="replacing-autoloads"></a>

## Shared state and autoloads

Use an autoload when shared state needs a persistent Godot node. Package-level
state can serve scripts that need no engine node:

- For timers, `_process`, or signals, attach an Odin script to an autoloaded
  node. Resolve its node through the scene tree and use `rt.script_of` to
  access the script data.
- For shared data alone, package-level state in a plain `.odin` file is
  visible to every script in the package. The pure-Odin event system supports
  typed one-to-many notifications through direct procedure calls;
  see [Events](../events.md).

## What the compiler checks

The compiler and scriptgen check different parts of this arrangement:

- An unknown struct field produces a compile error.
- A signal payload is typed: emit with an `int` where a `Node2d` is declared
  and it doesn't build.
- Refactors are grep-able and checked: rename a field, the compiler lists
  every use site.
- scriptgen validates field tags at build time and reports errors in
  `path:line:` format, so your editor can jump to the declaration.

In the next post, a field tag makes state *network-synchronized*. The
compiler-checked struct layout is what makes that possible.

*Next: [Field replication →](03-state-not-messages.md)*

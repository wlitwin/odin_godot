# 2 · Thinking in structs

The hard part of switching isn't Odin's syntax — you absorbed that from post
1's forty lines. The hard part is that a decade of Godot reflexes assume a
class: inherit a node, override its methods, `self` is everything. Odin
scripts have no classes. This post remaps each reflex, one at a time, so the
absence stops feeling like a missing limb.

The shape to internalize first:

> **A script is a struct (your state) plus free procs (your behavior), riding
> on an engine node (`self.owner`).**

Three separate things. GDScript fuses them into one `self`; keeping them apart
is what later makes the state diffable, shippable, and predictable — the
entire multiplayer story of posts 3–6 rests on your state being *just a
struct*.

## The reflex map

| The GDScript reflex | The Odin form |
| --- | --- |
| `extends CharacterBody2D` | `//gd:extends CharacterBody2D` marker; `owner: gd.Character_Body2d` first field |
| `class_name Enemy` | `//gd:class Enemy` (defaults to the struct name) |
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
struct's snake_case name (`enemy_ready` — all scripts share one package, so
prefixes prevent collisions), and the prefix is *stripped* for the
Godot-facing name (`enemy_take_damage` is `take_damage` to a signal, an
animation track, or GDScript).

## `self` is not the node

The one trap everyone hits, so it gets its own section. In GDScript, `self`
*is* the node. In Odin, `self` is your struct, and the node is `self.owner`:

```odin
gd.add_child(self.owner, node)     // ✓ the engine node
gd.add_child(self, node)           // ✗ hands the engine your struct — segfault
```

Both compile (engine handles are raw pointers), which is why the build now
refuses the second form outright:

```
scriptgen: error: scripts/powerup.odin:31: gd.add_child: `self` is the
^Powerup script struct, not an engine object — pass self.owner
```

When an engine API wants an object — `add_child`, `connect_to`,
`queue_free`, a Callable target — it wants `self.owner`. When *your* code
wants your state, it wants `self`. The separation you're being forced to
maintain here is the same one that pays off in post 3.

## Where inheritance went

You didn't lose extending *engine* classes — `//gd:extends
CharacterBody2D` gives you everything the node is. What's gone is
script-extends-script: no `class_name Enemy extends Actor` with overridden
methods. The replacements, in the order you'll actually reach for them:

**Shared data → a shared struct field.** The GDScript base class holding
`hp`, `speed`, `faction` becomes a plain struct embedded in each script:

```odin
Vitals :: struct { hp, hp_max: f32, faction: u8 }

Enemy  :: struct { owner: gd.Node2d, vitals: Vitals, /* ... */ }
Player :: struct { owner: gd.Node2d, vitals: Vitals, /* ... */ }
```

**Shared behavior → a proc taking the shared struct.** `damage(v: ^Vitals,
amount: f32)` works on anything with vitals. No virtual dispatch — you pass
the piece it needs.

**"Is this thing an X?" → `rt.script_of`.** The typed cross-script lookup:

```odin
player := rt.script_of(body, Player)   // ^Player, or nil if body isn't one
if player != nil {
	player_take_damage(player, CONTACT_DAMAGE)
}
```

Because all scripts compile into one package, `Player` in one file is the
same type in every file — cross-script calls are direct, typed calls, not
`get("hp")` string lookups.

If you're coming from C#, this is composition-over-inheritance with the
decision made for you. Most gameplay hierarchies are one level deep and exist
to share three fields; a struct member does that without the fragile-base
problems.

## Where autoloads went

An autoload is two things in one: a *node* that's always in the tree, and a
*global* everyone can reach. Odin splits them:

- Need the node (timers, `_process`, signals)? Make an autoload as usual —
  an Odin script on an autoloaded node works fine, and `rt.script_of` reaches
  its struct from anywhere.
- Need only the global? Package-level state in a plain `.odin` file is
  visible to every script in the package — no node required. For typed
  one-to-many "somebody should react to this" without engine signals, the
  extension ships a pure-Odin event system ([Events](../events.md)) at
  direct-call cost.

## What the compiler now does for you

The reflex map above is mechanical, and after a week you won't consult it.
What you'll notice instead:

- A typo'd field is a compile error, not a runtime `Nil` five playtests later.
- A signal payload is typed — emit with an `int` where a `Node2d` is declared
  and it doesn't build.
- Refactors are grep-able and checked: rename a field, the compiler lists
  every use site.
- The Inspector, the scene, and your code can't drift apart silently:
  scriptgen validates tags at build time and errors in the same
  `path:line:` format your editor already jumps to.

GDScript optimizes for the first hour of a script's life. This setup
optimizes for the next hundred. That trade gets extreme in the next post,
where a field tag makes state *network-synchronized* — and the compiler-checked
struct layout is the only reason it can.

*Next: [State, not messages →](03-state-not-messages.md)*

# Authoring guide — the Odin script feature reference

This is the complete reference for writing Odin scripts: the struct convention, the `//gd:`
markers, every `@export` form, lifecycle, methods, signals, resources, autoloads,
cross-script access, the `gd.*` helper catalog, and editor tooling. New to odin_godot? Read
**[Getting Started](getting-started.md)** first for setup and a hello-world; this page is the
deep dive. For the build/edit/debug loop, see **[Workflow](workflow.md)**.

You write `<name>.odin` in the clean authoring form below; a preprocessor (`scriptgen`, run
by `build/build_scripts.sh`) reads its struct tags + markers and *auto-emits* a sibling
`<name>.gen.odin` (the registration boilerplate — Variant trampolines, backing arrays,
`@(init)` registration) that you never edit. Both compile together into the scripts dll, so
you author the nice form and get the full typed dispatch for free.

### Single-file authoring

There is exactly **one file per script**: the `.odin` you write is also the resource
you attach to a node. Put your scripts under the project (e.g. `res://scripts/foo.odin`)
and attach `res://scripts/foo.odin` directly in the scene — the loader reads its
`//gd:class` marker and binds it to the compiled class. The sibling `<name>.gen.odin`
is a build artifact that lives beside the source; the loader deliberately **ignores
`*.gen.odin`** so it is never treated as an attachable script. There is no separate
"resource stub" file to keep in sync.

## Anatomy of a script

```odin
//gd:extends Node          // base Godot class. Optional — derived from `owner` when omitted.
//gd:class Ping            // optional class-name override (defaults to struct name)
//gd:tool                  // optional: registers as a @tool script
package my_scripts

import gd "godot:godot"

// The script struct. The FIRST field MUST be the owner Object handle (the core
// writes the owner pointer there at offset 0). Its type is just the handle you
// want to use in your procs (gd.Node, gd.Object, gd.Node2d, ...). The actual base
// class comes from //gd:extends.
Ping :: struct {
	owner:  gd.Node,
	pinged: gd.Signal1(int) `gd:"args=value"`, // signal field -> declared signal (see Signals)
	speed:  f32    `gd:"export"`,  // tagged field -> @export var
	count:  gd.Int `gd:"export"`,
	scratch: int,                 // untagged -> private per-instance state
}

// Engine calls (add_child, connect_to, queue_free, ...) take `self.owner` —
// NEVER `self`. `self` is this Odin struct; engine handles are raw pointers,
// so both compile, but the engine dereferencing your struct is a segfault.
// scriptgen rejects the bare-`self` form at build time
// ("...is the ^Ping script struct, not an engine object — pass self.owner").

// Lifecycle procs: matched by name (after stripping an optional `<struct>_`
// prefix) against ready / process / physics_process / enter_tree / exit_tree, and
// bound by the `^Ping` receiver. Write a plain Odin proc; codegen wraps it.
ping_ready :: proc(self: ^Ping) {
	if self.speed == 0 {self.speed = 1.5}
}

// Custom methods: tag with @(gd_method). Callable from GDScript. The exposed name
// is the proc name minus the `<struct>_` prefix (`ping_add` -> `add`). Codegen
// generates the Variant trampoline from the typed signature.
@(gd_method)
ping_add :: proc(self: ^Ping, a, b: int) -> int {return a + b}

@(gd_method)
ping_emit_ping :: proc(self: ^Ping, value: int) {
	self.count += gd.Int(value)
	ping_emit_pinged(self, i64(value))   // generated emit helper (see below)
}
```

### Markers (`//gd:` comments)

| Marker | Meaning |
| --- | --- |
| `//gd:extends <Class>` | The Godot base class. **Optional** — omitted, it is derived from the `owner` field's type. |
| `//gd:class <Name>` | Class name override. Defaults to the struct name. |
| `//gd:tool` | Registers the class as a `@tool` script (`is_tool() == true`) — runs in the editor. |
| `//gd:icon res://path.svg` | Custom class icon (Scene dock, Create Node/Resource dialog). |

These are the marker comments the engine's resource loader reads to bind the
authored `res://scripts/<x>.odin` resource (the same file you compile) to its
compiled class, so the convention is uniform.

`//gd:extends` and the `owner` field state the same fact twice, so scriptgen
cross-checks them: **the owner handle must be the declared base or one of its
ancestors.**

```odin
//gd:extends CharacterBody2D
Player :: struct { owner: gd.Node2d }   // fine — a wider handle; the script only calls Node2D methods

//gd:extends Node
Player :: struct { owner: gd.Node2d }   // build error — a NARROWER handle
```

The narrow direction is the bug: every class handle is a `rawptr` alias, so Odin
has no opinion, the class registers as a plain `Node`, and then every
`gd.node2d_*` call in the script reaches through that handle into an object that
never was a Node2D — a crash at the engine boundary with nothing pointing back
at the comment that lied. The error names both spellings and both fixes.

Leave the marker off and the base is **derived** from the handle instead, which
is the version with only one place to be wrong:

```odin
//gd:class Coin
package scripts
Coin :: struct { owner: gd.Area2d }     // registers as Area2D
```

(The old `Node` default survives only where the handle can't be placed — no
`-godot:` root, or a type that isn't a ClassDB class. The check degrades to
silence in exactly those cases rather than inventing errors about a class list
it cannot see.)

### The tag vocabulary

Every `` `gd:"…"` `` tag opens with ONE token that selects what the field is. The whole
set, and who consumes each (the table below is the human projection of
`decl/decl.odin`'s `FIELD_TOKENS` — the schema both scriptgen and the runtime's
reflection registrar read, so this page, the parser, the boot-time "unknown gd tag"
error, and the skip list cannot drift apart):

| First token | What it declares | Consumed by | In the wire fingerprint |
| --- | --- | --- | --- |
| `export` | an editor-visible property | the runtime registrar | no |
| `onready=PATH` | an auto-wired node reference | the runtime registrar | no |
| `replicate` | a networked field on the DELTA lane ([kit/net](kit/net.md)) | scriptgen | yes |
| `owner` | a networked field streamed from its owning peer | scriptgen | yes |
| `predict` | a networked field the sim predicts and reconciles ([kit/sim](kit/sim.md)) | scriptgen | yes |
| `backup` | a field the session backup carries | scriptgen | yes |
| `manual` | "I call the generated thing myself" | scriptgen | no |
| `profile=T` | the per-player profile row type | scriptgen | yes |
| `entity=Name:id` | a spawnable entity type and its stable id | both | yes |

One token rides BEHIND a first token as a spec: `args=a,b` (a signal payload's
parameter names). "In the wire fingerprint" means the declaration's shape folds into
`NET_FINGERPRINT`, so two builds that disagree about it are refused at the join door
rather than misparsing each other's packets.

**A WIRE DECLARATION IS A FIRST TOKEN.** That is the rule the column on the right
states: if the thing folds into `NET_FINGERPRINT`, it names what the field IS and it
leads the tag. Two consequences worth spelling out, because both used to read the other
way:

* **The three lanes are three tokens.** `owner` and `predict` used to be options inside
  `gd:"replicate,…"`, which put the one decision that matters — who writes these bytes —
  in the same syntactic position as a smoothing constant. Each lane now carries its own
  CLOSED option set (below), so `slack=` is not "an option requiring predict", it is an
  option the predict lane HAS. The combinations that used to be rejected by a pairwise
  rule (`owner` with `predict`, `slack=` without `predict`) are now unspellable.
* **`entity=Name:id` leads its tag.** It carries a permanent public type id and builds
  the factory table; it is not an Inspector detail of an export. An entity field is
  necessarily an exported `PackedScene`, so both of those are SYNTHESIZED — write
  `` `gd:"entity=Mob:3"` ``, not `` `gd:"export,resource=PackedScene,entity=Mob:3"` ``.
  Trailing export specs still ride behind (`entity=Mob:3,group=Spawns`).

| Lane | Tag | Its options |
| --- | --- | --- |
| delta | `gd:"replicate"` | `interp`, `interp=angle`, `interp=BLEND_PROC`, `wire=f16`, `wire=CODEC` |
| owner-streamed | `gd:"owner"` | `interp`, `interp=angle`, `interp=BLEND_PROC`, `wire=f16`, `wire=CODEC` |
| predicted | `gd:"predict"` | the above, plus `slack=N`, `glide=N`, `cut=N` |

`_edge` halves pair with `gd:"replicate"` fields only — predicted state resims and
owner-streamed state interpolates, so each of those lanes has its own presentation
answer.

Both grammars changed in one commit and the old spellings are REFUSED, by an error
naming the exact replacement tag — the old `replicate,interp,owner,wire=f16` answers with
`gd:"owner,interp,wire=f16"`. Nothing about the wire moved: the lane a field resolves to
is what folds into `NET_FINGERPRINT`, and it resolves identically, so a retagged build
still joins an un-retagged peer's session bit for bit.

### Exports

Struct fields tagged `` `gd:"export"` `` become `@export` vars: the field name is
the property name, the field type maps to a Variant type. `offset`/`size` are
derived with `offset_of` / `size_of`, so the core narrows native Variant widths
(Int=i64, Float=f64) to your field's real width (e.g. `f32`).

**Supported field types** — the FULL Godot Variant set. Use the `gd.<Type>` binding
type (or, for the scalar atoms, the bare Odin scalar, which is width-narrowed):

| Category | Field types |
| --- | --- |
| Scalars | `bool`; `i8`/`i16`/`i32`/`i64`/`int`/`u8`/`u16`/`u32`/`u64`/`uint`/`gd.Int`; `f32`/`f64`/`gd.Float` |
| Strings | `gd.String`, `gd.String_Name`, `gd.Node_Path` |
| Math | `gd.Vector2`/`Vector2i`, `gd.Rect2`/`Rect2i`, `gd.Vector3`/`Vector3i`, `gd.Vector4`/`Vector4i`, `gd.Transform2d`/`Transform3d`, `gd.Plane`, `gd.Quaternion`, `gd.Aabb`, `gd.Basis`, `gd.Projection`, `gd.Color` |
| Containers | `gd.Dictionary`, `gd.Array`, and every `gd.Packed_*_Array` (`Byte`, `Int32`, `Int64`, `Float32`, `Float64`, `String`, `Vector2`, `Vector3`, `Vector4`, `Color`) |
| Handles | `gd.Object` and any object/class handle (`gd.Node2d`, `gd.Texture2D`, …) or a pointer to one (`^gd.Node2d`); `gd.Rid` |

Note: `gd.Callable`/`gd.Signal`/`gd.Rid` map to their Variant types but are not
meaningfully editable in the Inspector (Godot itself doesn't expose them as exports);
prefer them only for cross-script data, not for editor-tunable values. An unrecognized
field type is a hard `scriptgen: error:` (so a typo is never silently an `Object`).

**Export hints.** Extend the tag with one comma-separated hint spec —
`` `gd:"export,SPEC"` ``. Top-level tokens are comma-separated; values WITHIN a spec
are colon-separated (so a file filter's commas never collide) and are rewritten to
Godot's comma-joined `hint_string` form:

| Tag | Inspector widget | Godot hint / hint_string |
| --- | --- | --- |
| `gd:"export,range=0:100"` | numeric slider | `Range` / `"0,100"` |
| `gd:"export,range=0:100:5"` | slider with step | `Range` / `"0,100,5"` |
| `gd:"export,enum=Idle:Walk:Run"` | named-int dropdown | `Enum` / `"Idle,Walk,Run"` |
| `gd:"export,multiline"` | multi-line text box | `Multiline_Text` |
| `gd:"export,file"` | file picker (any) | `File` / `""` |
| `gd:"export,file=*.png:*.jpg"` | filtered file picker | `File` / `"*.png,*.jpg"` |
| `gd:"export,dir"` | directory picker | `Dir` |
| `gd:"export,global_file"` / `global_dir` | global file/dir picker | `Global_File` / `Global_Dir` |
| `gd:"export,resource=Texture2D"` | typed resource picker | `Resource_Type` / `"Texture2D"` |
| `gd:"export,array=int"` | typed-array editor | `Type_String` / `"2:"` |
| `gd:"export,array=Texture2D"` | typed-array of resources | `Type_String` / `"24/17:Texture2D"` |
| `gd:"export,dict=String;int"` | typed-dictionary editor | `Type_String` / `"4:;2:"` |
| `gd:"export,dict=String;Texture2D"` | typed-dict, resource values | `Type_String` / `"4:;24/17:Texture2D"` |

`resource=` is for an `Object`/resource-handle field; `range`/`enum` for an int or
float; `multiline` for a `gd.String`. **`array=ELEM`** (on a `gd.Array` field) and
**`dict=KEY;VALUE`** (on a `gd.Dictionary` field) declare *typed* collections — the same
Inspector editors GDScript's `Array[T]` / `Dictionary[K,V]` produce. Each element/key/value
is a builtin (`int`, `float`, `String`, `Vector2`, `Color`, …) or a Resource class name
(`Texture2D`, `PackedScene`, …). At most one hint per field. (A scene that bodies a wire
entity does NOT declare a hint: **`gd:"entity=Name:id"`** is its own first token and
synthesizes both the export and the `resource=PackedScene` hint — see [Entities](#entities)
and [kit/boot](kit/boot.md)'s `boot_entities`.) Example:

```odin
Probe :: struct {
	owner:       gd.Node,
	health:      i32        `gd:"export,range=0:100:5"`,
	mode:        i32        `gd:"export,enum=Idle:Walk:Run"`,
	description: gd.String  `gd:"export,multiline"`,
	velocity:    gd.Vector3 `gd:"export"`,
	texture:     gd.Object  `gd:"export,resource=Texture2D"`,
	scores:      gd.Array   `gd:"export,array=int"`,            // Array[int]
	loot:        gd.Dictionary `gd:"export,dict=String;PackedScene"`, // Dictionary[String, PackedScene]
}
```

> The values still live as untyped `gd.Array` / `gd.Dictionary` handles in Odin (you
> read/write them through the `array_*` / `dictionary_*` methods); the `array=`/`dict=` tag
> only drives the export's *typing* — the Inspector widget and the engine-side key/value
> type enforcement.

**Type-driven form.** Instead of the tag, you can declare the field as a `gd.Typed_Array(T)` /
`gd.Typed_Dictionary(K, V)` and a bare `gd:"export"` derives the same hint from the type — no
duplication:

```odin
scores: gd.Typed_Array(i64)                       `gd:"export"`,  // == array=int
loot:   gd.Typed_Dictionary(gd.String, gd.Packed_Scene) `gd:"export"`, // == dict=String;PackedScene
```

Element types are the Odin spellings (`i64`, `gd.String`, `gd.Texture2d`); Resource handles are
mapped back to their engine class name automatically (`gd.Texture2d` → `Texture2D`). For
acronym-heavy class names that don't round-trip cleanly (e.g. `JSON`, `GLTFDocument`), use the
`array=`/`dict=` tag form with the exact name. Don't combine the two on one field — that's a
build-time error.

### Export groups & subgroups

Add a `group=` (or `subgroup=`) token to an export to open a collapsible Inspector
header that applies to that field and every export after it, until the next marker:

```odin
Player :: struct {
	owner:   gd.Character_Body2d,
	speed:   f32 `gd:"export,group=Movement"`, // "Movement" header starts here
	jump:    f32 `gd:"export"`,                 // …still under "Movement"
	hp:      i32 `gd:"export,group=Combat"`,    // "Combat" header starts here
	defense: i32 `gd:"export"`,                 // …under "Combat"
}
```

The marker is emitted as a `PROPERTY_USAGE_GROUP` (or `…_SUBGROUP`) entry immediately
before the field's own property entry, so the engine renders the header in both the live
property list and the editor placeholder. The group's name-prefix is empty (property names
are not auto-prefixed). `group=` and `subgroup=` combine with any hint/default/getter on
the same field.

### Export default values

`default=` carries an initializer for a **scalar** export (`int`/`float`/`bool`/`String`).
The value is applied to the field when the instance is created (after zeroing, before
`_ready`) and reported through Godot's default-value API, so the Inspector shows it and the
reset-to-default arrow works:

```odin
Player :: struct {
	owner: gd.Node,
	speed: f32       `gd:"export,default=200"`,
	name:  gd.String `gd:"export,default=Hero"`,
	alive: bool      `gd:"export,default=true"`,
}
```

Only scalar Variant types support `default=` today (numbers, bool, and `String`). A
`default=` on a math-struct/handle field is reported at **boot**, by the reflection
registrar, in the editor's output — not by `scriptgen` (see "Which tier catches what"
below). It is loud, but it is late. (Set those in `_ready` or from the scene instead.)

### Which tier catches what

Two different things read a `` `gd:"export,…"` `` tag, and knowing which one is about to
speak saves a confusing afternoon:

| Tier | When | What it checks | How a failure looks |
| --- | --- | --- | --- |
| `scriptgen` | build | the tag's VOCABULARY — the first token, and every spec NAME behind it | `scriptgen: error: player.odin:7: …`, the build stops |
| the reflection registrar | boot / class registration | what each spec MEANS — a value's type, a hint's arity, the Variant a hint requires | an error in Godot's output, the field registers with that spec dropped |

The split is deliberate: only the runtime knows a field's real Variant width, so only the
runtime can say `array=` needs a `gd.Array` or that `default=Hero` won't fit a `Vector2`.
But *spelling* needs none of that, so **a misspelled spec is a build error**:

```odin
hp: i32 `gd:"export,rnage=0:100"`
// scriptgen: error: Player.hp: unknown export spec "rnage" — did you mean `range`?
```

This used to be the language's sharpest inconsistency. `gd:"replicate,slcak=0.5"` failed
the build, because that spec loop refused what it didn't know; `gd:"export,rnage=0:100"`
sailed straight through scriptgen — the export-spec loop had no default arm — and surfaced
at boot as an error on a field that had silently lost its hint. Same tag, same class of
typo, two latencies and two audiences. The recognized spec set is
[`decl/decl.odin`](../decl/decl.odin)'s `EXPORT_SPECS`, and `tests/scriptgen` asserts it
against the registrar's own switches, so the two tiers can't drift into disagreeing about
which names exist.

### Getter / setter properties

Route an export's reads/writes through Odin procs — for validation, clamping, or
side-effects — with `get=`/`set=`. The named procs take `^<Struct>` plus (for the setter)
the field value, and run instead of the raw field access from both GDScript and the editor:

```odin
Player :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"export,get=player_get_hp,set=player_set_hp"`,
}

// reads of `hp` return this; writes are clamped into [0,100].
player_get_hp :: proc(self: ^Player) -> i32 { return self.hp }
player_set_hp :: proc(self: ^Player, v: i32) { self.hp = clamp(v, 0, 100) }
```

The `get`/`set` procs are **plain Odin procs** (no `@(gd_method)` needed) named exactly as
written in the tag. The backing field still exists — the getter/setter may use it as
storage (as above) or compute from other state. Combine with `group=`/`default=` freely
(a defaulted getter/setter field applies its default through the setter).

### @onready node references

A struct field tagged `` `gd:"onready=PATH"` `` is auto-wired to a child node on `_ready`,
mirroring GDScript's `@onready var sprite = $Sprite`. On the node's READY — *before* any
`@(gd_connect)` wiring and your own `_ready` proc — the core resolves
`get_node(owner, "PATH")` and writes the result into the field, so your `_ready` sees a
fully-resolved, non-null reference:

```odin
Player :: struct {
	owner:  gd.Character_Body2d,
	sprite: gd.Node2d `gd:"onready=Sprite"`,    // owner-relative node path
	label:  gd.Node   `gd:"onready=HUD/Label"`,
}
```

The field must be an object/node handle (`gd.Node2d`, `gd.Sprite2D`, `gd.Object`, …) — the
handle IS the node pointer, so use the bare handle type, not `^gd.Node2d`. An `@onready`
field is a **private auto-wired ref**, NOT a serialized `@export`: it never appears in the
property list / Inspector.

### Lifecycle & methods

Both are plain Odin procs whose first parameter is `^<Struct>`:

- **Lifecycle**: the proc name (minus an optional `<struct>_` prefix) is one of
  `ready`, `process`, `physics_process`, `enter_tree`, `exit_tree`, `reload`.
  `process` / `physics_process` take a `delta: f64` second parameter.
- **Methods**: tagged `@(gd_method)`. Any name; exposed minus the struct prefix.

#### `reload` — the hot-reload hook

`<struct>_reload(self: ^T)` runs on each live instance **after a hot reload** swaps the
scripts dll (editor save-on-rebuild, or an explicit `script.reload(true)` in a running game),
with the **new** code. You rarely need it: a same-layout reload preserves your struct in place
and re-points all engine entry points (`_process`, methods, signals) to the new code
automatically. The one thing the swap *can't* fix is a **raw proc pointer you cached into your
own struct** — a callback/dispatch table, or a behaviour-tree node like `flow.Action`'s
`Call.fn`. On a same-layout reload those bytes are preserved untouched, so they still point at
the *old* (still-mapped, now stale) code. Rebuild that state in `reload`:

```odin
boss_reload :: proc(self: ^Boss) {
    self.behaviour = build_behaviour_tree()  // re-capture fresh proc pointers
}
```

This only matters for scripts that (a) run in the editor (i.e. `//gd:tool`) or are explicitly
reloaded at runtime, *and* (b) cache proc pointers in their state. Ordinary gameplay scripts
never hit it (a running game doesn't hot-reload itself).

Codegen wraps each in the `proc "c"` form the runtime expects, establishing a
heap-backed default context before calling your proc, so your proc body can use
ordinary Odin (allocations, etc.).

### Signals

Signals follow the GDScript pattern of **declare / emit / connect**.

**Declare** a signal as a typed STRUCT FIELD of one of the `gd.Signal0` … `gd.Signal4`
marker types (arity = payload count). The **field name is the signal name**, the type
parameters are the payload types, and the optional `gd:"args=..."` tag names the payload
(comma-separated, one name per parameter — omitted names synthesize as `arg0`, `arg1`, …).
No tag is required; the field is recognized by its type. Declared signals are reported
through `_get_script_signal_list`, so GDScript and the editor see them.

```odin
Player :: struct {
	owner:          gd.Node2d,
	health_changed: gd.Signal1(int) `gd:"args=value"`, // health_changed(value: int)
	leveled_up:     gd.Signal0,                        // leveled_up()
	hit:            gd.Signal2(int, ^gd.Node2d) `gd:"args=amount,who"`,
	// ...
}
```

The payload types must be Variant-able — the same rule as `@export` and `@(gd_method)`
args (object/node handles present as `Object`). A signal field costs one nil pointer of
instance size and is never read or written at runtime; it exists so the declaration is
part of the type, checked by the compiler, and visible to reflection.

**`gd.SignalN` — the struct-payload general form.** Its single parameter is the argument
LIST as an inline struct: the struct's **field names are the arg names** (no `args=` tag —
a tag on a `SignalN` field is a build error), and any number of args works. Prefer it for
5+ payload args (past the arity family's cap) or whenever you want named args without the
tag:

```odin
Enemy :: struct {
	owner: gd.Node2d,
	hit:   gd.SignalN(struct {
		amount: int,
		who:    ^gd.Node2d,
		pos:    gd.Vector2,
		crit:   bool,
		combo:  i64,
	}), // hit(amount, who, pos, crit, combo) — 5 named args
}
```

One-way-to-do-it rule: `SignalN`'s parameter must be the payload **struct**, never itself a
single Variant-mappable type — `gd.SignalN(gd.Vector2)` is rejected. For one payload value,
either `gd.Signal1(gd.Vector2)` (name it with `args=`) or wrap it so the field name names
it: `gd.SignalN(struct { pos: gd.Vector2 })` → `moved(pos: Vector2)`.

**Emit** with the generated typed helper `<struct_snake>_emit_<field>` — e.g.
`ping_emit_pinged(self, value)` — which codegen emits from the signal field and which
calls through `gd.emit`/`gd.emit_args` (returning the engine `Error`, which you may
ignore):

```odin
player_emit_health_changed(self, i64(self.health))   // generated typed emitter
```

**Connect** a signal to a handler proc (which must be a `@(gd_method)` so the engine can
dispatch to it). Three ways, increasingly declarative:

```odin
// 1. Connect an emitter's signal to a target's method, from any script (gd.* helper):
gd.connect_to(player, "health_changed", self.owner, "on_health_changed")

// 2. Connect one of the OWNER's own signals to its own method:
gd.connect(self.owner, "body_entered", "collect")

// 3. Declaratively — see @(gd_connect) below — no _ready/connect call at all.
```

### Declarative signal wiring (`@(gd_connect)`)

Tag a `@(gd_method)` proc with `@(gd_connect = "signal_name")` to have the core
auto-connect the **owner's** `signal_name` to this method **on READY** — so you needn't write
a `_ready` proc just to wire a signal. The connection happens before your own `_ready` runs
(order: `@onready` field resolution → `@(gd_connect)` connections → your `_ready`).

```odin
// `on_body` is auto-connected to the owner's `body_entered` on READY. No manual connect.
@(gd_method, gd_connect = "body_entered")
enemy_on_body :: proc(self: ^Enemy, body: gd.Node2d) {
	if self.dead { return }
	player := rt.script_of(body, Player)    // typed cross-script (see below)
	if player != nil {
		player_take_damage(player, CONTACT_DAMAGE)
	}
}
```

`@(gd_connect)` implies the proc is a signal target, so it must also be a `@(gd_method)` (use
`@(gd_method, gd_connect = "...")`). The signal must exist on the owner (an engine signal like
`body_entered` / `area_entered`, or one this script declared with a signal field). It connects
only the owner's *own* signal to the owner's *own* method — to wire a different emitter or
target, use `gd.connect_to` from `_ready` instead. (`@(gd_connect)` requires the
`-custom-attribute:gd_connect` build flag, which `build/build_scripts.sh` passes for you.)

## Reserved shapes

Several toolkit declarations are recognized by the SHAPE of a proc rather than by anything
you write in the attribute — a parameter's name, its position, or its type. That is
deliberate (the declaration reads as ordinary Odin), but it means a rename can silently
change what a proc IS. This table is the whole set.

| Shape | Where it is legal | What it means | Rename it and… |
| --- | --- | --- | --- |
| first param `self: ^<Class>` | every bound proc | THE receiver — it is how scriptgen knows the proc belongs to this class at all | the proc is not bound; nothing generates, no diagnostic |
| a pointer param **immediately after the receiver** | `@(gd_command)` / `@(gd_method)` on an *embedded block* | the WIELDER — scriptgen fills it with `self`, so the block can touch the entity that carries it. Never a wire arg (a pointer can't cross the wire) | a pointer there on a *direct* command is a build error ("un-wire-able arg") |
| `by: knet.Player_Id` (after the receiver/wielder) | `@(gd_command)` | the ISSUER, framework-filled with the true sender — the whole point is that a predicate can arbitrate on WHO without trusting a client-claimed argument | `by` under any other name is an ordinary wire arg, i.e. client-controlled. The name **and** the type together are the declaration; a wire arg *named* `by` is refused outright |
| `mine: bool` | `@(gd_fact)` halves, and a tick's `_fx` half | the every-screen law: `true` on the screen whose live simulation caused the event, `false` on watchers replaying it off their watch clock | position and name are both checked; the error names the slot |
| `tick: u64` | `@(gd_sample)` (required, second), `@(gd_step)` (optional, second) | the lane's tick number | on a sample, a build error; on a step, the param is simply not passed |
| `l: ^ksim.Lane` | reserved *against* you — a generated fact door already names its lane param `l` | — | an author arg named `l` is refused, because the door's own binding would shadow it |
| a `kit/boot` `Boot` field on the script struct | the game shell | declares the four standard transport forwards (`on_packet` / `on_peer_left` / `on_net_up` / `on_net_down`) | see the note below |

**The `Boot` match, and how tight it is.** The shell used to be declared by *any* field
whose type name ended in `.Boot` — the loosest match in the language: a game's own
`startup.Boot`, a vendored library's, anything. It now requires the type's qualifier to
resolve to an import of `godot:kit/boot`. The **alias is free** (`kboot`, `boot`, whatever
you import it as) because the import PATH is what is checked, not the spelling; only a
`Boot` from a different package stops declaring the shell. That is as tight as it goes
without demanding an explicit tag on the field — which would be a breaking change to every
existing game, for a case that now cannot fire by accident.

## Manual overrides — name shadowing is the pattern

Wherever scriptgen generates a proc *for your convenience*, **a hand-written proc of that
name wins.** That is the one override mechanism; there is no opt-out tag, no config
token, no magic path.

| Generated | Yields to a hand-written… |
| --- | --- |
| census accessors — `<entity>_of`, `<entity>_owned_by`, `my_<entity>`, `<entity>_ids`, `<entity>_spawn` | proc of that name |
| acid probes — `probe_<entity>_count`, `probe_my_<entity>`, `probe_<entity>_<field>` | proc (or `@(gd_method)`) of that name |
| the four standard transport forwards | `@(gd_method)` of that name |

Every yield is **printed**, once per run:

```
scriptgen: yielded: runner_of (census accessor — the hand-written proc of that name wins)
```

which is the line that tells you an intended override took effect — and, when you *didn't*
intend one, that something in your package is already wearing a generated name. A silent
yield is indistinguishable from "the generation just didn't happen", which is exactly how a
typo'd override (`runner_of` where the entity is `Runner_Bot`) used to read.

**The one exception: `@(gd_fact)` announce doors refuse.** Write a proc with a declared
fact's door name and it is a build error, not a yield. The reason is that the door is not a
convenience you could re-implement: its generated body holds four gates you have no way to
reproduce from game code — it broadcasts the tuple only on the authority, fires the `_fx`
half on the causer's *live* pass with `mine=true`, fires it on every watching screen when
that screen's watch clock reaches the fact's tick with `mine=false`, and stays silent
through resim replays so a reconcile can't re-announce. A shadowing proc would compile,
look right, and quietly present the event once, locally, to whoever called it. The error
says so and asks you to rename yours.

**`gd:"manual"` means "I call the generated thing myself."** It is the *other* half of the
same idea: not "replace this generated proc", but "stop calling it for me — I own the call
site." Today it applies to an embedded sim block's `@(gd_tick)` (see
[kit/sim](kit/sim.md)): the block's state still flattens into the descriptor and its verbs
still hoist, only the auto-call is suppressed so your own tick can drive it with whatever
ordering or condition you want. Read it as a general token, not a sim-specific one — a
`manual` on something with nothing generated to call is a build error naming what it
expected to find.

## Generated names

Three naming formulas produce identifiers you are expected to *call*, and one produces a
name you are expected to *write*. They are not interchangeable, and two of them are one
letter apart.

**Command wrappers — two formulas.** A verb declared directly on the entity keeps its own
proc name; a verb hoisted out of an embedded block is renamed after the PATH it was reached
through, so two blocks of the same type on one entity never collide:

| Declaration | Generated wrapper |
| --- | --- |
| `@(gd_command) gunner_buy :: proc(self: ^Gunner, …)` | `gunner_buy_cmd` — i.e. `<proc>_cmd` |
| `@(gd_command) gun_fire :: proc(self: ^Gun, …)`, embedded as `primary: Gun` on `Gunner` | `gunner_primary_fire_cmd` — i.e. `<class>_<path>_<verb>_cmd` |

The composed form's path is the FIELD path, joined with `_`, so a block three levels down
still lands on the entity that owns the net id. Both formulas can reach the same name, and
when they do it is a build error naming both declarations rather than a silently
unreachable verb.

**Wire-id constants — prefixed and unprefixed.** Command ids are class-prefixed
(`GUNNER_CMD_BUY`, `GUNNER_CMD_PRIMARY_FIRE`); world-pass fact ids are not (`FACT_ROUND_OVER`),
and neither is `NET_FINGERPRINT`. That is not an oversight: commands are per-entity, so
several classes in one package legitimately declare a verb of the same name, and the class
prefix is what keeps their constants apart. Facts and the fingerprint are **module-wide** —
there is exactly one door per event name across the whole package (a second is a build
error, as is a u16 hash collision between two events), and exactly one fingerprint. A class
prefix on those would suggest a per-class namespace that doesn't exist.

**`<entity>_spawn` vs `<entity>_spawned` — the homophone trap.** These are one letter apart
and point in opposite directions:

| Name | Who writes it | Who calls it | What it does |
| --- | --- | --- | --- |
| `mob_spawn` | **generated** | **you** | the typed factory — you call it to bring a Mob into the world |
| `mob_spawned` | **you** | **the framework** | the hook — it calls you once the Mob exists, on every peer |

So `mob_spawn(…)` inside `mob_spawned(…)` is an infinite spawn loop, and a `mob_spawn` you
wrote by hand silently takes over the factory (it is a census name — it yields, and prints
`yielded: mob_spawn`). If a spawn seems to do nothing, check that line first. The same
`-ed` shape marks the other framework-called hook, `<entity>_freed`.

All of these are keyed by the entity's TARGET STRUCT, which is why two `entity=` tags may
not name the same struct — that would generate the whole census twice.

## Multiplayer RPCs (`@(gd_rpc)`)

> **Two multiplayer stories — pick before you read on.** This section is the
> ENGINE-NATIVE surface: `@(gd_rpc)` mirroring GDScript's `@rpc`, plus the
> `MultiplayerSpawner`/`MultiplayerSynchronizer` interop it enables — the right
> tool for GDScript parity, porting an existing RPC design, or talking to
> non-Odin peers. **Building a co-op game from scratch? Use the
> [friendslop toolkit](kit/index.md) instead** — replicated struct fields,
> predicted commands with typed `_then` consequences, generated entity
> factories, drop-in join, reconnect, and host migration, with zero RPCs to
> design. The [tutorial](kit/build-a-game-in-a-day.md) builds a whole co-op
> game on it; `examples/cavecrawl` and `examples/slopball` are its references
> (`examples/coop_arena` and `examples/survivors` demonstrate the raw path
> below).

Mark a `@(gd_method)` proc with `@(gd_rpc)` to expose it to Godot's high-level multiplayer,
exactly like GDScript's `@rpc(...)` annotation. The annotation only declares the *config*;
the engine routes `node.rpc("method", args)` (and incoming remote calls) to your proc through
the same dispatch path a normal method call uses, so no extra plumbing is needed.

```odin
//gd:extends Node
//gd:class Player
package game

import gd "godot:godot"

Player :: struct {
	owner:  gd.Node,
	health: gd.Int `gd:"export"`,
}

// Bare form: all defaults — authority mode, reliable, no call_local, channel 0.
@(gd_method, gd_rpc)
player_ping :: proc(self: ^Player) { /* runs when the authority RPCs us */ }

// Explicit config (comma-separated tokens, any order):
@(gd_method, gd_rpc = "any_peer,unreliable,call_local,channel=2")
player_take_damage :: proc(self: ^Player, amount: gd.Int) {
	self.health -= amount
}
```

`gd_rpc` implies `gd_method` — an RPC must be a registered, name-dispatchable method, so you
can drop the `gd_method` and write just `@(gd_rpc)` if you prefer (both forms are equivalent).

**Config tokens** (mirroring GDScript `@rpc` defaults):

| Token | Effect | Default |
| --- | --- | --- |
| `authority` / `any_peer` | who may call it (`RPCMode`) | `authority` |
| `reliable` / `unreliable` / `unreliable_ordered` | transfer mode | `reliable` |
| `call_local` | the RPC ALSO runs on the calling peer | off |
| `channel=N` | transfer channel | `0` |

Codegen emits this into the class's `_get_rpc_config` surface, which the engine reads (once,
per node) to learn the method's RPC config. From GDScript / another script you then call it as
usual:

```gdscript
# A multiplayer peer must be active (e.g. ENetMultiplayerPeer or, for a single-process
# loopback, OfflineMultiplayerPeer):
node.multiplayer.multiplayer_peer = ENetMultiplayerPeer.new()  # ...create_server / _client
node.rpc("take_damage", 10)   # routed to player_take_damage on the configured peer(s)
```

A small networked sketch: a `Player` autoloaded on both server and client, the server is the
node's `set_multiplayer_authority`, and an `any_peer,call_local` `take_damage` lets any client
request damage while still applying it locally. The exact config a script registered is
observable from GDScript via `node.get_script().get_rpc_config()` (a Dictionary keyed by
method name → `{rpc_mode, transfer_mode, call_local, channel}`).

### Host / join over ENet (the `gd.*` multiplayer helpers)

`godot/Ergonomics_Multiplayer.odin` wraps the ENet peer + MultiplayerAPI plumbing so standing
up a P2P session and reacting to peers is a few readable lines. Every helper takes the node
(e.g. a script's `self.owner`) and reaches its MultiplayerAPI through `Node.get_multiplayer()`:

```odin
import gd "godot:godot"

// Host or join (call from a LIVE frame — the node must be inside the tree). Each returns a
// bool so you can branch on failure (port in use, ENet unavailable on web, …):
@(gd_method)
player_host :: proc(self: ^Player, port: gd.Int) {
	if !gd.host(self.owner, int(port)) { gd.error("could not host"); return }
	gd.on_peer_connected(self.owner, "on_peer_joined")     // wire peer_connected -> method
	gd.on_peer_disconnected(self.owner, "on_peer_left")
}
@(gd_method)
player_join :: proc(self: ^Player, port: gd.Int) {
	gd.join(self.owner, "127.0.0.1", int(port))            // attempt; wait for connected_to_server
}

// Joined/left handlers (an @(gd_method) taking the peer id):
@(gd_method) on_peer_joined :: proc(self: ^Player, id: gd.Int) { /* spawn their avatar */ }
@(gd_method) on_peer_left   :: proc(self: ^Player, id: gd.Int) { /* despawn */ }

// Inside any @(gd_rpc), read who sent the call:
@(gd_method, gd_rpc = "any_peer")
player_chat :: proc(self: ^Player, msg: gd.String) {
	from := gd.rpc_sender_id(self.owner)                   // 0 for a local call_local dispatch
	_ = from
}
```

| Task | One-liner |
| --- | --- |
| Host an ENet server | `ok := gd.host(self.owner, 7777)` (optional `max_peers`, default 32) |
| Join an ENet server | `ok := gd.join(self.owner, "127.0.0.1", 7777)` |
| Am I the server/host? | `gd.is_server(self.owner)` |
| My peer id | `id := gd.my_peer_id(self.owner)` (server is always `1`) |
| Sender of the current RPC | `gd.rpc_sender_id(self.owner)` (call inside an `@(gd_rpc)`) |
| All connected peer ids | `peers := gd.connected_peers(self.owner)` (`[]int`, temp-allocated) |
| The MultiplayerAPI | `mp := gd.multiplayer(self.owner)` |
| React to a peer joining/leaving | `gd.on_peer_connected(self.owner, "on_peer_joined")` · `gd.on_peer_disconnected(self.owner, "on_peer_left")` |

> **Web/WASM:** Godot's web export does not ship `ENetMultiplayerPeer`, so `gd.host`/`gd.join`
> compile but return `false` on wasm32 — branch on the bool. For browser co-op use the WebRTC
> helpers below instead. The query helpers (`is_server`, `my_peer_id`, `rpc_sender_id`,
> `connected_peers`) are platform-independent and work over any peer (ENet **or** WebRTC).

These are proven end-to-end by `tests/rpc_net`: two real headless Godot processes (a server +
a client) connect over ENet and exchange `@(gd_rpc)` calls in both directions, asserting each
call executed on the *other* peer with the correct `get_remote_sender_id()`.

### WebRTC / web co-op (`gd.webrtc_host` / `gd.webrtc_join`)

For co-op **in the browser, over the internet, with no port-forwarding**, use WebRTC. The
browser has a native WebRTC stack; Godot exposes it through `WebRTCMultiplayerPeer` /
`WebRTCPeerConnection`. `godot/Ergonomics_WebRtc.odin` drives the whole async setup — open a
signaling channel, trade an SDP offer/answer, trickle ICE, build the data channels, install
the peer — so a game only writes:

```odin
// host becomes peer id 1 and gets a ROOM CODE to share; the joiner uses that code:
@(gd_method) lobby_host :: proc(self: ^Lobby) { gd.webrtc_host(self.owner, "wss://your-server/rtc") }
@(gd_method) lobby_join :: proc(self: ^Lobby) { gd.webrtc_join(self.owner, "wss://your-server/rtc", "WATR") }

// pump the signaling socket every frame until connected (cheap no-op afterwards):
lobby_process :: proc(self: ^Lobby, _delta: f64) {
    gd.webrtc_poll(self.owner)
    code := gd.webrtc_room_code(self.owner) // host: "" until the server assigns it — display to share
}
```

Once connected, **the same `@(gd_rpc)` methods + `gd.rpc` / `gd.rpc_id` used over ENet just
work** — a `WebRTCMultiplayerPeer` is a `MultiplayerPeer` like any other, and the high-level
RPC layer is transport-agnostic. Nothing about your RPC code changes; only the transport
setup does.

| Task | One-liner |
| --- | --- |
| Host a WebRTC lobby (id 1) | `ok := gd.webrtc_host(self.owner, "wss://host/rtc")` |
| Join a WebRTC lobby by code | `ok := gd.webrtc_join(self.owner, "wss://host/rtc", "WATR")` |
| Read the host's room code | `code := gd.webrtc_room_code(self.owner)` (`""` until assigned) |
| Signaling state / error | `gd.webrtc_session_state(...)` / `gd.webrtc_error_reason(...)` |
| Pump signaling (every frame) | `gd.webrtc_poll(self.owner)` |
| Tear the session down | `gd.webrtc_close(self.owner)` |

**Signaling server.** WebRTC needs a rendezvous channel to swap connection info before the
peer-to-peer link exists. The server brokers a **room-code lobby**: a host `create`s a room and
gets a short CODE; a friend `join`s that CODE; the server relays the SDP offer/answer + ICE
candidates between the two *verbatim* (it never parses their contents). The wire protocol is
**JSON text frames** over a raw WebSocket (server path `/rtc`) — ANY server speaking this
small protocol works; a Node reference implementation ships at `tests/webrtc/signal_server.mjs`
(used by the headless tests; the maintainer runs an Elixir implementation in production):

```
client -> server                                  server -> client
  {"type":"create"}                                 {"type":"created","room":"<CODE>","id":1}
  {"type":"join","room":"<CODE>"}                   {"type":"joined","room":"<CODE>","id":<n>}
  {"type":"signal","to":<peerId>,"data":<opaque>}   {"type":"peer","id":<peerId>}
  {"type":"leave"}                                  {"type":"signal","from":<peerId>,"data":<opaque>}
                                                    {"type":"peer_left","id":<peerId>}
                                                    {"type":"error","reason":"no_room"|"full"|"bad_msg"}
```

The host (id 1) creates the offer; the joiner answers. **Deployment:** the *game* traffic is
peer-to-peer WebRTC (NAT-punching, no port-forwarding), but this signaling server must be
reachable by both players during setup — host it at a public `wss://HOST/rtc`. `Ergonomics_WebRtc
.odin` already configures a public **STUN** server on the `WebRTCPeerConnection`; for symmetric-NAT
pairs add a **TURN** relay to its `_ICE_CONFIG_JSON` (localhost needs neither).

> **Native caveat:** desktop/native Godot ships **no** WebRTC implementation — `WebRTCPeer
> Connection` is an abstract extension point ("No default WebRTC extension configured") that
> the separate [`godot-webrtc`](https://github.com/godotengine/webrtc-native) GDExtension must
> fill. So these helpers are a **web-target path**: they compile and run natively, but
> `initialize` fails unless `godot-webrtc` is installed (out of scope here). Prove + use them
> in the browser export — which is exactly what `tests/webrtc` does.

Proven end-to-end by `tests/webrtc`: **two real headless-Chrome instances** load the same
exported web page (one `?role=host`, one `?role=join`), establish a genuine browser-native
WebRTC data channel via the signaling server, and exchange `@(gd_rpc)` calls in both
directions — asserting, from each browser's JS console, that the call executed on the *other*
browser with the correct sender id (the in-browser mirror of `tests/rpc_net`).

## Ergonomic helpers

The `godot` package ships a hand-written ergonomics layer (`godot/Ergonomics*.odin`) that
collapses the common — but otherwise verbose — StringName / Variant / method-bind dances
into `gd.<helper>(...)` one-liners. Every helper takes/returns `Object`/`Node`/`Resource`,
which are type-aliases all object handles (`Node2d`, `Area2d`, `Label`, …) collapse to, so a
script's `self.owner` passes with no cast and a returned `Node` assigns to any handle var.

| Task | One-liner |
| --- | --- |
| Resolve a child by path | `child := gd.get_node(self.owner, "Hud")` |
| Get the parent node | `p := gd.get_parent(self.owner)` |
| Get the SceneTree | `tree := gd.get_tree(self.owner)` |
| Parent a node | `gd.add_child(self.owner, child)` |
| Group add / check / remove | `gd.add_to_group(self.owner, "enemies")` · `gd.is_in_group(self.owner, "enemies")` · `gd.remove_from_group(self.owner, "enemies")` |
| Load a resource | `res := gd.load("res://icon.png")` |
| Load a PackedScene | `scene := gd.load_scene("res://enemy.tscn")` |
| Instance a PackedScene | `node := gd.instantiate(scene)` |
| Load + instance + add_child | `enemy := gd.spawn(self.owner, "res://enemy.tscn")` |
| Set a property by name | `gd.set_int/set_float/set_bool/set_string(obj, "value", v)` · `gd.set_value(obj, "p", variant)` |
| Get a property by name | `gd.get_int/get_float/get_bool/get_string(obj, "value")` · `gd.get_value(obj, "p")` |
| Connect own signal → own method | `gd.connect(self.owner, "body_entered", "collect")` |
| Connect emitter → target method | `gd.connect_to(emitter, "sig", target, "method")` |
| Build a bound Callable | `cb := gd.callable(self.owner, "method")` |
| Emit a signal (no payload) | `gd.emit(self.owner, "died")` |
| Emit a signal with payload | `v := i64(value); gd.emit_args(self.owner, "collected", gd.variant_from(&v))` |
| Read a project setting | `gd.get_setting_int/float/bool/string("game/lives")` · `gd.get_setting("p")` (raw Variant) · `gd.get_setting_or("p", default)` |
| Write a project setting | `gd.set_setting_int/float/bool/string("game/lives", v)` · `gd.set_setting("p", variant)` |
| Has a project setting | `gd.has_setting("game/lives")` |
| Define an input action | `gd.add_action("fire")` (optional `deadzone`) |
| Bind a key / mouse button | `gd.action_add_key("fire", i64(gd.Key.Space))` · `gd.action_add_mouse_button("fire", i64(gd.Mouse_Button.Left))` |
| Has / erase an action | `gd.has_action("fire")` · `gd.erase_action("fire")` |
| Poll an action | `gd.is_action_pressed("fire")` · `gd.is_action_just_pressed("jump")` · `gd.is_action_just_released("jump")` · `gd.get_action_strength("accelerate")` |
| Movement input | `x := gd.get_axis("ui_left", "ui_right")` · `v := gd.get_vector("ui_left", "ui_right", "ui_up", "ui_down")` |
| Synthesize input | `gd.action_press("fire", 0.8)` · `gd.action_release("fire")` |
| Intern a name inline | `gd.sname("run")` → `String_Name` · `gd.gstr("text")` → `String` (for raw calls with no `gd.*` wrapper) |
| Running in the editor? | `if gd.is_editor() { ... }` (wraps `Engine.is_editor_hint()`) |
| Set / get a control's text | `gd.set_text(self.label, "Score: 0")` · `s := gd.get_text(self.label)` (any Control with a `text` property) |
| Play / stop an animation | `gd.animation_play(self.anim, "run")` · `gd.animation_stop(self.anim)` · `gd.is_animation_playing(self.anim)` |
| Play / stop an AnimatedSprite2D | `gd.sprite_play(self.spr, "idle")` · `gd.sprite_stop(self.spr)` · `gd.is_sprite_playing(self.spr)` |
| Play / stop audio | `gd.audio_play(self.sfx)` · `gd.audio_stop(self.sfx)` (positional: `gd.audio_play2d` / `gd.audio_stop2d`) |
| Set one position component | `gd.node2d_set_x(self.owner, 100)` (also `node3d_*` with `_z`, `control_*` with `_width`/`_height`; see [Common 2D transforms](#common-2d-transforms--moving--rotating-a-node2d)) |

`gd.get_setting*`/`gd.set_setting*` wrap the `ProjectSettings` singleton; `gd.add_action`
/ `gd.action_add_*` wrap the `InputMap` singleton (constructing the `InputEventKey` /
`InputEventMouseButton` for you). Settings/actions registered at runtime are visible to
GDScript (`ProjectSettings.get_setting`, `InputMap.has_action`, `Input.is_action_pressed`)
but are NOT persisted to `project.godot` — they are the "register my game's settings +
actions on an autoload's `_ready`" pattern (see below). `gd.get_setting_string` is the one
that allocates (in `context.allocator`); the rest are `proc "contextless"`.

All helpers are `proc "contextless"` except `gd.get_string`, which allocates the returned
Odin `string` in `context.allocator` (fine inside any script proc — those run with the
script context set). For a script-declared signal field, prefer the generated typed
`<struct_snake>_emit_<field>` helper; `gd.emit_args` is the by-name escape hatch (and the
path `gd.emit`/`emit_args` both take — Godot's `emit_signal` is a vararg method, so they
varcall it rather than ptrcall).

**The interning pattern.** The `gd.*` helpers above all take plain Odin `cstring`s and do the
Godot `String` / `String_Name` interning internally — that's the ergonomic path, so reach for a
helper first. When you call a *raw* bound method that has no wrapper, it takes a `String_Name`
(method/signal/action/animation/property names) or a `String`, and you intern inline with
`gd.sname("…")` / `gd.gstr("…")` rather than spelling out `new_string_name_cstring(…, true)`:

```odin
// raw call (no dedicated helper): intern the name inline
if gd.object_has_method(enemy, gd.sname("take_damage")) {
    // ...
}
```

`gd.sname` uses `static = true` (intern once, keep) — correct for the string *literals* these
calls almost always use.

### Common transforms — moving / rotating a Node2D

`gd.Vector2` is just an Odin `[2]f32`, so you get Odin's vector math for free: component access
(`pos.x`), compound assignment (`pos.x += 10`), and whole-vector arithmetic (`pos += other`,
`pos * delta`). The only round-trip is the get/set across the engine boundary — and for the
common "move/rotate/scale by a delta" cases, Godot's own one-call methods skip even that, so you
don't need get → modify → set at all:

| Instead of (get → modify → set) | One call |
| --- | --- |
| `pos.x += 10` on the position | `gd.node2d_translate(self.owner, gd.Vector2{10, 0})` |
| move along the node's own axes (respects rotation) | `gd.node2d_move_local_x(self.owner, 10)` · `gd.node2d_move_local_y(self.owner, 10)` |
| rotate by radians | `gd.node2d_rotate(self.owner, 0.1)` |
| scale by a factor | `gd.node2d_apply_scale(self.owner, gd.Vector2{2, 2})` |
| set / get in world space | `gd.node2d_set_global_position(self.owner, p)` · `gd.node2d_get_global_position(self.owner)` |
| set ONE position component (keep the other) | `gd.node2d_set_x(self.owner, 100)` · `gd.node2d_set_y(self.owner, 250)` (and `_global_x` / `_global_y`) |

The `node2d_set_x` / `_set_y` (+ `_global_x` / `_global_y`) helpers cover the absolute-component
case — "snap x to 100, keep y" — without the get → modify → set round-trip. **The same setters
exist for the other positional types:** `node3d_set_x/_y/_z` (+ `_global_*`), and
`control_set_x/_y`, `control_set_width/_height`, `control_set_global_x/_y`. If you ever need it by
hand (a component with no setter, or another type), it's plain Odin array math:

```odin
pos := gd.node2d_get_position(self.owner)
pos.x = 100                                  // Odin array swizzle — no Vector2 ctor needed
gd.node2d_set_position(self.owner, pos)
```

The same shape generalizes: every Godot method on a node is bound as
`gd.<class_snake>_<method>(handle, args…)` (so reach for `node2d_translate`, `control_set_size`,
`sprite2d_set_frame`, …), and the math types (`Vector2/3`, `Color`, `Rect2`, …) are plain Odin
structs/arrays you manipulate with normal operators.

## Supported Odin → Variant types

| Odin type | Variant | Notes |
| --- | --- | --- |
| `int`, `i8/i16/i32/i64`, `u8..u64`, `uint`, `gd.Int` | `Int` | width-narrowed via `size_of` |
| `f32`, `f64`, `gd.Float`, `gd.Real` | `Float` | |
| `bool` | `Bool` | |
| `string`, `gd.String` | `String` | |
| `gd.Vector2`, `gd.Vector3`, `gd.Color` | matching | |
| `gd.String_Name` | `String_Name` | |
| `^gd.<Object subclass>`, `gd.Node`, `gd.Object`, ... | `Object` | object handle |

Unsupported types produce a clear `scriptgen` error (no silent miscompile).

## Threads & memory

Practical rules for what runs where and who owns which allocation:

- **Everything script-facing runs on the engine's main thread.** Lifecycle procs
  (`*_ready`, `*_process`, …), `@(gd_method)` calls, `@(gd_connect)` handlers and
  `@(gd_rpc)` procs are all invoked by the engine on its main thread; the generated
  trampolines add no synchronization. Don't call `gd.*` / engine APIs from threads you
  spawn with `core:thread` — compute on the worker, then apply the result back on the
  main thread from a lifecycle proc (e.g. poll a mutex-guarded value in `*_process`).
- **`rt.script_of` is main-thread-only too**: it resolves through the core's live-instance
  registry, which the main thread mutates as script instances are created and freed.
- **`context.allocator` is a real, persistent allocator** inside script procs: the Odin
  heap default on native, an engine-backed (alignment-correct) allocator on web. Either
  way, what you `make`/`new` there lives until you free it.
- **`context.temp_allocator` is call-local.** The core resets its shared temp arena once
  per frame from the main-thread frame pump, so never stash a temp pointer (including
  `fmt.tprintf`/`fmt.ctprintf` results) across frames — copy anything you keep into
  `context.allocator` memory.
- **String-returning helpers allocate — the caller frees.** `gd.get_string` (and helpers
  like it that return an Odin `string`) allocate from `context.allocator`; `delete(s)`
  when you're done with it.
- **`gd.sname` interns forever.** It is `new_string_name_cstring(name, true)` —
  `static = true` hands Godot the cstring pointer to keep for the program's lifetime.
  Pass only string literals (or otherwise program-lifetime, ASCII) names; never a name
  built at runtime from a temporary buffer such as `fmt.ctprintf(...)`.

## Building

`build/build_scripts.sh [PROJECT_DIR]` runs the full pipeline:

1. builds the `scriptgen` binary,
2. runs `scriptgen <scriptsdir>` to emit the `*.gen.odin` build artifacts beside the
   authored sources (no resource stubs — the authored `.odin` is the attached resource),
3. builds the scripts dll with `odin build <scriptsdir> -build-mode:dll
   -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc
   -custom-attribute:gd_command -custom-attribute:gd_tick
   -custom-attribute:gd_sample -custom-attribute:gd_step ...`
   (the `.gen.odin` are in the same package and compile together),
4. builds the core dll.

The seven `-custom-attribute:` flags are required so the Odin compiler accepts the
`@(gd_method)` / `@(gd_connect)` / `@(gd_rpc)` / `@(gd_command)` / `@(gd_tick)` /
`@(gd_sample)` / `@(gd_step)` marker attributes; the build script passes them for you.

The build, the **live-editing (show-on-save) loop**, the editor DX (validation / autocomplete
/ highlighting), debugging, and the editor settings (`odin_godot/odin_bin`,
`odin_godot/scripts_dir`, …) are all covered in **[Workflow](workflow.md)**.

## Multiple scripts in one package

A scripts dll is one Odin package. Because lifecycle/method procs and generated
emit helpers live in that shared package, prefix your proc names with the struct
name (`ping_ready`, `ping_add`) to avoid collisions — the prefix is stripped to
derive the GDScript-facing name. One script struct per file (identified by its
first field being named `owner`).

## Custom resources

`//gd:extends Resource` makes the script a **custom resource** — a pure data
container (a `RefCounted`, not a scene-tree node), exactly like a GDScript
`extends Resource`. Everything is the same as any other script; only the base
differs. Use it for designer-tunable data assets you create, edit in the
Inspector, and save as `.tres`.

```odin
//gd:extends Resource
//gd:class ItemData
package game_scripts

import gd "godot:godot"

ItemData :: struct {
	owner: gd.Resource,
	name:  gd.String   `gd:"export"`,
	value: gd.Int      `gd:"export,range=0:999"`,
	icon:  ^gd.Resource `gd:"export,resource=Texture2D"`,
}

@(gd_method)
item_data_item_total :: proc(self: ^ItemData) -> int {
	return int(self.value) + 100
}
```

- **No lifecycle.** A resource is not in the scene tree, so `_ready` / `_process`
  / `_physics_process` never fire — omit them. `@export` vars and `@(gd_method)`s
  work as usual.
- **First field is `owner: gd.Resource`** (the owner-Object convention), instead
  of a `gd.Node`/`gd.Node2d`.
- **`.tres` serialization is automatic.** `@export` vars carry the STORAGE usage
  flag, so Godot's own text-resource serializer writes them — plus a reference to
  this script — into a `.tres`. Loading the `.tres` reconstructs a live instance
  with the script re-attached, so its methods still dispatch:

  ```gdscript
  var item = Resource.new()
  item.set_script(load("res://scripts/item_data.odin"))
  item.set("name", "Sword"); item.set("value", 10)
  ResourceSaver.save(item, "res://sword.tres")

  var loaded = ResourceLoader.load("res://sword.tres")
  loaded.get("value")        # 10
  loaded.call("item_total")  # 110 — script re-bound on load
  ```

  The saved `.tres` is plain Godot text:

  ```
  [gd_resource type="Resource" format=3]
  [ext_resource type="Script" path="res://scripts/item_data.odin" id="1_x"]
  [resource]
  script = ExtResource("1_x")
  name = "Sword"
  value = 10
  ```

- **Editable in the editor.** Unlike a non-tool *node* script (which the editor
  shows via a read-only placeholder), attaching a resource script builds a real,
  live instance even in the editor — so its `@export` values are directly editable
  in the Inspector and persist on save.
- **Resource-typed `@export`.** A field `data: ^gd.Resource
  `gd:"export,resource=ItemData"`` on a *node* script gives a resource-picker slot
  that accepts a custom `ItemData` `.tres`. The `resource=` hint string filters the
  picker, and because `ItemData` is now registered as a global class (see below) the
  editor knows it as a type.

## Global class names

Every `//gd:class <Name>` is registered as a **global class** — a first-class engine
type, exactly like a GDScript `class_name`. No extra annotation is needed; the class
name you already declare becomes the global name.

- `Script.get_global_name()` returns `<Name>` (this is `ScriptExtension._get_global_name`,
  the virtual the editor's filesystem scan reads).
- After the editor scans the project, `<Name>` appears in
  `ProjectSettings.get_global_class_list()` with its declared native `base_type` (from
  `//gd:extends`), so the engine treats it as a usable type and a type-filter (e.g. a
  resource/node-typed `@export` picker).

The registration is driven by the language's `_handles_global_class_type` /
`_get_global_class_name(path)` virtuals, which reparse the `.odin` file's markers and
hand back `{name, base_type, icon_path}`.

## Typed cross-script references

Because every script in a project compiles into ONE shared dll, a struct type declared
in one script (e.g. `Enemy`) is the *same* type everywhere. `rt.script_of(obj, T)` turns
a live Godot object into a typed `^T` pointer to the Odin script struct the engine
allocated for it — giving DIRECT typed field and proc access across scripts, with no
Variant marshaling:

```odin
import gd "godot:godot"
import rt "godot:runtime"

@(gd_method)
controller_attack :: proc(self: ^Controller, amount: gd.Int) -> int {
	target := gd.get_node(self.owner, "Enemy")  // or an @export node ref
	enemy := rt.script_of(target, Enemy)         // -> ^Enemy (nil if not an Odin Enemy)
	if enemy == nil { return -1 }
	enemy.hp -= amount       // direct typed field write
	enemy_heal(enemy, 0)     // direct typed proc call
	return int(enemy.hp)
}
```

- `script_of` returns `nil` when `obj` is nil or carries no Odin script of *our*
  language (a foreign-language node, a placeholder, or a plain engine node) — it is
  nil-safe, never a wild cast.
- Works on web too (single module — the same resolver is wired directly).
- **Module boundary:** if the project uses [script modules](modules.md), `script_of` is
  typed access within *one* module only — across modules it returns `nil` by construction
  (modules can't import each other's types), and cross-module access goes through the
  engine (signals, name-based calls, autoloads). See [Script Modules](modules.md).
- For calling across a dll boundary (e.g. a tool that dispatches by name), the
  GDScript-style `obj.call("method", args...)` path remains available; `script_of` is the
  zero-overhead typed path within the shared scripts dll.

For shared state with *no* per-node instance to reference (a global score, a constant
table), the package-level "module" pattern (file-private vars + package procs like
`game_state_add`) is the simplest tool: every script in a project compiles into ONE Odin
package, so they all share those globals with zero Godot glue. It is NOT, however, a real
Godot singleton — it is not reachable at `/root/Name`, not visible to GDScript, and has no
`_ready`. When you need that (a manager node GDScript can call, lifecycle, persistence
across scene changes), use an **autoload** — see below.

## Autoload singletons

A `.odin` script can be a real Godot **autoload** singleton — a node added under `/root`
at startup, reachable everywhere (from GDScript as `Name` or `/root/Name`, from Odin via
`gd.get_node` on any node's tree), persistent across scene changes, running `_ready` once.

Write a normal script whose base is a `Node` (or any `Node` subclass), give it a
`//gd:class` name, and add it to `project.godot`'s `[autoload]` section with a leading `*`:

```odin
//gd:extends Node
//gd:class GameManager
package my_game_scripts

import gd "godot:godot"

GameManager :: struct {
	owner: gd.Node,
	score: gd.Int,
}

game_manager_ready :: proc(self: ^GameManager) {
	// Runs ONCE at startup. A good place to register the game's project settings +
	// input actions from Odin (see the ergonomic helpers above):
	gd.set_setting_int("game/lives", 3)
	gd.add_action("fire")
	gd.action_add_key("fire", i64(gd.Key.Space))
}

@(gd_method)
game_manager_add_score :: proc(self: ^GameManager, amount: int) {
	self.score += gd.Int(amount)
}

@(gd_method)
game_manager_get_score :: proc(self: ^GameManager) -> int {
	return int(self.score)
}
```

`project.godot`:

```ini
[autoload]

GameManager="*res://scripts/game_manager.odin"
```

The leading `*` is what makes the entry a **singleton node**: Godot instantiates the
script's base node (`//gd:extends Node`), attaches the Odin script, runs `_ready`, and adds
it under `/root` with the autoload's name. Without the `*` the path would be loaded as a
plain resource, not added to the tree. GDScript then reaches it directly:

```gdscript
GameManager.add_score(5)                       # autoload name is a global identifier
get_node("/root/GameManager").call("add_score", 5)
print(GameManager.get_score())
```

`@(gd_method)` procs are GDScript-callable (the proc name has its `<struct_snake>_` prefix
stripped: `game_manager_add_score` → `add_score`). The node is the SAME instance for the
whole session, so its struct fields are your singleton state.

> The base must be a `Node` subclass — an autoload entry is added to the scene tree, and a
> non-`Node` base cannot be parented. (A `Resource`/`RefCounted` script in `[autoload]`
> would load but not become a `/root` node.)

**Alternative — `Engine.register_singleton`.** For a *non-node* global (e.g. exposing an
object to GDScript as `Engine.get_singleton("Name")` without putting it in the scene tree),
the binding also has `gd.engine_register_singleton(engine, name, obj)` /
`gd.engine_get_singleton(engine, name)`. The `[autoload]` node form above is the
GDScript-parity path (lifecycle + `/root/Name` + persistence); `register_singleton` is the
lower-level escape hatch when you specifically do not want a node.

See `tests/autoload/` for a full, headless-verified example (a `GameManager` autoload whose
`_ready` registers a project setting + an input action, driven from GDScript).

## Editor tooling

Odin scripts can run **in the editor** and extend it. See `tests/editortools/` for the
headless-verified examples of everything below.

### `@tool` scripts + `gd.is_editor()`

A `//gd:tool` marker makes the engine build a **real instance in the editor** (not a
placeholder), so the script's lifecycle (`_ready`, `_process`, `_enter_tree`, …) runs at
edit time too. Branch editor-only logic with the `gd.is_editor()` helper (it wraps
`Engine.is_editor_hint()`):

```odin
//gd:extends Node
//gd:class ToolWidget
//gd:tool
package my_game_scripts

import gd "godot:godot"

ToolWidget :: struct { owner: gd.Node }

tool_widget_ready :: proc(self: ^ToolWidget) {
	if gd.is_editor() {
		// runs in the editor (edit mode) — e.g. live preview / gizmo setup
	} else {
		// runs only in the actual game
	}
}
```

`gd.is_editor()` returns `false` at game runtime (including exported builds) and `true`
while the editor holds the scene open. It's only meaningful inside `//gd:tool` scripts —
non-tool scripts never run at edit time.

### Custom class icons

`//gd:icon res://path.svg` gives a `//gd:class` a custom icon in the editor (Scene dock,
Create Node/Resource dialogs):

```odin
//gd:extends Node
//gd:class IconNode
//gd:icon res://icon.svg
package my_game_scripts
```

The path threads into both the script's `_get_class_icon_path` virtual and the global class
registry's `icon_path` (so `ProjectSettings.get_global_class_list()` carries it). *(The icon
PIXELS rendering in the dock is a visual editor behavior — the registered path is what these
hooks provide.)*

### EditorPlugin

A `//gd:extends EditorPlugin` script (also `//gd:tool`) is a real editor plugin. Register it
with the standard Godot plugin format — a `res://addons/<name>/plugin.cfg`:

```ini
[plugin]
name="My Odin Plugin"
script="my_plugin.odin"     ; relative to the addon dir
```

…and enable it in `project.godot`:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/<name>/plugin.cfg")
```

When the project opens, Godot instantiates the plugin in the editor and dispatches
`_enter_tree` / `_exit_tree` (which arrive as Node ENTER_TREE / EXIT_TREE notifications, so
author them as `enter_tree` / `exit_tree` lifecycle procs):

```odin
//gd:extends EditorPlugin
//gd:class MyPlugin
//gd:tool
package my_plugin

import gd "godot:godot"

MyPlugin :: struct { owner: gd.Node }

my_plugin_enter_tree :: proc(self: ^MyPlugin) {
	gd.print("MyPlugin loaded")   // or add_tool_menu_item / add_control_to_dock / ...
}
my_plugin_exit_tree :: proc(self: ^MyPlugin) {}
```

> The whole project's Odin scripts compile as **one Odin package**. Because a plugin's
> `script=` path must live under its addon dir, put the addon's package there (e.g.
> `res://addons/<name>/*.odin`) and point `build/build_scripts.sh <proj> <that-dir>` at it.

### EditorInspectorPlugin (advanced)

A `//gd:extends EditorInspectorPlugin` script can customize the Inspector. Expose the engine
virtuals as `@(gd_method)` procs — the codegen strips the `<struct_snake>_` prefix, so a
proc named `my_inspector__can_handle` is exposed as the exact virtual `_can_handle` (note the
double underscore):

```odin
@(gd_method)
my_inspector__can_handle :: proc(self: ^MyInspector, object: ^gd.Object) -> bool { return true }

@(gd_method)
my_inspector__parse_begin :: proc(self: ^MyInspector, object: ^gd.Object) { /* add controls */ }
```

These virtuals **dispatch into Odin** when invoked (verified headless by calling them
directly). Whether the editor auto-invokes them during a *live* Inspector rebuild — after
`add_inspector_plugin()` and selecting a handled object in the dock — is a UI-driven path
that is **visual-only** (not asserted headless).

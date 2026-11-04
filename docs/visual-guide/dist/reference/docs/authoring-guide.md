# Authoring guide — the Odin script feature reference

This reference covers the Odin script struct convention, `//gd:` markers,
`@export` forms, lifecycle callbacks, methods, signals, resources, autoloads,
cross-script access, `gd.*` helpers, and editor tooling. Start with
[Getting Started](getting-started.md) for setup and a first script. For the
build, edit, and debug loop, see [Workflow](workflow.md).

Write `<name>.odin` using the struct and procedure conventions below. The
`scriptgen` preprocessor, run by `build/build_scripts.sh`, reads its tags and
markers and generates registration code, including Variant argument wrappers,
backing arrays, and `@(init)` registration. The authored and generated files
compile together into the scripts library. Edit the authored source.

## API conventions shared by Kit and Replay

Use [Odin's naming and style conventions](https://github.com/odin-lang/examples/wiki/Naming-and-style-convention):
`Ada_Case` for types and enum members, `snake_case` for procedures and fields,
and `SCREAMING_SNAKE_CASE` for constants. Prefer a short, meaningful import alias.
Indent with four spaces and put each statement on its own line; `make format`
applies this layout. Use explicit error handling in examples. Generated Godot
bindings retain their existing engine-derived names, such as `gd.Node2d` and
`gd.node2d_set_position`.

Script helpers use the snake-case script type as their prefix:
`Player_Controller` and the existing `PlayerController` spelling both produce
`player_controller_*`; `HUD_View` produces `hud_view_*`. A lifecycle proc is
therefore `player_controller_ready`; an exposed `player_controller_jump` method
appears as `jump` to Godot. Two script types in one package must have distinct
snake-case prefixes. Regenerate scripts after changing a type name. Existing
acronym spellings that depended on one underscore per capital must migrate to
the whole-word prefix, such as `http_server_*` for `HTTPServer`.

| Rule | Kit (v1) | Replay (v2) |
| --- | --- | --- |
| Normal game loop | Generated `<game>_net_attach`, `<game>_net_frame`, `<game>_net_detach` | `session_open`, `session_frame`, `session_close`; use Room when authority can migrate |
| Gameplay mutation | Tagged fields and generated command wrappers | A typed value World and model step/action callbacks |
| Presentation | Generated event handlers and typed entity queries | Drain all presentation changes, then present copied state |
| Additional mechanisms | Raw session/lane/transport APIs for custom integrations | Raw net/P2P/transport APIs for custom policies |

Choose one top-level runtime to drive the game. Kit's generated network
callbacks, Replay Session, and Replay Room each advance their lower layers;
do not also advance those layers yourself. Keep live owners at stable
addresses and pass them by pointer. Configuration and copied World/frame values
may be copied; live owners with allocations, callbacks or connections may not.
Start configuration from the documented defaults, rather than assuming every
empty options struct is usable.

Match setup and teardown: `init`/`destroy` for owned Odin storage,
`open`/`close` for a live session, and `attach`/`detach` for an engine
attachment. Packages with several owners add a type prefix, such as
`session_open`. These verbs describe ownership. In a Godot script, release live
owners in `*_exit_tree`. A `defer` in
`*_ready` would run when that callback returns, not when the node leaves the tree.
Borrowed readers, handles and views do not acquire ownership merely by being
returned from a procedure. A query may return copied values, an owner-borrowed
slice, or a frame-temporary view of live entity handles. Check its lifetime
before retaining a result. Initialization can allocate diagnostics even when it
fails; perform the documented cleanup on failure too. Fixed-value World
components such as Pool and owned state need no independent destructor.

The ordinary call sequence is setup, frame/service, drain, read, teardown.
Queries read current state; frame/service calls advance it; queue consumers
must drain until empty. Configuration fields and documented observations form
the supported API of a runtime owner. Its other fields are storage
for the implementation, not another way to drive it.

Successful action or chat submission can mean that work was queued locally.
Use the authoritative receipt or confirmed presentation change when game logic
needs an accepted outcome; a successful send alone does not establish it.

See [Kit conventions](kit/conventions.md) and the
[Replay starting path](../replay/getting-started.md) for each model's concrete
lifetimes, defaults and extension points.

## Single-file authoring

There is one file per script: the `.odin` you write is also the resource
you attach to a node. Put your scripts under the project (e.g. `res://scripts/foo.odin`)
and attach `res://scripts/foo.odin` directly in the scene. The loader reads its
canonical resource path and binds it to the descriptor generated for that exact file.
`//gd:class` is optional and only adds a Godot global-class alias. There is no separate
"resource stub" file to keep in sync.

Each scripts directory gets one `odin_godot_scripts.gen.odin` beside its sources,
with a marked section for each script. The generated file must share the
directory's package. The loader ignores `*.gen.odin`, so generated files are
not attachable scripts. The editor hides them from the FileSystem dock by
default.

## Anatomy of a script

```odin
//gd:extends Node          // base Godot class. Optional — derived from `owner` when omitted.
//gd:class Ping            // optional: opt into Godot's global class namespace
//gd:tool                  // optional: registers as a @tool script
package my_scripts

import gd "godot:godot"

// The script struct's first field must be the owner Object handle. The core
// writes the owner pointer at offset 0. Choose the handle type used by your
// procedures (gd.Node, gd.Object, gd.Node2d, ...). The base follows
// //gd:extends when present; otherwise it is derived from the handle type.
Ping :: struct {
	owner:  gd.Node,
	pinged: gd.Signal1(int) `gd:"args=value"`, // signal field -> declared signal (see Signals)
	speed:  f32    `gd:"export"`,  // tagged field -> @export var
	count:  gd.Int `gd:"export"`,
	scratch: int,                 // untagged -> private per-instance state
}

// Engine calls (add_child, connect_to, queue_free, ...) take `self.owner`.
// `self` points to this Odin struct. Engine handles are distinct types,
// so the compiler rejects a script pointer passed as an engine handle.
// scriptgen also rejects the bare-`self` form at build time
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
| `//gd:extends <Class>` | The Godot base class. **Optional**: when omitted, it is derived from the `owner` field's type. |
| `//gd:class <Name>` | Optional Godot global-class alias, like GDScript `class_name`. Runtime attachment does not need it. |
| `//gd:tool` | Registers the class as a `@tool` script (`is_tool() == true`) and runs in the editor. |
| `//gd:icon res://path.svg` | Custom class icon (Scene dock, Create Node/Resource dialog). |
| `//gd:group a b` | Declarative group membership: every instance joins the named groups on READY (space-separated, repeatable). Replaces `gd.add_to_group` boilerplate in `_ready`; pairs with the typed group queries (`rt.scripts_in_group` & co.). |

The authored `res://scripts/<x>.odin` path is the runtime identity. Markers add
engine metadata and behavior; they do not decide which compiled descriptor attaches.
Several scripts may therefore share a base type, or a struct name across
separate Odin packages, because their resource paths distinguish them.

`//gd:extends` and the `owner` field state the same fact twice, so scriptgen
cross-checks them. The owner handle must be the declared base or one of its
ancestors.

```odin
//gd:extends CharacterBody2D
Player :: struct { owner: gd.Node2d }   // fine — a wider handle; the script only calls Node2D methods

//gd:extends Node
Player :: struct { owner: gd.Node2d }   // build error — a NARROWER handle
```

A narrower handle lets a script call methods its Godot base does not support.
Class handles share the distinct `gd.Object` representation, so Odin accepts a
`gd.Node2d` handle even when the registered class is a plain `Node`. A `gd.node2d_*` call through
that handle can then crash inside Godot. The build error names the declared
base, the handle type, and the two ways to make them consistent.

Omit the marker to derive the base from the handle type:

```odin
//gd:class Coin
package scripts
Coin :: struct { owner: gd.Area2d }     // registers as Area2D
```

The base falls back to `Node` only where the handle can't be placed (no
`-godot:` root, or a type that isn't a ClassDB class), and the check stays silent
in exactly those cases.

### The tag vocabulary

Every `` `gd:"…"` `` tag starts with a token selecting the field kind. The table
below follows `FIELD_TOKENS` in `decl/decl.odin`, the schema shared by scriptgen
and the runtime reflection registrar:

| First token | What it declares | Consumed by | In the wire fingerprint |
| --- | --- | --- | --- |
| `export` | an editor-visible property | the runtime registrar | no |
| `onready=PATH` | an auto-wired node reference (`^ScriptStruct` field: node + typed script struct) | the runtime registrar | no |
| `replicate` | a networked field on the DELTA lane ([kit/net](kit/net.md)) | scriptgen | yes |
| `owner` | a networked field streamed from its owning peer | scriptgen | yes |
| `predict` | a networked field the sim predicts and reconciles ([kit/sim](kit/sim.md)) | scriptgen | yes |
| `backup` | a field the session backup carries | scriptgen | no (see below) |
| `manual` | "I call the generated thing myself" | scriptgen | no |
| `profile=T` | the per-player profile row type | scriptgen | yes |
| `entity=Name:id` | a spawnable entity type and its stable id | both | yes |

`args=a,b` follows the first token and names a signal payload's parameters.
"In the wire fingerprint" means the declaration contributes to
`NET_FINGERPRINT`. Peers compare that fingerprint at join and reject mismatched
builds before interpreting gameplay packets.

`backup` is excluded from the session fingerprint. Its codec checks a
`fnv1a32` format stamp when loading a save and rejects an incompatible format.
That check is separate from network admission: peers with different save
formats can still play together if their network declarations agree. The
table marks a declaration yes when peers must agree on its wire representation.

A declaration that contributes to `NET_FINGERPRINT` selects the field kind
and must be the tag's first token. `backup` and `manual` also lead their tags,
though they do not contribute to the fingerprint. The selected kind determines
which options may follow:

- `replicate`, `owner`, and `predict` each select one lane with its own allowed
  options, listed below. `slack=` belongs to the predicted lane. Combining
  `owner` with `predict`, or using `slack=` outside `predict`, is invalid.
- `entity=Name:id` declares a permanent public type id and an entry in the
  factory table. Scriptgen makes the field an exported `PackedScene`, so write
  `` `gd:"entity=Mob:3"` `` rather than
  `` `gd:"export,resource=PackedScene,entity=Mob:3"` ``. Follow it with entity
  options: `stream_hz=N` sets the kind's owner-stream rate for every peer and
  spawn, and `avatar` marks a seat's body so a host takeover parks it with the
  seat instead of adopting it. Export specifications can follow, as in
  `entity=Mob:3,stream_hz=30,group=Spawns`. See
  [kit/boot](kit/boot.md#the-entity-factory).

| Lane | Tag | Its options |
| --- | --- | --- |
| delta | `gd:"replicate"` | `interp`, `interp=angle`, `interp=BLEND_PROC`, `wire=f16`, `wire=CODEC` |
| owner-streamed | `gd:"owner"` | continuous stock types interpolate by default; `snap` opts out; `interp=angle`, `interp=BLEND_PROC`, `wire=f16`, `wire=CODEC` customize |
| predicted | `gd:"predict"` | the above, plus `slack=N`, `glide=N`, `cut=N` |

`_edge` halves pair with `gd:"replicate"` fields and discrete owner fields.
Predicted state uses resimulation, and continuous owner-streamed state uses
interpolation, so those fields have separate presentation paths.

A field's resolved lane is what folds into `NET_FINGERPRINT`, so two builds that resolve a
field to the same lane share a session bit for bit regardless of how the tag is spelled.
A field selects one lane. The deprecated combined spelling `gd:"replicate,interp,owner,wire=f16"`
is refused at build time, with the error naming its replacement, `gd:"owner,wire=f16"`
(continuous owner fields interpolate automatically).

### Exports

Struct fields tagged `` `gd:"export"` `` become `@export` vars: the field name is
the property name, the field type maps to a Variant type. `offset`/`size` are
derived with `offset_of` / `size_of`, so the core narrows native Variant widths
(Int=i64, Float=f64) to your field's real width (e.g. `f32`).

Export fields use the supported Godot Variant types below. Use a `gd.<Type>`
binding type or a bare Odin scalar, which the runtime narrows to the field's width:

| Category | Field types |
| --- | --- |
| Scalars | `bool`; `i8`/`i16`/`i32`/`i64`/`int`/`u8`/`u16`/`u32`/`u64`/`uint`/`gd.Int`; `f32`/`f64`/`gd.Float` |
| Strings | `gd.String`, `gd.String_Name`, `gd.Node_Path` |
| Math | `gd.Vector2`/`Vector2i`, `gd.Rect2`/`Rect2i`, `gd.Vector3`/`Vector3i`, `gd.Vector4`/`Vector4i`, `gd.Transform2d`/`Transform3d`, `gd.Plane`, `gd.Quaternion`, `gd.Aabb`, `gd.Basis`, `gd.Projection`, `gd.Color` |
| Containers | `gd.Dictionary`, `gd.Array`, and every `gd.Packed_*_Array` (`Byte`, `Int32`, `Int64`, `Float32`, `Float64`, `String`, `Vector2`, `Vector3`, `Vector4`, `Color`) |
| Handles | Resource handles such as `gd.Texture2d` and pointers to them; `gd.Object` with an explicit `resource=` hint; `gd.Rid` (see below) |

Note: `gd.Callable`/`gd.Signal`/`gd.Rid` map to their Variant types but are not
meaningfully editable in the Inspector (Godot itself doesn't expose them as exports);
prefer them only for cross-script data, not for editor-tunable values. An unrecognized
field type is a hard `scriptgen: error:` (so a typo is never silently an `Object`).

Extend the tag with a hint specification: `` `gd:"export,SPEC"` ``.
Top-level tokens are comma-separated; values within a specification
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
float; `multiline` for a `gd.String`. A typed resource handle derives its own
`resource=` hint. Prefer `bullet_scene: gd.Packed_Scene `` `gd:"export"` ``:
the build reads the class from the type, the Inspector shows a PackedScene
picker, and `gd.instantiate(self.bullet_scene)` needs no cast.

Write `resource=` explicitly only for a type-erased `gd.Object` field. Object
exports require a resource hint, whether derived or explicit, so the runtime
can retain the assigned resource. Without a hint, the scene loader could drop
its reference and leave a dangling pointer; the build rejects that declaration.
Node handles such as `gd.Node2d` or `^gd.Node2d` cannot be exported. Use
`onready=` to reference scene nodes.
**`array=ELEM`** (on a `gd.Array` field) and
**`dict=KEY;VALUE`** (on a `gd.Dictionary` field) declare *typed* collections, the same
Inspector editors that GDScript's `Array[T]` / `Dictionary[K,V]` produce. Each element/key/value
is a builtin (`int`, `float`, `String`, `Vector2`, `Color`, …) or a Resource class name
(`Texture2D`, `PackedScene`, …). Each field accepts at most one hint. For a
scene used to spawn a network entity, `gd:"entity=Name:id"` generates both
the export and the `resource=PackedScene` hint. See
[Entities](kit/net.md#declaring-a-replicated-entity) and the `<game>_entities`
factory in [kit/boot](kit/boot.md).

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
> only drives the export's *typing*: the Inspector widget and the engine-side key/value
> type enforcement.

Alternatively, declare the field as `gd.Typed_Array(T)` or
`gd.Typed_Dictionary(K, V)`. A bare `gd:"export"` then derives the hint from
the type:

```odin
scores: gd.Typed_Array(i64)                       `gd:"export"`,  // == array=int
loot:   gd.Typed_Dictionary(gd.String, gd.Packed_Scene) `gd:"export"`, // == dict=String;PackedScene
```

Element types are the Odin spellings (`i64`, `gd.String`, `gd.Texture2d`); Resource handles are
mapped back to their engine class name automatically (`gd.Texture2d` → `Texture2D`). For
acronym-heavy class names that don't round-trip cleanly (e.g. `JSON`, `GLTFDocument`), use the
`array=`/`dict=` tag form with the exact name. Don't combine the two on one field: that's a
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

Only scalar Variant types support `default=`: numbers, bool, and `String`.
The reflection registrar reports `default=` on a math-struct or handle field
in the editor's output at boot, after `scriptgen` has run. Set those values
in `_ready` or in the scene instead. The following table explains when each
validation check runs.

<a id="which-tier-catches-what"></a>

### Export validation at build and registration

Both `scriptgen` and the runtime reflection registrar read
`` `gd:"export,…"` `` tags. They validate different parts of the declaration:

| Tier | When | What it checks | How a failure looks |
| --- | --- | --- | --- |
| `scriptgen` | build | the first token and each specification name that follows it | `scriptgen: error: player.odin:7: …`, the build stops |
| the reflection registrar | boot / class registration | each specification's value type, hint arity, and required Variant type | an error in Godot's output, the field registers with that spec dropped |

The runtime uses the field's reflected Variant type to check whether `array=`
has a `gd.Array` field or `default=Hero` has a compatible type rather than a
`Vector2`. Scriptgen can check specification names earlier, so a misspelling
stops the build:

```odin
hp: i32 `gd:"export,rnage=0:100"`
// scriptgen: error: Player.hp: unknown export spec "rnage" — did you mean `range`?
```

The recognized spec set is [`decl/decl.odin`](../decl/decl.odin)'s `EXPORT_SPECS`, and
`tests/scriptgen` asserts it against the registrar's own switches, so the two tiers agree
on which names exist.

### Getter / setter properties

Route an export's reads/writes through Odin procs (for validation, clamping, or
side-effects) with `get=`/`set=`. The named procs take `^<Struct>` plus (for the setter)
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

The `get`/`set` procs are plain Odin procedures (no `@(gd_method)` needed) named exactly as
written in the tag. The backing field still exists: the getter/setter may use it as
storage (as above) or compute from other state. Combine them with `group=`/`default=`
(a defaulted getter/setter field applies its default through the setter).

### @onready node references

A struct field tagged `` `gd:"onready=PATH"` `` is auto-wired to a child node on `_ready`,
mirroring GDScript's `@onready var sprite = $Sprite`. On the node's READY (*before* any
`@(gd_connect)` wiring and your own `_ready` proc), the core resolves
`get_node(owner, "PATH")` and writes the result into the field before your
`_ready` runs:

```odin
Player :: struct {
	owner:  gd.Character_Body2d,
	sprite: gd.Node2d `gd:"onready=Sprite"`,    // owner-relative node path
	label:  gd.Node   `gd:"onready=HUD/Label"`,
}
```

The field must be an object/node handle (`gd.Node2d`, `gd.Sprite2D`, `gd.Object`, …). The
handle contains the node pointer, so use the bare handle type, not `^gd.Node2d`.
An `@onready` field is a private reference resolved at runtime. It is not
serialized or shown in the property list or Inspector.

When the field type is `^<script struct>`, the core resolves the node and its
typed Odin script struct using the same checks as `rt.script_of`. One
declaration replaces a separate node handle and `rt.script_of` call in `_ready`:

```odin
Player :: struct {
	owner: gd.Character_Body2d,
	hud:   ^Hud `gd:"onready=HudLayer/Hud"`,   // node -> ^Hud, wired before _ready
}

// instead of:
//   hud_control: gd.Control `gd:"onready=HudLayer/Hud"`,
//   hud_script:  ^Hud,                          // + rt.script_of in _ready
```

The pointee must be a script struct in the module; other types are a build
error. If the node exists but carries no `Hud` script, the field stays nil and
`push_error` names the field. After a changed-layout hot reload, the core
re-resolves these declared references once every instance has migrated. A
manually cached `rt.script_of` pointer would instead refer to the old storage.

A typed reference points to script data. Pass its `.owner` to engine calls,
as in `gd.canvas_item_set_visible(self.hud.owner, false)`. Passing the script
reference itself is a compile error (`Cannot assign value ... of type '^Hud' to 'Canvas_Item'`)
because engine handles are distinct types.

For a fixed-array field, use `[N]Handle` or `[N]^Script` to resolve N sibling
nodes in one declaration. The path holds exactly one `%d`, substituted
with 0-based indices at READY:

```odin
Shop :: struct {
	owner:   gd.Control,
	cards:   [9]gd.Button `gd:"onready=Grid/Card%d"`,   // Grid/Card0 … Grid/Card8
	choices: [3]^Choice   `gd:"onready=Panel/Choice%d"`, // typed script refs work too
}
```

Each element resolves independently (a missing index leaves that slot nil with the
engine's path error); a `%d` on a scalar field — or an array without one — is a build
error. This replaces separate numbered fields (`card0`, `card1`, …) and a
manual lookup loop in `_ready`.

Godot's scene-unique `%Name` syntax works in any `onready=` path. Check *Access
as Unique Name* on the node, as for GDScript's `$` `%Name` lookup. The marker
passes through to `get_node`, so the path can start at the unique node:

```odin
Player :: struct {
	owner: gd.Character_Body2d,
	hud:   ^Hud       `gd:"onready=%Hud"`,          // unique name, anywhere in the scene
	ammo:  gd.Label   `gd:"onready=%Hud/AmmoLabel"`, // unique segment, then a normal path
	slots: [4]gd.Button `gd:"onready=%Inv/Slot%d"`,  // combines with the array template
}
```

Only a `%` at a *segment start* (path start or right after `/`) is the unique-name
marker; the array template's `%d` is recognized mid-name only (`Slot%d`), so a unique
name that itself starts with `d` (`%dock`) is never mistaken for a template. Any other
mid-name `%` is a build error. Unique names resolve through the owning scene's registry,
so they follow the same scoping rules as GDScript's `%Name`.

### Lifecycle & methods

Both are plain Odin procs whose first parameter is `^<Struct>`:

- **Lifecycle**: the proc name (minus an optional `<struct>_` prefix) is one of
  `ready`, `process`, `physics_process`, `enter_tree`, `exit_tree`, `reload`.
  `process` / `physics_process` take a `delta: f64` second parameter.
- **Methods**: tagged `@(gd_method)`. Any name; exposed minus the struct prefix.

#### `reload` — the hot-reload hook

`<struct>_reload(self: ^T)` runs with the new code after a hot reload swaps the
scripts library. Reloads occur on editor save-on-rebuild or an explicit
`script.reload(true)` in a running game. A same-layout reload preserves the
struct in place and redirects engine entry points (`_process`, methods,
signals) to the new code.

Stored procedure values still point into the old library. These include a
callback or dispatch table, an `events.Event`, or a behaviour-tree node such
as `flow.Action.Call.fn`. Reflection detects procedure-bearing state
recursively. Rebuild that state in `reload`:

```odin
boss_reload :: proc(self: ^Boss) {
    self.behaviour = build_behaviour_tree()  // re-capture fresh proc pointers
}
```

After the reload hook returns, no state or external registration may call
the previous library generation. The core releases the instance's lease on
that generation and unloads it once no live instance retains it.

If reflection detects procedure-bearing or opaque `rawptr` state without a
hook, the instance stays on its old code and retains that generation. A
warning identifies the script that needs a hook. Other instances and
intermediate generations continue reloading normally.

Reflection cannot see a callback erased inside an engine `Callable`/Variant container or
registered with an external library without being stored in the struct. Those cases carry the
same contract: define `reload`, remove/replace the old registration there, and never allow the
old callback to survive the hook.

This only matters for scripts that run in the editor (`//gd:tool`) or are explicitly reloaded
at runtime and retain callbacks. Ordinary gameplay scripts never hit it because a running game
does not hot-reload itself.

Codegen wraps each in the `proc "c"` form the runtime expects, establishing a
heap-backed default context before calling your proc, so your proc body can use
ordinary Odin (allocations, etc.).

### Signals

Declare a signal as a struct field of one of the `gd.Signal0` … `gd.Signal4`
marker types, whose arity is the payload count. The field name is the signal name, the type
parameters are the payload types, and the optional `gd:"args=..."` tag names the payload
(comma-separated, one name per parameter, with omitted names synthesizing as `arg0`, `arg1`, …).
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

The payload types must be Variant-able, following the same rule as `@export` and `@(gd_method)`
args (object/node handles present as `Object`). A signal field costs one nil pointer of
instance size and is never read or written at runtime; it exists so the declaration is
part of the type, checked by the compiler, and visible to reflection.

`gd.SignalN` accepts an inline struct describing any number of arguments.
Its field names become the argument names; an `args=` tag on a `SignalN` field
is a build error. Use it for 5+ payload arguments, beyond the arity family's
cap, or to name arguments in the type declaration:

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

`SignalN` requires a payload struct. A single Variant-mappable type such as
`gd.SignalN(gd.Vector2)` is rejected. For one payload value,
either `gd.Signal1(gd.Vector2)` (name it with `args=`) or wrap it so the field name names
it: `gd.SignalN(struct { pos: gd.Vector2 })` → `moved(pos: Vector2)`.

**Emit** with the generated typed helper `<struct_snake>_emit_<field>` (e.g.
`ping_emit_pinged(self, value)`), which codegen emits from the signal field and which
calls through `gd.emit`/`gd.emit_args` (returning the engine `Error`, which you may
ignore):

```odin
player_emit_health_changed(self, i64(self.health))   // generated typed emitter
```

Connect a signal to a handler procedure marked `@(gd_method)` so the engine can
dispatch to it. Use a helper call or declarative wiring:

```odin
// 1. Connect an emitter's signal to a target's method, from any script (gd.* helper):
gd.connect_to(player, "health_changed", self.owner, "on_health_changed")

// 2. Connect one of the Godot owner's signals to its own method:
gd.connect(self.owner, "body_entered", "collect")

// 3. Use @(gd_connect), shown below, instead of a _ready/connect call.
```

### Declarative signal wiring (`@(gd_connect)`)

Tag a `@(gd_method)` procedure with `@(gd_connect = "signal_name")` to connect
the Godot owner's `signal_name` to this method on READY. The connection happens
before your own `_ready` runs
(order: `@onready` field resolution → `@(gd_connect)` connections → your `_ready`).

```odin
// Connect the Godot owner's `body_entered` to `on_body` on READY.
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
`@(gd_method, gd_connect = "...")`). The signal must exist on the emitter (an engine signal
like `body_entered` / `area_entered`, or one a script declared with a signal field).

Use `@(gd_connect = "Path/To/Node:signal")` to connect another node's signal
to this method. The part before the last `:` is a node
path resolved at READY exactly like an `onready=` ref (owner-relative, absolute
`/root/...`, or `..` — anything `get_node` takes), the part after is the signal:

```odin
// Connect the child turret's `fired` signal to the parent before _ready.
@(gd_method, gd_connect = "Turret/Barrel:fired")
tank_on_fired :: proc(self: ^Tank, heat: gd.Int) { ... }
```

Children ready before parents, so a child emitter's script (and its declared signals)
exists by the time the parent connects. For a missing node or signal, the
connection is skipped and `push_error` names the declaring class and method.
Use `gd.connect_to` from `_ready` for emitters resolved at runtime, such as
spawned scenes. (`@(gd_connect)` requires the `-custom-attribute:gd_connect` build
flag, which `build/build_scripts.sh` passes for you.)

A single `%d` in the path connects a sequence of emitters to one handler. It
probes `Choice0`, `Choice1`, … until the first missing index and binds each
match's index as a trailing callable argument. The engine passes that index
after the signal's own arguments on every dispatch:

```odin
// Connect Panel/Choice0..ChoiceN's `pressed` here; `idx` identifies the emitter.
@(gd_method, gd_connect = "Panel/Choice%d:pressed")
menu_on_choice :: proc(self: ^Menu, idx: gd.Int) {
	menu_pick(self, int(idx))
}
```

This lets `pick0`, `pick1`, and `pick2` share a handler. Index 0 must exist;
a declaration that connects nothing reports `push_error`.

Scene-unique names work in the path part too, with the same rules as `onready=`
(segment-start `%` = unique-name marker, mid-name `%d` = the indexed template):

```odin
@(gd_method, gd_connect = "%SavePanel:saved")     // unique-name emitter
@(gd_method, gd_connect = "%Inv/Slot%d:pressed")  // unique prefix + indexed bank
```

<a id="reserved-shapes"></a>

## Reserved procedure signatures and fields

Some toolkit declarations depend on a parameter's name, position, or type, or
on a script field's type. Changing those parts can change the generated
behavior even when the Odin code still compiles. The following table lists
these declarations and the result of changing them.

| Shape | Where it is legal | What it means | Effect of changing the declaration |
| --- | --- | --- | --- |
| first param `self: ^<Class>` | every bound proc | identifies the receiver class by type | the parameter name may change; a type that no longer matches the class prevents binding |
| a pointer param immediately after the receiver | `@(gd_command)` / `@(gd_method)` on an embedded block | identifies the containing entity, called the wielder; scriptgen supplies `self` so the block can access it. The pointer is never a wire argument | a pointer there on a direct command is a build error ("un-wire-able arg") |
| `by: knet.Player_Id` (after the receiver/wielder) | `@(gd_command)` | identifies the issuer; the framework supplies the resolved sender so the predicate does not need to trust a client-supplied identity | under another name, the parameter is ordinary client-controlled wire data. Both the name and type are required; other wire args named `by` are refused |
| typed entity params before `mine` | an `@(gd_event)` `_fx` proc | concrete entities used by presentation; one is the inferred anchor, while several require `anchor=PARAM`. The anchor chooses the session or sim clock | an unknown/non-entity anchor, ambiguous list, or entity outside the selected runtime is a build error |
| `mine: bool` | an `@(gd_event)` body's `_fx` proc, and a tick's `_fx` half | `true` on the anchor owner/source timeline, `false` on observers; audience policy can omit either side | position and name are both checked; the error names the slot |
| `tick: u64` | `@(gd_sample)` (required, second), `@(gd_step)` (optional, second) | the lane's tick number | on a sample, a build error; on a step, the parameter is omitted |
| `l: ^ksim.Lane` | generated fact announcement procedures reserve `l` for the lane parameter | — | an author arg named `l` is refused because the generated parameter would shadow it |
| a `kit/boot` `Boot` field on the script struct | the game shell | declares the four standard transport forwards (`on_packet` / `on_peer_left` / `on_net_up` / `on_net_down`) | see the note below |

A field declares the game shell when its type's qualifier resolves to an
import of `godot:kit/boot`. Any import alias works, including `kboot` or `boot`,
because scriptgen checks the import path. A `Boot` from a different package
does not declare the shell.

## Manual overrides

To override one of the generated procedures below, define a procedure with
the same name. Scriptgen then uses the authored implementation. There is no
separate opt-out tag or configuration token.

| Generated | Yields to a hand-written… |
| --- | --- |
| census accessors: `<entity>_ref`, `<entity>_of`, `<entity>_owned_by`, `<entity>_mine`, `<entity>_ids`, `<entity>_all`, `<entity>_despawn`, `<entity>_teleport`, `<entity>_spawn` | proc of that name |
| acceptance-test probes: `probe_<entity>_count`, `probe_my_<entity>`, `probe_<entity>_<field>` | proc (or `@(gd_method)`) of that name |
| the four standard transport forwards | `@(gd_method)` of that name |

Scriptgen prints each override once per run:

```
scriptgen: yielded: runner_of (census accessor — the hand-written proc of that name wins)
```

That line confirms an intended override took effect and, when you didn't intend one,
tells you a procedure in your package already uses a generated name. Check it if a proc
you meant to override (`runner_of` where the entity is `Runner_Bot`) seems to do nothing.

Announcement procedures generated by `@(gd_event)` cannot be overridden. An
authored procedure with the same name is a build error requiring a rename.
The generated procedure coordinates authority-only broadcasts, `_fx`
execution on the causer's live pass with `mine=true`, execution on watching
screens at the fact's tick with `mine=false`, and suppression during
resimulation so reconciliation cannot announce the event again.

`gd:"manual"` suppresses an automatic call while retaining the generated
procedure for game code to call. For an embedded simulation block's
`@(gd_tick)`, the block's state still joins the entity descriptor and its
commands still join the command table, but the game chooses when and whether
to call its tick. See [kit/sim](kit/sim.md). The token is not limited to
simulation: using `manual` where there is no generated procedure to call is a
build error naming what scriptgen expected.

## Generated names

Generated wrappers, wire constants, and lifecycle hooks use different naming
rules. Use the wrapper to issue an action and implement the matching hook to
receive a callback.

**Action policies.** `@(gd_command)` is owner-only and non-predicted by default. Use
`knet.ACTION_OWNER_PREDICTED`, `knet.ACTION_ANY_SEAT`,
`knet.ACTION_ANY_SEAT_PREDICTED`, or `knet.ACTION_AUTHORITY` when the verb differs.
Both co-op and sim descriptors carry the same typed `knet.Action_Policy`, and access is
enforced before the verb predicate. A `knet.Action_Policy{...}` literal can additionally
set `max_args_bytes`. Quoted comma-string command policies are rejected; use a
typed preset or literal.

Every generated command wrapper returns `knet.Action_Outcome`. Most call sites use
`knet.command_ok(outcome)` to test whether the action applied or was predicted.
UI that needs the cause of an immediate refusal can inspect `outcome.reason`;
the generated game-shell
`<game>_command_rejected` half receives the final authority reason (`Access`, `Rate`,
`Malformed`, `Stale`, `Predicate`, or `Timeout`) for both co-op and tick-scheduled verbs.
Its `model` parameter distinguishes `.Immediate` from `.Scheduled`; no packet or pending
table is required in game code.

A command declared directly on the entity keeps its procedure name with a
`_cmd` suffix. A command from an embedded block includes its field path, so
two blocks of the same type on one entity get distinct names:

| Declaration | Generated wrapper |
| --- | --- |
| `@(gd_command) gunner_buy :: proc(self: ^Gunner, …)` | `gunner_buy_cmd` (i.e. `<proc>_cmd`) |
| `@(gd_command) gun_fire :: proc(self: ^Gun, …)`, embedded as `primary: Gun` on `Gunner` | `gunner_primary_fire_cmd` (i.e. `<class>_<path>_<verb>_cmd`) |

The composed form's path is the field path, joined with `_`, so a block three levels down
still lands on the entity that owns the net id. Both formulas can reach the same name, and
when they do it is a build error naming both declarations rather than a silently
unreachable verb.

**Wire-id constants: prefixed and unprefixed.** Command ids are class-prefixed
(`GUNNER_CMD_BUY`, `GUNNER_CMD_PRIMARY_FIRE`); world-pass fact ids are not
(`FACT_ROUND_OVER`), and neither is `NET_FINGERPRINT`. Commands are per-entity, so several
classes in one package can declare a verb of the same name, and the class prefix keeps their
constants apart. Facts and the fingerprint are module-wide: there is exactly
one announcement procedure per event name across the package (a second is a build error, as is a u16 hash
collision between two events), and exactly one fingerprint.

Call `<entity>_spawn` to create an entity. Implement `<entity>_spawned` to
receive the framework's creation notification:

| Name | Who writes it | Who calls it | What it does |
| --- | --- | --- | --- |
| `mob_spawn` | **generated** | **you** | the typed factory: you call it to bring a Mob into the world |
| `mob_spawned` | **you** | **the framework** | the hook: it calls you once the Mob exists, on every peer |

Calling `mob_spawn(…)` inside `mob_spawned(…)` creates an infinite spawn loop.
An authored `mob_spawn` replaces the generated factory because the name is a
census accessor; scriptgen prints
`yielded: mob_spawn`. Check that line if spawning does not behave as expected.
The other framework-called hook, `<entity>_freed`, also uses the `-ed` suffix.

These identifiers are keyed by the entity's target struct. Two `entity=` tags
cannot name the same struct because that would generate its entity accessors
twice.

## Multiplayer RPCs (`@(gd_rpc)`)

> This section covers Godot's native multiplayer APIs: `@(gd_rpc)` mirrors
> GDScript's `@rpc` and supports `MultiplayerSpawner`/`MultiplayerSynchronizer`
> interoperation. Use these APIs when porting an RPC design or communicating
> with non-Odin peers. For a new cooperative game, the
> [Kit multiplayer toolkit](kit/index.md) provides replicated fields, predicted
> commands with typed `_then` consequences, entity factories, joining,
> reconnect, and host migration. The game still defines its state and gameplay
> rules. See the [tutorial](kit/build-a-game-in-a-day.md), `examples/cavecrawl`,
> and `examples/slopball`. `examples/coop_arena` and `examples/survivors`
> demonstrate the native RPC APIs below.

Mark a `@(gd_method)` proc with `@(gd_rpc)` to expose it to Godot's high-level multiplayer,
exactly like GDScript's `@rpc(...)` annotation. The annotation only declares the *config*;
the engine routes `node.rpc("method", args)` (and incoming remote calls) to your proc through
the same dispatch path as a normal method call.

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

`gd_rpc` implies `gd_method`: an RPC must be a registered, name-dispatchable method, so you
can write `@(gd_rpc)` alone. Both forms are equivalent.

**Config tokens and SDK defaults:**

| Token | Effect | Default |
| --- | --- | --- |
| `authority` / `any_peer` | who may call it (`RPCMode`) | `authority` |
| `reliable` / `unreliable` / `unreliable_ordered` | transfer mode | `reliable` |
| `call_local` | the RPC also runs on the calling peer | off |
| `channel=N` | transfer channel | `0` |

Codegen exposes this configuration through `_get_rpc_config`, which the engine
reads once per node. From GDScript or another script, call the method as
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

`godot/Ergonomics_Multiplayer.odin` provides helpers to create an ENet peer,
install it in the MultiplayerAPI, and receive connection callbacks. Each
helper takes a node, such as a script's `self.owner`, and accesses its
MultiplayerAPI through `Node.get_multiplayer()`:

```odin
import gd "godot:godot"

// Host or join while the node is inside the tree. Each returns a
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
> compile but return `false` on wasm32, so branch on the bool. For browser co-op use the WebRTC
> helpers below instead. The query helpers (`is_server`, `my_peer_id`, `rpc_sender_id`,
> `connected_peers`) are platform-independent and work over any peer (ENet **or** WebRTC).

`tests/rpc_net` runs a headless Godot server and client, connects them over
ENet, and exchanges `@(gd_rpc)` calls in both directions. It checks that each
call executes on the other peer with the correct `get_remote_sender_id()`.

Launch parameters select an instance's role, relay, or room. Native launch
scripts and the integration harness use environment variables; a browser
instance can read the page URL's query string. `gd.launch_param` checks the
environment first, then the web query parameter:

```odin
role := gd.launch_param("COOP_ROLE", "role")   // env COOP_ROLE, else ?role= on web
url  := gd.web_query("url")                     // web-only knob; "" on native
```

`gd.web_query` evaluates `location.search` through the JavaScriptBridge (values
percent-decoded via `gd.uri_decode`); `gd.IS_WEB` is the compiled-for-the-browser constant
the platform branches use. Results are temp-allocated. Both cooperative
examples use these helpers during startup and exercise them in their native
and browser integration tests.

### WebRTC / web co-op (`gd.webrtc_host` / `gd.webrtc_join`)

WebRTC supports browser multiplayer over the internet without port-forwarding.
Godot exposes the browser's implementation through `WebRTCMultiplayerPeer`
and `WebRTCPeerConnection`. `godot/Ergonomics_WebRtc.odin` opens a signaling
channel, exchanges the SDP offer and answer, sends ICE connection candidates,
creates data channels, and installs the peer. The game starts hosting or
joining and polls the setup each frame:

```odin
// The host becomes peer id 1 and receives a room code for the joiner to use:
@(gd_method) lobby_host :: proc(self: ^Lobby) { gd.webrtc_host(self.owner, "wss://your-server/rtc") }
@(gd_method) lobby_join :: proc(self: ^Lobby) { gd.webrtc_join(self.owner, "wss://your-server/rtc", "WATR") }

// Poll signaling every frame until connected; later calls do no setup work:
lobby_process :: proc(self: ^Lobby, _delta: f64) {
    gd.webrtc_poll(self.owner)
    code := gd.webrtc_room_code(self.owner) // host: "" until the server assigns it — display to share
}
```

Once connected, the existing `@(gd_rpc)` methods and `gd.rpc` / `gd.rpc_id`
calls use the WebRTC peer. Godot's RPC layer accepts a `WebRTCMultiplayerPeer`
through the same `MultiplayerPeer` interface used for ENet, so the RPC
declarations and calls can stay the same.

| Task | One-liner |
| --- | --- |
| Host a WebRTC lobby (id 1) | `ok := gd.webrtc_host(self.owner, "wss://host/rtc")` |
| Join a WebRTC lobby by code | `ok := gd.webrtc_join(self.owner, "wss://host/rtc", "WATR")` |
| Read the host's room code | `code := gd.webrtc_room_code(self.owner)` (`""` until assigned) |
| Signaling state / error | `gd.webrtc_session_state(...)` / `gd.webrtc_error_reason(...)` |
| Pump signaling (every frame) | `gd.webrtc_poll(self.owner)` |
| Tear the session down | `gd.webrtc_close(self.owner)` |

WebRTC needs a signaling server to exchange connection information before the
peer-to-peer link exists. The host sends `create` and receives a room code;
the other player sends `join` with that code. The server relays SDP offers,
answers, and ICE candidates without parsing their contents. The protocol uses
JSON text frames over a WebSocket at `/rtc`. A compatible server can implement
the protocol below. The Node reference implementation at
`tests/webrtc/signal_server.mjs` serves the headless tests; the maintainer uses
an Elixir implementation in production.

```
client -> server                                  server -> client
  {"type":"create"}                                 {"type":"created","room":"<CODE>","id":1}
  {"type":"join","room":"<CODE>"}                   {"type":"joined","room":"<CODE>","id":<n>}
  {"type":"signal","to":<peerId>,"data":<opaque>}   {"type":"peer","id":<peerId>}
  {"type":"leave"}                                  {"type":"signal","from":<peerId>,"data":<opaque>}
                                                    {"type":"peer_left","id":<peerId>}
                                                    {"type":"error","reason":"no_room"|"full"|"bad_msg"}
```

The host (id 1) creates the offer and the joiner answers. Both players must be
able to reach the signaling server during setup, so deploy it at a public
`wss://HOST/rtc`. Game traffic then uses WebRTC's peer-to-peer connection and
NAT traversal without port-forwarding. `Ergonomics_WebRtc
.odin` configures a public STUN server on the `WebRTCPeerConnection`. Add a
TURN relay to `_ICE_CONFIG_JSON` for symmetric-NAT pairs; localhost needs
neither STUN nor TURN.

> Desktop/native Godot ships no WebRTC implementation: `WebRTCPeer
> Connection` is an abstract extension point ("No default WebRTC extension configured") that
> the separate [`godot-webrtc`](https://github.com/godotengine/webrtc-native) GDExtension must
> fill. These helpers target web exports. They compile and run natively, but
> `initialize` fails unless `godot-webrtc` is installed. Native extension setup
> is outside this guide's scope. `tests/webrtc` exercises the browser export.

`tests/webrtc` loads the same exported web page in two headless Chrome
instances, one with `?role=host` and one with `?role=join`. They establish a
browser-native WebRTC data channel through the signaling server and exchange
`@(gd_rpc)` calls in both directions. Assertions in each browser's JS console
check execution on the other browser with the correct sender id, matching the
native checks in `tests/rpc_net`.

<a id="ergonomic-helpers"></a>

## Godot helper procedures

The `godot/Ergonomics*.odin` helpers create the StringName and Variant values
and resolve the method bindings needed for common engine calls. Their
`Object`/`Node`/`Resource` parameters and results share the representation used
by object handles such as `Node2d`, `Area2d`, and `Label`. A script's
`self.owner` therefore passes without a cast, and a returned `Node` assigns
to another handle type.

| Task | One-liner |
| --- | --- |
| Resolve a child by path | `child := gd.get_node(self.owner, "Hud")` |
| Get the parent node | `p := gd.get_parent(self.owner)` |
| Get the SceneTree | `tree := gd.get_tree(self.owner)` |
| Parent a node | `gd.add_child(self.owner, child)` |
| Group add / check / remove | `gd.add_to_group(self.owner, "enemies")` · `gd.is_in_group(self.owner, "enemies")` · `gd.remove_from_group(self.owner, "enemies")` |
| Iterate a group | `for n in gd.nodes_in_group(self.owner, "enemies") { ... }` (live members, temp-allocated) |
| One group member | `game := gd.first_in_group(self.owner, "game")` |
| Group → script structs | `for p in rt.scripts_in_group(self.owner, "players", player) { ... }` · `rt.first_script_in_group(self.owner, "game", Game)` (see [Typed cross-script references](#typed-cross-script-references)) |
| Unpack an engine array | `kids := gd.array_unpack(&children)` (any `Typed_Array` return → Odin slice, element-converted) |
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
but do not persist to `project.godot`. Register them during an autoload's
`_ready`, as shown below. `gd.get_setting_string` allocates its returned string
in `context.allocator`; the other setting and action helpers are
`proc "contextless"`.

All helpers are `proc "contextless"` except the ones that allocate: `gd.get_string`
(returned Odin `string`, in `context.allocator` — `delete` it) and the slice-returning
queries `gd.nodes_in_group` / `gd.array_unpack` / `rt.scripts_in_group` (in
`context.temp_allocator` by default; iterate before the temporary storage is
reset, or pass a persistent allocator to retain the slice). Script procedures
run with a context set, so they can call either form. For a script-declared
signal field, prefer the generated typed `<struct_snake>_emit_<field>` helper.
Use `gd.emit_args` for by-name dispatch. Both `gd.emit` and `emit_args` use a
Variant call because Godot's `emit_signal` is a vararg method and cannot use
the pointer-call path.

The helpers above accept Odin `cstring`s and create the Godot `String` or
`String_Name` internally. For a raw bound method without a helper, create
those values with `gd.sname("…")` or `gd.gstr("…")`. Names for methods, signals,
actions, animations, and properties usually take `String_Name`. The helper
avoids spelling out `new_string_name_cstring(…, true)`:

```odin
// raw call (no dedicated helper): intern the name inline
if gd.object_has_method(enemy, gd.sname("take_damage")) {
    // ...
}
```

`gd.sname` uses `static = true` (intern once, keep), correct for the string *literals* these
calls almost always use.

### Common 2D transforms — moving / rotating a Node2D

`gd.Vector2` is an Odin `[2]f32`, so it supports Odin's vector operations: component access
(`pos.x`), compound assignment (`pos.x += 10`), and whole-vector arithmetic (`pos += other`,
`pos * delta`). The only round-trip is the get/set across the engine boundary. For the
common move, rotate, and scale operations, Godot provides methods that apply
the delta directly:

| Instead of (get → modify → set) | One call |
| --- | --- |
| `pos.x += 10` on the position | `gd.node2d_translate(self.owner, gd.Vector2{10, 0})` |
| move along the node's own axes (respects rotation) | `gd.node2d_move_local_x(self.owner, 10)` · `gd.node2d_move_local_y(self.owner, 10)` |
| rotate by radians | `gd.node2d_rotate(self.owner, 0.1)` |
| scale by a factor | `gd.node2d_apply_scale(self.owner, gd.Vector2{2, 2})` |
| set / get in world space | `gd.node2d_set_global_position(self.owner, p)` · `gd.node2d_get_global_position(self.owner)` |
| set one position component (keep the other) | `gd.node2d_set_x(self.owner, 100)` · `gd.node2d_set_y(self.owner, 250)` (and `_global_x` / `_global_y`) |

The `node2d_set_x` / `_set_y` (+ `_global_x` / `_global_y`) helpers cover the absolute-component
case ("snap x to 100, keep y") without a separate get, modify, and set. The same setters
exist for other positional types: `node3d_set_x/_y/_z` (+ `_global_*`), and
`control_set_x/_y`, `control_set_width/_height`, `control_set_global_x/_y`. If you ever need it by
hand (a component with no setter, or another type), it's plain Odin array math:

```odin
pos := gd.node2d_get_position(self.owner)
pos.x = 100                                  // Odin array swizzle — no Vector2 ctor needed
gd.node2d_set_position(self.owner, pos)
```

Godot methods on nodes are bound as
`gd.<class_snake>_<method>(handle, args…)` (so reach for `node2d_translate`, `control_set_size`,
`sprite2d_set_frame`, …), and the math types (`Vector2/3`, `Color`, `Rect2`, …) are plain Odin
structs/arrays you manipulate with normal operators.

## Supported Odin → Variant types

| Odin type | Variant | Notes |
| --- | --- | --- |
| `int`, `i8/i16/i32/i64`, `u8..u64`, `uint`, `gd.Int` | `Int` | width-narrowed via `size_of` |
| `f32`, `f64`, `gd.Float`, `gd.Real` | `Float` | |
| `bool` | `Bool` | |
| `string` | `String` | Method arguments/results are converted as UTF-8; use `gd.String` for exported storage. |
| `gd.String` | `String` | Engine value with explicit ownership. |
| `gd.Vector2`, `gd.Vector3`, `gd.Color` | matching | |
| `gd.String_Name` | `String_Name` | |
| `^gd.<Object subclass>`, `gd.Node`, `gd.Object`, ... | `Object` | object handle |

Scriptgen rejects unsupported types with a build error.
Raw `gd.Variant` signatures are not supported at this method boundary; use a
concrete supported type or a lower-level Variant dispatch API.

### Method value ownership

Use ordinary Odin strings for textual method APIs:

```odin
@(gd_method)
player_echo :: proc(self: ^Player, text: string) -> string {return text}
```

The trampoline converts the incoming Godot String into temporary UTF-8 storage,
copies returned text into the outgoing Variant, and releases its Godot argument
copy when the call finishes.
Keep returned storage valid until marshaling finishes: literals, instance-owned
strings and `context.temp_allocator` data work; a view into a local stack array
does not. Copy an argument with `strings.clone` if you retain it across frames.
The trampoline does not free an Odin string you return from your own allocator.

A bare `@(gd_method)` uses these ownership rules: owning builtin
argument copies belong to the callee, while returned Godot values are borrowed.
The method must free its `gd.String`/`gd.Array` argument copies and may return
an instance-owned value. Object-handle arguments are borrowed pointers,
not owning builtin copies.

To change these ownership rules, add options to the attribute:

```odin
@(gd_method="borrowed_args,owned_return")
player_copy_values :: proc(self: ^Player, values: gd.Array) -> gd.Array {
    return gd.new_array_array(values)
}

@(gd_method="owned_return")
player_description :: proc(self: ^Player) -> gd.String {
    return gd.new_string_odin("Ready")
}
```

`borrowed_args` makes the trampoline release its builtin argument copies after
the call. Treat those values as borrowed; use a Godot copy constructor before
retaining or replacing a handle. A copied Array/Dictionary reference may still
share mutable contents—ownership does not imply a deep copy.

`owned_return` transfers one owned builtin reference to the trampoline, which
releases it after the outgoing Variant retains the value. It also supports a
declared RefCounted subclass with one owned reference (factory results, or a
new object after `ref_counted_init_ref`). It rejects Node/Object/scalar results;
a Variant does not own a Node's lifetime. Native Odin string results already use
the conversion path and do not take this option. Returning a borrowed argument
as `owned_return` requires first acquiring a separate reference.

The options also follow composed methods and property accessors when the accessor
proc has the annotated `gd_method`. Unannotated accessors use the default
ownership rules. A String property's getter may return an Odin `string`, which is copied;
its actual exported storage remains `gd.String`. Native `string` exports are
rejected by scriptgen and reflection because their storage is not a Godot String.

## Threads & memory

Script callbacks use the engine thread and the allocators installed by the
runtime:

- Lifecycle procs
  (`*_ready`, `*_process`, …), `@(gd_method)` calls, `@(gd_connect)` handlers and
  `@(gd_rpc)` procs are all invoked by the engine on its main thread; the generated
  trampolines add no synchronization. Don't call `gd.*` / engine APIs from threads you
  spawn with `core:thread`: compute on the worker, then apply the result back on the
  main thread from a lifecycle proc (e.g. poll a mutex-guarded value in `*_process`).
- `rt.script_of` is main-thread-only: it resolves through the core's live-instance
  registry, which the main thread mutates as script instances are created and freed.
- `context.allocator` is persistent inside script procedures: the Odin
  heap default on native, an engine-backed (alignment-correct) allocator on web. Either
  way, what you `make`/`new` there lives until you free it.
- `context.temp_allocator` supplies temporary storage. The core resets its shared temp arena once
  per frame from the main-thread frame pump, so never stash a temp pointer (including
  `fmt.tprintf`/`fmt.ctprintf` results) across frames. Copy anything you keep into
  `context.allocator` memory.
- The caller frees strings allocated by `gd.get_string` and helpers
  like it that return an Odin `string`. They allocate from `context.allocator`; use `delete(s)`
  when you're done with it.
- `gd.sname` uses `new_string_name_cstring(name, true)`:
  `static = true` hands Godot the cstring pointer to keep for the program's lifetime.
  Pass only string literals (or otherwise program-lifetime, ASCII) names; never a name
  built at runtime from a temporary buffer such as `fmt.ctprintf(...)`.

## Building

`build/build_scripts.sh [PROJECT_DIR]` runs the full pipeline:

1. builds the `scriptgen` binary,
2. runs `scriptgen <scriptsdir>` to emit the build artifacts beside the authored sources
   (one `odin_godot_scripts.gen.odin` per package directory, plus the scripts dir's
   staleness guard and boot shim; no resource stubs, since the authored `.odin` is the
   attached resource),
3. builds the scripts dll with `odin build <scriptsdir> -build-mode:dll
   -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc
   -custom-attribute:gd_command -custom-attribute:gd_tick
   -custom-attribute:gd_input -custom-attribute:gd_sample -custom-attribute:gd_step
   -custom-attribute:gd_event -custom-attribute:gd_half
   -custom-attribute:gd_message`
   (the `.gen.odin` are in the same package and compile together),
4. builds the core dll.

The eleven `-custom-attribute:` flags are required so the Odin compiler accepts the
`@(gd_method)` / `@(gd_connect)` / `@(gd_rpc)` / `@(gd_command)` / `@(gd_tick)` /
`@(gd_input)` / `@(gd_sample)` / `@(gd_step)` / `@(gd_event)` / `@(gd_half)` /
`@(gd_message)` marker attributes; the
build script passes them for you. The set lives in `decl/decl.odin`'s `ATTRS`, and
`tests/scriptgen` checks that the build scripts pass those attributes. Odin
rejects an unknown custom attribute, so adding one to the schema also requires
updating the build scripts.

[Workflow](workflow.md) covers builds, live editing with updates on save,
validation, autocomplete, highlighting, debugging, and editor settings such
as `odin_godot/odin_bin` and `odin_godot/scripts_dir`.

## Multiple scripts in one package

All the `.odin` files in one directory are one Odin package. Because lifecycle/method procs
and generated emit helpers live in that shared package, prefix your proc names with the
struct name (`ping_ready`, `ping_add`) to avoid collisions, since the prefix is stripped to
derive the GDScript-facing name. One script struct per file (identified by its
first field being named `owner`).

### Organizing a project

Start with one `res://scripts/` directory. Split out packages when the directory
becomes hard to navigate, and consider modules when rebuild latency warrants
separate libraries:

| Shape | Use it for | Cost |
|---|---|---|
| **flat `res://scripts/`** | everything, until a directory listing gets hard to read | none; this is the default |
| **a helper subpackage** (`scripts/util/`, no annotated scripts in it) | pure Odin logic with no engine surface: math, parsers, tables. Import it relatively (`import "util"`) | none; it compiles into the same dll |
| **a script subpackage** (`scripts/ui/`, with annotated scripts) | self-contained engine-native classes the rest of the game does not need to name: HUD widgets, menus, tools, effects. They attach from their own path (`res://scripts/ui/hud.odin`) | kit declarations must stay in the top-level scripts dir, and a subpackage may not import it back. Still one dll, so a save still rebuilds all of it |
| **a script module** (`res://modules/<name>/`) | a subsystem whose rebuild latency warrants a separate library (hundreds of scripts) | its own dll, so no shared types or globals with other modules: cross-module calls go through the engine |
| **`res://shared/`** | types, constants and pure procs several modules must agree on | verified state-free (no mutable globals, no `@(init)`, no scripts), and an edit there rebuilds every module |

The last three are covered in **[Script Modules](modules.md)**, including the cost model,
the isolation rule, and the exact build-time refusals.

## Custom resources

`//gd:extends Resource` attaches the script to a custom resource, a RefCounted
data container outside the scene tree, like GDScript's `extends Resource`.
Use it for designer-tunable data assets you create, edit in the
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
  / `_physics_process` never fire, so omit them. `@export` vars and `@(gd_method)`s
  work as usual.
- **First field is `owner: gd.Resource`** (the owner-Object convention), instead
  of a `gd.Node`/`gd.Node2d`.
- **`.tres` serialization is automatic.** `@export` vars carry the STORAGE usage
  flag, so Godot's own text-resource serializer writes them (plus a reference to
  this script) into a `.tres`. Loading the `.tres` reconstructs a live instance
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
  live instance even in the editor, so its `@export` values are directly editable
  in the Inspector and persist on save.
- **Resource-typed `@export`.** A field `data: ^gd.Resource
  `gd:"export,resource=ItemData"`` on a *node* script gives a resource-picker slot
  that accepts a custom `ItemData` `.tres`. The `resource=` hint string filters the
  picker, and because `ItemData` is registered as a global class (see below) the
  editor knows it as a type.

## Global class names

`//gd:class <Name>` registers the script as a global class, like GDScript's
`class_name`. The declared name becomes the engine's global name without
another annotation.

The marker is optional. Without it, the script still attaches, instantiates, reloads,
and supports typed `rt.script_of` access through its source-path identity. It does
not reserve a project-wide global type name. Use it when another editor surface needs a
named type (for example a custom `Resource` picker), not as routine binding boilerplate.
The editor's new-script template therefore leaves it out by default.

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

All scripts in a module compile into one shared library, so they can use the
same struct types. `rt.script_of(obj, T)` resolves a live Godot object to a
typed `^T` pointer to its Odin script data. Scripts in that module can then
access fields and call procedures directly without Variant marshaling:

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
  language (a foreign-language node, a placeholder, or a plain engine node). It is
  safe to call with a nil object.
- Works on web too (single module: the same resolver is wired directly).
- **Subpackages are not a boundary:** a class in a subfolder of the same module lives in the
  same dll, so import that package and name its type: `rt.script_of(node, ui.Hud)`.
- **Module boundary:** if the project uses [script modules](modules.md), `script_of` is
  typed access within *one* module only: across modules it returns `nil` by construction
  (modules can't import each other's types), and cross-module access goes through the
  engine (signals, name-based calls, autoloads). See [Script Modules](modules.md).
- For calling across a dll boundary (e.g. a tool that dispatches by name), the
  GDScript-style by-name path is `gd.vcall` (below); `script_of` provides direct
  typed path within the shared scripts dll.

These three helpers combine scene instantiation and typed
script lookup. Choose one according to whether the new instance's `_ready`
needs to see the initial field values:

```odin
// Set initial fields before _ready with spawn_scripted + add_child:
node, b := rt.spawn_scripted(self.bullet_scene, Bullet)
if b == nil { return }
b.dir = dir; b.damage = dmg
gd.add_child(arena, node)

// Assign fields after _ready has run:
if e := rt.spawn_as(parent, self.enemy_scene, Enemy); e != nil { e.tier = 2 }

// from a physics callback (body_entered, contact resolution): deferred parenting —
// _ready runs at idle time and sees assignments through the returned ^T.
if g := rt.spawn_as_deferred(parent, self.gem_scene, Gem); g != nil { g.value = 5 }
```

All are nil-safe (nil scene, failed instantiate, or a root without the expected script
→ nil `^T`; the caller's nil-check decides whether that's fatal).

Where types cannot be shared, such as across script modules or through
engine-mediated dispatch, `gd.vcall` converts Odin arguments to Variants
automatically, calls by name, and frees every temporary; the typed forms unwrap the
result:

```odin
gd.vcall_void(spawner, "register_kill")
hits := gd.vcall_int(field, "spawn_aimed", x, y, sx, sy, speed, dmg, gd.Int(1))
if gd.vcall_bool(game_state, "is_cleared") { ... }
```

Accepted argument types: integers, floats, bool, cstring/string, `gd.String`,
`gd.String_Name`, object/node handles, `Vector2/2i/3/3i/4`, `Color`, `Rect2`, and
prebuilt `Variant`s, which pass through with ownership retained by the caller.
An unsupported argument rejects the entire call and reports an error. A nil
target is a silent no-op returning zero, which supports group or path lookups
that find no object. `method` must be an interned string literal.

Use scene-tree groups to find nodes without retaining their paths or a
separate registry. Add nodes with `gd.add_to_group` in `_ready`, then use the
`rt` queries to resolve group members through `script_of`. The queries return
script pointers and skip members that carry a different script or no script:

```odin
// Find players through a temporary slice of struct pointers; iterate before it resets:
for p in rt.scripts_in_group(self.owner, "players", player) {
	p.hp -= 1                                     // direct field access
	pos := gd.node2d_get_global_position(p.owner) // engine calls via the owner
}

// the single-expected-object query (the game orchestrator, the world, the camera):
game := rt.first_script_in_group(self.owner, "game", Game)
```

`first_script_in_group` scans until it finds a member with the requested
script. Calling `gd.first_in_group` and then `script_of` instead checks only
the first node listed by the engine. The node-level forms (`gd.nodes_in_group`,
`gd.first_in_group`) and the generic engine-array unpacker (`gd.array_unpack`) live in the
[ergonomics layer](#ergonomic-helpers). One timing note: nodes join groups as they enter
the tree, so a group scan inside another node's `_ready` can run before later siblings
have registered. Query from process or tick code when the game needs the result.

### Any-class references & static dispatch ("interfaces")

Use `script_of` when the expected class is known. For a bullet that can damage
several classes, or a cursor that can interact with several classes,
`rt.script_any(obj) -> (ptr: rawptr, id: typeid)` returns the instance data
and its type. It returns nil,nil for a plain engine node, a foreign module's
class, or an object without a script.

A static table can map each `typeid` to the operations that class supports.
Each entry applies to every instance of its class, so the game needs no
per-instance registration or teardown. This explicitly represents a dispatch
table similar to a C++ or C# vtable:

```odin
Damage_Entry :: struct {
	id:   typeid,
	hurt: proc(ctx: rawptr, amount: int),
}

DAMAGE_IMPLS := [?]Damage_Entry {
	{typeid_of(bug),    proc(ctx: rawptr, n: int) {bug_take_damage(cast(^bug)ctx, n)}},
	{typeid_of(cactus), proc(ctx: rawptr, n: int) {cactus_smash(cast(^cactus)ctx)}},
}

// the one call site every projectile shares:
hurt :: proc(node: gd.Object, amount: int) -> bool {
	if d, ptr, ok := rt.dispatch(DAMAGE_IMPLS[:], node); ok {
		d.hurt(ptr, amount)
		return true
	}
	return false
}
```

`rt.dispatch(table, obj)` composes the resolve and the table scan; `rt.lookup(table, id)`
is the scan alone (for call sites that must distinguish "not a script" from "no entry",
or that already hold the typeid). Both are generic on the entry type: any
struct with an `id: typeid` field works, checked at instantiation.
`INTERACT_IMPLS` and `SAVE_IMPLS` can therefore use their own entry structs
without a shared header or a requirement that `id` come first. `[:]` converts
the table from an array to a slice (`[2]Damage_Entry` → `[]Damage_Entry`), and
the `$E` parameter accepts different entry types. The compiler checks both
the slice and entry types.

The `[?]` literal is initialized as constant data in the binary. A
package-global `map[typeid]` instead needs allocation during library loading,
when the web target's allocator is not yet usable; see `runtime/context.odin`.
Scriptgen's generated tables use `[?]` arrays for the same reason. A short
contiguous scan also avoids hash-table overhead for small sets. If the table
outgrows a scan or needs per-file registration, initialize a map lazily inside
the dispatch procedure on its first call after boot.

Procedure literals must be capture-free because Odin has no closures. Pass
the instance through `ctx`. The core reports the instance's class name, and
`script_any` resolves it through the current library's registry to a typeid.
A class from an unregistered module resolves to nil, preventing access through
an incompatible struct layout. Like `script_of`, these queries require the
main thread and work on web through a directly wired resolver.

For a closed set whose callers need type-specific behavior, a tagged union
such as `union {^bug, ^cactus}` with an exhaustive `switch` lets the compiler
check that each type is handled. Use the table when N types share one
operation; use the union when callers need exhaustive case analysis.

For a global score or constant table without a per-node instance, use
file-private variables and package procedures such as `game_state_add`.
Scripts in one directory share an Odin package and can access that state
directly. Package state has no `/root/Name` node, GDScript visibility, or
`_ready` callback. Use an autoload when a manager needs those engine features
or persistence across scene changes.

## Autoload singletons

A `.odin` script can be a Godot autoload singleton: a node added under `/root`
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
	// Runs once at startup. Register the game's project settings and
	// input actions here using the Godot helpers described above:
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

Godot instantiates the script's base node (`//gd:extends Node`), attaches the
Odin script, and adds it under `/root` with the autoload's name, running
`_ready`. The leading `*` also exposes that name as a GDScript global.
Without `*`, the node is still autoloaded but must be accessed through the
scene tree. With it, GDScript can call the global directly:

```gdscript
GameManager.add_score(5)                       # autoload name is a global identifier
get_node("/root/GameManager").call("add_score", 5)
print(GameManager.get_score())
```

`@(gd_method)` procs are GDScript-callable (the proc name has its `<struct_snake>_` prefix
stripped: `game_manager_add_score` → `add_score`). The node is the same instance for the
whole session, so its struct fields are your singleton state.

> The base must be a `Node` subclass: an autoload entry is added to the scene tree, and a
> non-`Node` base cannot be parented. (A `Resource`/`RefCounted` script in `[autoload]`
> would load but not become a `/root` node.)

For a non-node global, such as exposing an object to GDScript as
`Engine.get_singleton("Name")` outside the scene tree,
the binding also has `gd.engine_register_singleton(engine, name, obj)` /
`gd.engine_get_singleton(engine, name)`. The `[autoload]` node form above is the
form provides lifecycle callbacks, `/root/Name`, and scene-change persistence.
Use `register_singleton` to register an object that does not need a node.

See `tests/autoload/` for a full, headless-verified example (a `GameManager` autoload whose
`_ready` registers a project setting + an input action, driven from GDScript).

## Editor tooling

Odin scripts can run in the editor and extend it. See `tests/editortools/` for the
headless-verified examples of everything below.

### `@tool` scripts + `gd.is_editor()`

A `//gd:tool` marker makes the engine instantiate the script in the editor,
so its lifecycle callbacks (`_ready`, `_process`, `_enter_tree`, …) run at
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
while the editor holds the scene open. It's only meaningful inside `//gd:tool` scripts:
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

The path is returned by the script's `_get_class_icon_path` virtual and stored
in the global class registry's `icon_path`, visible through
`ProjectSettings.get_global_class_list()`. These hooks register the path;
checking that the icon renders in the dock requires a visual editor check.

### EditorPlugin

A `//gd:extends EditorPlugin` script with `//gd:tool` can extend the editor. Register it
with the standard Godot plugin format, a `res://addons/<name>/plugin.cfg`:

```ini
[plugin]
name="My Odin Plugin"
script="my_plugin.odin"     ; relative to the addon dir
```

Enable it in `project.godot`:

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

> A scripts dir compiles into **one dll**, and a plugin's `script=` path must live under its
> addon dir, so put the addon's package there (e.g. `res://addons/<name>/*.odin`) and point
> `build/build_scripts.sh <proj> <that-dir>` at it.

### EditorInspectorPlugin (advanced)

A `//gd:extends EditorInspectorPlugin` script can customize the Inspector. Expose the engine
virtuals as `@(gd_method)` procs: the codegen strips the `<struct_snake>_` prefix, so a
proc named `my_inspector__can_handle` is exposed as the exact virtual `_can_handle` (note the
double underscore):

```odin
@(gd_method)
my_inspector__can_handle :: proc(self: ^MyInspector, object: ^gd.Object) -> bool { return true }

@(gd_method)
my_inspector__parse_begin :: proc(self: ^MyInspector, object: ^gd.Object) { /* add controls */ }
```

Headless tests call these virtuals directly and verify dispatch into Odin.
They do not check whether the editor invokes them during a live Inspector
rebuild after `add_inspector_plugin()` and selection of a handled object.
That behavior requires a visual editor check.


### Optional Replay view descriptors

`//gd:replay_view` is an optional header declaration for Node2D presentation
scripts. It generates a typed descriptor over public Replay/Godot helpers, without
adding wire fields, simulation lifecycle hooks or authority/sampling policy:

```odin
//gd:replay_view value=value,present=enemy_present,validate=enemy_validate,retired=enemy_retire,appearance=skin,configure=enemy_configure
```

`value` names a direct display field; optional `appearance` names a typed Resource
script pointer. `present` is required, `validate`/`retired` are optional, and
`appearance`/`configure` must be paired. Unknown/duplicate options, missing fields
and incompatible callbacks fail generation/compilation. Generated descriptors and
handwritten descriptors share the same implementation. See
[adapter bindings](../replay/godot/scene/adapter-bindings.md) for ownership, lifetimes,
scene validation and the distinct permanent-runner and entity-enemy examples.

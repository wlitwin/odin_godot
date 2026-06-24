# Bindgen patches (Odin `dev-2026-04`, Godot 4.6.2)

The vendored generator under `bindgen/upstream/` (a copy of
`dresswithpockets/odin-godot`, Apache-2.0) was written against an older Odin
stdlib. This file records every edit needed to make it build with the current
compiler and to generate a valid `godot` binding package from our
`extension_api.json` (Godot 4.6.2). All edits are surgical and in-place.

## Reproduce

All commands must run inside the project Nix dev shell. From the repo root:

```sh
nix develop --command make -C bindgen          # build + generate -> ../godot, ../gdext
nix develop --command make -C bindgen check    # odin check the generated package
```

The pipeline the Makefile encodes (matches the upstream `Makefile`):

1. `cd upstream && odin build temple/cli/ -o:speed -out:bin/temple_cli`
2. `cd upstream && ./bin/temple_cli bindgen bindgen bindgen`   (writes `bindgen/templates.odin`)
3. `cd upstream && odin build bindgen/ -o:speed -out:bin/bindgen`
4. `cd upstream && ./bin/bindgen <abs path>/extension_api.json -jobs:1`  (writes `upstream/godot/*.gen.odin`)
5. copy `upstream/godot/*.odin` -> `../godot/` and `upstream/gdext/*.odin` -> `../gdext/`

## Stdlib drift fixes (compile errors)

`core:os` was rewritten to the os2-style API (handles are now `^File`, errors are
`os.Error`, file metadata uses `File_Type`/`Permissions`). `core:path/filepath`
lost `walk`/the old `join`. Fixes:

### `upstream/temple/cli/main.odin`
- `filepath.walk(root, callback, &s)` → `os.walker_create` + `for info in os.walker_walk(&w)` loop. The walker only yields a directory's *contents* (not the root itself, unlike the old `filepath.walk`), so we collect `root` plus every walked sub-directory into a list and parse each as a package. Without seeding `root`, 0 compile-calls were found and `templates.odin` came out empty.
- `info.is_dir` (removed field) → `info.type != .Directory` (new `File_Type` enum).
- `in_err != os.ERROR_NONE` → `werr != nil` via `os.walker_error(&w)`.
- `os.open(p, os.O_TRUNC|os.O_RDWR|os.O_CREATE, 0o600)` → `os.open(p, {.Read,.Write,.Create,.Trunc}, os.Permissions_Default_File)`; `errno != os.ERROR_NONE` → `errno != nil`.
- `os.stream_from_handle(handle)` → `os.to_stream(handle)`.
- `os.read_entire_file_from_filename(p)` (×2) → `os.read_entire_file(p, context.allocator)` (now returns `(data, os.Error)`); `if !ok` → `if rerr != nil`. (This also fixed the "ambiguous `parser_init`" error: once `data` had a concrete `[]byte` type the `parser_init_bytes` overload resolved.)
- `filepath.join({...})` (×3) → `filepath.join({...}, allocator)` — it now requires an allocator and returns `(string, Error)` (use `x, _ = …` / `x, _ := …`).

### `upstream/bindgen/main.odin`
- `os.read_entire_file(api_file) or_return` → `os.read_entire_file(api_file, context.allocator)` with an explicit `if derr != nil { return }` (signature now needs an allocator and returns `os.Error`, not `bool`); `delete(data)` → `delete(data, context.allocator)`.

### `upstream/bindgen/gen.odin`
- `UNIX_ALLOW_READ_WRITE_ALL :: 0o666` → `:: os.Permissions_Default_File` (the perm arg is now `Permissions`-typed).
- `os.open(p, os.O_CREATE|os.O_TRUNC|os.O_RDWR, perm)` → `os.open(p, {.Create,.Trunc,.Read,.Write}, perm)`; `ferr != 0` → `ferr != nil`.
- `os.stream_from_handle(fhandle)` → `os.to_stream(fhandle)`.

### `upstream/bindgen/systeminfo_darwin.odin`  (NEW FILE)
- `num_processors()` only had `linux`/`windows` implementations, so it was undeclared on macOS. Added a `#+build darwin` variant that returns `os.get_processor_core_count()`.

## Generator logic fixes (otherwise builds but crashes / emits invalid code)

### `upstream/bindgen/main.odin` — call `init_templates()`
`init_templates()` populates the package-global compiled-template values
(`core_template`, `variant_template`, …). It was defined but **never called**, so
every template's `with` proc pointer was `nil` and the first codegen call jumped
to address 0 (segfault). Added `init_templates()` as the first statement of `main`.

### `upstream/bindgen/gen.odin` — stray line-continuation
Removed a stray trailing `\` after `codegen_godot(thread.Task{data = &graph})` in
the `job_count == 1` branch (a hard tokenizer/parse error; Odin has no line
continuation).

### `upstream/bindgen/graph/graph.odin` — three fixes for the 4.6.2 API

1. **Pointers to classes.** `Pointable_Type` excluded `^Builtin_Class` /
   `^Engine_Class`, but 4.6.2 native structs contain `Object *collider` fields.
   Added both to the `Pointable_Type` union and added the matching cases to
   `pointable_to_any` and `any_to_pointable`. (Without this: panic "Couldn't
   match any type to pointable type".)

2. **`meta` is not always a type.** Method return resolution did
   `return_value.meta.(string) or_else return_value.type`. In 4.6 object return
   values carry non-type metas — `"required"` (a nullability hint) and `"None"` —
   which were being treated as the type name and resolved to nothing. Now `meta`
   is used only when it actually names a known type (the numeric refinements
   `int32`/`double`/… that exist in `graph.types`), otherwise we fall back to
   `return_value.type`.

3. **Unresolved-type fallback.** `Root_Type` is a `#no_nil` union, so indexing
   `graph.types` with a missing key returns its *first variant wrapping a nil
   pointer* (a non-nil-tagged `^Builtin_Class(nil)`) instead of a nil union —
   which silently propagated and segfaulted during rendering. Added an explicit
   `_, exists := graph.types[name]` check in `_graph_resolve_type`: unknown C
   typedefs (e.g. `GDExtensionInitializationFunction`, and the Godot 4.5+
   `typeddictionary::…` form the generator doesn't model) now map to an opaque
   `rawptr` with a `WARN:` line instead of crashing.

No template (`*.temple.twig`) changes were required — the emitted Odin is valid.

## Output placement

- Generated package → `../godot/` (`package godot`, 1059 `*.gen.odin` files plus
  the upstream hand-written `Strings.odin` and `Variant.odin`).
- The package's only external dependency is `import "godot:gdext"`. The upstream
  `gdext` runtime package (`package gdextension`) was copied to a new top-level
  `../gdext/` so the generated package resolves and type-checks at its final
  location (`collection godot = repo root`).

## Caveats / coverage limitations of the generated bindings

- **Opaque `rawptr`** is emitted for: `GDExtensionInitializationFunction*`
  (the one real rendered case — `GDExtensionManager.load_extension_from_function`).
- The comma-separated **property hint** type strings (e.g.
  `"Texture2D,-AnimatedTexture,…"`) still warn and map to `rawptr`, but they are
  only ever a *property's declared type*; property accessors are typed from the
  underlying getter/setter method signatures (see below), so these never leak.
- `void*` / `const void*` are handled correctly as `rawptr` (built-in primitive
  mapping), not via the fallback.

---

# Follow-up: typed property accessors + typed dictionaries

Two ergonomics additions. Files touched:
`bindgen/graph/{api,graph}.odin`, `bindgen/views/{views,engine_class,package}.odin`,
`templates/bindgen_view_engine.temple.twig`, and the hand-written
`upstream/godot/Variant.odin`. Regenerate + verify exactly as above
(`make -C bindgen generate && make -C bindgen check`, both clean / exit 0).

## 1. Class properties are now emitted as typed accessors

`extension_api.json` lists `properties` per class; their getter/setter already
exist as generated **method** procs (`<class>_<method>`). For each property we
emit thin `"contextless"` accessor procs that delegate to those method procs:

- `bindgen/graph/api.odin` — added `index: Maybe(i64)` to `ApiClassProperty`.
- `bindgen/graph/graph.odin` — added `index: Maybe(i64)` to `Property` and set it
  in `_graph_property`.
- `bindgen/views/views.odin` — new `Property` view struct.
- `bindgen/views/engine_class.odin` — added a `properties: []Property` field and a
  builder loop that, per property, locates the getter/setter **method on this
  class** and records the proc to define, the proc to call, the resolved return /
  value types (taken from the *method* signature, so hint-string property types
  never matter), and the index.
- `templates/bindgen_view_engine.temple.twig` — renders a `// properties` block.

### Naming, collision-safety, contract
- Accessors are named `<class_snake>_get_<prop>` and `<class_snake>_set_<prop>`.
- If a method literally named `get_<prop>` / `set_<prop>` already exists, the
  wrapper is **skipped** (that method already *is* the accessor) — so a proc is
  never defined twice. Net contract for consumers: **for any property `X` on a
  class `C` whose getter is defined on `C`, `c_get_X(self)` exists** (either as the
  original method or as a generated wrapper); likewise `c_set_X(self, value)` when
  the property has a setter. Properties whose getter/setter is *inherited* are not
  re-emitted — use the defining parent's `parent_get_X`.
- Indexed properties (one getter/setter shared via a leading index arg) bake the
  index into the wrapper, cast to the index parameter's real type (usually an
  enum): `<class>_get_<prop>(self) -> T { return <class>_<getter>(self, IdxType(N)) }`.

### Real examples (from the generated `godot/`)
```odin
// CanvasItem.visible — getter method is irregularly named `is_visible`:
canvas_item_get_visible :: proc "contextless" (self: Canvas_Item) -> Bool {
    return canvas_item_is_visible(self)
}

// AudioStreamPlaylist.stream_0 — indexed (int index 0 into `get_list_stream`):
audio_stream_playlist_get_stream_0 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(0))
}
audio_stream_playlist_set_stream_0 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(0), value)
}

// Camera2D.limit_left — indexed by the `Side` enum:
camera2d_get_limit_left :: proc "contextless" (self: Camera2d) -> i32 {
    return camera2d_get_limit(self, Side(0))
}

// Node2D.position — getter/setter are exactly `get_position`/`set_position`,
// so NO wrapper is emitted; the existing methods already provide
// node2d_get_position(self) / node2d_set_position(self, v).
```
Counts in the 4.6.2 package: **1234 getter wrappers + 746 setter wrappers**.
(`core/` / script authors: read a property with `c_get_X(self)`, write with
`c_set_X(self, value)`. If your editor can't find `c_get_X`, the getter is
inherited — call it on the parent class, e.g. `node_get_owner(...)`.)

## 2. Typed dictionaries (`typeddictionary::K;V`) → `Typed_Dictionary(K, V)`

Previously these fell through to the opaque-`rawptr` fallback. They are now
modelled exactly like typed arrays:

- `upstream/godot/Variant.odin` — new parametric type mirroring `Typed_Array(T)`:
  ```odin
  Typed_Dictionary :: struct($K, $V: typeid) {
      using untyped: Dictionary,
  }
  ```
- `bindgen/graph/graph.odin` — new `Typed_Dictionary{key_type, value_type}` graph
  node, added to the `Any_Type` union, and the `typeddictionary` case in
  `_graph_resolve_type` now parses `K;V` (dropping any `:` hint suffix) and
  resolves both sides.
- `bindgen/views/package.odin` — handled `^g.Typed_Dictionary` in every exhaustive
  `Any_Type` switch (`_any_to_rawptr`, `_any_to_variant_type` → `"Dictionary"`,
  `_any_to_odin_name`) and in the `ensure_imports` / `resolve_qualified_type`
  branches, where it renders as `Typed_Dictionary(K, V)`.

Consumer-facing shape: a `typeddictionary::Color;Color` value is rendered as
`Typed_Dictionary(Color, Color)` — a distinct, type-checking wrapper that shares
`Dictionary`'s layout (via `using untyped`), so it can be passed wherever a
`Dictionary` is expected and documents its key/value types.

**Coverage note:** in 4.6.2 the only two `typeddictionary` uses are the *declared
types* of two properties (`DPITexture.color_map`, `GraphEdit.type_names`) whose
getter methods Godot itself types as plain (untyped) `Dictionary`. Because
property accessors are typed from the getter/setter method signatures, those two
accessors return `Dictionary`, and `Typed_Dictionary(...)` therefore does not
appear in the current generated output — but the type, the resolver, and all view
plumbing are in place, so any method return/argument that uses a typed dictionary
in a future API will render `Typed_Dictionary(K, V)` automatically (verified:
the `typeddictionary::…` entries no longer appear in the generator's
`WARN: unresolved` output).

---

# Binding correctness fixes (runtime crashes found while building Phase 1)

Three systemic defects that produced null method-binds / wrong object pointers at
runtime. All fixed at the generator source and re-generated via `bindgen/Makefile`;
`odin check godot/` stays clean (exit 0). Each is verified at **runtime** by
`bindgen/verify/` (a throwaway GDExtension run headless — `bindgen/verify/run.sh`):

```
VERIFY: A push_back/size/get -> size=2 e0="hello" e1="world"  PASS
VERIFY: B singletons -> ResourceLoader=true ProjectSettings=true  PASS
VERIFY: C ref instance method get_as_text -> "Phase2 marshalling OK"  PASS
VERIFY: ALL PASS
```

## Bug A — builtin-class methods interned the prefixed Odin name (all builtin types)
`variant_get_ptr_builtin_method` requires the **bare** engine method name, but the
variant view set `method.name` to the class-prefixed Odin proc name, which the
template used both for the proc identifier (double-prefixing it) AND for the
interned StringName.

- File: `bindgen/views/variant.odin` (`variant` proc, method loop).
- Before: `name = fmt.aprintf("%v_%v", class.snake_name, class_method.name)`
- After:  `name = strings.clone(class_method.name)`  (template already prepends `{{ this.snake_name }}_`)

Emitted `Packed_String_Array.gen.odin`, before → after:
```odin
// proc name:  packed_string_array_packed_string_array_push_back  ->  packed_string_array_push_back
_gde_name := new_string_name_cstring("packed_string_array_push_back", true)   // before (null bind -> crash)
_gde_name := new_string_name_cstring("push_back", true)                       // after
```
(Systemic: same correction now applies to Array, Dictionary, String, Vector*, all Packed_* etc.)

## Bug B — singletons looked up by snake_cased name (all multi-word singletons)
The singleton StringName was interned from the Odin name (`"Resource_Loader"`)
instead of the engine class name (`"ResourceLoader"`), so `global_get_singleton`
returned null.

- Files: `bindgen/views/engine_packages.odin` (new `godot_name` field on the
  `Singleton` view, populated from `singleton.godot_name`) and
  `templates/bindgen_view_core.temple.twig` (intern `{{ singleton.godot_name }}`,
  while the StringName *variable* still uses `{{ singleton.name }}` so the Odin
  identifier stays valid).

Emitted `godot.gen.odin`, before → after:
```odin
__Resource_Loader_name   = new_string_name_cstring("Resource_Loader", true)    // before -> null
__Resource_Loader_name   = new_string_name_cstring("ResourceLoader", true)     // after
__Project_Settings_name  = new_string_name_cstring("ProjectSettings", true)    // also DisplayServer, RenderingServer, ...
```

## Bug C — engine instance methods passed `&self` instead of the object pointer
`object_method_bind_ptrcall(method, p_instance: ObjectPtr, …)` wants the object
pointer value. An engine-class `self` already *is* that pointer (non-refcounted
classes alias to `Object :: rawptr`; RefCounted classes are `^Object` whose value
holds the object-pointer bits). The template passed `&self` — the address of the
stack local (`^rawptr`) — so the engine dereferenced a stack address. Static
methods passed `nil` and were unaffected, which is why only instance methods crashed.

- File: `templates/bindgen_view_engine.temple.twig` (both instance-method blocks).
- Before: `object_method_bind_ptrcall(__{{ method.name }}_method_ptr, &self, raw_data(args), …)`
- After:  `object_method_bind_ptrcall(__{{ method.name }}_method_ptr, self,  raw_data(args), …)`

Both `Node2d`-style (rawptr) and `File_Access`-style (`^Object`) selfs implicitly
convert to `ObjectPtr`, yielding the correct object pointer. (The builtin/variant
template was already correct — its `self` is a `^Value` passed directly.)

## Bug D — `float` args/returns sized as `f32` in ptrcall (every method taking/returning a float)
In Godot's `ptrcall` ABI the scripting `float` type is **always** encoded as a
64-bit `double`: `core/variant/method_ptrcall.h` defines
`MAKE_PTRARGCONV(float, double)`, so a `float` argument is read via
`*(const double *)ptr` and a `float` return is written via `*(double *)ptr` — 8
bytes either way, regardless of the C++ `meta` width (`"float"` vs `"double"`).

The generator resolved the meta-type `"float"` to Odin `f32` (4 bytes) everywhere
(`graph.odin` `odin_primitives`). For ptrcall callables this is wrong:
- A `float` **return** read back the low 4 bytes of the double the engine wrote.
  For a returned `1.0` (`0x3FF0000000000000`) those low 4 bytes are `0x00000000`,
  so the binding returned exactly `0.0f`. This is why `Input.get_axis(...)`,
  `get_action_strength(...)`, `Vector2.length()`, etc. all returned `0`.
- A `float` **argument** passed `&f32` (4 bytes); the engine read 8 bytes, taking
  4 bytes of adjacent garbage as the high half of the double — e.g.
  `Input.action_press(action, strength)` sent a garbage strength.

Scope: this hit **every** engine method, builtin method, operator, constructor,
and utility function that takes or returns a scalar `float` — single-arg and
multi-arg alike. It was *not* specific to `StringName` or to multi-arg calls (the
`get_axis` symptom that surfaced it just happened to be a float-returning method);
`StringName`/object/int args marshal correctly. `is_action_pressed` "worked" only
because it returns `bool` (`MAKE_PTRARGCONV(bool, uint8_t)`, 1 byte, no
truncation). `Vector2`-returning methods worked because `Vector2` is
`real_t`-componented (`[2]f32` in single precision) and passed whole via
`PtrToArg<Vector2>`, which is *not* the `float→double` conversion.

Fix (generator source): `upstream/bindgen/graph/graph.odin` adds
`_graph_resolve_ptrcall_type`, which resolves a type and, if it is the scalar
`float` primitive, substitutes `double` (→ Odin `f64`). It is used in place of
`_graph_resolve_type` for the args/returns of engine methods, builtin methods,
operators, constructors, and utility functions (all ptrcall paths). Native-struct
fields and builtin member *layouts* keep `_graph_resolve_type` (real 32-bit C
floats); `real_t`/vector types are unaffected. The public binding signatures for
these floats are now `f64` (which matches Godot's own `float` precision).

Regenerate with a forced bindgen rebuild — the `bindgen` Make target lists only
`templates.odin` as a prerequisite, not the `graph/` sources, so a `graph.odin`
edit alone won't relink the generator: `rm -f upstream/bin/bindgen && make generate`.

## Verification harness
`bindgen/verify/verify.odin` is a minimal GDExtension (`entry_symbol
odin_godot_init`) that, on Scene-level init, constructs a `Packed_String_Array`
and pushes/reads strings (A), fetches the `ResourceLoader` + `ProjectSettings`
singletons (B), and opens a temp file via `FileAccess` then calls the instance
method `get_as_text` on the returned Ref (C). Run with
`nix develop --command bash bindgen/verify/run.sh`.

### Out-of-scope observation (NOT one of the three bugs)
During Godot's `--import` GDExtension verification, `file_access_init()` (which
eagerly fetches all 68 FileAccess method binds) emits `Parameter "mb" is null`
warnings for some methods across the multi-pass scan. The methods exercised by the
tests (`open`, `get_as_text`, plus the builtin/singleton paths) all resolved
correctly — A/B/C pass. The remaining nulls point to a *separate* method-hash
question (some 4.6.2 compatibility-versioned methods not resolving against the
running build), which is independent of the three name/pointer fixes above.

## Bug E — eager method-bind resolution at init flooded ~16,807 `mb is null` errors
Every run printed ~16,807 `ERROR: Parameter "mb" is null at
gdextension_classdb_get_method_bind` lines (identical in Phase 2 & 3 → tied to
init). Harmless to functionality but buried real errors.

### Root cause (NOT a wrong hash/name)
The engine-class template resolved **every** method bind eagerly in each class's
`*_init()` proc, all driven by `godot.init()` — which `core/main.odin` calls at
the GDExtension **entry point** (Core initialization level). But most engine
classes are only registered with ClassDB at *later* levels (Servers/Scene), so
`classdb_get_method_bind` returns null for them at that early point.

Instrumented proof (temporary `dbg_method_bind` wrapper logging null fetches):
of 16,349 total binds, **14,906 distinct returned null** — and the split is by
registration timing, not hash/name:
- `FileAccess` (core, registered early): **0/68 null** — every bind resolved
  (its hashes match the engine exactly, e.g. `get_as_text` hash `201670096` in
  both the emitted code and `extension_api.json`).
- `Node`/`RenderingServer`/`DisplayServer`/… (registered later): hundreds null
  each (`RenderingServer` 526, `DisplayServer` 269, …), purely because they
  weren't registered yet when `godot.init()` ran.

So the hashes and interned names were already correct; the binds were just
fetched too early.

### Fix (generator: `templates/bindgen_view_engine.temple.twig`)
Resolve engine-class method binds **lazily on first call**, exactly like the
builtin/variant methods already do (`@(static) __ptr` guard), instead of eagerly
in `_init`:

```odin
// before — global ptr, fetched eagerly in <class>_init():
__bindgen_gde.object_method_bind_ptrcall(__get_as_text_method_ptr, self, raw_data(args), &ret)
// <class>_init(): __get_as_text_method_ptr = classdb_get_method_bind(&__class_name, &__name, 201670096)

// after — per-proc static, fetched on first call (class is registered by then):
@(static) __ptr: __bindgen_gde.MethodBindPtr
if __ptr == nil {
    _gde_name := new_string_name_cstring("get_as_text", true)
    __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
}
__bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
```

`<class>_init()` now only interns the class StringName (still needed for object
construction and as the class arg to the lazy fetch); the per-method global
`__*_method_ptr` declarations are removed. This is **not** error suppression: a
genuinely unresolvable bind stays nil and the following ptrcall surfaces it at
the call site (findable), and the hashes/names are unchanged.

### Verification
- `mb is null` count, Phase 3: **16,807 → 0** (also 0 in Phase 1 & 2). The
  related one-off `Method 'AnimationMixer._post_process_key_value' has changed`
  error (a virtual method) is also gone — virtual binds are now only fetched if
  actually called.
- **PHASE1_OK / PHASE2_OK / PHASE3_OK all still print** (the methods the tests
  call resolve correctly at call time).
- `odin check godot/` exit 0.
- Residue: none in normal operation. Methods never called are never fetched;
  Godot virtual methods (`is_virtual`, ~1415) and classes absent from a given
  run would only null **if called**, which is the correct, locally-visible
  behavior rather than an init-time flood.

(Instrumentation note: the diagnosis used a throwaway `gdext/dbg.odin` wrapper +
a temporary template hook, both removed afterwards. `tests/phase1/` had a
prebuilt dll but no runner script; its `bin/` dlls were rebuilt from `core/` +
`showcase/` to re-verify PHASE1_OK — build artifacts only.)

## Bug F — enum values out of i32 range overflow on wasm32
On `wasm32`, Odin's `int` is 32-bit, so an `enum` (default `int` backing) cannot
hold values outside the signed-32-bit range. `RenderingServer.ArrayFormat` has
`Array_Flag_Format_Version_2 = 34359738368` (`0x8_0000_0000`, bit 35), so
`odin check godot -target:freestanding_wasm32` failed:

```
rendering_server.gen.odin(670:35) Error: Cannot convert numeric value
'34359738368' ... to 'Rendering_Server_Array_Format' from 'untyped integer'
```

On 64-bit native it only compiled by luck (`int` = 64-bit).

### Rule
Emit an explicit enum backing type:
- **all `is_bitfield` enums → `enum i64`** (flag enums whose high bits can be
  set/combined), and
- **any non-bitfield enum with a value outside the i32 range → `enum i64`**.
- everything else → `enum int` (explicit; identical to the previous default).

No enum value in 4.6.2 exceeds the i64 range, so `i64` is sufficient and used
uniformly (no `u64` needed). Class-constant enums (`*_Constants`) were checked —
no constant is out of i32 range — so they are left as plain `enum`.

### Generator changes (`bindgen/upstream/`)
- `bindgen/views/views.odin`: added a `backing: string` field to the `Enum` and
  `Bit_Field` view structs and a helper `enum_backing(values, force_wide)` that
  returns `"i64"` when `force_wide` (bitfields) or when any value parses outside
  the i32 range, else `"int"`.
- `bindgen/views/engine_class.odin`, `engine_packages.odin`, `variant.odin`: set
  `backing` at every enum/bit-field construction site — `"i64"` for bit-fields
  (and the builtin bit_set view), `enum_backing(values, false)` for plain enums.
- `templates/bindgen_view_enum.temple.twig` and `bindgen_view_bit_field.temple.twig`:
  `{{ this.name }} :: enum {{ this.backing }} {`.

### Before / after (RenderingServer.ArrayFormat)
```odin
// before
Rendering_Server_Array_Format :: enum {
    Array_Flag_Format_Version_2 = 34359738368,   // overflows i32 on wasm32
}
// after
Rendering_Server_Array_Format :: enum i64 {
    Array_Flag_Format_Version_2 = 34359738368,
}
```

### No call-site changes needed
On native, `int` is already 64-bit, so `enum i64` and the previous `enum`(int)
are the same width — ptrcall arg marshalling (`&flags_`) and any enum passing is
byte-for-byte identical, which is why native behaviour is unchanged. The
generated code does no `|`/arithmetic on these enums itself (Godot bitfields are
plain `enum`, not `bit_set`), so widening the backing required no other edits.

### Verification
- `odin check godot -no-entry-point -collection:godot=.. -target:freestanding_wasm32`
  → **exit 0** (was failing with the overflow error). 0 remaining
  "Cannot convert numeric" errors.
- `odin check godot/` native → exit 0.
- Distribution in the regenerated package: 35 `enum i64` (the 35 bitfields,
  incl. `ArrayFormat`), 728 `enum int`, `_Constants` enums unchanged.
- `tests/phase{2,3,35,4,5}/run.sh` → PHASE2_OK / PHASE3_OK / PHASE35_OK /
  PHASE4_OK / PHASE5_OK all print, `mb is null` = 0 (native binds unchanged).

## Bug G — vararg engine methods are uncallable (ptrcall aborts)
Godot aborts with `"ptrcall can't be used with vararg methods"` for any
`is_vararg` method, but the generator emitted a normal **ptrcall** wrapper for
them. Found via `object_emit_signal` (it aborted even with zero payload); the
same latent bug hit `Object.call`/`call_deferred`, `Node.rpc`/`rpc_id`,
`SceneTree.call_group`, `TreeItem.call_recursive`, etc.

### Scope
**15** engine methods have `"is_vararg": true` (all instance methods), across 8
classes. Returns: 7 `Variant`, 5 `void`, 3 `enum::Error`. New signatures append a
variadic `extra: ..Variant`:

| method | new signature |
|---|---|
| `Object::emit_signal` | `object_emit_signal(self: Object, signal_: String_Name, extra: ..Variant) -> Error` |
| `Object::call` / `call_deferred` | `object_call(self: Object, method_: String_Name, extra: ..Variant) -> Variant` |
| `Node::rpc` | `node_rpc(self, method_: String_Name, extra: ..Variant) -> Error` |
| `Node::rpc_id` | `node_rpc_id(self, peer_id_: Int, method_: String_Name, extra: ..Variant) -> Error` |
| `SceneTree::call_group` | `scene_tree_call_group(self, group_, method_: String_Name, extra: ..Variant)` (void) |

(also `Node::call_deferred_thread_group`/`call_thread_safe`, `ClassDB::class_call_static`,
`EditorUndoRedoManager::add_do_method`/`add_undo_method`, `GDScript::new`,
`JavaScriptBridge::create_object`, `TreeItem::call_recursive`.)

### Generator change (`templates/bindgen_view_engine.temple.twig` + view)
Added an `{% if method.vararg %}` branch in both method loops. The bind is fetched
the same way (`classdb_get_method_bind` + the method hash, lazy); only the CALL
and marshalling differ — it now matches the hand-written `Object::emit_signal`
varcall in `godot/Ergonomics_Signals.odin`:
- marshal each fixed declared arg to a `Variant` (`variant_from(&arg)`), append
  the variadic `extra` Variants into a `[64]gdext.VariantPtr` buffer,
- `gdext.object_method_bind_call(__ptr, self, &__argv[0], argc, &ret_variant, nil)`,
- convert the return: `Variant` passed straight through; `Error`/ints via
  `Error(variant_to_int(&ret))`; void ignored; the temporary fixed-arg Variants
  (and the scratch return Variant for non-Variant returns) are `variant_destroy`-ed.

A `ret_is_variant: bool` field was added to the `Method` view
(`bindgen/views/views.odin`, set in `engine_class.odin`) so the template knows
whether to pass the return Variant through or convert it.

Before / after (`object_emit_signal`):
```odin
// before: object_emit_signal(self: Object, signal_: String_Name) -> (ret: Error) {
//             ... object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)   // Godot ABORTS
// after:
object_emit_signal :: proc "contextless" (self: Object, signal_: String_Name, extra: ..Variant) -> (ret: Error) {
    ... __fv_signal := variant_from(&signal_); fill __argv ...
    __ret: Variant
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(VariantPtr)&__ret, nil)
    ret = Error(variant_to_int(&__ret))
    ... variant_destroy(&__ret); variant_destroy(&__fv_signal) ...
}
```
Exactly 15 `object_method_bind_call(` call sites are emitted (Object 3, Node 4,
SceneTree 2, EditorUndoRedoManager 2, ClassDB/GDScript/JavaScriptBridge/TreeItem 1).

### Caller safety
grep of `core/`, `runtime/`, `tests/`, `scriptgen/`, `showcase/`, hand-written
`godot/*.odin` for all 15 wrapper names found **no callers** (only a comment in
`godot/Ergonomics_Signals.odin`). The ergonomics `emit`/`emit_args` hand-roll
their own varcall and were left untouched — they still compile and their test
passes. **No caller fixes were needed.**

### Verification
- Native `odin check godot/` → exit 0; `odin check godot -target:freestanding_wasm32`
  → exit 0 (Bug F not regressed).
- Runtime (throwaway GDExtension, `bindgen/verify/`):
  ```
  VERIFY: G object_call set_meta/get_meta round-trip -> 4242  PASS
  VERIFY: G object_emit_signal -> err=Ok  PASS (previously ABORTED)
  ```
  `object_call` round-trips a 2-arg payload through the vararg path and converts
  the Variant return; `object_emit_signal` (after `add_user_signal`) now returns
  `Error.Ok` instead of aborting.
- `tests/run_all.sh` → **ALL GREEN (14/14)**, incl. ergonomics + web.

### Limitation
The fixed-arg marshalling uses the generic `variant_from(&arg)` group; every
fixed arg of the current 15 (StringName/Object/String/int) is covered. A future
vararg method whose fixed arg or non-Variant return isn't an int-like/`variant_from`-able
type would need the group extended (none exist in 4.6.2).

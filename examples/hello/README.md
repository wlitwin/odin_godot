# examples/hello — Odin → GDExtension registration ABI proof

A minimal Odin-authored GDExtension class, `OdinHello` (extends `RefCounted`),
that GDScript can construct, call a custom method on, read/write a property,
and receive a signal from — verified headless against **Godot 4.6.2**.

This exists to validate the low-level registration primitives that the real
`ScriptLanguageExtension` core (`core/`) will reuse.

## Files

- `src/main.odin` — entry point `odin_hello_init` (`@(export)`), calls
  `gdext.init` + `godot.init`, registers the module at the `.Scene` level.
- `src/hello_class.odin` — the `OdinHello` class: custom method `add(a, b) -> int`,
  property `value` (get/set), signal `value_changed(value: int)` emitted on set,
  plus `create_instance`/`free_instance`.
- `example.gdextension` — `entry_symbol = "odin_hello_init"`,
  `compatibility_minimum = "4.6"`, macOS library → `bin/hello.dylib`.
- `project.godot` — minimal Godot 4.6 project.
- `test_hello.gd` — headless `SceneTree` script asserting all of the above;
  prints `HELLO_OK` on success or `HELLO_FAIL: <reason>`.
- `build.sh` — builds the dll into `bin/hello.dylib`.

## Build

From the repo root, inside the Nix dev shell:

```
nix develop --command bash -c 'bash examples/hello/build.sh'
```

This runs:

```
odin build examples/hello/src \
    -collection:godot=/Users/walter/data/code/odin/odin_godot \
    -build-mode:dll -out:examples/hello/bin/hello.dylib -debug
```

(The linker emits `could not find symbol ... _method_ptr` warnings for stripped
core method binds — benign; the dll links and loads fine.)

## Run (headless)

The first run must generate `.godot/extension_list.cfg` so the runtime knows to
load the extension:

```
nix develop --command bash -c '$GODOT --headless --path examples/hello --import'
```

(That import pass also prints a Godot-internal `EditorHelp` doc-gen crash at
cleanup — unrelated to this extension; the `extension_list.cfg` is written
before it.) Then run the test:

```
nix develop --command bash -c '$GODOT --headless --path examples/hello --script test_hello.gd'
```

Expected output ends with:

```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HELLO_OK
```

(The leading `Parameter "mb" is null` errors come from `godot.init()` resolving
core method binds whose symbols were stripped at link time — they do not affect
`OdinHello`.)

## ABI primitives proven

| Primitive | Where | Status |
|-----------|-------|--------|
| Extension entry / init (`get_proc_address`, `Initialization`, init levels) | `main.odin` `odin_hello_init` | proven |
| `classdb_register_extension_class2` (class registration under a base) | `hello_class_register` | proven |
| Instance create / free (`classdb_construct_object`, `object_set_instance`, `object_set_instance_binding`) | `create_instance`/`free_instance` | proven |
| **Custom method bind** (`classdb_register_extension_class_method`, `ExtensionClassMethodInfo`, call + ptrcall) — GDScript `obj.add(2,3)` | `bind_returning_method_2_args` | proven |
| Property bind (get/set via `classdb_register_extension_class_property`) — `obj.value` round-trip | `bind_property_and_methods` | proven |
| Signal bind + emit (`classdb_register_extension_class_signal`, `Object::emit_signal` method bind) — `value_changed` fires | `bind_signal` / `emit_value_changed` | proven |
| Virtual dispatch (`get_virtual_call_data_func` / `call_virtual_with_data_func`) | slots present in `ExtensionClassCreationInfo2`; not exercised here (RefCounted needs no `_process`) — see `examples/hello-gdextension` for a working `_process` example | not exercised |

The custom method bind is the new capability vs. the upstream
`hello-gdextension` reference (which only bound properties + virtuals).

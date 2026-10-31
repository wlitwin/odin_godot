# examples/hello — Odin → GDExtension registration ABI proof

This early registration experiment defines `OdinHello`, an Odin-authored
GDExtension class extending `RefCounted`. GDScript constructs it, calls a custom
method, reads and writes a property, and receives its signal. The recorded
headless validation used Godot 4.6.2.

The experiment tested low-level registration primitives for the
`ScriptLanguageExtension` core in `core/`. Its build output and warnings below
record that test configuration.

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

The recorded linker output included `could not find symbol ... _method_ptr`
warnings for stripped core method binds. The fixture's dll still linked and loaded.

## Run (headless)

The first run must generate `.godot/extension_list.cfg` so the runtime knows to
load the extension:

```
nix develop --command bash -c '$GODOT --headless --path examples/hello --import'
```

The recorded import pass also reported a Godot-internal `EditorHelp` doc-gen
crash during cleanup, after writing `extension_list.cfg`. Then run the test:

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

This experiment added custom method binding to the upstream `hello-gdextension`
reference, which exercised properties and virtuals.

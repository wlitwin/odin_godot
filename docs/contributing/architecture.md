# SDK architecture

The core GDExtension registers Odin as a Godot script language. Each game builds
its authored scripts and generated registration into a scripts library. The core
loads that library through the shared runtime contract and dispatches Godot
lifecycle, property, method, and signal operations to its callbacks.

## Build and load

1. `scriptgen/` reads script structs, markers, tags, and attributes.
2. Generated code describes classes, fields, callbacks, and optional framework
   protocols through `runtime/`.
3. `build/build_scripts.sh` compiles authored and generated code, then builds the
   core when needed. Script modules can have separate libraries.
4. The core validates a candidate's entry points and ABI fingerprint before boot.
5. Boot initializes its engine binding globals; the manifest supplies immutable
   class descriptors owned by that scripts generation.

See [Core and scripts boundary](native-boundary.md) for layouts, compatibility,
allocation ownership, and callback lifetimes.

## Reload

The core retains script generations while instances, callbacks, and retained
owners still depend on them. A candidate must pass admission before becoming
active. Script state that contains callbacks or pointers needs an explicit
refresh boundary; see [Workflow](../workflow.md) and [Script modules](../modules.md).

Changing a Box3D backend is a separate process-lifetime operation. Opted-in
desktop modules use one loaded native domain, with checks for build/target and
producer ownership. See the
[runtime contract](https://github.com/wlitwin/odin_godot/blob/main/box3d/docs/runtime-deployment.md).

## Desktop export

The editor export plugin selects the target, compiles scripts, and adds their
library beside the core. Native runtime loading resolves the sibling library
through the actual filesystem; a packed `res://` resource cannot be passed to
`dlopen`. The `.gdextension` manifest supplies the platform core entries.

## Browser export

The web builder composes the core, binding, and game scripts into one Emscripten
side module. Web-specific code avoids native filesystem loading and dynamic
library APIs. Godot's web exporter bundles the module, and the serving environment
supplies cross-origin isolation headers when required by the threaded build.

Use [Exporting](../exporting.md) for project configuration and public platform
limits. `build/build_web.sh` owns composition/linking and `tests/web/` exercises
the exported browser runtime.

## Framework ownership

Kit and Replay share engine bindings and suitable utility packages, while
retaining separate sessions, protocols, history, and presentation contracts.
Box3D's adapters attach complete solver state to those existing runtimes; they
do not introduce a second tick scheduler. Current technical contracts are kept
[beside Box3D](https://github.com/wlitwin/odin_godot/tree/main/box3d/docs).

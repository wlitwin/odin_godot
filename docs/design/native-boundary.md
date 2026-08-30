# Native core ↔ scripts boundary

Native builds use two libraries: the prebuilt odin_godot core and the project's compiled
scripts library. This page records exactly what crosses that boundary, how compatibility is
decided, and which side owns each allocation.

## Compatibility rule

The loader validates a candidate before booting it or reading its manifest:

1. Required C-callable entry points must exist.
2. `ABI_VERSION` must match. This is the manually bumped semantic generation for function
   signatures and contract meaning.
3. The 64-bit ABI layout fingerprint must match. It covers every boundary struct's size,
   alignment, and named field offsets, plus the primitive, Godot enum, and procedure-pointer
   representations those structs use.

`odin version` is retained as build provenance, but exact string equality is not a load
requirement. If two Odin releases compile the boundary identically, the scripts library loads
and the native log records `ODIN_COMPILER_SKEW_ABI_COMPATIBLE`. If either the semantic
generation or any layout fact differs, the library is rejected before `odin_scripts_boot` and
the old hot-reload generation remains active.

This does not promise that every Odin release can compile every odin_godot checkout. Source
and compiler API changes are ordinary build-time compatibility constraints. The Nix-pinned
compiler remains the tested recommendation, especially before Odin 1.0, but it is no longer an
artificial binary lock when the produced ABI is demonstrably identical.

## Boundary inventory and ownership

| Surface | Representation | Ownership and lifetime |
|---|---|---|
| Compatibility/provenance | `proc "c"` returning integers or a static `cstring` | No allocation; safe before boot |
| Boot | `proc "c"` with Godot's C function pointer and opaque library handle | Borrowed engine values |
| Class manifest | DLL-owned pointer + `i32` count of descriptors | Immutable for that scripts generation; core never frees it |
| Registration errors | DLL-owned pointer + `i32` count of static cstrings | Core clones messages before a generation can unload |
| Lifecycle, method, getter/setter callbacks | Contextless `proc "c"` pointers | Core calls them only while the owning generation is leased |
| Typed script resolver | `proc "c"`, opaque object/byte pointers, `uintptr` length | Returned script memory is borrowed while the live-instance/execution gate permits access |
| Panic reporter | `proc "c"` with a `cstring` | Borrowed for the duration of the call |
| Script struct storage | Raw block described by `uintptr` size/alignment and field offsets | Allocated and freed by the core; scripts operate on the borrowed block |

No Odin slice, dynamic array, map, string, `any`, allocator, closure context, or by-value
Godot `Variant` crosses the library boundary. Tables are pointer+count pairs, text is cstring
or pointer+length, flags are `b8`, counts and type tokens are fixed-width, and sizes are `uintptr`.
Script `typeid` remains available to authored code and the runtime registry, but its descriptor
slot is only an opaque `u64` token and is never interpreted by the core.

Each side frees only its own allocations. The scripts DLL owns registry storage and static
descriptor tables. The core clones path identities, cache metadata, and error text that must
survive a reload; it also owns the outer script-struct allocation. Any heap-backed value a
game stores inside its struct remains the game's responsibility, as it was before this ABI
handshake.

## Performance

Compatibility work happens once per initial load or hot-reload candidate. Normal execution
still uses direct typed script pointers, direct field offsets, and native C-convention
callbacks. There is no adapter object, descriptor translation, Variant marshaling, allocator
bridge, or new lock on method/property/frame dispatch.

The boundary intentionally is not packed: natural alignment keeps callback and pointer loads
efficient. The fingerprint verifies the compiler's actual natural layout instead.

## Changing the contract

- Adding, removing, or reordering a descriptor field automatically changes the layout
  fingerprint.
- Changing an exported function signature, callback meaning, or another semantic fact that
  layout cannot express requires bumping `ABI_GENERATION` in `runtime/runtime.odin`.
- Keep all cross-library procedures `"c"` and contextless; never add an Odin-owned container
  or allocator to a boundary type.
- Extend the fingerprint when adding a new boundary struct.

`tests/reload_exports` proves both sides of the gate: a doctored compiler identity with an
identical fingerprint loads, while a doctored descriptor layout is refused and the running
generation remains intact.

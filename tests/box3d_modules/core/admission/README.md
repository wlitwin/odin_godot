# Executable admission controls

The opt-in Core reads one open module file, caps it at 64 MiB, validates the
actual bytes, and writes those bytes to an exclusive process-qualified generation
copy beside the module. It loads only that copy. Initial load and reload retain
the existing generation/refcount/gate cleanup. An atomic build publication cannot
swap another original file into the checked load. Default Core is unchanged.

Accepted metadata is little-endian Mach-O64 for the selected ARM64/x86-64 slice,
standard big-endian fat32/fat64 wrappers, and little-endian ELF64 shared objects
with ordinary section headers. Extended ELF counts/SHN_XINDEX, sectionless ELF,
compressed chained symbol pools, legacy nonempty Mach bind-opcode programs and
undeclared non-system dependencies are Unsupported. This is the bounded alpha
SDK profile, not a general native-plugin dependency resolver.

Direct dependency names are closed:

- Mach-O: `@rpath/libogb3.dylib`, `/usr/lib/libSystem.B.dylib`, and
  `/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa`.
- Qualified Linux x86-64: `libogb3.so`, `libm.so.6`, `libc.so.6`, and
  `ld-linux-x86-64.so.2`.

Profile 0 may omit the backend. Every other dependency is rejected even when a
canonical backend is also listed or no function is imported from the extra
library. Defined `ogb3_*` symbols are rejected. Undefined native functions require
the canonical import; Mach library ordinals must select it. Mach exports tries
and chained import names are also scanned. Symbol and dependency ranges remain
slice-bound. ELF dynamic/dynsym/dynstr virtual ranges must have one unambiguous
file-backed PT_LOAD translation matching the scanned section bytes; section
addresses alone are not trusted. Zero string tables always return Malformed.

Bounds are 64 fat slices, 1024 Mach commands / ELF program headers, 16384 ELF
sections, 256 direct dependencies, 1,048,576 scanned symbols, 32 MiB total string
scan, 16 KiB names, and bounded exports-trie depth/node traversal. No external
command or sidecar assertion is used by the production parser. File-format
admission is not a sandbox for arbitrary authored code or a proof of all OS
loader invariants.

Core preloads the one controlled adjacent native library and checks its actual
contract against BOTH Core compile-expected SHA256 values before registry/object
initialization. Existing module postload ABI/cookie/expected checks remain.
Expected values use `sha256:<64hex>` to avoid Odin numeric flag inference. Script
threading flags are unchanged. `LOADER_RELEASED` means a successful loader-ref
release; macOS may physically retain TLV-bearing script code. No physical unmap
is inferred. Duplicate native images are rejected before they can be mapped.

`admission_cases.py` mutates only parser input bytes. It never calls dlopen on a
mutation. It includes real Mac/Linux SDK positives, profile0, fat wrappers,
static definitions, noncanonical and unrelated names, simultaneous canonical and
foreign dependencies, ELF pointer/file disagreement, ambiguous PT_LOADs, the
zero-string-table regression and deterministic malformed metadata fuzz. Root's
actual Godot runner independently checks @init sentinels and preservation of a
live old world/capsule on rejected reload.

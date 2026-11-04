# One Box3D domain in a Godot Web export

Select a production archive from `build/build_box3d.sh WebSIMD CACHE` with
`BOX3D_WEB_ARCHIVE=/absolute/CACHE/build/WebSIMD/BUILD/libogb3.a` when running the
normal Web build/export. `build_web.sh` verifies its source/manifest/target and
links it once into the existing Core + scripts AOT side module. Desktop shared
libraries are separate inputs. Native-free Web builds keep their existing path.

The Odin object enables atomics/bulk-memory for the shared-memory template ABI.
Its C imports use Odin's `env.o` environment marker; archive filenames are build
inputs rather than browser import namespaces. Function-pointer GOT relocations
are accepted only when this module defines the corresponding function. No C
backend function remains imported from another implementation.

Core installs the real existing host registry and Meter service. One permanent
AOT image has real code pins, protected origins, weak instance contexts and
accounting. Callback origins use the actual imported `__table_base` and a
verified `dylink.0` table size; a two-pass link checks the final interval. A
one-time direct handoff within the AOT image installs Core's stateless engine
allocator for Meter. No Odin allocator is added to the C host protocol, no fake
owner is installed, and native Meter backing policy remains unchanged.

The Core access gate owns an engine-backed temporary arena and restores its
outer marker after return marshalling. Nested calls retain their caller's
temporaries. Freestanding Odin's native default-temp guards are no-ops, so they
cannot implement this lifetime. Pointer-backed owner/producer/capsule tokens
retire exhausted16-bit generations on wasm32; native64 retains its u32 range.

`run.py` stages the standard addon/SDK fixture, performs an ordinary native
build/import and uses Godot's official Web exporter. It writes a plan unless
`--execute` is supplied. `browser.py --export-record ABS_REPORT --out NEW`
serves the immutable export with COOP/COEP and runs actual Chrome in an owned
profile. Use the installed official extension-capable threaded Web template.

The fixture checks C/Odin layouts, actual authored source destruction, visible
Native poses, canonical reencoding, malformed-load preservation, source-free
exact continuation, live allocations,20,000 getter calls,70,000 actual owner
cycles, out-of-image callback rejection, real creator death/stale-owner drop,
and successful engine/service/arena shutdown. Native compatibility and the
existing native-free Web smoke are separate evidence.

Release tests use explicit checks. Godot strips GDScript assertions in release
exports, including side-effecting calls inside `assert`; an early internal
ownership result was therefore unqualified. Its original report and the finding
are retained. The final fixture returns the actual completed cycle count and
performs weak-owner cleanup outside assertions. The browser independently checks
the returned values and actual shutdown marker. See [report.json](report.json).

This establishes the shared Web backend/SDK boundary. It does not qualify Replay
or Kit browser multiplayer, game performance, Internet reachability or
native/browser cross-play.

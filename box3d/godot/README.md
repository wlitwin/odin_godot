# Optional SDK host protocol

`protocol.h` and `protocol.odin` define the same C-shaped records. The protocol
package imports no native backend, framework, Godot objects, allocator or typeid.
Importing `Owner`/`Status` activates no native profile. Core's implementation is
in `host/`; the optional producer-side retained allocator is in `meter/`.

The public ABI is version 1: Owner 48 bytes, Data_Lease 24, Capsule 32 and
Service 200 on the supported 64-bit targets. `protocol_fingerprint()` covers
actual sizes, alignments and offsets; the independent C reference is in
`tests/box3d_modules/core/protocol_test.c`.

Runtime exports pure `odin_scripts_box3d_profile`, `odin_scripts_box3d_protocol`
and `odin_scripts_box3d_contract`, and an installation entry
`odin_scripts_box3d_install`. A native binding registers discovery/install with
`module_register`; optional adapters register pure realm installers with
`module_add_hook`. Install hooks configure guards/realms only; they must not
create resources or invoke authored code. Core validates before boot, creates a
producer record once its existing Script_Generation exists, then installs before
instances can use it. Hook installation publishes the module Service only after
all hooks succeed. Every opted-in SDK module must explicitly declare even
profile 0; older modules cannot evade admission by omitting the handshake.

`BOX3D_HOST_ENABLED=true` enables the Core service. Root's build/deployment code
supplies `BOX3D_NATIVE_LIBRARY`, copies the verified shared backend beside Core
as `libogb3.dylib`/`libogb3.so`, and supplies controlled consumer loader paths.
Core resolves that exact adjacent filename; it does not search a runtime
environment override. Scripts use `BOX3D_REQUIRE_DOMAIN=true` and the verified
`BOX3D_EXPECTED_BUILD=sha256:<64hex>` and
`BOX3D_EXPECTED_TARGET=sha256:<64hex>`. The explicit prefix prevents Odin command
line numeric inference from truncating hashes such as `9e41bb...`; comparison
strips only that prefix and still requires exactly 32 digest bytes. Discovery and binding
installation compare these compile expectations and the actual native cookie;
an older mapped ABI-compatible library cannot silently satisfy a new build.
The cookie and producer realm are process-local lifetime capabilities, never
Game, network, recovery or durable identity. Standalone/default native-free
framework behavior remains available without this service.

## Code, data and scene context

An Owner retains its existing SDK generation independently of its data context.
Its check/retain/drop functions point into stable Core. The consumer checks its
module-local realm before any typed object, allocator or type metadata access,
then calls Core's protected-origin check. A different producer or reload realm
requires a C capsule or canonical conversion, even when nominal types match.
Native-profile `script_of`/`script_any` also reject a raw typed userdata handoff
across producer generations; ordinary non-native targets keep their existing
behavior.

Data_Lease callbacks retain an actual managed heap/allocator context. They must
be paired, have atomic failure behavior, and belong to the originating loaded
code image (or the known stable Core same-producer Owner hook pair). They do not
make arbitrary raw pointers owned. Strict factories reject unsupported borrowed
allocators/users, validate exact declared context pointers or explicit retained
allocation-block aliases, and use the SDK meter for participating containers.
Source scene userdata and its subfields cannot be claimed by a Data_Lease; Core
checks their registered allocation spans before invoking retain callbacks.

`context_caps` contains MANAGED_DATA=1 plus WEAK_INSTANCE=2 or
INDEPENDENT_CONTEXT=4. READ=0 permits cached reads, clones and destruction under
the origin. EXECUTE=1 additionally requires the captured weak scene instance to
remain live. A weak declaration cannot retain raw self. Logical invalidation
precedes actual source free; `context_release` closes the physical span only
after its userdata allocation is freed. Detached weak owners retain a tombstone
until their final drop. New instance/reload contexts are bound before any new
setter/default/reload callback runs. Retained data and code can therefore support
cached operations after actual scene destruction while authored execution fails.

Capsule data stays opaque outside its producer. Creation validates and stores
the origin C dispatcher while the caller is protected. `Capsule.invoke` and
`Capsule.destroy` enter stable Core, acquire the existing execution gate and a
temporary generation pin, establish the origin, and invoke the whole typed
operation. That includes fields, events, allocator frees and accounting. The
producer callback returns into Core before the call pin and gate are released.
Last release schedules the existing writer-gate collector; no producer-local
leave-and-return wrapper substitutes for this outer boundary.

Operations 0 (destroy) and 1 (clone with Capsule_Clone_Args) are common. Other
operation argument records require the producer's separately agreed C-shaped
interface; no typed framework object/allocator/typeid crosses an opaque args
pointer. Wrong origin/thread and invalid handles reject before dispatch. A
valid data release is expected to succeed; if its atomic drop declines after a
payload destructor, Core retains a cleanup-only tombstone, denies reads and
retries only the final lease drop, never the freed payload destructor.

## Shared request and reservation accounting

Core uses the one native ledger. Fixed bounded Core registry storage is charged
once. Each producer has ONE aggregate LIVE plus remaining-reservation token;
category publishers report actual live bytes and monotonic successful HOST
requests. Forecast admission sizes are not observed live storage. Successful
requests remain counted after frees, reallocations or admission failure. The
native engine and snapshot-wrapper requested counters are observed once, and
all producer HOST requests participate in the cumulative operation observer.
Metadata/allocator table costs must also be charged. Covered SDK allocations
must not be counted again by old manual provider/Core estimates.

Each successful `budget_begin` returns a unique mark. A same-producer child
compares its declared bound with the outer ORIGINAL bound, shares the remaining
promise and adds no ticket. Actual cumulative requests consume that promise;
net-live differences never substitute. Another producer's allocation budget or
increasing account while one is active returns Unsupported before mutation.
Cached cross-producer reads remain allowed. An allocating A capsule clone under
caller B is allowed when B has no active allocation budget.

`budget_reconcile` never ends a mark. Exactly one deferred cleanup owns each
successful begin. `budget_end` accepts only the top unique mark; duplicates,
stale IDs and ending a parent while a child exists return InvalidHandle without
popping anything. A valid end returning Capacity still ends that mark and
releases its promise; clear the caller's mark and abort the candidate, never
retry the end or accidentally end its parent.

`legacy_extra(user,0,0,proposed_extra,out)` reconciles first. Within an active
budget, the proposed request must fit remaining and is already covered; the
result includes all registered LIVE plus remaining reservations once. Outside
a budget it additionally counts the unregistered extra. It excludes native
engine/wrapper bytes because the legacy native/alpha check adds those once.

An explicit current mark plus `implicit_C_reserve` excludes only the held
portion of that operation's promise, up to `min(implicit,remaining)`. Native C
still adds its FULL implicit reserve; any gap is conservative, never a skipped
check or another producer's stolen ticket. An ancestor and child cannot both
exclude an implicit reserve. For opaque custom recovery catalogs, read holds a
6 MiB operation bound but excludes only the guaranteed native 4 MiB staging
floor; C still checks actual DTO limit plus 4 MiB. A known exact configured DTO
limit permits its exact DTO+4 MiB exception. Write retains its 8 MiB operation
preflight and all original resource/semantic/codec validation.

Core uses its existing reader/writer gate and generation references. The alpha
host supports one main-thread caller; other threads return Unsupported before
native/typed owner use. Core shutdown refuses live native/typed owners and never
force-frees them. It closes the registry charge only after all producer/data
owners are gone. This service is not an allocator hard cap or recovery from the
native engine's fatal OOM boundary.

Actual Godot two-module/reload acceptance belongs to the coordinator. C/fake-gate
controls alone do not certify it. The separate cold editor-import failure in
Godot 4.7.1 is recorded with original-binary cold/warm controls and LLDB evidence;
it has no SDK workaround or accepted cold-import pass here. The declared macOS reference Gate B is recorded separately in
`docs/design/box3d/gate-b.md`; functional host tests alone do not establish CPU
or whole-application performance.

# Canonical solver recovery, format 3

The fixed-count measurements in this record describe the legacy qualification
profile. Current world capacities are selected through
[the shared capacity profile](../../docs/box3d/capacities.md); recorded timings and
artifacts are not reclassified by changing those settings.

The shared native codec encodes the complete admitted Box3D solver state as
explicit little-endian fields. It does not export the opaque local snapshot
image. Kit and Replay compose their own Game, Side, registered prediction
fields, completed observations, occurrences, tick/epoch and input identities
around these solver bytes. Their ordinary value-only packages remain native-free.

The contract is **same native build, target and declared catalog/profile**. A matching field grammar is not a claim of Mac/Linux exact-physics
compatibility. Historical Gate A v2 artifacts remain historical. Local normalized
solver comparison uses version 4 and owned local resources use version 2;
the recovery format has its own version 3. Earlier qualification reports retain
the versions and measurements they actually tested.

## Public ownership and limits

[recovery_codec.h](../native/recovery_codec.h) is authoritative. Odin
uses `Recovery_Config`, `Recovery_Asset`, `Recovery_Catalog`,
`Recovery_Identity`, `Recovery_Diagnostic`, and the `recovery_*` procedures in
[recovery.odin](../recovery.odin).

1. Start with `recovery_config_default()`. It supplies the actual embedded native
   build identity. A caller-supplied replacement identity is rejected.
2. Create a catalog from sorted, unique nonzero asset IDs. The catalog copies
   immutable definitions. Use `recovery_catalog_create` for primitives or
   `recovery_catalog_create_authored` with `Recovery_Authored_Asset` for hulls
   and meshes. Both produce identical identities and bytes for equivalent
   primitives. Equivalent geometry must share one ID. Clone explicitly and
   release every owner.
3. `recovery_write(catalog, snapshot, nil)` queries the exact size. NULL/zero is
   successful; a short output returns Capacity with the required size and leaves
   the output untouched. Neither query nor write consumes either owner.
4. `recovery_read(catalog, bytes, additional_owned_bytes)` returns a new owned,
   detached Snapshot only on success. Every failure leaves the output empty.
   The borrowed bytes, catalog and original world may then be destroyed.
5. Restore/open that image through the existing staged-world transaction.
   Decoding never selects or modifies a published execution.

Defaults come from [the shared capacity profile](../../docs/box3d/capacities.md).
Callers may lower limits, not exceed that build's limits. Sparse/free slots,
retained history, live objects and tree nodes have separate bounds. This solver
codec has no gameplay clock or timeline; adapter history and repair policies are
additional admission constraints.

The primitive convenience accepts Box, Sphere and Capsule assets. Box `a` is
positive half extents; Sphere `a` is its center; Capsule `a,b` are its endpoints.
Radius is positive for sphere/capsule. Dimensions/radius are at least 0.01 m,
coordinates and dimensions are finite and at most 32 m in magnitude, and unused
fields/reserved words are zero. Authored descriptors also support copied Hull
and static Mesh geometry, including externally baked heightfields. See
[the authoring contract](../authoring/API.md) for geometry validation.

Both constructors support all current joint families. The authored descriptor
ABI version `AUTHORING_ASSET_VERSION` is separate from the recovery format.
Recovery formats 1 and 2 are rejected. Primitive catalogs reserve only catalog
storage; hull/mesh construction also reserves geometry and staging storage.
Asset IDs identify geometry, not bodies or gameplay entities. Compounds and
multiple inline materials remain outside this recovery contract.

Precommit `recovery_world_admit(catalog, idle_world, external_bytes)` runs the
same full semantic verifier and scalar/count/asset/size walker directly on a
checked borrowed execution, returning the exact canonical byte count. It creates,
restores and steps no world and mutates no solver state. Temporary DTO checks
include external charges. Adapters capture this same execution and preserve the
trusted source image <= `RECOVERY_MAX_SOURCE_IMAGE_BYTES` gate before
publication. This admission path produces no transport bytes and bypasses none
of decoding's validation. Actual export still uses full `recovery_write`. An internal sizing callback may
reuse an exact required length produced by this complete admission for the same
immutable retained image/catalog. The actual fill still performs full Resource,
semantic, scalar/count, size and output validation with the 8 MiB reserve; no
returned transport bytes rely on a cached validation ticket alone.

Encoding uses disposable native scratch worlds and can require two spare world
slots. Before scratch creation, trusted resource preflight bounds the local
image to `RECOVERY_MAX_SOURCE_IMAGE_BYTES`, bounds body count, and checks retained
geometry against the immutable catalog; unknown geometry is rejected. A public world slot cannot
be substituted for missing history.

## Identity and bytes

All integer fields have explicit widths, little-endian order and two's-complement
signed interpretation. Booleans are exactly one byte, 0 or 1. Floats are IEEE
binary32 bits in little-endian order; there is no native padding, pointer,
`size_t`, enum-layout blob or raw struct on the wire. Collection counts are u32,
sparse slots are emitted in allocation-index order, and ordered free lists,
probe slots, sensor histories and pending queues retain their original order.

The 192-byte header is:

| Offset | Field |
| ---: | --- |
| 0 | Eight bytes `OGB3REC\0` |
| 8 | recovery format u32 = 3 |
| 12 | logical solver format u32 = 4 |
| 16 | header length u32 = 192 |
| 20 | section count u32 = 12 |
| 24 | profile u64 |
| 32 | complete wire length u64 |
| 40 | pinned runtime native fingerprint u64 |
| 48 | native build/target digest, 32 bytes |
| 80 | asset descriptor digest, 32 bytes |
| 112 | solver schema/limits digest, 32 bytes |
| 144 | SHA256 of bytes following the header, 32 bytes |
| 176 | additional native target descriptor u64 |
| 184 | eight reserved zero bytes |

The native build digest binds actual native source/header/patch/dependency
content, effective compiler/version/target/SDK/deployment configuration, build
configuration, FP/assert/SIMD compile options and the runtime private-ABI
fingerprint. CMake records content-relative paths and refreshes on source edits.
The asset digest hashes `ogb3-authored-assets-v2\0` followed by each sorted
40-byte base descriptor (id/kind, seven binary32 values, reserved zero), two u32
vertex/triangle counts, and copied geometry payloads. Primitive counts are zero.
This algorithm is shared by both constructors; no API choice enters identity. The solver
schema binds the generated field visitor digest, manual format rules and all
configured limits. Debug and Release are different build identities.

Each section starts with `{tag:u16, version:u16=1, records:u32=1,
payload_bytes:u64}`. Tags must appear once in ascending order. Payloads are:

| Tag | Fields in stream order |
| ---: | --- |
| 1 | world configuration, fixed-step inverse times, step/split IDs, capacity history, flags |
| 2 | six ID pools: next index and ordered free lists |
| 3 | solver sets and ordered body states/sims, joints, contacts and island sims |
| 4 | body sparse slots, live flags, generations and scalar topology |
| 5 | shape sparse slots, live flags, generations, scalar shape/material and trusted asset ID |
| 6 | contact sparse slots, full u32 generations, scalar topology/cache, manifolds and active SAT/GJK cache |
| 7 | joint sparse slots, generations and scalar topology |
| 8 | sensors with hits and the two retained overlap histories |
| 9 | islands and ordered body/contact/joint membership |
| 10 | all three trees, free nodes/order, moves/bitsets and contact-pair hash probe slots |
| 11 | constraint graph color bitsets, joint sims, convex contacts and contact specifications |
| 12 | ordered future sensor/contact end queues as world-independent allocation keys |

The exact scalar order is the explicit bidirectional visitor in
[recovery_codec.c](../native/recovery_codec.c), generated from the
audited logical dump visitor by
[generate_fields.py](../../tests/box3d_recovery/generate_fields.py).
`--check` rejects drift and checks the scalar schema digest. Variable collections,
active union dispatch and geometry IDs are explicit manual visitors. Inactive
union/pointer fields and free-slot payload are omitted; free-slot generations
remain. Prepared cache indices which this pin overwrites before use are retained
as scalar history without being mistaken for live allocation references.

Completed native output buffers, body move-output links, names, userData, host
callbacks, scratch arenas, mutexes and allocator capacities are excluded. Game
rebinding is explicit. Both adapters separately preserve completed sensor
observations needed within a tick. The current future end queue is included,
including retired generations after slot reuse; it is not cleared as completed
output. Logical dump4 still includes tree node capacity, so an undersized tree
is rejected rather than silently inflated. Sensor array capacities are not
logical state; reconstructed/locally restored sensors receive the constructor's
hits=4 and overlap=16 minimum storage to satisfy the pinned zero-count append
implementation without null-pointer arithmetic.

## Validation and trusted construction

The header length, version, build/target/profile/assets/schema, reserved bytes,
section framing and checksum are checked first. A checksum is integrity checking,
not authentication or permission to load a native image.

Parsing allocates a bounded, zeroed DTO ledger. It reads explicit fields; the
private C structs used as internal DTO containers are never copied from the
wire. Every collection has a profile limit before multiplication/allocation.
Unknown tags, trailing bytes, illegal boolean/enum/union values and nonfinite
floats reject. Ordinary scalar magnitude is at most 1e12, with tighter world,
pose, velocity/material checks. Exact finite `FLT_MAX` is allowed only for the
pinned threshold/default classes (joint force/torque thresholds and classified
SAT/minExtent sentinels); a generic magnitude relaxation is not used. Inverse
times are compared to the actual binary32 fixed 1/60 s, four-substep calculation.

Semantic verification checks the complete sparse/live/free partition, duplicate
ownership, reciprocal solver/graph slots, linked-list bounds/cycles/counts,
body/shape/contact/joint references, distinct enabled contact endpoints with a
dynamic endpoint, touching manifold/island agreement, hinge settings and local
frames, sensor ordering, island membership, tree reachability/free chains and
heights, shape proxy/category/AABB ownership, permitted dirty dynamic/kinematic
ancestors, moved bitset coverage, pair hashes/probe reachability and exact contact
pairs, graph dynamic conflict bits including omitted high bits, active SAT
face/vertex/twin-edge bounds, GJK indices, and bounded retired pending keys.
Static enlarged roots, zero-capacity trees, invalid active SAT cache indices and
empty graph membership bitsets for used dynamic bodies reject before assembly.

A verified DTO builds a detached ledger of native allocations against a valid
empty shell. Arrays, copied trusted hull database references and manifolds remain
ledger-owned until every allocation and operational reference is ready. Any
pre-assembly failure unwinds those pieces against their valid owners, then
normally destroys the still-empty shell. The final assembly only transfers
complete storage; it has no fallible operation halfway through a published
world. The complete candidate is re-encoded and compared byte-for-byte to the
input. Only then does normal trusted snapshot capture create the returned local
Resource2 owner. Failure after assembly destroys a fully valid private candidate.
No arbitrary-byte destructive loader or wire-derived local seal is used.

## Memory and failure boundary

`snapshot_info` returns `Snapshot_Info{metrics, storage}` after one identical
full Resource seal and structural validation. It replaces paired storage/metrics
reads at adapter admission; the existing getters retain their semantics. Every
output pointer is required in C and failures leave all outputs unchanged. Clones
and source-world destruction preserve logical image metrics. Native storage
charges can increase when standalone P2 compound resources materialize lazy
geometry; process-global engine/wrapper counters remain authoritative. The
primitive recovery profile contains no compounds.

`snapshot_capture_info` and `snapshot_clone_info` return
`(Snapshot, Snapshot_Info, Status)`. They call the unchanged existing constructor
into a local owner, retaining its full validation, then copy pure metadata before
exposing that owner. `recovery_read_info` follows the same pattern around the
unchanged complete decoder; its diagnostic variant returns a fourth Diagnostic.
All native output pointers are checked first; failures leave owner=NULL and
metadata untouched. These paths remove a subsequent getter call, not a seal,
structural, allocation, semantic or canonical re-encode check. Arbitrary-resource
getters, clone, dump and restore validation remain unchanged.

The owned-resource FNV-1a implementation inspects an unaligned-safe eight-byte
word with `memcpy`. Eight zero bytes multiply the running value by
`0x1efac7090aef4a21` (FNV prime^8 modulo 2^64); other words fold every byte.
Independent bytewise vectors cover every length 0..1024, every offset 0..15,
zero/dense/sparse/random data and four seed families (262,400 comparisons), plus
standard golden values. Hash outputs and all format/resource versions remain
identical; no bytes or integrity checks are omitted.

All codec catalogs, DTO blocks and verification buffers use the existing owned
snapshot accounting domain. Native arrays/hulls/manifolds use the one engine
allocation domain. Caller/framework byte buffers and metadata are charged via
`additional_owned_bytes` and the sibling admission helpers. There is no hidden
mutable runtime pointer.

`RECOVERY_WRITE_RESERVE_BYTES` is conservative 8 MiB requested-byte headroom for
the supported profile, including DTO work. Adapters must preflight engine +
wrapper + all external live charges + this reserve before both query and write,
and check totals afterwards. Decode preflights configured DTO ceiling plus
4 MiB native staging, applies external charges during DTO/native/re-encode
allocation checks and checks final resource admission. A Capacity/OOM error
leaves no returned owner and no publication change. Allocation-header/alignment
and framework overhead are separately measured; requested-byte admission is not
an allocator-enforced hard cap.

Wrapper failures and every native-ledger construction boundary are fallible and
tested. Actual pinned `b3Alloc` exhaustion remains a fatal native assertion;
these tests inject failures *before* those native calls and do not claim recovery
from engine allocator OOM. Global native calls remain single-caller/nonreentrant.
A later real Godot deployment must share one loaded native DSO across adapters,
not link independent engine domains into modules.

## Executable evidence

[tests/box3d_recovery](../../tests/box3d_recovery) contains native grammar-correct
semantic controls, independently rechecksummed scalar mutations, truncation and
identity/finite/budget controls, wrapper/write/native-ledger failure sweeps,
unchanged-publication and zero-owner checks; a separate lifecycle suite exercises
all three primitive asset families, defaults, source destruction, slot reuse, pending ends
exactly once and longer suffix equality. An independent Python parser checks LE
framing, SHA256, catalog identity, fixed defaults and ID-pool order. Odin's actual
32-body fixture exercises motor/limits, contacts, sensor deletion, sleep/wake,
detached catalog/world lifetime, exact full-dump/re-encode and resimulation.

Historical per-target/configuration artifacts, sanitizer results and the separate Kit
and Replay integration results are recorded in the P3.4 task report. Passing
limited fuzzing and bounded local/network fixtures is not a general untrusted
geometry importer, portable save-game certification or mixed-target lockstep
claim.

The historical native functional matrix did not certify the full adapter CPU budget.
Whole-call depth-eight complete recovery remains above 4 ms in the recorded Kit
and Replay runs; this is an explicit UNMET GateB/P4.4 requirement. The native
codec's functional closure does not waive it or claim the full goal achieved.

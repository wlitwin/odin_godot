Test-only Kit checkpoint capsule fixture
======================================

Import `kf "godot:tests/box3d_modules/kit/fixture"` into the producer's
existing class. No Node class is declared by this package. Invoke
`kf.create(&capsule, &info)` inside a Core-protected originating instance
callback. The optional native SDK build installs the domain service and Kit
realm before this call. Nil services, borrowed custom default allocator data
and unavailable weak instance contexts reject before publication.

`create` is a C procedure returning `bg.Status`. Its outputs are unchanged on
failure. The successful capsule owns a tick-4 whole-world checkpoint with typed
Side, registered pose/tick fields and a native box body. Before returning, the
fixture detaches physics, destroys the Lane and frees five separate heap
allocations: source, Lane, Session, provider Instance and proxy. Its independent
allocator context survives only through actual Core-owned Data_Lease references.
There are no borrowed source FX or user callbacks in this checkpoint.

Only `bg.Capsule` (32 bytes) crosses producer realms. Move it once; a byte copy
is not a clone. The root test's process-local PackedByteArray transport is not
a network or persistent pointer format. Do not pass World_Checkpoint, Side,
typeid, slices, allocators or provider pointers to the receiving module.

The native library must be the one SDK-installed shared DSO. The focused local
registry test also permits a static archive as unit evidence; this establishes
neither module reload nor actual Godot loader acceptance.

All records below use the platform C ABI on the tested 64-bit targets:

| Operation | Invocation / C arguments |
| --- | --- |
| Factory | `kf.create(Capsule *out, Factory_Info *info) -> i32` |
| Clone (1) | `capsule.invoke(user, 1, &bg.Capsule_Clone_Args{out=&clone})`; args are one pointer, 8 bytes |
| Dump (16) | `p.SDK_Checkpoint_Dump_Args{out:u8*, capacity:u64, required:u64*}`, offsets 0/8/16, 24 bytes |
| Body (17) | `p.SDK_Checkpoint_Body_Args{key:u64, state:b.Body_State*}`, offsets 0/8, 16 bytes |
| Key-valid (18) | Same body args, key checked; state pointer is unused |
| Destroy | `capsule.destroy(capsule.user)`; operation 0 cannot be sent to invoke |

Dump nil output/capacity zero queries the exact normalized dump-3 length.
Insufficient capacity returns Capacity and does not write partial bytes. Body
output is the authoritative native 80-byte Body_State POD; read its world-
independent key and pose, never reinterpret it as a live host-world Body ID.
Invalid keys preserve the body output. All origin casts and callbacks occur
inside Core's stable outer capsule trampoline, including the whole checkpoint
and allocator destructor and the return from producer code. Caller B needs no
A realm install to invoke a Core capsule. A direct typed checkpoint operation
from a foreign realm is unsupported.

Factory_Info is 64 bytes: `size:u32, version:u32`, then seven u64 fields at
offsets 8/16/24/32/40/48/56: `key, tick, dump_bytes, source_objects_live,
managed_contexts_live, host_live, host_requested`. Version is 1. Success has
`tick=4` and `source_objects_live=0`. `kf.stats(Stats*) -> i32` copies the last
four counts (32 bytes) without an allocation; after the final capsule releases,
all live counts must be zero. Requested is cumulative, not expected to be zero.

The fixture now uses the production pure `box3d/godot/meter` allocator,
installed before the Lane, Session, provider and proxy are constructed. Its
charged fixed context/table metadata and successful requests include every
covered allocation, including later freed/reallocated work. One Core category
receives the actual observed sum; the fixture does not also publish manual
provider/Core estimates for those bytes. The metadata/API unit and actual
registry fixture tests are evidence for this composition; production Kit's
remaining SDK admission integration is separate. There are no raw FX callback
users in this fixture. The backing heap allocator has no borrowed data; code
is retained by the stable owner/capsule. Data_Lease callbacks point into the
origin image and Core must validate their actual origin (the unit test uses
an explicit fake procedure validator; actual Godot Core uses dladdr).

The root runner should move the capsule to B, free A and request reload before
B calls clone/body/dump/destroy. A retained checkpoint intentionally pins the
old producing generation. Only after the last clone is released may Core collect
it. Reload and instance destruction are separate events: neither grants access
to a stale weak source context, while these independent cached reads remain valid.

The focused unit suite is now in `fixture/tests/`; production import of this
fixture includes neither its fake Host registry nor core:testing. The suite also
checks strict SDK codec ownership/descriptor copying, missing/wrong owner
rejection before allocation, a primitive 32-body world through H128/history wrap,
an eight-tick local transactional repair, failed-candidate and unbound-FX
preservation, a second producer's actual 16 MiB allocation forcing resource
rejection, and complete canonical export/decode callbacks at frame 0. Network
attachment is explicitly detached before the local repair so the authority's
confirmed frontier is preserved. This is not an additional impaired Session or
whole-wire correction throughput claim; P3 transport tests remain separate.

Raw normal-call samples and local-repair whole-call samples are observations.
The whole-wire 4 ms Gate B requirement remains UNMET. The suite reports sampled
actual live bytes, sampled live-plus-reservation admission, sampled reservation,
and the native ledger's committed admission peak separately. Its 22 MiB parent
promise for an eight-tick local operation is `2 MiB * (8 + 3)`; 2 MiB remains a
primitive allowance. Core consumes actual Native/Wrapper/HOST cumulative requests
and closes the exact unique child mark once. It does not reject by clock.

SDK application usage requires `sdk_context_create` before container construction,
its Meter allocator for covered Session/Lane/schema/container allocations, and
separate `sdk_user_owner_create` bindings for provider, authored callback user,
network/codec contexts and a nonnull independent FX sink. An allocator-context
lease does not claim those different pointers. Fixed registered proxies and
Session/Lane storage remain caller-owned until detach/destroy. A raw Scene
instance or arbitrary external callback cannot be made rollback-owned by a code
pin. FX callbacks must use the explicit independent sink and may not dereference
an expired Lane/scene. Tear down Network then owned codecs before freeing their
source container; attempting codec destruction while borrowed returns Busy.

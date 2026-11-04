# Audited alignment fixes

Both additions were explicitly approved by coordinator t12 during P1.3.
The native build owner applies them only in a derived source tree after checking
pristine Box3D `d421e45c828f6f853a145f726f0b9425d31146eb`, and records base,
patch and resulting source hashes in the dependency/build manifests. The Phase 0
scratch source remains unchanged. Original MIT notices remain intact.

`block_allocator.c` accepts any element size at least `sizeof(void*)`; an element
stride need not preserve pointer alignment. On macOS arm64, a manifold is 268
bytes and a pointer requires eight-byte alignment. The unpatched allocator's
`*(void**)element = allocator->freeList` at line 88 produced a UBSan misaligned
store. The matching free-list pop also dereferenced a potentially misaligned
`void**`. The observed stack was:

```text
b3FreeElement (block_allocator.c:88)
b3FreeManifolds (physics_world.h:347)
b3ComputeConvexManifold (contact.c:540)
b3UpdateConvexContact (contact.c:619)
b3UpdateContact (contact.c:845)
b3CollideTask (physics_world.c:740)
b3ParallelForTrampoline -> b3DefaultAddTaskFcn -> b3ParallelFor
b3Collide -> b3World_Step -> ogb3_world_step_fixed
mutation_controls (lifecycle.c)
```

The minimal fix copies the pointer representation with `memcpy` on both load
and store. The byte stride, pointer representation and free-list order remain
unchanged. A direct twelve-byte-stride regression exercises both operations.

| `block_allocator_alignment.patch` provenance | SHA-256 |
| --- | --- |
| Pristine `src/block_allocator.c` | `0e7f3cf86b6ae33d4650853681f409d2a9f9259801dbeb56914f3da0a376fd60` |
| Patch | `4e1c5c3f567cfbc06987123bc3528a1fe546493faf6db4d4d43b3ac878c90677` |
| Result | `80a59b74039ba41ccc805fc745c3dab9ef1020ca7722dc5957a67747b0d672b4` |

With that fix applied, full sanitizer execution found a second error: a baked
compound's shared hull pointer was four modulo eight. `b3CreateCompound` places
a 36-byte hull-instance array before its packed shared hull blobs, without
aligning each blob. Hull and mesh headers contain 64-bit fields and require
eight-byte alignment. The first observed access was in the dump, which received
this pointer from the engine's `b3GetCompoundChild`:

```text
n_b3HullData (state_dump.c:299): member access within misaligned address
hull -> compound -> geometry -> dump_world -> ogb3_state_dump
ogb3_snapshot_capture -> geometry_lifetime
```

The compound fix rounds the running byte count to `_Alignof(b3HullData)` or
`_Alignof(b3MeshData)` before every shared blob. Stored offsets account for the
gaps, and the existing whole-allocation zero fill initializes them. Instance
arrays and geometry semantics retain their existing representations. Odd/even
one/two-instance cases exercise all four child families, two distinct meshes
and hulls, typed alignment checks, capture/restore, asset destruction and contacts.

| `compound_geometry_alignment.patch` provenance | SHA-256 |
| --- | --- |
| Pristine `src/compound.c` | `e6489620692ac63874376ff84aff5a66e6c5db70e9746a56a8d737ccbe840332` |
| Patch | `d81f1b8d8488c64d4ca9d3044d64a89cebe78084d2c39b890aedcda8cba531d1` |
| Result | `7ab1c5486a092b0f6a45181003b9ee1d14d4a6db67f39632ee218f8d08cea5cc` |

Full `-fsanitize=address,undefined -fno-omit-frame-pointer` execution passes after
both fixes, with no alignment or undefined-behavior suppression. The CTest
static/shared API and lifecycle tests pass 3/3. Original unpatched UBSan failure
and corrected logs are retained in the P1.3 scratch report directory. This
records observed local arm64 evidence, not every target's sanitizer result.

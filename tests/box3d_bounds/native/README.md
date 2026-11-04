Two source-only Native profile edge groups use the current public format-3
catalog, real worlds, detached snapshots, canonical encoding/decoding and full
normalized solver dumps. Root schedules compilation and execution.

- Body edge: actual35 bodies/35 shapes pass; the detached candidate's36th body
  leaves35 shapes and must fail admission and canonical export with Capacity.
- Shape edge: actual1 body/35 shapes pass; its36th shape leaves1 body and must
  fail the same boundaries. Static bodies isolate these counts from the separate
  initial-dynamic, contact, joint and sensor limits.

`admitted_capture` is explicitly a **test caller composition** of public
`ogb3_recovery_world_admit` followed by `ogb3_snapshot_capture`. Its refused owned
output must be empty. Raw factories and raw capture intentionally support larger
trusted worlds; the tests do not assert a factory cap. The valid public encoder
cannot generate a36-count profile packet, so no fake canonical packet/private
parser is introduced and no over-cap wire-decode claim is made.

The candidate is intentionally mutated before rejection. Each failed operation
must preserve that post-mutation candidate and an independently published valid
world, emit no canonical bytes, and balance actual Native/wrapper live bytes.
The earlier detached valid image must still encode identically. Removing only
the extra object must permit valid admission, exact canonical roundtrip, explicit
publication and matching fixed-step continuation. Final typed teardown returns
Native/wrapper live bytes to the measured zero baseline. Intentional pool growth
is not mistaken for a leak, and these are solver-only controls, not Game/Side/
five-part, SDK-owner, transport, timing or whole-P6.3 acceptance evidence.

Existing malformed/rechecksummed384-mutation, semantic/reference, allocation-
failure and lifetime controls remain in `tests/box3d_recovery/native_test.c`.
Authored Hull/Mesh descriptors and caches remain covered by
`tests/box3d_authoring/native/authoring_test.c`; motion unions, malformed settings,
queries and movers by `tests/box3d_motion/native/motion_test.c`. This test does not
duplicate those corpora or change their assertions, Native sources or limits.

Root can compile this standalone source with the current verified Native archive:

```sh
clang -std=c11 -UNDEBUG -fno-fast-math -ffp-contract=off \
  -Ibox3d/native tests/box3d_bounds/native/profile_edges.c \
  /absolute/current/Release/libogb3.a -lm -lpthread \
  -o /absolute/fresh-output/profile_edges
```

Use the actual target compiler/library and existing source/binary fences. Running
the resulting executable selects exactly these two groups; no source agent runs
the compiler, tests or a Native build.

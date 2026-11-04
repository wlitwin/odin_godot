# Independent framework transaction tests

These tests use the actual Kit lane and existing Replay Timeline with the same
pointer-free game rules and independently owned native worlds. They are separate
from the provider authors' own suites.

Run with a coherent native archive:

```sh
nix develop --command bash tests/box3d_framework/run.sh \
  /absolute/libogb3.a /tmp/framework-debug Debug
```

Use the matching optimized archive and `Release` for the optimized gate.
The test runner must use one thread because the optional native backend currently
has one caller and one allocator/world domain.

Coverage includes world-independent entity/body maps; spawn/removal/impulses;
typed game state plus exact normalized solver bytes compared against an
independently stepping world; corrected input suffixes; rejected native/game/event
work; registered Kit prediction fields and post-commit effects; history eviction;
complete checkpoint survival after source runtime/world destruction; and
readonly cached poses. Pure-core controls also reject game-only physics truth and
stale borrowed execution after Timeline storage is destroyed and reused.

`pending_end_probe.c` is a public-operation counterexample for post-step sensor
destruction: the next-step end event must match an untouched reference after
capture/restore. Historical v2 images lost it. Current snapshots must preserve
future pending sensor/contact ends while clearing already completed output
buffers. Provider suites add the analogous network action/savepoint cases.

This gate does not certify a network codec, mixed-target solver agreement,
Godot-module shared-library deployment, or production frame budgets. The alpha
supports only its explicit measured workload/ownership constraints. Additional
integration cost and staging memory are recorded in the validation report.

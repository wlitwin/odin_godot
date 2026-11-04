# Replay full-canonical Gate B CPU probe (in development)

Test-only, actual Godot Core/SDK/Meter and one Native DSO. This is an offline
serialized-packet CPU fixture over existing public Link/Server/Client/Timeline;
it does not establish the Root-owned independent ENet soak or Gate B acceptance.

`GATE_B_FIXTURE=dense|common` chooses distinct workloads: the preserved dense
32 boxes plus extra sphere reference, or the production common two spheres and
30 crates plus extra capsule. References141/122 contacts are not fabricated
sample counts. Initial32/H128/eligible total8 and global64MiB stay unchanged.

Default timing mode is functional-only: no new clock reads/SAMPLE records.
Profiling is forbidden until Root grants an exclusive window. In profile mode,
the GDScript caller's1us clock brackets Node.call BEFORE actual Core entry and
AFTER complete return. Inside is public Link ingress, Client receive/decode,
Native read/build/reencode, typed decode, staged8revision/full paired check,
publication/journal consumption and mandatory operation cleanup. Rendering and
separate diagnostic output/oracle are outside; required work cannot move there.
Shared exact JSON schema: ../shared/records-v1.md.

Normal operations are separate streams selected with
`--operation client_prediction_send` or
`--operation authority_step_requested_canonical` (dense fixture only, hooks off).
The former advances159->160 with confirmed152 using public Link/Client pumps,
one public prediction step and actual typed Input send. The latter advances an
authority159->160 and services a real correlated Physics_Request160 so complete
canonical serialization and real Sent chunk copies remain inside its boundary.
It is an offline request-egress composite, not live scene snapshot cadence.
Both use independent public-runner full-state oracles with H128 runtimes retired
sequentially. Their actual step counters are unavailable/null; positive public
step, actual `Timeline.external.require_step`, and committed tick delta1 are
reported explicitly. Never pool their19-sample distributions or relabel replay
counters as normal steps. Functional mode stays clock/SAMPLE-free; every later
timing run still requires Root's explicit exclusive grant.

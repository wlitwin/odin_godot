# P4.4 initial source/boundary audit (read-only)

Root task t_6d1ea94bc14540f1 is working as box3d-gate-b/t12, revision7 and
supplied claim verified. This helper owns shared/ +audit/ TEST ONLY; no claim,
production change, optimization or timing run was made.

## Workload parity

The existing dense fixture is tests/replay_physics_net/fixture/fixture.odin,
profile504859534e455431, primitive floor Box(7,1,7), sensor Box(1.5,1,1.5),
32dynamic Box(.25,.25,.25), extra Sphere(.25), grid placement/hinge at body0.
Kit's tests/kit_box3d_net/fixture.odin wraps that world but uses different typed
Side/control/action callbacks. Profile ID alone therefore does not prove equal
control schedule, Side schema or measured correction workload.

The current examples/box3d_common fixture is profile534c494345503031,
2dynamic spheres +30crates, extra capsule, damping.5 and a different hinge/pose
layout. Its observed contact reference about122 is distinct from dense141.
Both remain required labelled profiles; never pool samples or rename one into
the other. Bind assets/placement/hinge/inputs/schedule/seed/source hashes and
actual measured counts. A run-level peak35 does not prove every correction had35
bodies/141contacts; retain per-sample counts and labelled peak scope.
The historical dense trajectory is Spawn40/41, Remove95, Motor115, target160;
its extra sphere is already gone at160. The common trajectory removes the extra
capsule at56. Keep those exact trajectories, not a new spawn near the measured
eight-tick window. A future max35-active repair would need a distinct descriptor.

## Historical timer boundaries

The old tests/kit_box3d_net/envelope_test.odin times lane_frame with time.tick_now
and also prints work.correction_latest_ns. Those are distinct boundaries. The
nilOwner fixture pumps copied packets directly through Session; it is not an
actual Godot Core/one-DSO/Meter/outer-return measurement.

The old Replay native/profile_test.odin times net.client_pump after replaying
saved public protocol packets. It includes required checks in that pump but
then captures/complete_views/signs the independent final checkpoint AFTER its
wall timer. It also does not include actual Core return or public Link work if
packets are placed above Link. Preserve its raw result as a diagnostic baseline;
do not call it the new full boundary or silently hide the postcheck. The current
Gate B whole operation must include every declared required comparison and
cleanup; rendering/diagnostic serialization may occur after return.

Real Host registry with fakeCore hooks is valuable ownership evidence but lacks
actual Core loader/generation/ABI/return cost. Keep it separate from nilOwner
and actualCoreSDK. ActualCore test methods can be timed by a GDScript caller
through the full return without production timing hooks.

## Long-soak evidence boundaries

Short runner currently hard-fails at MAX_FRAMES2048 and MAX_LOG64MiB; it drains
rather than silently blocking a failed process. Do not merely enlarge the caps
or truncate old frames while declaring a long pass. EndpointEvidence also keeps
unbounded accepted/predicted/actions/effects/status arrays for a short case.
Replay exports every retained authority tick; Kit currently exports30-tick
anchors. A long gate must predeclare complete comparison cadence and coverage,
not claim all ticks when only anchors exist.

Kit example FX_Sink observed/delivered arrays are fixed8192 entries. No clearing
is authorized here. Predeclare a duration/event bound that cannot overflow, or
request a narrow acknowledged rolling-observation hook from the owner. A reset
must never silently erase already-delivered duplicate detection.

Proposed controller-only rolling design:

1. Fixed hot H128 plus transport-lag allowance per actor; compare complete5parts
   only matching immutable identity/epoch/tick. Missing required match before
   eviction is a HOLD/FAIL, never live-world substitution.
2. After byte comparison, atomically seal a bounded segment containing frame
   signature/part lengths+SHA, source/process scope, actual comparison receipt,
   accepted/predicted input window, decisions, actual FX phases+payloads and
   delivery/consumption watermark. A hash chain binds segment order/counters.
   Declare a finite total disk budget/archive policy before execution; no silent
   history loss. If raw matched bytes are retired, explicitly distinguish sealed
   comparison receipts from independently replayable raw bytes.
3. Keep actual effect settlement IDs globally unique across the entire epoch/run
   in an indexed on-disk ledger, not just the hot window. Preserve full payload
   and Begin/Update/Cancel/Confirm lifecycle. Expected authority occurrences are
   separate from ACTUAL delivered journal/postcommit observations. Late old IDs
   must still be detected after H128 rotation.
4. Before any resync can hide a mismatch, atomically preserve first full expected
   and actual5parts, signatures, actual accepted/predicted windows, scope and
   actual repair depth/sequence. An out-of-band comparison has from=to=tick,
   depth0 and explicit unavailable sequence, not invented active rewind context.
5. Log packet/socket writes as writes, not endpoint consumption. Only actual
   endpoint receipt/commit/ledger acknowledgments allow safe retirement. Finish
   drains tails and verifies actual natural exits, real metrics and unmatched0.

Root owns the actual soak/controller/source-hook decision. This note is a plan,
not implementation or runtime acceptance. No change to any production ring,
profile cap, clock, reliable contract, journal or Native ABI is proposed here.

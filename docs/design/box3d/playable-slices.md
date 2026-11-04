# Matching Kit and Replay slices

Both authored Godot projects build with the shared native
backend and use their existing accepted-input session/runtime:

| Project | Scene | Runtime |
| --- | --- | --- |
| [Kit](../../../examples/kit_box3d/project.godot) | `kit_box3d.tscn` | Kit Session + Lane |
| [Replay](../../../examples/replay_box3d/project.godot) | `slice.tscn` | Replay Session + Server/Client + Timeline |

The functional scenarios pass actual macOS Godot/ENet tests, including Host +
Client, observer, dedicated authority with two clients, and client process
teardown/rejoin. Current 32-dynamic-body pairs confirm Kit ticks 0–240 at eight
complete-state anchors and Replay ticks 1–241 at 118 matching checkpoints. Both
exercise all six action kinds, the conflicting Spawn predicate, published input
provenance, confirmed effect payloads, and clean process/owner teardown. The
requested-memory envelope stays below 64 MiB; this is not an RSS limit.

Real GUI input moves both players and spawns visible objects. Presentation reads
owned cached poses and uses ordinary visual proxies. Exact reports, source and
artifact identities, prior failures and limits are recorded in
[the functional report](../../../tests/box3d_slices/report.json). The current
scene observations are macOS evidence; the earlier cross-platform backend/SDK
matrix is a separate prerequisite. Whole-call 4 ms, long impairment soak and
Phase 4 Gate B remain unmet, and later phases are not performance-accepted.

## Build once, launch separate processes

From the repository root, enter the development environment and build a coherent
native library. Keep the shared-library input exported for every SDK build:

```sh
nix develop
bash build/build_box3d.sh Release /tmp/box3d-slice-native
case "$(uname -s)" in
  Darwin) ext=dylib ;;
  Linux) ext=so ;;
esac
export BOX3D_NATIVE_LIBRARY="/tmp/box3d-slice-native/build/Release/libogb3.$ext"
bash build/build_scripts.sh examples/kit_box3d
bash build/build_scripts.sh examples/replay_box3d
```

Use the same build, seed, body count and port for each pair. For example, start
Kit's host in one terminal, then its client in another development shell:

```sh
env -u ODIN_SCRIPTS_DLL B3_ROLE=host B3_PORT=49652 B3_SEED=1 B3_BODIES=4 B3_TICKS=240 \
  "$GODOT" --headless --max-fps 60 --path examples/kit_box3d
env -u ODIN_SCRIPTS_DLL B3_ROLE=client B3_PORT=49652 B3_SEED=1 B3_BODIES=4 B3_TICKS=240 \
  "$GODOT" --headless --max-fps 60 --path examples/kit_box3d
```

Use `examples/replay_box3d` and a different port for Replay. Omit `--headless`
and set `B3_SCRIPTED=0 B3_TICKS=0` for live controls without an automatic stop.
Use separate writable project copies for simultaneous GUI actors; the automated
GUI proof used isolated imported caches and serial renderer startup. Earlier
shared-cache shader errors are preserved; no engine/cache root-cause fix is
claimed. See each example README for keys, roles and output settings.

The build helper deploys one verified `libogb3` beside each project's Core,
records actual source/build/target hashes and prepares first-start extension
discovery. The unchanged-engine cold-import limitation and module ownership
policy are described in [runtime-deployment.md](runtime-deployment.md).

## Shared rules, separate adapters

[box3d_common](../../../examples/box3d_common/README.md) defines the same five
primitive assets, pointer-free game state and intent rules. The two players push
a shared crate, with a motorized hinge, one sensor and deterministic capsule
spawn/removal. Sleep, wake and query actions are explicit. Four- and 32-dynamic
body layouts are separate measured cases; the small case does not establish the
32-body/H128/eight-tick resource or CPU envelope.

Each framework retains its own session, accepted history, staging and effects.
The common rule order is pre-step controls, exactly one existing fixed step,
copied sensor outputs, then actions in semantic seat order. This preserves
Replay's existing action/savepoint order and gives both adapters post-step
removal with a next-tick pending end. Retired shape keys retain game lifetime
identity until that end is consumed. Rendering uses owned cached body states;
visual nodes do not act as a second rigid-body solver.

Kit uses its existing tick-stamped class-1 input stream. Replay uses its public
Receipt action policy uniformly across roles. Logs distinguish requested,
predicted/submitted and authority execution ticks; corresponding button intents
do not imply identical execution ticks or cross-framework wire compatibility.

Semantic seats 1/2 are distinct from transport peer IDs. The two player mappings
are frozen before full Welcome; observers have no input driver. Replay's
membership bootstrap currently produces Welcome baseline 1; Kit's baseline is
0. Logs record the actual baseline and scenario target. They are not fabricated
common-history ticks, nor a claim that the two framework wire formats interoperate.

## Independent evidence contract

The actual-process harness uses `B3_ROLE`, `B3_PORT`, `B3_ADDRESS`, `B3_SEED`,
`B3_BODIES`, `B3_TICKS` and `B3_OUTPUT`. Ready means complete truth has arrived,
not merely that an ENet socket opened. Each endpoint writes the complete
signature and all five canonical parts at retained confirmed anchors. Comparisons
use the same epoch/tick within a sibling/build/target. No process-local pointer,
domain cookie, pose-only digest or speculative head is used as physics agreement.

Accepted input/provenance and applied action verdicts come from published history.
Effect evidence comes from actual deliveries with stable IDs, payload and phase;
speculative Begin plus later Confirm is not a duplicate committed effect. End-of-
run success requires actual target-confirmed acknowledgement and drained protocol
work, successful process exits, and owner/native/Meter cleanup. A fixed wall-time
grace period cannot establish remote consumption.

The tests also preserve rejected input/resource publication and canonical reset
evidence. A bounded FIFO fixes completed Kit checkpoints conflicting with the
next transfer during a packet burst; decoding and publication remain in the
existing frame phase. Replay restores its existing held prediction lead after
a validated receive-time catch-up so ongoing snapshots cannot starve fresh
control sampling. Both fixes have failed-before public regressions and cleanup
checks; no wire version or deterministic window was enlarged.

Managed SDK Room/bundle, non-ENet transports, Solo and cross-role
takeover/rejoin entry points reject unsupported use before effects. Ordinary
fresh-client rejoin to the same authority and owned archive/redirect paths have
separate evidence; this does not establish HA migration. P4.3 owns reusable
presentation/debug and scene impairment controls. P4.4 owns whole-call timings
and the long impairment soak. Phase 4 Gate B remains open.

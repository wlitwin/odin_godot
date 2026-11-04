# Replay authored Box3D sample

This project uses the same `AuthoredWorld` content as the Kit sibling. Its driver
is `res://modules/authoring_demo/demo.odin` (`ReplayAuthoringDemo`). The ordinary
shared preparation helper copies the addon, content, project modules and scripts;
it builds with the existing SDK pipeline and an already verified Native library.
Set `BOX3D_NATIVE_LIBRARY`, `ODIN` and `GODOT` to those installed tools, then:

```sh
python3 examples/box3d_authoring_shared/prepare.py --framework replay \
  --out /tmp/replay-authoring-sample --native-library "$BOX3D_NATIVE_LIBRARY" \
  --native-sha256 "$NATIVE_SHA256" --build --odin "$ODIN" --godot "$GODOT"
```

Use a fresh output path. Open its `project/project.godot`, or launch that project
with the official Godot executable. Run Host and Client in separate processes
with the same `BOX3D_SAMPLE_PORT` (default49742):

```sh
BOX3D_SAMPLE_ROLE=host "$GODOT" --path /tmp/replay-authoring-sample/project
BOX3D_SAMPLE_ROLE=client "$GODOT" --path /tmp/replay-authoring-sample/project
```

The shared view supplies camera, visible proxies, keyboard controls and HUD.
Both seats control the same authored sphere. Axis impulses are0.04; a sampled
pulse gives an upward0.2 impulse. The five control bytes are signed i16 x/z and
one bool. Missing/Held input is neutral, including pulse. Pulse is a tick control,
not a uniquely acknowledged action. The fixed tick and rollback belong to the
existing Replay Session/Timeline. The view never steps a solver.

For the bounded automated path set `BOX3D_SAMPLE_SCRIPTED=1`,
`BOX3D_SAMPLE_TICKS=120`, and a distinct existing absolute
`BOX3D_SAMPLE_OUTPUT` directory per role. Scripted Host waits for the actual
Client admission/ready message; both export the same confirmed target. The
existing application lane carries only startup and final-signature handshake
metadata. It cannot acknowledge physics packets or alter simulation input.
Host exits after accepting Client's matching signature/final ACK. Client waits
for Host close. `SAMPLE_READY` reports the measured Native image count;
`SAMPLE_RESULT` follows ordered teardown and actual allocation observations.

Each output contains the actual public complete-view `Solver.bin`, `Game.bin`,
`Side.bin`, `Observations.bin`, `Occurrences.bin`, `signature.bin` and
`final-frame.json`. Replay's Side part is legitimately empty: this sample's
ordinary value Game contains its allocation keys and counters. Full solver
state comes from the complete provider/checkpoint/codec, never a bare Frame or
pose-only reconstruction. Hashes are diagnostics; Host/Client comparison uses
the complete signatures and retained original part bytes.

Setup extracts/bakes once, builds actual Native, copies stable logical/allocation
maps into Game, initializes the trusted catalog and complete codec, and opens
the real Godot ENet Session. It then destroys the detached source bake/build and
queues the authoring nodes for deletion. Three real SDK leases protect allocator,
codec and Session state. Teardown closes Session, codec, residual build/catalog,
then creator owners, Runtime allocation and Meter context. Any declined cleanup
retains the surviving owner and reports failure.

The public methods are `status()`, `presentation()`, `control(x,z,pulse)`,
`request_reset()` and `close()`. Presentation returns only copied poses keyed by
`ground`, `pendulum`, `player`, `sensor`. Replay currently has no public manual
Resync facade: `request_reset()` returns false and status reports Unsupported.
Real complete Welcome and automatic Replay recovery remain enabled. Runtime
geometry/identity edits and alternate stepping/network loops are unsupported.

## Telemetry, recovery and maintenance

`status()` reads live head/confirmed/epoch/phase/GO. Scripted `SAMPLE_STATUS`
prints at roughly1Hz plus the first real GO transition. Native/Meter values are
cached measurements with `native_sampled_frame`/`meter_sampled_frame`, not
same-frame UI reads; null/unavailable stays explicit. Recovery fields describe
only a validated current Welcome scope (`recovery_epoch`,
`recovery_generation`, `recovery_serial`, `baseline`), never an inferred head
jump. Committed `controls_by_seat`/`nonzero_by_seat` come from confirmed Timeline
inputs; receipt origins have separate available/unavailable coverage. Do not
infer remote input from partially observed Local/Sample/Held totals.

The Host's actual `SAMPLE_TAIL stage=final_accepted,signature_match=true`
acknowledges the final signature. A producer RESULT, complete five parts, natural
process exit and checked cleanup remain separate. Optional Replay
`Profile_Clock`/`Profile_Metric` values use microseconds; Physics Inspect/Decode/
Repair/Compare and snapshot subphases can nest inside Pump/outer calls. Missing
clocks are unavailable; histogram bounds are not raw percentiles or extra costs
to add. See [production diagnostics](../../docs/design/box3d/production-diagnostics.md).

The authored UI exposes Host/Client only. Replay Session `.Observer`/public
`spectator=true` is receive-only and rejects step/action; SDK Client/Observer
uses ordinary `session_open`, not authority-only `session_open_complete`.
Same-token reconnect preserves published complete state until a real replacement
Welcome. Canonical hard resync follows actual window loss through public pumps;
same-scope signed-fact healing is separate. Manual UI Reset remains unsupported.
Use [recovery contracts](../../docs/design/box3d/recovery-hardening.md); no private
resync call, fake notice or second networking loop is a supported workaround.

Inspect a saved trace with `"$INSPECTOR" "$TRACE"`. For bounded offline
`tools/box3d_diagnostics.py collect/verify/inspect`, use the exact commands and
explicit labelled attachments in the [release procedure](../../docs/design/box3d/release.md).
Inspection decodes/re-encodes bytes without Native physics or simulation; it
does not reproduce gameplay or infer a report verdict.

Keep the [original sample proof](../../tests/box3d_samples/report.json),
[P6.2 production](../../tests/box3d_production/report.json),
[P6.3 bounds](../../tests/box3d_bounds/report.json) and
[P6.4 recovery](../../tests/box3d_recovery_flows/report.json) separate. The strict
Replay SDK observer run preserved by P6.4 is still FAIL; passing public observer
contracts do not relabel it. Historical8.894ms CPU failure/cause unknown also
remains unchanged. Use the [desktop CLI](../../tests/box3d_desktop/README.md) for
actual normal exports and the [compatibility table](../../docs/design/box3d/desktop-compatibility.md)
for ARM64 SDK/universal launcher, effective macOS14+ floor and translated Linux
x86_64 limits. No native-x86 hardware, Windows/web/mobile or remote-CI claim.

Follow [upgrade](../../docs/design/box3d/upgrade.md) and
[deployment](../../docs/design/box3d/runtime-deployment.md) before source or Native
changes. Preserve callback temporary scopes, owning-return/borrowed-argument
annotations, checked lifetime order, shared content bytes and failed evidence.
The older stress example and exact CPU workloads remain separate and unchanged.

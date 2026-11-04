# Kit authored Box3D sample

This is the small Kit sibling of `replay_box3d_authoring`. Both projects receive
the same `box3d_authoring_shared` authored content through the preparation helper
owned by that content. The older `kit_box3d` stress example remains unchanged.

Use the repo's ordinary preparation and SDK Core/scripts build before opening
the project. `scripts/boot.odin` is a real root script; the gameplay driver is
`res://modules/authoring_demo/demo.odin`, class `KitAuthoringDemo`, on `Sample`.
Its direct `AuthoredWorld` child is extracted once with `ga.extract`; shared
`a.build` creates the actual world/catalog, then `p.authoring_attach` transfers
only the world into Kit. Body/shape/joint resources never step themselves.

Prepare a NEW output with explicit verified tools/Native, then launch the two
project instances (this project path is development, not exported proof):

```sh
python3 examples/box3d_authoring_shared/prepare.py --framework kit \
  --out "$NEW_KIT_OUT" --native-library "$NATIVE" --native-sha256 "$NATIVE_SHA256" \
  --build --odin "$ODIN" --godot "$GODOT"
BOX3D_SAMPLE_ROLE=host BOX3D_SAMPLE_PORT=43125 "$GODOT" --path "$NEW_KIT_OUT/project"
BOX3D_SAMPLE_ROLE=client BOX3D_SAMPLE_PORT=43125 "$GODOT" --path "$NEW_KIT_OUT/project"
```

Use separate terminals and an unused common port. WASD/arrows and Space control
the shared player; R/Reset requests the supported Client Reset. See the
[desktop CLI](../../tests/box3d_desktop/README.md) for normal exported execution.

Run two instances: `BOX3D_SAMPLE_ROLE=host` and `client`, using the same
`BOX3D_SAMPLE_PORT` (default43125). The host waits for the real Session roster,
the client's content identity and validated complete-Welcome signature ACK
before sending GO. The UI calls `control(x,z,pulse)`; axes are quantized to -1/0/1
and a pending Space edge is consumed only by the real sample callback. Both
seats act on `player`, with axis impulse0.04 and upward pulse0.2. Missing controls
use the existing Neutral policy, so a missing packet cannot repeat a pulse.
The pendulum has one actual hinge. Sensor observations and a staged-world
downward query are copied into Side alongside tick/player/allocation-key state.

Kit remains the tick owner: service Session/wire, one ingress0, bounded existing
four-tick client bootstrap, then one scale-aware NORMAL call (<=two ticks,
prediction8/end budget). Reset uses the actual public request; after a validated
new bootstrap scope, the caller waits for a newer matched signature before the
same bounded re-anchor. No raw head/clock setter or action reissue exists here.
This sample clamps large frame hitches instead of retaining a time debt.

`presentation()` returns copied public checkpoint body poses as
`{version:1,bodies:[{key,position,rotation}]}`; the UI only moves proxies.
`status()` reports role/phase/head/confirmed/error and reset availability.
`request_reset()` is supported for a ready Client; `close()` performs ordered
wire/network/codec/provider/Lane/Session/map/owner/context teardown.

For Root's bounded functional run, set `BOX3D_SAMPLE_SCRIPTED=1`,
`BOX3D_SAMPLE_TICKS=120`, and an absolute `BOX3D_SAMPLE_OUTPUT` directory per role.
Scripted seat1 drives X and seat2 Z, changing sign every60ticks; pulse is true at
multiples of45. Actual SAMPLE_READY includes content SHA and loaded Native image
count. Both roles write public complete `Solver.bin`, `Game.bin`, `Side.bin`,
`Observations.bin`, `Occurrences.bin`, `Signature.bin` and `final-frame.json` at
the declared confirmed target. Host retirement waits for the actual client's
matching final signature. SAMPLE_RESULT prints only after teardown, including
actual Native/wrapper/Meter/ledger owner observations. Setup, export, receipt or
cleanup errors produce an honest failed result rather than a success waiver.

## Telemetry, recovery and maintenance

`status()` reads live head/confirmed/epoch/phase/GO. Scripted `SAMPLE_STATUS`
prints at bounded roughly1Hz plus a first-GO row. Native/Meter fields are cached
observations identified by `native_sampled_frame`/`meter_sampled_frame`; false
availability/null is not zero, and calling the UI getter does not force a new
memory measurement. Validated recovery scope/count is distinct from a head jump.
`SAMPLE_ACK` is the Host's actual verified terminal-signature ACK; final part
bytes and `SAMPLE_RESULT` cleanup remain independent requirements. Replay's
profile clock markers are not Kit timing counters; use the documented whole-call
Kit fixtures and [diagnostic boundaries](../../docs/design/box3d/production-diagnostics.md).

The authored UI exposes Host/Client only. Generic Kit Session spectator
enrollment does not itself disable positive World stepping: the tested observer
policy is receive-only/zero-delta. Existing-identity peer replacement, late
observer enrollment and a fresh logical driver after GO have distinct contracts;
the legacy Kit example refuses that fresh driver. There is no `reconnect()` UI
method here. Use [current recovery contracts](../../docs/design/box3d/recovery-hardening.md)
rather than inventing a head setter, input reissue or another Session.

For a saved trace, `"$INSPECTOR" "$TRACE"` performs native-free bounded exact
inspection. The [release procedure](../../docs/design/box3d/release.md) gives the
published `tools/box3d_diagnostics.py collect/verify/inspect` commands, explicit
attachments and limits. No sample environment flag automatically produces a
bundle or upgrades a retained mismatch/report to current acceptance.

The [original sample proof](../../tests/box3d_samples/report.json),
[P6.2 production](../../tests/box3d_production/report.json),
[P6.3 bounds](../../tests/box3d_bounds/report.json) and
[P6.4 recovery](../../tests/box3d_recovery_flows/report.json) retain distinct
candidate/workload scope and failures. Mac execution uses ARM64 SDK/Native with
a universal Godot launcher; the bundle requires macOS14+, not the launcher's11.0
minimum. Linux evidence is translated x86_64 functional. See
[compatibility](../../docs/design/box3d/desktop-compatibility.md) and
[upgrade/deployment](../../docs/design/box3d/upgrade.md) before changing artifacts.
Retain checked lifecycle ownership, callback temp scopes/owning-return semantics,
shared content and old failure bytes; no Native hot replacement or automatic
physics in authoring/view nodes.

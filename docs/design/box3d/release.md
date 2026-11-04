# Box3D release procedure

Release a declared candidate with separate Kit and Replay evidence. A completed
local phase, exported smoke test or diagnostic bundle does not certify every
platform/workload or authorize distribution. Keep previous artifacts and FAILs.

## Candidate and evidence

1. Record the exact source/model/rules and authored asset identities, upstream
   pins/patches/notices, compiler and flags, FP/SIMD/precision, Native build/target,
   private ABI and deployed-library hashes. Preserve one shared Native image per
   process and typed producer code/data ownership. Follow the authoritative
   [upgrade procedure](upgrade.md), [dependency record](dependencies.md),
   [runtime deployment](runtime-deployment.md) and
   [desktop/cache CLI guidance](../../../tests/box3d_desktop/README.md).
2. Record compatibility per layer: exact-build local images, canonical recovery,
   authoring/artifact and each framework's wire/schema/rules contracts are
   distinct. Do not reinterpret an old version or use a checksum as sender
   authorization. Changed contracts need an explicit rejection/conversion and
   content/save migration decision, with affected gates re-earned.
3. Use ordinary SDK build/import/export and the explicit-input desktop CLI.
   It stages plans without jobs by default; `--execute` runs the selected case.
   Publish actual source/tool/binary/Native fences, full five-part comparisons,
   remote controls, terminal ACK, natural exits and observed cleanup. Retain all
   CPU cold/error/outlier samples and whole-call boundaries; never pool profiles,
   subtract phases, silently rerun or inherit unrelated old performance proof.
4. Publish the scoped evidence matrix and unavailable work before signing or
   packaging. Signing/notarization/upload and distributed compatibility require
   separate authorization and evidence. Local ad-hoc signing is not notarization.

| Retained evidence | What it establishes |
| --- | --- |
| [Gate B](../../../tests/box3d_soak/gate-b-report.json) / [Gate C](../../../tests/box3d_gate_c/report.json) | Their declared reference CPU/functional and normal exported-pair candidates. |
| [P6.2 production](../../../tests/box3d_production/report.json) | Four corrected exported108600-tick/>1809s pairs, eight service pauses, scoped CPU/quota/lifetime results; earlier failures retained. |
| [P6.3 bounds](../../../tests/box3d_bounds/report.json) | Separate Native/Kit/Replay ingress and semantic rejection tests plus short SDK regressions. |
| [P6.4 recovery](../../../tests/box3d_recovery_flows/report.json) | Current public late-join/observer/reconnect/resync tests, migrated Kit guarantees and separately labelled SDK lifecycle results. |

These reports bind their actual candidates; a later source change does not
rewrite their provenance. See [recovery hardening](recovery-hardening.md) for
framework distinctions and the preserved strict Replay SDK observer FAIL.

## Support boundary

The tested desktop configurations are native macOS ARM64 SDK/Native with the
official **universal Godot launcher**, and **translated Linux x86_64** functional
execution. SDK/Native macOS deployment requires14.0 despite the launcher's11.0
plist minimum; actual reference execution was15.8. Neither the universal launcher
nor translated Linux proves Intel SDK/native-x86 hardware performance. Use the
exact [compatibility table](desktop-compatibility.md), not the preset label alone.

Native Linux hardware/remote CI, Windows/web/mobile Box3D, manual pixel/usability,
mixed-target deterministic equality and distributed release certification remain
unqualified by these local records. Preserve35 bodies/shapes,32 initial dynamics,
one joint/eight assets, H128/prediction8/repair8 and64MiB tracked admission. OS RSS,
Godot heap and Odin TLS are separate observations, not that quota. Controlled
service pauses do not certify packet loss/jitter.

The historical8.894ms Dense sample remains FAIL/cause unknown. Later passing
samples do not explain or remove it. The strict Replay observer run also remains
FAIL even though independently scoped public observer tests pass. Keep original
verdict bytes, contexts and unavailable coverage visible.

## Diagnostics and sample maintenance

Use the [production diagnostics contract](production-diagnostics.md) for actual
profiling boundaries, units, live versus cached telemetry and first-divergence
ownership. A missing counter/clock is unavailable, not an observed zero. Retain
the trace's full five parts and accepted/predicted input windows with explicit
source/build/log/report attachments. The native-free inspector accepts exactly
`INSPECTOR TRACE_FILE`; success requires bounded decode and byte-exact re-encode.
It does not simulate physics or reproduce gameplay.

Framework code obtains Kit's borrowed first-conflict trace through
`lane_world_network_trace` and copies it with `bd.trace_encode` before Lane
teardown; Replay exposes `client_physics_trace(client,dst)` before Client
destruction. Neither is a new sample GDScript method or an automatic bundle flag.

The published offline CLI uses explicit paths and a trusted inspector SHA:

```sh
python3 tools/box3d_diagnostics.py collect --framework kit \
  --trace "$TRACE" --inspector "$INSPECTOR" --inspector-sha256 "$INSPECTOR_SHA256" \
  --out "$NEW_BUNDLE" --attachment "report:case=$CASE_REPORT" \
  --attachment "log:runtime=$RUNTIME_LOG" --attachment "source:inputs=$SOURCE_MAP"
python3 tools/box3d_diagnostics.py verify --bundle "$NEW_BUNDLE"
python3 tools/box3d_diagnostics.py inspect --bundle "$NEW_BUNDLE" \
  --inspector "$INSPECTOR" --inspector-sha256 "$INSPECTOR_SHA256"
```

Use `--framework replay` for a Replay trace. Optional `--manifest-sha256` pins the
manifest for verify/inspect. Collection publishes only a new verified bundle;
verify is read-only and starts no process. Inspection runs only the pinned
native-free inspector. Results are `BUNDLE_COLLECTED`, `BUNDLE_VALID` or
`TRACE_INSPECTED`, with `run_verdict: NOT_INFERRED`; exit0 is tool success and
exit2 is rejection/usage. Fixed bounds are32 files,16MiB/file,64MiB total,9MiB
trace,256KiB manifest and64KiB per inspector output with30s supervision. No
implicit environment/account capture or repository copy is intended.

An intentional first-divergence fixture may have `success:true`; do not label
that case FAIL merely because it produced a mismatch trace. Historical P3.5
traces retain their old build/target identities. Separately attached actual FAIL
reports stay FAIL; bundling preserves either original verdict without inferring
current compatibility, a physics PASS or gameplay reproduction.

Maintain the [Kit](../../../examples/kit_box3d_authoring/README.md) and
[Replay](../../../examples/replay_box3d_authoring/README.md) samples together:
stage the shared authored scene byte-identically, keep stable keys and pure
Game/Side validation, and keep presentation detached from simulation. Preserve
existing owning-return/borrowed-argument annotations, nested callback temporary
scopes and checked close/free order. Never clear a shared caller arena or weaken
cleanup to hide growth. The old stress examples, failed reports and exact
benchmark workloads are separate assets, not cleanup targets.

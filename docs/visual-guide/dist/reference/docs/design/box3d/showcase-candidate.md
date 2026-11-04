# Dockyard Duo review handoff

Status on 2026-11-03: **playable, unreleased review candidate**. Native and browser
multiplayer, cooperative rounds, complete-state agreement, recovery, audio and
checked shutdown work in the recorded local cases. Three release gates remain:
one failed correction-time limit, public connectivity acceptance and two-human
cooperative play feedback.

The [current build status](../../../tests/replay_dockyard/qualification/handoff-status.json)
binds the exact frozen export, actual browser versions, raw evidence hashes and
open requirements. Earlier qualification reports and the original review archive
retain their earlier artifact scopes.

## Final browser measurements

The same frozen export ran once in each final arrangement, for over 610 seconds
per arrangement, on the Apple M3 Mac15,13 reference machine, 24 GiB, AC power,
1280×720/DPR1, visible tabs and hardware rendering. Both used actual authenticated
forced TURN on a local interface. This establishes local relay behavior.

| Arrangement | Normal whole-call timing | Actual eight-step corrections | Verdict |
| --- | --- | --- | --- |
| Firefox 159.0.1 host / Chrome 156.0.8078.80 client | Firefox p95 3.061 ms, p99 3.581 ms, max 8.000 ms; Chrome max 5.079 ms | Chrome 3,849 samples, p95 7.014 ms, max 10.486 ms | All original measured budgets pass. |
| Chrome host / Firefox client, same versions | Chrome p95 2.270 ms, p99 2.729 ms, max 7.880 ms; Firefox max 8.501 ms | Firefox 3,968 samples, p95 8.599 ms, p99 9.640 ms, max 45.920 ms | Rejected: one correction exceeds the original 25 ms maximum. |

Both arrangements met the presentation, cold-menu and memory limits. They ran
multiple jobs through the actual NEXT JOB control, agreed on all five final
state parts, completed the terminal acknowledgement, returned tracked ownership
to zero and exited the Godot runtime without leaked audio playbacks. The first
arrangement reached six rounds and nine eligible delivery cues; the second
reached eleven rounds and thirty cues.

Every selected sample and outlier remains recorded. There is no timing overhead
subtraction or unchanged retry for a lucky maximum. Memory growth preceded the
slow correction by about 102 seconds; its cause remains unestablished. The
original performance contract remains in force while the user decision is pending.

## Recovery and compatibility

The current artifact passes late receive-only observation, pending-action
connection replacement, bounded delay/jitter/loss, complete recovery after a gap
beyond H128, checked cold rejoin with the same membership and a fresh incarnation,
and frozen-host permission fencing followed by the actual new-crew flow. These
cases retain state agreement, acknowledgements, ownership and artifact fences.
Earlier hidden-client and abrupt host-loss records keep their own build scopes.

Current macOS ARM64 Native SDK multiplayer passes. The affected complete-physics
network suite passes all 16 tests, and the broader default network suite passes
182. The minimal Kit browser case uses the same unchanged backend/custom template
and covers provider/World2/complete codec/cleanup; it supplies no Kit game or
network performance claim. Safari remains unadmitted because its actual remote
automation prerequisite was unavailable. Native/Web crossplay, mobile, Intel SDK
and current Linux hardware performance remain unqualified.

## Review package and reproduction

The [packaging tool](../../../examples/replay_dockyard/package.py) creates a new
candidate directory from verified ordinary export bytes, a frozen macOS ARM64 SDK
project, operator templates, notices and the current qualification status. Its
manifest always records `release_admitted:false`. It includes no room database,
TURN credential, TLS private key, browser profile or fixture bridge.

The package preserves the pinned custom Godot template record and reproduction
helper. Only its RTC JavaScript send-copy function changes; the official engine
Wasm payloads remain byte-identical. One 64 KiB JavaScript scratch backing store
belongs to each loaded engine module. The record identifies the original template,
helper, derived ZIP and every payload. Re-derivation requires the exact official
Godot 4.7.1 template and a new output directory. Ordinary SDK/export steps still
build the extension and PCK from the repository. See the [game README](../../../examples/replay_dockyard/README.md).

The backend remains pinned to unpatched Box3D
336263320469e5e9febfe18697ab562488f7e97a, with the declared small rollback-shim
adaptation. The selected Wasm SIMD profile uses float32, 60 Hz, four substeps and
one simulation worker. Assertions, validation and strict floating-point flags
remain enabled. There are 19 bodies/shapes, eight geometries and one hinge;
H128, prediction/repair8 and the 64 MiB tracked backend limit remain unchanged.

Public hosting requires a selected HTTPS/WSS endpoint, real remote connectivity
checks and a compatible TURN route. Operator files are templates; no public
service has been deployed. Two-human feedback on movement, grabbing and readability
is still needed. Automation and recorded audio signal do not supply that feedback.

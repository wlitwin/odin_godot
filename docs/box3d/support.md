# Box3D support

Choose the backend, target, authoring schema, and framework adapter as one
configuration. Complete physics history has stricter identity and resource
requirements than drawing body poses.

## Platform scope

| Configuration | Scope |
| --- | --- |
| macOS arm64 | Native backend, Godot authoring, separate Kit/Replay samples, and desktop export |
| Linux x86_64 | Functional desktop export and host/client runs under translation on an arm64 VM; independent native-hardware performance needs validation |
| Offline web example | Dedicated WebAssembly backend and example export helper |
| Windows, mobile, other architectures | Require target-specific build and runtime validation |
| Mixed target deterministic matches | Unsupported; exact physics uses same-build, same-target identity |

Debug/Release configurations and different native targets can have different
identities and results. Do not mix their checkpoints or infer cross-platform
determinism from separate successful builds.

## Complete-state runtime profile

The authored rollback/network profile uses these bounded limits. They are
admission rules for this integration, rather than general upstream engine limits.

| Resource | Bound |
| --- | --- |
| Initial dynamic bodies | 32 |
| Total bodies and shapes | 35 each |
| Contacts | 147 |
| Joints | 1 |
| Deduplicated catalog assets | 8 |
| Retained history | 128 ticks |
| Prediction and ordinary repair | Up to 8 ticks |
| Fixed tick | 60 Hz, four substeps |
| Accounted resource allowance | 64 MiB |
| Caller | One main-thread caller |

Capacity, missing history, incompatible identity, and unsupported operations
must be handled explicitly. Missing predecessor history cannot be replaced by
the current live solver. Older settled state cannot be rewritten by ordinary
correction; recovery requires the framework's explicit reset protocol.

The resource allowance includes declared native, wrapper, history, payload,
and provider allocations/reservations. It is not a process RSS cap. Bound and
account for application-owned queues separately. Native engine allocator
exhaustion remains a fatal boundary.

## Geometry and presentation

Meshes and heightfields are static-only and cannot act as sensors. Body/world
transforms must be rigid. Joint family availability does not raise the one-joint
profile limit. See [API map](reference.md) for shape-specific constraints.

Pose and motion digests are diagnostics. Complete checkpoint equality requires
the complete solver plus game/Side state, observations, and occurrences. Debug
drawing consumes copied values and does not establish solver equality.

## Deployment

Desktop SDK modules share one loaded backend and retain originating code and
data owners. Stop Godot before replacing the native library. The offline web
example's static WebAssembly path does not establish equivalent deployment for
every multiplayer configuration.

Measure full frame and correction cost with your content and target hardware.
Supported storage bounds do not guarantee a frame-time budget at maximum load.

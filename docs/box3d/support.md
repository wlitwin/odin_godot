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

## Configurable world capacities

World capacities come from one build profile shared by the native backend, Odin
modules, authoring addon, presentation, and recovery/network codecs. These are
configurable storage and admission ceilings. The shipped defaults are:

| Resource | Bound |
| --- | --- |
| Total bodies, including static bodies | 1024 |
| Shapes | 4096 |
| Contacts | 16384 |
| Joints | 256 |
| Deduplicated catalog assets | 128 |
| Sensor pairs | 4096 |
| Accounted resource allowance | 1 GiB |

Use [Configure capacities](capacities.md) to select larger or smaller settings
without editing the SDK. The build reads a JSON profile, rebuilds the backend,
and supplies matching settings to every consumer. Native/Odin mismatches reject
before world construction. The native recovery configuration can also impose
lower per-world limits within the selected capacities.

The resource allowance is a quota, not a 1 GiB preallocation. Actual storage
depends on the scene, retained solver images, metadata, and temporary work.

<a id="timing-and-ownership-requirements"></a>

## Timing settings and ownership

History, timing, and window ceilings come from the same build profile as world
capacities. These are the defaults; use [Configure timing](timing.md) to change
them and initialize matching framework settings.

| Setting | Default | Configuration |
| --- | --- | --- |
| Retained history | 128 frames | Build profile `history_frames` |
| Kit prediction and ordinary repair ceiling | 8 ticks | Build profile `kit_repair_ticks` |
| Replay prediction | 30 ticks | Build default `replay_prediction_ticks`; network runners can choose a smaller active window |
| Replay prediction and synchronous repair ceiling | 32 ticks | Build profile `replay_window_ticks`; repair stays within the active runner window |
| Simulation tick rate | 60 Hz | Build profile `tick_hz` |
| Native substeps per simulation tick | 4 | Build profile `substeps` |

The caller contract remains one main-thread caller. The managed adapters and
shared backend rely on serialized execution and retained code/data ownership;
thread count is not a profile setting.

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
transforms must be rigid. Joint families share the selected joint capacity.
See [API map](reference.md) for shape-specific constraints.

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

# Box3D API map and limits

Use this page to locate public packages and look up authoring constraints.
Start with [the tutorial](quickstart.md) for a running project.

## Packages

| Import | Public surface | Source reference |
| --- | --- | --- |
| `godot:box3d` | Worlds, bodies, shapes, fixed stepping, queries, characters, joints, snapshots | [Native binding](https://github.com/wlitwin/odin_godot/blob/main/box3d/README.md) |
| `godot:box3d/authoring` | Parse, bake, build, catalogs, mappings, artifacts | [Authoring API](https://github.com/wlitwin/odin_godot/blob/main/box3d/authoring/API.md) |
| `godot:box3d/godot/authoring` | Extract Godot nodes and Resources into detached authoring data | [Extractor](https://github.com/wlitwin/odin_godot/blob/main/box3d/godot/authoring/README.md) |
| `godot:box3d/debugdraw` | Bounded line generation from copied geometry and frames | [Debug API](https://github.com/wlitwin/odin_godot/blob/main/box3d/debugdraw/API.md) |
| `godot:box3d/presentation` | Copied presentation values without a live solver | [Package](https://github.com/wlitwin/odin_godot/tree/main/box3d/presentation) |
| `godot:kit/physics` | Kit world participant, complete checkpoints, authoring and network integration | [Package](https://github.com/wlitwin/odin_godot/tree/main/kit/physics) |
| `godot:replay/physics` | Managed solver attachments, complete checkpoints, authoring and network codec | [Package](https://github.com/wlitwin/odin_godot/tree/main/replay/physics) |

## Raw world lifecycle

| Procedure | Result |
| --- | --- |
| `world_def_default()` | Default world definition |
| `world_create(def)` | World handle and status |
| `body_def_default()` | Default body definition |
| `body_create(world, def)` | Body handle and status |
| `shape_def_default()` | Default material/filter settings; density 1000 kg/m³ |
| `shape_box(body, def, half_extents)` | Shape handle and status |
| `body_get_pose(body)` | Copied pose and status |
| `world_step_fixed(world)` | Status; advances 1/60 second with four substeps |
| `world_destroy(&world)` | Status; destroys the world's bodies and shapes |

Check status before reading returned values. Native handles are local to their
world/domain and are unsuitable as durable authored IDs.

## Authoring lifecycle

| Procedure | Result |
| --- | --- |
| `bake(input, allocator)` | Owning `Baked_Scene` and `Diagnostic` |
| `parse_and_bake(json_bytes, allocator)` | Owning `Baked_Scene` and `Diagnostic` |
| `destroy(&scene)` | Release a baked definition |
| `build(&scene, profile)` | Owning `Built_Scene` and `Diagnostic` |
| `built_destroy(&built)` | Checked status; release world, catalog, and local maps |
| `artifact_create(bytes, metadata, allocator)` | Owning artifact and diagnostic |
| `artifact_load(encoded, allocator)` | Independent owning artifact and diagnostic |
| `artifact_destroy(&artifact)` | Release the artifact |

Owning values must use their matching destructor. Assignment can alias ownership.
Allocators and callback contexts must outlive the owners that retain them.

## Definition constraints

| Setting | Constraint |
| --- | --- |
| Schema 1 | Bodies and shapes |
| Schema 2 | Adds characters and joints |
| Body/world transforms | Rigid finite poses |
| Shape scale | Positive; sphere/capsule require uniform scale |
| Mesh/heightfield | Static, non-sensor; sensor events disabled |
| Hull | 4–256 points |
| Mesh | Up to 4096 vertices and 24576 indices |
| Heightfield | Up to 64 × 64 samples |
| Authoring input | Selected `dto_bytes` capacity; 32 MiB by default |
| Authored logical IDs | 64-bit namespace/key-derived values |
| Native catalog IDs | 32-bit content-derived geometry identities |

See [Support](support.md) for the bounded complete-state runtime profile.

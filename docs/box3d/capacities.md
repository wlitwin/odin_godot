# Configure world capacities

Select the body, shape, joint, asset, and byte capacities for your game when
building its Box3D backend. The SDK propagates that profile to Odin modules and
the authoring addon. You do not need to edit framework source or raise limits
in several packages manually.

This guide assumes [the Box3D build setup](building.md).

## Choose a profile

The SDK's default profile is in
[box3d/capacity.json](https://github.com/wlitwin/odin_godot/blob/main/box3d/capacity.json).
It permits 1024 bodies, 4096 shapes, 16384 contacts, 256 joints, and 128
deduplicated geometry assets, with a 1 GiB accounted-memory allowance.

Create a JSON file in your game or build configuration. Supply the fields you
want to override; omitted fields retain their SDK defaults. For example:

```json
{
  "max_bodies": 2048,
  "max_shapes": 8192,
  "max_contacts": 32768,
  "max_joints": 512,
  "max_assets": 256,
  "memory_bytes": 2147483648
}
```

Keep this file in version control with the game. Unknown keys, invalid numbers,
and incompatible byte budgets are rejected by the builder.

## Build and select the backend

From the SDK checkout, inside `nix develop`:

```sh
BOX3D_CAPACITY_PROFILE=/absolute/path/to/physics-capacity.json \
  bash build/build_box3d.sh Release "$PWD/.box3d-cache/my-game"

export BOX3D_NATIVE_LIBRARY="$PWD/.box3d-cache/my-game/build/Release/libogb3.dylib"
bash build/build_scripts.sh /absolute/path/to/your/project
```

Linux uses `libogb3.so`. The native build records the resolved profile in its
manifest. The ordinary script builder reads that manifest and passes matching
compiler defines to the core and every gameplay module. If the project contains
`addons/box3d_authoring`, it also writes the selected authoring capacities into
that project's addon copy.

Use a copied authoring addon for a custom profile. The build refuses to replace
the SDK's canonical default through a project symlink.

Stop Godot before replacing a deployed backend. A changed profile changes the
native build identity; follow [the replacement workflow](building.md).
Peers, modules, and checkpoints must use compatible build and content identities.

## Capacity fields

| Field | Default | Meaning |
| --- | --- | --- |
| `max_bodies` | 1024 | Total static, kinematic, and dynamic bodies |
| `max_shapes` | 4096 | Total shapes across those bodies |
| `max_contacts` | 16384 | Solver contact and manifold capacity |
| `max_joints` | 256 | Total joints across supported families |
| `max_assets` | 128 | Deduplicated immutable catalog geometries |
| `max_sensor_pairs` | 4096 | Sensor-pair capacity; copied begin/end buffers scale with it |
| `memory_bytes` | 1073741824 | Shared accounted native, wrapper, history, and provider allowance |
| `recovery_bytes` | 8388608 | Maximum canonical native recovery payload |
| `dto_bytes` | 33554432 | Authoring input and bounded native decode workspace |
| `snapshot_bytes` | 16777216 | Maximum opaque captured native source image |
| `network_bytes` | 33554432 | Maximum complete framework envelope |
| `debug_lines` | 32768 | Debug drawing line budget |

Bodies and shapes have independent counts: a compound body can use several
shapes. Reused geometry can share a catalog asset while retaining separate
authored keys. A larger body allowance does not enlarge every byte budget.
Choose storage, history headroom, and transfer sizes for the actual content.

## Build capacities and runtime quotas

The build profile determines fixed value-buffer sizes and the backend's
maximum admission bounds. Changing those sizes requires rebuilding the backend
and modules. A recovery catalog can choose lower body, shape, contact, joint,
and byte limits through `Recovery_Config`; it cannot exceed its backend profile.

The 128-tick history, fixed timestep, caller contract, and framework prediction
windows remain separate [runtime requirements](support.md).

## Measure the workload

Capacity is not a frame-time guarantee. Joint topology, contact density,
geometry, retained history, and correction depth affect CPU and memory costs.
The memory quota counts requested ownership and reservations, rather than RSS.
It does not recover the native engine from allocator exhaustion.

For reproducible capacity and rollback checks, use
[the capacity suite](https://github.com/wlitwin/odin_godot/tree/main/tests/box3d_capacity).

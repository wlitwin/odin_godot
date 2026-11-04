# Box3D authoring and framework samples

For an offline, single-player game, Kit and Replay are optional: see
[examples/box3d_offline](../examples/box3d_offline/README.md), where one script
creates a Box3D world, steps it each physics frame and copies body poses onto
ordinary Godot nodes.

Start with the [shared authoring contract](design/box3d/authoring.md) for World,
Body, Sensor and six shape Resources. [Character movement, queries and joints](design/box3d/motion.md)
describe fixed-tick value state and all eight joint families. The
[editor workflow](design/box3d/editor.md) covers Inspector/gizmo tools, deterministic
Mesh baking, owning artifacts and optional debug drawing.

Use the separate [Kit and Replay sample instructions](design/box3d/samples.md).
Both use shared authored content and the same Box3D backend; each keeps its own
Session, tick ownership, complete checkpoint and recovery APIs. The
[migration guide](design/box3d/migration.md) maps ordinary Godot physics scenes to
those explicit contracts and lists supported operations and named failures.

The source API is [box3d/authoring/API.md](../box3d/authoring/API.md). Native
ownership and identity are documented in [box3d/README.md](../box3d/README.md),
and SDK code/data/accounting requirements in
[box3d/godot/README.md](../box3d/godot/README.md). Completed authoring, motion and
editor reports retain actual commands, artifact hashes, prior failures and
platform limits. Export Gate C is a separate milestone.

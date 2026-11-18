# Use Box3D with Kit or Replay

Choose the adapter for your multiplayer framework. Both use the same native
backend and shared authoring data, while retaining independent session,
checkpoint, and recovery APIs. Start with the framework's tutorial and
[Box3D ownership](ownership.md).

## Compare the entry points

| Responsibility | Kit | Replay |
| --- | --- | --- |
| Tick owner | Kit Lane | Replay Session/Timeline |
| Adapter | `godot:kit/physics` | `godot:replay/physics` |
| Authored setup | `authoring_attach` | `authoring_config`, `authoring_checkpoint` |
| Gameplay state | Side and tracked fields | Typed Game/frame values |
| Physics history | Complete world participant checkpoints | Managed complete solver attachment |
| Sample | `examples/kit_box3d_authoring` | `examples/replay_box3d_authoring` |

Do not combine these adapters on one world or call raw stepping from rendering.
The framework owns accepted input, staged physics work, history, and commit.

## Prepare an authored sample

From the repository root, enter `nix develop` and build the backend:

```sh
bash build/build_box3d.sh Release "$PWD/.box3d-cache"
```

On macOS, prepare the Kit project in a new output directory:

```sh
python3 examples/box3d_authoring_shared/prepare.py \
  --framework kit --out /tmp/first-kit-box3d \
  --native-library "$PWD/.box3d-cache/build/Release/libogb3.dylib" \
  --odin "$(command -v odin)" --godot "$GODOT" --build
"$GODOT" --editor --path /tmp/first-kit-box3d/project
```

Use `--framework replay` and a different output directory for Replay. Linux
uses the corresponding `.so` backend and target toolchain. The helper copies
the project, shared content, addon, and tool module, then performs the ordinary
SDK build. It requires a fresh output directory so it cannot overwrite a game.

## Run host and client

After importing the prepared project, start the two roles from separate terminals:

```sh
BOX3D_SAMPLE_ROLE=host "$GODOT" --path /tmp/first-kit-box3d/project
```

```sh
BOX3D_SAMPLE_ROLE=client "$GODOT" --path /tmp/first-kit-box3d/project
```

For Replay, substitute its prepared path. Both processes must use matching
backend, target, content, and framework schema. The scene contains a ground,
pendulum, player body, and sensor. Both seats can control the player body; the
framework combines accepted input against one complete world.

The module under `modules/authoring_demo/` owns the framework integration.
The scene script samples controls and displays copied poses. Read its
`status`, `presentation`, `control`, `request_reset`, and `close` procedures to
follow that boundary. The sample reports unsupported reset operations explicitly.

## Retain complete checkpoints

Complete state includes the solver, gameplay values, sensor observations,
occurrences, and accepted input needed by the selected protocol. Never replace
the attachment with a list of transforms or a motion digest.

Kit transfers the built world on successful `authoring_attach`; the caller still
owns the catalog and local mappings. Replay's complete checkpoint retains its
image and trusted catalog. Its codec and runtime must use matching configuration
and catalog identity. Follow the complete sample's allocator and callback-owner
setup when retaining these objects.

During shutdown, stop frame work, close Session/network bindings, release
checkpoints, then release dependent providers, catalogs, and allocation owners.
Check cleanup results and keep a surviving owner if a drop declines.

## Next

Read [Support](support.md) for correction, memory, and target bounds, and
[Build and export](building.md) for deployment. The lower-level adapter contracts
are [Kit physics](https://github.com/wlitwin/odin_godot/tree/main/kit/physics)
and [Replay physics](https://github.com/wlitwin/odin_godot/tree/main/replay/physics).


## Standard authored owners

Use `godot:kit/godot/physics.Authored_World` or
`godot:replay/godot/physics.Authored_Session` for the standard Godot path. They
manage metered storage, exact callback leases, catalogs/codecs and temporary
checkpoints, and close resources in dependency order. The authored samples use
these helpers while keeping their input, roster, rules, presentation and test
telemetry explicit.

Kit keeps ordinary lane/model and network attachment choices. Replay composes
its existing Session. Both expose managed temporary checkpoint borrows and allow
explicit independent clones. Failed setup/close retains cleanup state for retry;
keep the control record until close succeeds. Finalize terminal ownership instead
of destroying it during temporary tree exit.

See the [Kit owner source guide](https://github.com/wlitwin/odin_godot/tree/main/kit/godot/physics)
and [Replay owner source guide](https://github.com/wlitwin/odin_godot/blob/main/replay/godot/physics/OWNERSHIP.md)
for the complete contracts. Lower-level APIs remain available for custom ownership.

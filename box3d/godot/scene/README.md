# Offline authored scene owner

`godot:box3d/godot/scene` binds an editor-authored World to local fixed-step
physics. It is separate from the native-free authoring/extraction packages.

- `open(world, allocator)` captures an immutable bake, creates the native
  world/catalog and binds body nodes automatically. The baked content ID supplies
  the local catalog profile; no application profile configuration is needed.
- `step_fixed(&scene)` validates presentation bindings, advances one fixed step
  and copies body poses to nodes. Godot's physics rate must equal `box3d.FIXED_HZ`.
- `reset(&scene)` rebuilds from the captured initial bake and resets visual
  interpolation. It never re-extracts simulated nodes.
- `body_for_node(&scene, body_node)` resolves the current body handle, including
  after reset. Use it for gameplay forces/queries; retain lifetime ownership here.
- `destroy(&scene)` checks native teardown before freeing the bake and binding
  storage. Call it even after a failed open/reset: failure can retain ownership.
  A non-OK destruction result leaves that owner intact for diagnosis/retry.

Diagnostics retain extraction errors when present; call `diagnostic_destroy`.
`describe` formats an actionable message in the current temporary allocator.
`Interrupted` means a synchronous transform callback reset or destroyed the
owner; stop the current game callback without treating intentional destruction
as a new gameplay error. The helper stops publishing immediately.

One script owns one Scene. Keep it through temporary tree exit and destroy it in
`finalize`; do not add an empty reload hook to an owner containing allocator or
catalog state. Stop/recreate live gameplay instances for owned-layout changes.

Bindings use weak ObjectIDs and parent-before-child order, exclude nested
Worlds, and publish global transforms relative to the current World frame.
Mesh-child transforms remain unchanged. Bound-node deletion or moving a body
outside its captured World/body ancestry is reported before the next step.
This helper does not discover new runtime bodies, own a separate clock, provide
interpolation snapshots, or implement framework checkpoint/network policy.

See the SDK's `template/box3d` starter, or `examples/box3d_starter` in the source
checkout, for the small complete game loop.

# Own an authored Kit physics world

`Authored_World(Side, Control, Proxy, User)` is the standard Godot owner for an
authored complete-physics Kit game. It owns stable metered storage, exact callback
leases, wire/session/lane state, physics, codecs, catalog and source bake.
The lower-level `kit/physics` APIs remain available for custom composition.

```odin
import physics "godot:kit/godot/physics"

report := physics.authored_open(&self.physics, authored_world)
data := physics.authored_data(&self.physics) // guarded, borrowed
// Configure the ordinary Session, attach/listen/open its wire, select the roster.

error := physics.authored_lane_init(data)
// Set the existing lane callbacks, control classes and tracked values.
error = physics.authored_attach(data, initial_side, fields, proxy_descriptor, settle)
error = physics.authored_network_attach(data, wire_fields, inputs, drivers, effects, rules)

error = physics.authored_close(&self.physics)
```

Check every report/status before continuing. The defaults supply ownership and
physics timing; input semantics, descriptors, roster, drivers, effects and game
rules remain game decisions. Lane callbacks use the stable `Authored_Data` as
their user context. Its `game` field contains `User` and promotes those fields for
convenient access. Keep user field names distinct from the framework fields.

The catalog profile defaults to the baked content ID. Supply `profile` when an
explicit persistent profile identity is part of the game's contract.

`authored_checkpoint` holds one managed temporary checkpoint. Its pointer is
borrowed until release, next capture or close; a refused release stays owned for
retry. Clone through the existing Kit API when the checkpoint should live
independently of the source. Detached checkpoints retain their own native/data/
code capabilities; closing this source does not destroy them.

Close stops ingress first, then releases managed checkpoints, network/codec/
provider users, lane/session state, authored content and finally capabilities
and storage. It records each completed phase; failure preserves the remaining
owner for retry. Do not discard an owner or its control record after a failed
close. Retry Busy after the active callback/tick finishes.

An optional `cleanup_user(^User, allocator)` hook releases application-specific
owned buffers after framework resources close. It must clear each field as it
releases it so a failed hook can be retried. Plain value-only user data needs no
hook. The framework does not guess how application data should be destroyed.

Keep ownership across temporary tree exit and finalize at terminal destruction.
Use checked explicit close before deleting an owner with pending work, and queue
node destruction outside callbacks. Do not add an empty reload hook to owned
allocator/catalog state.

The [authored sample](../../../examples/kit_box3d_authoring/README.md) retains its
separate verification telemetry while using this owner for lifecycle work.

# Shared turret

Equip **shared turret** in an ability slot in staging. Q/E deploys it using the
normal ability targeting. Walk within 64 units and press **T** to operate it;
aim/fire with the mouse, and press T again to release it. Any living player can
take a vacant turret. An occupied turret cannot be stolen.

The stock turret has **24 shared rounds**, fires every six simulation ticks, and
does two damage per ballistic shot. Switching operators preserves ammunition and
the next-shot deadline. The final shot removes the turret and its occupancy in
the same simulation tick. It never also fires the operator's handheld weapon in
that tick; continuing to hold fire after dismount resumes normal weapon input.

Mounted players stay in place and cannot dash, cast, revive or fire their handheld
weapon. Death, disconnect, player-generation replacement, teleport/warp and floor
cleanup release them. Placement checks arena bounds, cover, line of sight and
spacing; mounting checks range and line of sight. Invalid placement or a full
eight-turret pool spends no cooldown. A full projectile pool spends no round.

Try `dev/turret_workbench.tscn` with F6, then **Run isolated encounter**. It equips
and deploys the authored ability through normal game actions. The preview and
encounter use the existing ability workbench. For a quiet shared test, launch
the normal host/client with `RSY_RUN=0 RSY_ENCOUNTER=turret`, equip the ability,
ready and start. Everyone needs the matching content-51/K build.

| Responsibility | Source |
| --- | --- |
| Inspector tuning | `data/deployables/shared_turret.tres`, `scripts/defs/turret_def.odin` |
| Ability/cooldown | `data/abilities/turret.tres` (ID 7) |
| Replayable lifetime, occupancy, ammo, firing | `shared/game/turret.odin` |
| Detached view values | `shared/presentation/turrets.odin` |
| Authored node composition | `entities/turret.tscn`, `scripts/views/turret.odin` |
| Typed scene pool and targeted input | `scripts/turret_bridge.odin` |

The turret records its operator's seat and player generation in a `Credit` value.
It needs no second mounted flag on Player, Godot ownership RPC, or timer to
reconcile. Mount/release actions
carry the turret's pool handle, so delayed input cannot operate a replacement
turret that happens to occupy the same slot. Existing reliable action intents own
queueing and outcome tracking; the simulation rule validates mount/release requests.
These actions use receipt timing alongside dash. Held aim/fire remain controls.

Rollback restores turret state with the rest of World. Correcting a predicted
claim also corrects its shots and ammo. The scene pool follows that state through
generation handles and scope changes. Seated clients use the predicted turret
world; spectators use the delayed observed world, including its despawn timing.
The scene handles barrel rotation, color and text; it has no gameplay authority.

Recovery carries occupancy, ammo and the next-shot deadline in the checkpoint.
The real crash fixture kills the deployer's host process while a surviving player
is operating the turret, checks the restored operator/ammo, then hands it to a
third player and empties it. If the departed host was the operator, ordinary
disconnect cleanup releases the turret instead.

Content advances from **50/J to 51/K** (`0x525343524150304b`), protocol 7 unchanged.
The offline converter accepts content 50 as well as prior supported revisions.
Frozen old catalog/action contracts map explicitly to the new representation; old runs
receive an empty turret pool and zero turret definitions/targets. Conversion
preserves their original catalog rather than adding this ability to an existing
run. The historical recording verifier accepts `--content50`. See [saves](saves.md).

The authoring exercise fit the existing framework without adding transport,
rollback, recovery or code-generation primitives. The main extra work was schema
evolution: adding a targeted action and a new ability family required freezing the
old action type and explicitly mapping the extended enum. Gameplay remains a
small value-state feature plus a scene adapter; compatibility code is separate.

Run the focused suite from the repository root:

```sh
nix develop --command bash tests/replay_turret/run.sh
```

It covers contention, handoff, exhaustion, forced dismount, stale handles,
placement/cover/capacity, late correction, occupied checkpoint continuation,
content-50 import, native/WASM equality, the authored workbench, three real peers
and occupied host-crash recovery. Browser compilation and pure WASM execution are
covered; this feature has not had a separate interactive browser or human balance
playtest. See the [implementation receipt](../../docs/replay/turret-progress.md).

# Development actions

`RSY_DEV=1` enables development command submission in the Godot adapter. The
authority admits `Dev_Spawn` only from its local player seat. The shared model
defaults to rejecting it, including when used without the Godot adapter. A remote
client cannot grant itself permission by enabling its own flag or constructing an
action packet. Dedicated servers without a local player seat do not admit it.

`dev_spawn(kind, relative_seat, dx, dy)` returns an action sequence when submitted.
The final verdict arrives through normal action results; submission is not proof
of acceptance. Spawn is an ordinary replayable reducer operation, using the entity
pool and updating query history. Relative positions clamp to the original 40-pixel
arena margin. Capacity or invalid-state refusal cannot partially spawn an entity.
Accepted decisions use the existing action log, deduplication and checkpoints.

The pure `game.action` procedure intentionally performs no external permission
lookup. Run transport-facing requests through the model's admission hook. A custom
adapter that replaces that hook must preserve the development-command restriction
as well as its own checks. The Godot adapter combines it with spray admission.

`dev_walk(x, y, enabled)` is a test input driver. It navigates around authored cover
and stops within 35 pixels of the target; it does not teleport or edit saved state.
It is useful for reproducible setup before an interaction.

The gauntlet gate uses this path after all three waves/rests. Players stop fighting
and walk to a clear setup area; only the host then spawns the original two barrels
at offsets (150, 0) and (150, 50). The guest's attempted development spawn must
receive an Invalid verdict. One ordinary host shot must cause both barrel blasts,
without another clear reward, before all peers compare the complete world.

The action enum changes the schema fingerprint and Scrapyard's experimental
content ID advances to `0x5253435241503041`. Older experimental run archives and
gameplay peers require explicit conversion/update; they are rejected rather than
silently interpreted under the new contract. Profile values are unchanged.

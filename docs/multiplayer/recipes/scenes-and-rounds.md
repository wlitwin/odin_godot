# Coordinate scenes and round transitions

Make every peer understand when a round starts, finishes, and restarts, while
letting Godot load and display the corresponding scene. This guide assumes a
working [Kit](../../kit/quickstart.md) or [Replay Session](../../replay/godot.md)
project and a game with a lobby and one playable level.

Begin with a round transition that reuses the same loaded level. It exposes
the gameplay rules without also requiring asynchronous asset loading. Add a
level change once the state transition works for a late joiner.

## 1. Put shared phase in shared state

Describe the match with a small set of phases and permitted transitions. For
example, a cooperative job might move from Working to Departing to Results,
then accept a Retry or Next Job action.

Keep the phase, round identity, selected layout, and relevant timers under
authority control. A timer that decides a winner should advance from simulation
ticks or the game's authoritative clock, rather than each client's frame delta.
The HUD can display a countdown derived from that state.

| State | Used by the game | Used by presentation |
| --- | --- | --- |
| Round identity | Distinguishes this job from another job on the same map | Clears effects belonging to an earlier round |
| Phase | Permits movement, scoring, retry, or progression | Selects play, departure, and results UI |
| Layout/content ID | Selects collision and gameplay definitions | Selects the matching visuals |
| Start/deadline tick | Determines authoritative timing | Draws the countdown |
| Score and payout | Records the result | Displays the result screen |

A Godot scene path alone cannot express those rules. Two peers can have the
same scene loaded while disagreeing about whether a shot or purchase is allowed.

## 2. Accept a transition through gameplay

Treat Start, Retry, and Next Level as operations with predicates. Check who
may request them, which phase permits them, and which players or assets must
be ready. Receiving a button press does not itself grant permission.

For requests that can outlive a round, include the expected round identity in
the game's request context and validate it against current state. A duplicate
sequence check prevents one request being executed twice; it does not establish
that a distinct request still belongs to the current round.

In ordinary Kit field replication, keep shared match values in the appropriate
replicated game entity and apply accepted authority consequences through commands
or authority steps.
Use player profiles for player-supplied readiness or selection, then validate
them before the authority starts play. [Kit Session](../../kit/session.md)
describes ready-up profiles and locking new admission while allowing reconnects.

For Kit's complete Box3D mode, phase and causal round data belong in `Side`
and its staged game-state callbacks. That mode refuses the ordinary generated
tick/authority-step and scheduled-verb paths; its presentation follows accepted
commit. Use [Kit Box3D](../../kit/box3d.md) for that integration.

In Replay, make the phase and its dependencies part of the World. The model
checks a discrete action and changes the shared state. Dockyard's
[round rules](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_dockyard/modules/dockyard/round.odin)
permit Retry and Next Job for the controlling seat during Results; the view
displays that decision. Scrapyard's
[model actions](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_scrapyard/shared/game/game.odin)
check its ready state and host before starting.

## 3. Define what resets and what survives

Write down the reset policy before implementing it. Position, velocity,
cooldowns, projectiles, delivered cargo, and the round timer usually belong
to a new round. Player identity, a session invitation, or account progress
may outlive it. A retry and a new match can have different policies.

Reset dependent state together. Teleporting a rigid body while retaining an
old velocity, or clearing an inventory while leaving a pending trade active,
creates a partially reset game. For managed Box3D worlds, use the framework's
physics mutation/reset path so complete solver state and gameplay agree;
follow [Box3D multiplayer](../../box3d/multiplayer.md).

Give discontinuous movement the framework's explicit presentation treatment.
Kit provides teleport marking for streamed entities. Replay views need a
clear policy for a changed lifetime, warp, or round. Interpolating a respawn
from the previous position draws travel that never happened in gameplay.

## 4. Load the view without changing the verdict

Once the shared phase is accepted, let each peer prepare its local scene and
assets. If loading must block play, include an explicit readiness policy in
the game flow. A fast host should not silently start an encounter while a
joining client is still loading collision or required visuals.

Immutable content must match the session's content contract. Changing a level's
collision definition while preserving its visible name can still change the
simulation. Choose whether a content change requires a new session or an
explicit supported transition; a scene-change message cannot bypass content
admission.

Separate the lifetime of networking from the lifetime of a view. Keeping a
stable runtime owner outside replaceable presentation nodes can make a level
transition easier. If the runtime belongs to the departing scene, close it
and create the new runtime through its documented lifecycle instead of
retaining pointers to freed scene-owned data.

## 5. Close owners in their documented order

For a Kit game using the generated Boot stack, `<game>_net_detach` releases
the attached stack. On final scene
exit, follow it with destruction of the retained Session wiring. Godot freeing
the node tree does not release every Odin allocation; see
[Kit Boot](../../kit/boot.md).

Replay Session exposes `session_close`; outer owners such as Room own and
drive their Session. Close the outer owner before releasing the callbacks,
transport, storage, catalogs, or Godot instances it retains. Keep runtime owners
at stable addresses during their lifetime and handle close errors before
discarding their storage. See [Replay recovery](../../replay/recovery.md).

## Check the behavior

Join during play, departure, and the results screen. The received state should
explain which phase to show without replaying a “round ended” message. Try
Retry twice, disconnect during loading, and send a request carrying an old
target lifetime or obsolete round context; the game should apply its stated
eligibility policy.

Repeat several rounds in the same process. Look for duplicate network pumps,
old nodes that still receive callbacks, retained effects, and inputs that
survive from a previous round. Compare the next round's initial state with
the intended reset policy rather than relying on a visually empty screen.

Play [Dockyard](https://itchyitches.itch.io/dockyard) to observe the shared job
flow, then follow its round rules and view separately. Use
[testing and debugging](../concepts/testing-and-debugging.md) to exercise the
same transitions with delayed state and interrupted connections.

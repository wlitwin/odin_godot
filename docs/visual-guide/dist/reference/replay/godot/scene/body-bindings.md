# Choosing a body contract

`Simulation_Body2` / `Simulation_Body3` are for replayable World-owned motion.
`Body2` / `Body3` plus `session_body*_frame/sample` are for cooperative Godot solver
motion accepted through the existing ownership protocol. Keep one owner per node;
do not use both contracts concurrently or let an unrelated controller write its
transform. Authored collision geometry/scale remains separate from the pose.

```odin
body: scenegd.Simulation_Body2
ok := scenegd.simulation_body2_attach(&body, rigid_body, .Rigid, visual_child)
error := scenegd.simulation_body2_present(&body, {epoch, view_revision},
    view.Pose2{position=display.position, angle=display.angle}, display.teleport_cut)
```

The simulation-driven binding freezes rigid bodies, applies the selected pose to
node and PhysicsServer, and resets engine interpolation on scope/cut changes.
It preserves authored child offsets and rejects invalid poses or older epochs.
The 3D variant requires a finite unit quaternion. It offers no observation/sample
publication API. Character bodies are supported as passive scene representations;
application controllers must not call move_and_slide on them. Gameplay collision
and movement remain in the replayable model. A passive body is not a substitute
for implementing gameplay collisions there.

The cooperative facade centralizes authority selection and suspension:

```odin
result := scenegd.session_body2_frame(&session, &body, render_delta,
    proc(_: rawptr, world: World) -> (owned.State(owned.Pose2), bool) {
        return world.crate.body, world.crate.alive
    })
if scenegd.body2_simulating(&body) {
    // Apply this frame's authorized/local solver controls.
}
sample, error := scenegd.session_body2_sample(&session, &body, physics_frame)
// Feed nonempty samples to the existing authenticated observation/admission path.
```

Selection reads the latest authority frame, never local prediction. Missing/fenced
state or an absent entity suspends solving/publication. `eligible=false` disables
local solving for game rules such as kickoff or menus while still presenting the
authority pose. Optional presentation state changes observer interpolation only
within the matching owned scope; it grants no publication permission.

Sample rechecks readiness, fencing, pause, client phase and authority epoch, so a
transition between frame selection and sampling cannot publish a stale observation
under a new epoch. Call frame selection before operating the local solver and
sampling. A Room caller passes its Session and includes Room/handoff eligibility
in `eligible`; these helpers do not override Room admission or game permissions.

Existing Body2/Body3 drivers retain the offer/preparing/owner/observer protocol,
full pose/velocity reseeding, revision/epoch rejection and visual correction.
A prepared sample can commit an authority-issued transfer through `owned.accept`;
the helper does not bypass authenticated sender checks or game transition rules.
Absent samples use sequence zero. The adapter remains a presentation/producer owner,
not World state. Parent/body/skin nodes must outlive it; destroy before freeing them.

Godot's solver contacts, joints and hidden caches are not replayable through this
pose protocol. Cooperative recovery reseeds pose/velocity; it does not make Godot
physics deterministic. The existing skin smoothing assumes unit global body scale.
See [Body2 details](body2.md) and [Body3 details](body3.md).

Focused engine checks cover both dimensions: authored offsets, simulation freeze,
invalid poses/old epochs, observer freeze, preparing transfer, accepted samples,
cuts, fencing, recovered epochs and pause. Existing owned-protocol tests remain
unchanged and pass. All binding fixtures compile for WASM.

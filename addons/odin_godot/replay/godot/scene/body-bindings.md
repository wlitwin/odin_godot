<a id="choosing-a-body-contract"></a>

# Selecting simulation or solver motion

Choose the body adapter according to which system computes motion.
`Simulation_Body2` / `Simulation_Body3` display poses from replayable World state.
`Body2` / `Body3`, driven through `session_body*_frame/sample`, use cooperative
Godot solver motion accepted by the entity-ownership protocol.

Give each node one motion adapter. Using both at once, or letting another
controller write its transform, creates conflicting writers. Authored collision
geometry and scale remain separate from the selected pose.

```odin
body: scenegd.Simulation_Body2
ok := scenegd.simulation_body2_attach(&body, rigid_body, .Rigid, visual_child)
error := scenegd.simulation_body2_present(&body, {epoch, view_revision},
    view.Pose2{position=display.position, angle=display.angle}, display.teleport_cut)
```

The simulation-driven binding freezes rigid bodies and applies the selected
pose to both the node and PhysicsServer. It resets engine interpolation when
the presentation scope or teleport cut changes.
It preserves authored child offsets and rejects invalid poses or older epochs.
The 3D variant requires a finite unit quaternion. It offers no observation/sample
publication API. Character bodies are supported as passive scene representations;
application controllers must not call move_and_slide on them. Implement movement
and gameplay collision in the replayable model; the passive Godot body only
represents its result.

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

Frame selection reads the latest authority frame to decide who may operate
the solver; it never takes that permission from local prediction. Missing or
fenced authority state, or an absent entity, suspends solving and publication.
Set `eligible=false` to disable local solving during kickoff or menus while
continuing to display the authority pose. Optional presentation state changes
observer interpolation only within the matching ownership scope and grants no
permission to publish observations.

Sample rechecks readiness, fencing, pause, client phase and authority epoch, so a
transition between frame selection and sampling cannot publish a stale observation
under a new epoch. Call frame selection before operating the local solver and
sampling. A Room caller passes its Session and includes Room/handoff eligibility
in `eligible`; these helpers do not override Room admission or game permissions.

Body2/Body3 retain their existing ownership-transfer stages: an authority offer,
preparation, and selection as owner or observer. The drivers reseed complete
poses and velocities, reject invalid revisions/epochs, and smooth visual
corrections.
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

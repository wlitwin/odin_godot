# Godot angular correction acceptance

Run `nix develop --command bash tests/replay_rotation_godot/run.sh`, or `web_run.sh`
for the exported Chrome/Godot version. `REPLAY_ROTATION_GODOT_OUT` selects logs.

The fixture uses real frozen RigidBody2D/3D scenes and offset/rotated visual children.
It checks visible continuity across a combined pose correction, half-life decay,
authored transforms, unchanged PhysicsServer state during presentation, new-epoch
cuts, observer publication refusal and eventual solver-transform catch-up. The
browser reports success and stops its fixture processing; the harness closes it.

These are controlled adapter checks. The separate owned-body and Slopball network
fixtures exercise live transfer, momentum and gameplay with the same adapters.

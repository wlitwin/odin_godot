# Quickdraw combat presentation

The gunner skin uses the original seat palette directly. The gun and hitscan
beam retain their own colors instead of inheriting a whole-avatar tint. Drone and
lob skins also use their owner's palette directly. The view geometry is stored as
immutable meshes, preserving the original vertices and tint values without asking
Polygon2D to rebuild buffers on color changes.

A decrease in sampled HP starts the original 0.25-second red skin flash. Healing
alone does not start a flash. After a lethal flash, the skin uses the original dark
translucent dead color; the gun and beam remain independent. New lives, initial
observations, departure, resync and epoch changes seed health without flashing.
An empty, unfocused chat panel stays hidden so it does not obscure the actors or
landing cues. Multiple HP changes coalesced into one observation produce one pulse, as in the
original's replicated HP-edge behavior.

The local player's pulse follows authority HP, while remote players follow the
watched HP shown with their bodies. Predicted damage alone does not create a local
hurt pulse. A pulse for an old life cannot color a newly predicted respawn. These
choices preserve the intent of the original replicated-health feedback; the complete
Replay world's prediction and timing still differ from the old mixed-state model.

Landing rings are an addition: the original source has splash damage and a landing
receipt, but no ring renderer. A ring outlines the existing 26-pixel splash radius
with a two-pixel band and fades over 0.3 seconds. Its position comes from the detached
`Landed` occurrence, so the projectile can already be gone. Local speculative events
can begin immediately; watched events follow their journal policy. Update moves an
active ring without restarting it, Cancel removes it, and Confirm does not replay it.
Consumed IDs remain suppressed after cancellation, expiry and same-epoch resync.

The component uses the existing bounded `One_Shots` ledger and 64 active ring slots.
Overflow is a counted cosmetic drop, not a simulation mutation or unbounded allocation.
Epoch/reset handling clears active cues and seeds history; leaving a session creates
a fresh ledger so independent sessions may reuse epoch one. Normal acceptance requires
zero dropped rings. Broader stress and human visual comparison remain separate work.

`tests/replay_quickdraw_feedback/run.sh` builds an isolated game and runs its existing
UI/profile tests plus three-peer combat presentation checks. Pure tests cover
health/life boundaries and actual journal update/cancel/reappearance behavior.

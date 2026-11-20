# Rock presentation

A cast supplies the rock’s slot, generation and launch position. A hit adds the
point on the rock’s swept segment and the center and lifetime of the body it
struck. The same information is recorded for the server-motion and owner-motion
games. A reused pool slot gets a new generation.

Every network player and observer draws the party, dwellers and rocks from one
Replay contact view. A rock can appear, hit and retire between two snapshots.
The contact tick shows the rock at impact. Changing floors or starting a new
run cuts the old paths. The owner-motion variant still uses its local producer
for control and action origins. On the authority, an active rock can also
advance by a fraction of its next tick, clipped against visible bodies.

The dot is centered using its actual font size. Damage comes from the simulation.
The hit journal drives the sparks. The current checkpoint fixtures were converted
with their original state and pending inputs intact. Impact recordings were
captured again from those checkpoints under the new event schema.

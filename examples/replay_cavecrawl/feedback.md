# Combat feedback

Cavecrawl now presents its replayed player-hit, dweller-hit, player-death and dweller-death
occurrences through `replay/view.Cues`. The common frontend covers both server
motion and the separately runnable owner-motion profile.

Player death emits the original red pyre color; slain dwellers emit purple sparks;
player and dweller hits emit yellow sparks and a red-to-white 0.3-second flash. The emitter
matches the original authored values: 12 particles, 0.4-second particle lifetime,
one shot, full explosiveness, 180-degree spread and speed 40–90. Detached burst
nodes live for 0.8 seconds under Stage. Their saved occurrence position survives
entity removal. The copied avatar's dormant Pyre node remains non-emitting.

Confirmation does not restart particles. Correction moves an active burst;
cancellation hides and removes it. Consumed IDs remain remembered after expiry or
cancellation. Late joins seed from the snapshot baseline without manufacturing
bursts from old corpses. Epoch changes and floor/run transitions clear prior
visuals. Leaving destroys both nodes and bookkeeping. The presentation layer does
not change gameplay/save/wire schemas; C9/O3 separately version the new simulation
impact events.

The player Hit occurrence also covers dweller bites; these now receive the same
flash/sparks. The original explicit contact renderer was tied to rock tracers, so
this broader damage feedback is a recorded presentation difference.

[C9/O3](impacts.md) adds all dweller contacts, retaining their target generation
for flashes and detached positions for sparks. [Rock views](projectiles.md) now move between fixed simulation ticks, while
render-time cast/contact prediction remains a separate difference from Kit.
Particle paths are cosmetic and are not part of deterministic state or a pixel-equality guarantee.

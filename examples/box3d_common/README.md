# Shared Box3D slice rules

Kit and Replay import this package for the same primitive assets, game state and
recorded intent. It contains no session, history, rollback or presentation loop.
The separate projects remain responsible for their existing framework adapters.

`world(4|32, seed)` creates two player spheres, a contested crate, a hinged box,
optional background boxes, one floor and one sensor. One additional capsule can
be spawned and removed. `assets()` returns the five sorted recovery descriptors;
bind `PROFILE`, actual native build/target, `game_rules()`, schemas and the exact
provider configuration when constructing an adapter. The small and 32-body cases
are distinct measured workloads.

Each tick uses this order:

1. `pre_step` validates both controls and applies bounded impulses/RNG progress.
2. The existing adapter performs exactly one fixed step.
3. `post_step` consumes the adapter's copied sensor observations and returns
   ordered game events.
4. `apply_action` runs for semantic seats 1 and 2, after the step. Emit its event
   only when `applied` is true and `event.serial` is nonzero.

This follows Replay's existing `Model.step` then `Model.action` contract. Kit
queues accepted actions until its settle callback, after its provider step and
sensor processing. Removal therefore leaves native pending input for the next
step. Game state retains retired shape-to-lifetime tombstones until that output
is consumed; a recycled native slot cannot rename an old occurrence.

`Operations` is borrowed only during that staged callback. Native/resource errors
must use the adapter's candidate-abort path. A rejected gameplay predicate makes
no native call and changes no game state. The caller must not retain the operation
table, its user pointer or sensor buffers.

Semantic game seats are independent of ENet/Session peer IDs. Freeze the two
non-spectator players and their mapping before physics attachment and the full
Welcome. Observers have no input driver; a dedicated server has no player driver.

`scripted_control`/`scripted_action` supply reproducible intent outside simulation.
Both players request Spawn together, exercising one accepted and one rejected
game predicate, followed by Remove, Motor, Sleep, Wake and Query. Live input is
sampled outside staged simulation too. Tick/RNG and all future-affecting game
values live in `Game`; renderer state and wall clocks do not drive these rules.

The standalone common test validates 240 ticks for each layout, canonical import
with a pending end, exact 184-tick solver/game/event suffixes, counts within the
current profile and zero native/wrapper teardown. This supports the projects; it
does not establish playable Session integration, a history/resource envelope or
the whole-call 4 ms Gate B target.

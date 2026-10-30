# Stormcaller: a Replay-only feature exercise

The Stormcaller is a new enemy archetype (kind 6). It closes on a living target,
plants its feet, shows its complete danger radius, charges an electrical core and
pulses damage around itself. Step outside the ring or kill it during the wind-up.
The ordinary no-living-target pause behavior remains shared with the other brains.

Default authored settings: 12 HP, movement speed 65, a 140-unit pulse radius,
45-tick wind-up (0.75 seconds at 60 Hz), 2 damage and 150 ticks between pulses.
Spawn grace is 60 ticks. Regular wave runs introduce it from floor 2 where the
admitted catalog enables the component. Existing migrated catalogs keep the new
component disabled until a new run admits updated definitions.

## Try it

After building the Replay project, run `dev/stormcaller.tscn` with F6 for a live
workbench encounter. It spawns through an admitted development action. Move with
WASD, fire with the mouse, and dodge the warning. `dev/stormcaller_view.tscn` is an
independent cosmetic preview of the composed charge view.

For a fixed encounter through the normal game:

```sh
RSY_ROLE=solo RSY_RUN=0 RSY_ENCOUNTER=stormcaller \
  nix develop --command bash examples/replay_scrapyard/play.sh
```

Choose Ready/Start in the lobby. This training setup fixes starting positions and
holds enemy movement at zero; ordinary waves/workbench use its authored movement.
All network participants need the matching content-50/J build.

## Where the feature lives

| Responsibility | Source |
| --- | --- |
| Inspector attack settings | `scripts/defs/pulse_def.odin`, `data/attacks/storm_pulse.tres` |
| Enemy numbers and component reference | `data/mobs/stormcaller.tres`, MobDef.pulse |
| Immutable baked definition | `content.Pulse_Def` inside the existing mob catalog |
| Tick-owned charge/cooldown | `shared/game/pulse.odin`, composed from existing saved Telegraph/next_act fields |
| AI/spawn/wave integration | Small hooks in brains/combat/run; any non-prop mob with an enabled PulseDef uses the pulse behavior |
| Detached display | Mob_View carries charge state, fraction and gameplay radius |
| Authored appearance | `visuals/enemies/stormcaller.tres` reuses existing art with a cyan tint |
| Local charge animation | `views/components/charge.tscn` and `scripts/views/charge.odin` |
| Full-size warning | Existing Telegraph child receives the actual radius; Titan's growing warning remains unchanged |

The charge component rotates/scales the authored glyph; it cannot deal damage or
complete the attack. The reducer owns every transition. Death uses the existing
telegraph cancellation/death machinery. Host takeover preserves an already-active
charge, matching the existing policy for Titan wind-ups; it does not replay a
completed attack. Cooldown/grace remains ordinary saved state.

No transport, rollback, journal or view-pool implementation needed a feature-specific
change. No Kit or original-game implementation was changed.

## Compatibility

This changes the catalog schema: each mob definition gains a bounded Pulse_Def.
The semantic content ID advances from 49/I to **50/J** (`0x525343524150304a`);
network protocol 7 is unchanged. Old peers cannot silently share the new contract.

The offline converter now accepts content 49 as well as older supported saves.
Historical Mob/Catalog shapes are frozen rather than aliasing today's live structs.
Conversion fills the new component with zeros, preserving the prior catalog and
behavior. It does not add enemies or retrofit new balance settings into an old run.
The source-49 checkpoint fixture was captured with the old code before this edit.
See [save conversion](saves.md) for the existing offline command and identity
requirements; write to a new destination. The recording verifier also exposes `--content49` for the retained historical model.

## What this authoring exercise revealed

The replay/network behavior required ordinary game code and data, with no custom
correction or recovery hook. Scene composition worked: an authored child handles
charge animation and the existing binding handles entity lifetime.

The largest friction was compatibility: old archive types referenced the live
catalog, and tests assumed that adding an epoch was the only schema change. Those
were made explicit/frozen, keeping byte-preservation checks for every old field.

That exercise led to the [authoring tools workflow](authoring-tools.md). Visual
registration now lives in a typed `ScrapEnemyArchetype` Resource, and the enemy view
has one appearance input. Godot and headless code share a canonical bake instead
of separate nested-Resource parsing. The actual historical catalog now has fully
frozen type dependencies, and the feature tests use shared correction/takeover and
native/WASM/peer helpers. The linked feature receipt below remains the historical
record of the original feature implementation.

## Validation

Focused tests cover wind-up timing, warning radius, no repeated pulse, late escape
correction, death interruption, mid-charge checkpoint takeover and conversion of
the real content-49 checkpoint. Native and executed WASM continuation hashes match.
The WASM fixture links normal math through Emscripten and uses sufficient fixed test
arena storage for two servers/checkpoints; its memory allocation is a harness choice.

Three actual Godot processes with 120 ms configured latency see the warning, apply
one inside hit, preserve the dodging player's HP and agree on the final world hash.
The full game compiles for WASM. A separate live workbench check edits PulseDef before
admission and verifies later Resource edits cannot mutate the running World.
Existing 108 model tests and the older offline save CLI checks pass.

```sh
REPLAY_STORM_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_stormcaller/run.sh
```

[Implementation/test evidence](../../docs/replay/results/stormcaller-2026-09-20/README.md)
records the exact scope and initial harness failures. This does not claim new public
server deployment, full browser gameplay or a complete re-run of every old game gate.

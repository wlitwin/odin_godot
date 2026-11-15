# Choose gameplay helpers

Choose a helper according to the system that owns its state and tick. Similar
operations in Kit and Replay have different runtime contracts.

## Script and entity composition

Use [`play`](../kit/play.md) when composing Kit script entities. An embedded
`play.Gun` contributes replicated weapon state and commands to the parent
entity. Your game supplies projectile creation, hit validation, and cross-entity
consequences after acceptance. `play.Puppet` and `Puppet3` stream Godot body
motion from a trusted owner.

Use [`play/sim`](../kit/sim.md) for tick-driven predicted blocks in Kit's
simulation lane. Check field ownership before combining blocks: a reliable
authority field, owner stream, and predicted field follow different clocks.

## Restorable value state

Use [`replay/play`](https://github.com/wlitwin/odin_godot/blob/main/replay/play/README.md)
for helpers that operate on restorable values. Keep their timers, RNG, inventory,
entity lifetime, and other dependencies inside World. Use occurrences to describe
results; Godot effects run outside the step.

Engine Tween steps and callback-bearing flow trees belong to presentation. They
can animate a replayed event but cannot serve as its canonical simulation state.

## Pure algorithms and engine adapters

Range/facing selection, inventory packing, and other pure value algorithms can
be reused when their inputs and outputs fit your model. Engine navigation,
widgets, and visual effects require Godot and must follow scene lifetimes.

The [library map](index.md) links to each package's guide. Check imports and
ownership before extracting a helper; the package name alone does not establish
that it is independent of a framework.

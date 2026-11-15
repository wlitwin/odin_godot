# Compose gameplay systems

Choose gameplay components according to who owns their state and tick. Use
[the gameplay helper guide](libraries/gameplay.md) for Kit components, Replay
value helpers, and engine presentation.

- [Kit components](kit/play.md): embedded weapons, health, abilities, channels, and bodies.
- [Kit simulation](kit/sim.md): predicted movement and cooldown blocks.
- [Replay World and history](replay/architecture.md): values that restore together.
- [Presentation](replay/presentation.md): effects outside replayed steps.
- [Timed sequences](libraries/flow.md): local orchestration and cleanup.

Cross-entity mutations and authority rules remain game code. Check the helper's
runtime contract before composing it with another framework.

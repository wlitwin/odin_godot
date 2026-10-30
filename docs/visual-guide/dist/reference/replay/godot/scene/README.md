# Replay scene adapters

Import `scenegd "godot:replay/godot/scene"` for Godot presentation and authored
content. Gameplay values come from Replay; these owners keep Godot nodes,
Resources, callbacks and visual lifetimes outside the replayable World.

Choose the helper for the scene's lifetime:

- `Script_Binding` borrows an existing authored scene. Use `script_bind`,
  `script_present` and `script_release`; the scene keeps its Godot lifetime.
- `View_Pool2` owns a bounded set of entity scene instances. Use
  `view_pool_load`, `view_pool_present` and `view_pool_destroy` with explicit
  generation handles and view scopes.
- `Script_Archetypes` combines typed scene scripts with retained scenes and
  appearance Resources. Its descriptor has one optional report-returning
  `validate` callback.
- `Bake_Context`, `Resource_Batch` and `Archetype_Assets` validate authored
  Resources and scenes, then publish copied gameplay values or retained local
  presentation assets.
- `Audio_Pool`, effect routes and body adapters provide bounded presentation
  and explicit physics ownership. `session_body*` and `session_tick_phase`
  consume the public Session lifecycle.

Keep live owners and borrowed callback configuration at stable addresses.
Destroy them before their parent nodes or compiled script module disappear.
The framework owns pooled root transforms; scene-local scripts own their child
animation. A detached display value can be copied; a live pool or binding cannot.

Use `replaygd "godot:replay/godot"` for Session/Room/Party. Scene adapters import
that lifecycle package when they need it, keeping presentation optional for a
game that only uses networking. See [typed adapters](adapter-bindings.md),
[view pools](view-pools.md), [body contracts](body-bindings.md) and the
[checked recipes](../../../examples/replay_recipes/README.md).

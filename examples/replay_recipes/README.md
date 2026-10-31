# Checked API recipes

`recipes.odin` instantiates three documented flows with the existing Hello/Duel
models. Session runs a direct network simulation; Party stores enrollment before
opening a Room for coordinated authority recovery; admitted P2P binds authenticated
peers to a runtime that exchanges inputs and retains simulation history. It is
a compile-checked reference, not another game or a claim that compilation validates networking.
The actual runnable counterparts are linked in [getting started](../../replay/getting-started.md).

```sh
nix develop --command bash tests/replay_recipes/run.sh
```

Keep runtime-owning structs at stable memory addresses. Pump Party before
using its grant and keep it alive while RTC/Direct borrows authorization. Consume all presentation
changes before the next frame. Use Room for elected authority recovery; a direct
Session save/resume does not elect or fence hosts. The examples return errors;
the embedding chooses UI/retry behavior and supplies its own content IDs.

`bridge.odin` also checks detached actor display, typed scene baking, and Room
signal-action submission/results. `tests/replay_nodes` checks actual node, input,
effect, and body lifecycles.

The recipe gate checks native and WASM builds with Odin's unused/shadowing, style,
semicolon and tab checks scoped to `replay_recipes`, with warnings treated as
errors. Imported generated bindings have their own style; global `-strict-style`
and `-disallow-do` would also apply to those imports.

The bake example returns a copied definition. Its temporary Store's `Ref` remains
local and expires when the Store is destroyed.

`components.odin` demonstrates an owned actor composed from health, movement and
the shared gun mechanism. It introduces no engine state or component registry.

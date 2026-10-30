# Checked API recipes

`recipes.odin` instantiates the documented Session, Party→Room and admitted
P2P→Runner flows with the existing Hello/Duel models. It is a compile-checked
reference, not another game or a claim that compilation validates networking.
The actual runnable counterparts are linked in [getting started](../../replay/getting-started.md).

```sh
nix develop --command bash tests/replay_recipes/run.sh
```

Owners must remain at stable addresses. Pump Party before using its grant and
keep it alive while RTC/Direct borrows authorization. Consume all presentation
changes before the next frame. Use Room for elected authority recovery; a direct
Session save/resume does not elect or fence hosts. The examples return errors;
the embedding chooses UI/retry behavior and supplies its own content IDs.

`bridge.odin` also checks detached actor display, typed scene baking and Room signal-action submission/results. Actual node, input, effect and body lifecycle checks live in `tests/replay_nodes`.

The recipe gate checks native and WASM builds with Odin's unused/shadowing, style,
semicolon and tab checks scoped to `replay_recipes`, with warnings treated as
errors. Imported generated bindings have their own style; global `-strict-style`
and `-disallow-do` would also apply to those imports.

The bake example returns a copied definition. Its temporary Store's `Ref` remains
local and expires when the Store is destroyed.

`components.odin` demonstrates an owned actor composed from health, movement and
the shared gun mechanism. It introduces no engine state or component registry.

# Godot helper ownership gate

```sh
nix develop --command bash tests/godot_lifetimes/run.sh
```

This real-engine test checks temporary references used by the handwritten Godot
helpers and Kit adapters. It binds/erases 128 keyboard/mouse action pairs, repeats
multiplayer queries 128 times, replaces offline peers eight times, performs 64
file write/read pairs, and waits for 64 hit-flash tweens to finish. Live-object or
reference-count growth must be zero, and shutdown must report no leaked objects.
The same script package is type-checked for WASM.

`gd.release_ref` consumes one owned RefCounted reference. It is nil-safe and does
not clear the caller's handle. Use it for owned factory/getter results, including
`gd.node_get_multiplayer` and the `gd.multiplayer` convenience function. Do not
apply it to borrowed Node handles or objects borrowed from a Variant. Exported
resource fields assigned by Godot have their own runtime-managed references.

For signal wiring, `gd.on_peer_connected` / `gd.on_peer_disconnected` manage the
temporary MultiplayerAPI reference. If the API itself is needed:

```odin
mp := gd.multiplayer(owner)
defer gd.release_ref(mp)
// Use mp while this owned reference is held.
```

Constructed input events, ENet/offline peers and completed tweens/file handles
must also release the caller's reference. The helpers do this after the engine
retains whatever it needs. A returned reference is distinct from the engine's
longer-lived ownership; releasing the caller's reference does not detach a live
peer or remove an InputMap binding.

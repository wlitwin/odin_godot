# Browser UI acceptance

The UI gate runs three independent Chrome processes against the actual exported
Scrapyard game and local authenticated WebRTC room fixture. It drives real canvas
keyboard/mouse input for chat, middle-mouse pings, shop cards, ability keys and
revival. A query-parameter-gated test node supplies observations and prepares
funds/wounds/jams through the existing admitted development actions. Ordnance
checks use the existing manual firing-control driver and bounded scene samples.

```sh
RSB_UI_LOGS=/absolute/output/directory \
  nix develop --command bash examples/replay_scrapyard/web_ui_run.sh
```

The gate first checks muster previews, both picker directions, readiness clearing,
host Start and late Drop In through actual buttons. It then covers chat focus/cancellation and plain text, late-join chat history
without expired markers, ping delivery/expiry, purchase accounting without gunfire,
plate/jam/cooldown HUD state, borrowed camera/revival, rail contact sparks,
grenade bounce/embers/fuse expiry, Escape menu input/focus/resizing, tally release
while chatting, slime/sparkjar/spit discs on the owner and remote screens, and
filled nova fades, single buff bursts, constant zone fill/expiry and common
whole-world hashes. It also checks the local/remote cone distinction and recorded
spread bolts, then the natural barrel wipe and next-yard recovery. It quits one peer through the
menu and verifies the remaining yard continues and removes that player row.
It uses an empty single wave to reach the shop, later adds one spitter for the
disc check, and disables audio. It does not
replace the separate combat, migration, storage or hardware-listening gates.

`REPLAY_PREBUILT=1` reuses current native/WASM artifacts but still runs the Godot
release export. Run it inside the Nix shell: the export plugin needs the compiler
toolchain even when the script's explicit build stage is skipped.

[Recorded results](../../docs/replay/results/scrapyard-browser-ui-2026-09-07/README.md)
include inspected captures and a build-time fix. A full-frame fallback assignment
in the chat-history adapter produced costly aggregate lowering; using a separate
owned read removed the aggregate store and restored a short standard web build.
No optimizer passes or gameplay validation were disabled.

Additional browsers/devices, named-observer metadata, broader presentation,
hardware listening, human playtests and full comparison remain requirements.

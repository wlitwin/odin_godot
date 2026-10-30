# Replay — experimental multiplayer library

The addon includes `godot:replay` beside `godot:kit`. Replay uses an explicit value
world, fixed simulation ticks, ordered input/actions and checkpoints. The library
is experimental; its APIs/formats and supported envelopes are not a stable release
promise. Kit and its authoring model remain available independently.

## Start with the included project

Copy the contents of `template/replay/` into a new project that contains this addon.
Build using the packaged `build/build_scripts.sh` (or PowerShell counterpart) with
`ODIN_GODOT_ROOT` pointing at the addon. No source-repository checkout is needed.
The starter moves two value-owned players and atomically transfers a shared coin
into one bag. Its default mode is offline; host/client/observer native modes use
the same simulation model.

The model is in `shared/game/game.odin`; the Godot adapter is in
`scripts/starter.odin`. Choose one starter for a new project rather than copying
two directories with different package declarations into the same scripts module.
The ordinary Hello starter remains the simplest introduction to Odin scripts.

## Main primitives

- `replay.Frame`, `Timeline` and the model's pure step define replayable state.
  Keep pointers, dynamic allocations, Godot nodes/resources and I/O outside frames.
- `replay/net.Model` supplies simulation, action and validation functions.
  The server/client runner handles admission, prediction, correction, action IDs,
  acknowledgements and bounded history. Validate your game-specific permissions.
- `replay/godot.Session` owns a local or network runner and engine transport.
  Pump it every frame and consume presentation changes once. Rendering reads the
  simulation; smoothing never writes display positions back into saved state.
- Checkpoints preserve complete authority state and reconnect/action metadata.
  Recipient projections are separate from complete authority archives.
- `replay/godot.Room` adds coordinator-approved recovery and host migration.
  `Party` handles durable enrollment and setup. A trusted provider and usable
  checkpoint are prerequisites, not configuration labels that confer authority.
- `replay/p2p` is a separate deterministic rollback runner. Its declared math,
  input-delay, prediction and platform requirements still apply.

Library declarations and contracts are in the packaged `replay/` source tree.
Module markdown also contains development-repository examples and test commands;
those require the source repository and are not all part of this downloaded addon.
Use this guide and the included starter for a self-contained consumer path.

The packaged [compatibility policy](../replay/compatibility.md) distinguishes
content/schema/protocol/archive versions and explicit conversion. The
[support assessment](../replay/support.md) lists tested modes, resource bounds and
limitations; links from it into repository evidence require the source checkout.
Native authenticated two-player P2P is available through `P2P_Party` and
`P2P_Direct`, with separate listener and advertised endpoint options. The browser
party flow uses authenticated RTC. Both retain the library's experimental status.

## Capabilities and deployment boundaries

Native ENet and browser RTC are available. Steam requires a compatible GodotSteam
extension and application/account setup; presence of the adapter is not live Steam
acceptance. Native RTC requires a WebRTC extension. Browser RTC needs a reachable
signaling/ICE deployment. Relay-only Coturn and authenticated short-lived relay
credentials have local acceptance, but public infrastructure remains deployment work.

Authority/credential SQLite adapters currently target macOS/Linux and are optional
imports. Browser storage uses IndexedDB. Other native platforms require suitable
storage backends and runtime validation. Save formats have explicit compatibility
checks; do not infer compatibility across experimental revisions or discard corrupt
data to make a load succeed.

The source repository contains separately runnable full-game ports and detailed
evidence/roadmaps. Those assets, development harnesses and result archives are not
included in this addon. Packaging the library does not establish complete game
parity, all-platform runtime support or framework superiority.

Keep the compiler and Godot setup consistent with the addon's
[getting-started guide](getting-started.md), and follow [exporting](exporting.md)
for native/browser builds.

## Godot authoring bridge

The packaged library also includes typed entity/view pools and detached projections,
immutable Resource/scene baking, InputMap and signal-action bindings, declarative
visual/audio routes, and explicit simulation/cooperative body adapters. Start with
[view pools](../replay/godot/view-pools.md), [definitions](../replay/definitions/README.md),
[controls](../replay/godot/controls.md), [effects](../replay/godot/effect-routes.md)
and [body contracts](../replay/godot/body-bindings.md). These owners stay outside
World and reuse existing replay, intent, journal and ownership protocols.

The editor-first layer adds `Script_View(Value, Script)` for ordinary authored Odin
Node scripts. Views can compose child scenes and use normal Godot process callbacks,
while adapters feed detached display values. The source repository's canonical
walkthrough is `examples/replay_scrapyard/editor-first.md`, including independent
enemy, runner and HUD previews. It uses the normal Odin/Godot script generator; no
additional Replay-specific generator or component registry is required.

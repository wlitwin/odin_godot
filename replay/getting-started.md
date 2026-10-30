# Starting a Replay game

Replay keeps gameplay in a typed Odin world and puts devices, networking, scenes
and persistence around it. The same gameplay rules run offline and under a chosen
multiplayer policy. The framework handles history, delivery, correction and
recovery; the game still chooses authority/trust, prediction scope and game rules.

Start with the [Scrapyard authoring guide](../examples/replay_scrapyard/editor-first.md)
for the recommended editor/gameplay split and a complete game example.

## Choose the owner

| Game requirement | Public owner/API | Small runnable reference |
| --- | --- | --- |
| Offline deterministic/value simulation | `Timeline`, `advance`, `revise_input` | [Loot](../examples/replay_loot/README.md) |
| Godot input, scenes and replay presentation | `Session` or a local Timeline plus view adapters | [Hello](../examples/replay_hello/README.md) |
| Listen host or dedicated authoritative server | `Session` with Host/Server/Client/Observer roles | Hello's network scene |
| Co-op with invitations, reconnect and host migration | `Party` → `Room` | [Cavecrawl](../examples/replay_cavecrawl/README.md) |
| Cooperative live Godot body ownership | `owned` plus Body2/Body3 and the authority runner | [Slopball](../examples/replay_slopball/README.md) |
| Competitive authority/prediction and historical queries | `net.Model` policies through Session/Room | [Quickdraw](../examples/replay_quickdraw/README.md), [Claimball](../examples/replay_claimball/README.md) |
| Deterministic peer rollback | `P2P_Party` + native `P2P_Direct` or RTC + `p2p.Runner` | [Duel](../examples/replay_duel/README.md) |

Use the existing example closest to your network policy. Their game-specific
content is not required to use the library. Kit and its original games remain
separate and independently runnable.

[Checked API recipes](../examples/replay_recipes/README.md) instantiate the Session,
Party→Room and admitted P2P→Runner lifecycle calls against the actual public API.
They are checked natively and for WASM by the framework smoke command.

## Author scenes around the World

The [Godot bridge](godot/README.md) provides [typed views](godot/view-pools.md),
[definition baking](definitions/README.md), [device/signal bindings](godot/controls.md),
[effect routes](godot/effect-routes.md) and [body contracts](godot/body-bindings.md).
These owners keep node references and presentation lifetimes outside World while
reusing its replay, action, journal and ownership protocols. Start with explicit
typed callbacks; code generation is not required.

Run the focused bridge gate with `nix develop --command bash tests/replay_bridge/run.sh`.
The [performance assessment](../docs/replay/godot-bridge-performance.md) explains
measured improvements, memory costs and why COW history was deferred.

## First run

From this repository, with its pinned development shell:

```sh
nix develop --command bash examples/replay_loot/run.sh
nix develop --command bash tests/replay_framework/run.sh
```

The first command executes a standalone world, corrects a contested transfer and
checks a resumed timeline against a fresh run. The second is a bounded framework
smoke command: it uses no account, public deployment or full-game parity campaign.
It writes individual receipts and fails if any selected gate fails.

For an existing Odin/Godot project, make this repository available as the `godot`
collection (`-collection:godot=/absolute/path/odin_godot`) and import packages such
as `"godot:replay"`, `"godot:replay/net"` and `"godot:replay/godot"`. Godot scripts
also use this repository's normal scriptgen/extension build pipeline. Core gameplay
packages do not require Godot or generated scene bindings.

## Write gameplay once

Put mutable gameplay state in `World`: entity pools, RNG, inventories, cooldowns,
ownership revisions and scheduled work. Use bounded value types and handles rather
than pointers to nodes or another world's memory. Immutable authored data can live
outside World, but it must be fixed and content-versioned while a session runs.

Write a step that mutates World using its input and `Step.tick`; emit semantic
occurrences through `emit`. Cross-entity actions are ordinary operations on that
world. Do not read device state, wall time or live Godot transforms inside a replayed
step, and do not play sounds or write files there.

Start with `examples/replay_loot/main.odin` for the complete local lifecycle. For
authoritative networking, expose a `net.Model` with step/action callbacks, input
and state validators, and held-input behavior. Hello's
`shared/hello/network.odin` is a compact complete implementation. A model is more
than a toggle: define scheduled controls versus reliable actions explicitly.

## Godot frame loop

Keep Session/Room and their models at stable addresses. Sample devices before the
frame call; use the fixed-tick input helpers to retain short presses. For a direct
Session, call `session_frame`, drain `session_changes`, then present a copied
`session_state`. Check errors and drain all pending changes, not only one small
buffer. `session.control_consumed` distinguishes a
captured input from a frame that merely polled the network; follow the example's
button-edge handling.

For Room, call `room_frame` and consume changes/state from `room.session`.
`room_issue` submits actions and `room_handoff` requests a planned transfer. A
fenced Room must keep pumping control/UI while gameplay waits. Do not make another
authority by changing an epoch yourself. [Room](godot/room.md) owns that transition.

Presentation journals report Begin/Update/Confirm/Cancel. Use their identity-aware
one-shot/cue helpers so correction does not replay a sound or attach a death effect
to a recycled entity. Remote interpolation and correction smoothing use copies;
they must not change simulation values.

## Invitations and recovery

`Party` persists enrollment requests and grants before exposing them to the game.
Open with a service/content ID, storage namespace, endpoint and invite policy;
pump until recent selection is loaded; begin Create, Join or Rejoin. Use
`party_room_options` once its grant is ready, then `room_open`.

A trusted co-op successor receives complete authority state. A competitive
dedicated authority should fail over only to trusted infrastructure. Select those
permissions intentionally; a network role name alone does not grant authority.
See [Party](godot/party.md) and [dedicated rooms](godot/dedicated.md).

For deterministic P2P, `P2P_Party` registers the process and waits for the fixed
roster. Native two-player games can use `P2P_Direct`; browser games use its RTC
configuration. Bind runner slots only to admitted member identities. A fresh
process needs both its stored enrollment and a compatible participant archive;
the surviving runner keeps its history and rebinds the new authenticated generation.
See [P2P setup](godot/p2p_party.md) and [native transport](godot/p2p_direct.md).

Use distinct native profile/database/archive paths for multiple local players.
Same-origin browser tabs share a profile; use separate profiles for independent
participants. Never put credentials or complete authority backups in invitation
URLs. Plain enrollment WS is an explicit loopback development option; production
configuration requires a verified confidential service connection.

## Ownership checklist

- World/frame values are copied; live runtime owners are not. Keep Timeline,
  Session, Room, Party, Router and transport owners at stable addresses.
- Keep model callbacks, immutable definitions and borrowed storage/cache owners
  alive until their users close. Schema owners may also borrow compiler metadata.
- Close dependent gameplay transports/Room before Party and native stores. Destroy
  decoded checkpoints, recordings and schema owners on failure paths too.
- Keep identity storage separate from gameplay archives. A checkpoint contains
  game/ledger state, not live connections or a transferable authority permit.
- Persistent external side effects need an application/service idempotency design;
  a speculative gameplay occurrence is not an exactly-once external transaction.

Read [compatibility](compatibility.md) before changing schemas or gameplay rules.
Use [the framework audit](../docs/replay/framework-audit.md) for actual test scopes
and the remaining release assessment. Experimental support is not a claim that
all engines, platforms, public networks or arbitrary physics are deterministic.

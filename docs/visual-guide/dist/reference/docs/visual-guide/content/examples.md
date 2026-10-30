# Runnable examples

Choose the smallest example that demonstrates the behavior you want to change.
The repository keeps Kit games and Replay games as independent projects. Run
commands from the repository root with its development environment available.

## Scripting and a single-player game

| Example | What to inspect |
| --- | --- |
| [Showcase setup](../../getting-started.md) | A small scene using the script binding and typed engine calls |
| [Survivors](../../../examples/survivors/README.md) | A top-down game with movement, enemies, effects, and authored scenes |

Build a project with `build/build_scripts.sh`, then launch it with the Godot
executable selected by the development shell:

```sh
nix develop
bash build/build_scripts.sh examples/survivors
"$GODOT" --path examples/survivors
```

## Kit multiplayer

| Example | What it demonstrates |
| --- | --- |
| [Hello Net](../../../examples/hello_net/README.md) | The smallest two-peer game with owner motion and shared entity state |
| [Hello Sim](../../../examples/hello_sim/README.md) | The same square with server-authoritative fixed ticks and local prediction |
| [Cavecrawl](../../../examples/cavecrawl/README.md) | Interactions, inventory, AI, session identity, and recovery |
| [Quickdraw](../../../examples/quickdraw/README.md) | Competitive rules, prediction, and historical hit queries |
| [Claimball](../../../examples/claimball/README.md) | A contested ball with local presentation claims |

Start with Hello Net and Hello Sim side by side. Keep an injected-delay run in
the development loop so current-input prediction and watched presentation remain
observable while gameplay changes.

## Replay simulation and networking

| Example | What it demonstrates |
| --- | --- |
| [Loot](../../../examples/replay_loot/README.md) | Complete-world restoration and an independent reference comparison, without Godot |
| [Session starter](../../../build/template/replay/README.md) | A small authored Godot project with direct offline and native network roles |
| [Hello and Loot views](../../../examples/replay_hello/README.md) | Input capture, detached presentation, occurrence reconciliation, and lower-level network integration |
| [Checked recipes](../../../examples/replay_recipes/README.md) | Public lifecycle calls for Session, Party → Room, and admitted P2P setup |
| [Duel](../../../examples/replay_duel/README.md) | Deterministic fixed-roster peer rollback |

The examples have different network policies. Use their own README commands and
test scope rather than inferring that one scene enables every runner feature.

## Scrapyard: follow a complete feature

[Play the live browser build](https://itchyitches.itch.io/scrapyard) to try the game.
The repository's [Replay Scrapyard guide](../../../examples/replay_scrapyard/contributor-guide.md)
then follows a shared turret through authored definitions, input, simulation,
and scene composition. Its workbenches provide isolated actor and HUD previews
as well as encounters that run the actual gameplay rules.

Use the [code guide](../../../examples/replay_scrapyard/code-guide.md) to find an
input handler, frame service, simulation rule, or view. Use the feature guide's
focused tests before running a full multiplayer scenario.

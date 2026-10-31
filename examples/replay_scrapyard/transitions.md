# Run transitions

The authored [transition scene](ui/transitions.tscn) displays the large
departure countdown, wipe summary, and recovery note from the original game,
plus a compact current wave/rest display. A pure `shared/flow` projection derives the
display from confirmed world state and its tick. There is no local countdown
deadline or remembered stage edge to recover.

The wave panel reports incoming/alive enemies, the next wave's saved rest deadline,
the final securing interval and floor clear. The original announced wave changes
through system chat; this current-state panel does not replace that historical
feed. [Chat and yard history](chat.md) implement that separate retained feed.

While the crew gathers, the large countdown reads the same saved departure ticks
as the gate and status line. Cancellation hides it, and its tint uses the original
within-second pulse. The existing authoritative audio observer supplies one tick
sound and small camera jolt per observed second change. Initial/duplicate/old
observations and restore/epoch boundaries remain silent; a snapshot gap coalesces
missed ticks rather than playing a burst of old sounds.

The wipe summary reads floor, kills, lost scrap and retained cores before reset
clears the temporary values. Spectators receive a crew summary without invented
personal totals. The recovery note reads Room phase even while gameplay frames
are unavailable, hides the frozen countdown/wave panel, and clears once the room
is running again. Neither these nodes nor their visibility enter checkpoints.

Validation is part of the existing commands:

```sh
nix develop --command bash tests/replay_scrapyard/run.sh
nix develop --command bash examples/replay_scrapyard/run_loop.sh
nix develop --command bash examples/replay_scrapyard/gauntlet_run.sh
nix develop --command bash examples/replay_scrapyard/migration_run.sh
```

[Recorded evidence](../../docs/replay/results/scrapyard-transitions-2026-09-07/README.md)
includes real checkpoint reconstruction at a new epoch, countdown audio boundaries,
three-peer wave/rest and run tests, and planned/crash recovery narration. Native
captures use Dummy audio; WASM has a compile check for this slice. Browser/platform
interaction, hardware listening, broader UI parity and the full
comparison remain requirements. The [downed-player camera](camera.md) has
separate revival, warp and host-loss checks.

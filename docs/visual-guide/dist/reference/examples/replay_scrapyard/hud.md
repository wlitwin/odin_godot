# Combat HUD

The editable [HUD scene](ui/hud.tscn) restores the original health plate, three
cooldown pips, draining status squares, large magazine display, Titan health bar
and nearby-teammate revive prompt. It shares the copied steel theme with the
counter. The scene owns layout and node lifetime; `scripts/hud.odin` supplies values.

The game's adapter passes the predicted local player and tick plus the confirmed
world into the HUD each frame. Health, ammunition, ability cooldowns and dash
readiness therefore follow the predicted player state used for local movement. Boss health and
downed-teammate eligibility use confirmed state; the local revive hold displays
its progress. A spectator sees the boss bar without personal health/ammo panels.
The HUD retains neither a world nor a Session and makes no gameplay decisions.

Health drains and changes color, including the plate's increased maximum. Q/E
and Shift pips consume/refill through ordinary casts and dashes; status squares
use catalog colors and remaining duration. The magazine distinguishes ready,
low, jammed and reloading states, rises above the counter during a floor clear,
and returns to its authored offsets on descent. The boss bar hides on death.

Original dimensions/colors/texture regions come from the original `ui/hud.tscn`
and `scripts/hud.odin`. This port labels its selected ability slots Q/E and its
revive key F. The boss plate sits below the existing selected-ability name line;
the prompt adds hold progress. These are authored adaptations rather than a
pixel-identical HUD claim. Fill extents and magazine offsets are cached from the
scene at ready, so editing those dimensions does not require renderer constants.

```sh
nix develop --command bash examples/replay_scrapyard/hud_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_HUD_CAPTURE=/absolute/existing/output/directory \
  nix develop --command bash examples/replay_scrapyard/hud_run.sh
```

The gate drives the actual game in the workbench: preparation uses admitted
development actions, then normal firing, casts, dash, purchases and boss combat
exercise the displays. `revive_run.sh` checks the prompt across a multiplayer
hold/cancel/completion, and `run_loop.sh` checks magazine placement across clears
and descent. Existing workbench and shop gates remain runnable.

See [evidence](../../docs/replay/results/scrapyard-hud-2026-09-07/README.md).
Native captures use Dummy audio because the local CoreAudio issue remains open.
[Run transitions](transitions.md) are implemented. Browser interaction,
additional platforms, listening/feel comparisons and
broader UI parity remain work. The [downed-player camera](camera.md) has separate
implementation and tests. This HUD evidence does not establish completion of
the full roadmap.

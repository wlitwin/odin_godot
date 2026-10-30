# Escape menu and tally

The menu and tally are separate authored scenes using the original steel theme.
The Escape menu dims the whole local view, centers horizontally and scrolls at
smaller window heights. It keeps the existing save, spray, invite and settings
controls and adds Quit. Quit first unloads the game and closes its session. Native builds allow a brief
cleanup interval and then exit; browser builds display a closed-yard screen and
leave the tab open.

Menu input does not move, dash, shoot, cast, ping or buy. The simulation and
networking continue. Resume gets keyboard focus when the menu opens, and closing
it consumes that frame's input so Enter does not also focus chat or a click fire
a shot. Physical held-key state is retained while pending button presses are
discarded, so holding Shift through Resume does not create a fresh dash. Tab opens the centered tally and releases unrelated gameplay UI focus;
releasing Tab still closes the tally while chat has focus.

The tally reads confirmed gameplay counters for connected players: kills, damage,
healing credit (Mends), scrap and cores, plus the original registered Deaths
column and application round-trip time (Ping ms). Observers do not acquire player rows.
The original registers deaths but never credits runner downs as deaths; that
column remains zero here too. Telemetry is session metadata from the current
authority, with zero for its local seat and `--` until a peer has a fresh sample.
The [telemetry component](../../replay/telemetry/README.md) measures application
queues/pump time as well as transit. It is independent of the gameplay world,
actions, events and checkpoints; content remains 45.

```sh
nix develop --command bash examples/replay_scrapyard/menu_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy RSY_MENU_QUIT=1 \
  RSY_MENU_CAPTURE=/absolute/existing/directory \
  nix develop --command bash examples/replay_scrapyard/menu_run.sh
RSY_ARMORY=mend nix develop --command bash examples/replay_scrapyard/combat_run.sh
```

The [browser UI gate](browser_ui.md) exercises the same menu, resizing, tally/chat
focus and peer departure, alongside the earlier UI and ordnance checks.
[Evidence](../../docs/replay/results/scrapyard-menu-2026-09-07/README.md) records the
native/browser results and a communications-adapter regression found during this
work. A gameplay resync now preserves chat on the still-admitted connection;
fencing, failed admission and new connection/epoch boundaries retain their guards.

Broader actor presentation parity, additional platform and browser tests, hardware
listening, playtests and full M9 comparisons remain requirements.

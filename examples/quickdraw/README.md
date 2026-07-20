# quickdraw — the kit/sim showcase

A top-down western duel whose PREMISE is lag compensation: a quickdraw is
unplayable unless your shots land where YOUR screen aimed. This is the
server-authority resim companion's reference game, the way cavecrawl and
slopball are the coop kit's:

- **Movement** is `gd:"predict"` state stepped by one `@(gd_tick)`
  proc — server-simulated from inputs, predicted on your screen (strafe and
  dash answer the stick at any latency), reconciled when they disagree, the
  corrections glided by the render-error smoother.
- **The revolver** is hitscan judged by `ksim.lane_rewound`: the server winds
  every target back to what the shooter's screen was drawing — the view is
  bound to the very input packet that pulled the trigger.
- **hp, score, chat, roster** ride the coop kit's delta lane beside it,
  unchanged — one game, both netcodes.

Run it:

```sh
bash build/build_scripts.sh examples/quickdraw
$GODOT --path examples/quickdraw            # host a duel, join from a second window
QD_LATENCY=120 $GODOT --path examples/quickdraw   # feel it under 240ms RTT

bash examples/quickdraw/run.sh          # solo gate (headless, QUICKDRAW_SINGLE_OK)
bash examples/quickdraw/native_run.sh   # the duel acid: rewound hits vs live misses, A/B
```

WASD move · mouse aim · click fire · space dash · tab scores · enter chat.
Env: `QD_ROLE` (host/join/single/serve) · `QD_PORT` · `QD_NAME` · `QD_TOKEN` ·
`QD_LATENCY` (ms, one-way) · `QD_BOT` (orbit/strafer/deadeye) · `QD_NOREWIND`
(judge shots live — the acid's control arm; feel free to feel the difference).

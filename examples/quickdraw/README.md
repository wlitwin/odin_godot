<a id="quickdraw--the-kitsim-showcase"></a>

# Quickdraw — lag-compensated hitscan

Run this top-down western duel to study lag compensation: the server judges a
shot against historical target poses associated with the shooter's firing input.
Quickdraw uses Kit's `kit/sim` server-authority simulation, with local prediction
and replay after correction:

- **Movement** is `gd:"predict"` state stepped by one `@(gd_tick)`
  proc — server-simulated from inputs, predicted on your screen (strafe and
  dash respond locally), corrected when authority state disagrees, and replayed
  from that accepted state. The render-error smoother eases the visible correction.
- **The revolver** is hitscan judged by `ksim.lane_rewound`. The server
  reconstructs target poses from recorded snapshots associated with the firing
  input packet, subject to the lane's rewind limits.
- **hp, score, chat, roster** use the co-op Kit's delta lane, which replicates
  changed fields alongside the simulation.

The generated attach starts from `.Listen_Server_Action` and overrides only
Quickdraw's deliberate half-second favor-the-shooter rewind and teleport cut.
This makes the timing policy visible without hand-assembling a lane config.

Run it:

```sh
bash build/build_scripts.sh examples/quickdraw
$GODOT --path examples/quickdraw            # host a duel, join from a second window
QD_LATENCY=120 $GODOT --path examples/quickdraw   # compare shot judgment under 240ms RTT

bash examples/quickdraw/run.sh          # solo gate (headless, QUICKDRAW_SINGLE_OK)
bash examples/quickdraw/native_run.sh   # integration test: rewound hits vs live misses
```

WASD move · mouse aim · click fire · space dash · tab scores · enter chat.
Env: `QD_ROLE` (host/join/single/serve) · `QD_PORT` · `QD_NAME` · `QD_TOKEN` ·
`QD_LATENCY` (ms, one-way) · `QD_BOT` (orbit/strafer/deadeye) · `QD_NOREWIND`
(judge shots live, providing the comparison case for the integration test).

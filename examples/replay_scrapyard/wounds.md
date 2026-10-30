# Directional wounds

The local player now receives the original red wound chevron, 30 pixels toward
the hit origin, fading over 0.55 seconds. It stays at the location of that hit as
the player moves. Spectators and other players do not receive that personal cue.

`Hurt.position` already means damage origin. The saved collision-proxy history
provides the victim's position at the event tick, including a fatal hit. The helper
checks both current and recorded generations. Missing/expired history or a replaced
body suppresses the historical effect; self-origin damage supplies no direction.
This avoids inventing a bearing from later positions.

The same geometry now places the hurt burst and spatial sound at the victim.
The earlier feedback/audio mapping had treated the origin as the victim position.
No gameplay, event, content or checkpoint schema changed. Direction nodes share
the feedback ledger and scope cleanup, with a cap of 32 active indicators.

```sh
nix develop --command bash examples/replay_scrapyard/wounds_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_WOUND_CAPTURE=/absolute/output/wound.png \
  nix develop --command bash examples/replay_scrapyard/wounds_run.sh
```

[Evidence](../../docs/replay/results/scrapyard-wounds-2026-09-07/README.md) includes
historical-position/generation tests, a live stationary-marker test and faulted
three-peer revival. History is bounded to the existing proxy window; omitted
feedback is counted. Browser visuals, hardware listening and wider failure cases
remain part of full validation.

For wall effects, [wall contacts](walls.md) retain explicit contact information
from the simulation. Projectile disappearance alone cannot distinguish a wall hit
from a body hit or timeout. Broader actor/menu behavior, other platforms, playtests
and full comparison remain requirements.

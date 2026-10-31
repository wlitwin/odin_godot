# Area effects and buff bursts

Novas, reaction/lob-impact flashes and grenade blasts use filled 24-point
discs at depth 8, with their existing radius and payload RGB. Nova base alpha is
0.5; reaction/blast base alpha is 0.45. Over the displayed flash lifetime they
expand from 0.92 to 1.06 times the radius while fading to zero. Late observations
start partway through that curve, and expiration/correction removes the view.

The original uses a 0.28-second local announcement clock. Replay retains its
existing 17-tick flash lifetime (about 0.283 seconds at 60 Hz), deriving progress
from displayed state. Nova and reaction discs use observed state; grenade blasts
retain predicted local / observed remote selection. Separate bounded banks keep
predicted and observed effect lifetimes independent. This is presentation
metadata only: the simulation's flash, action/event, content and checkpoint formats are unchanged.

Standing zones are filled 24-point discs, radius from their catalog row and alpha
0.22. Payload RGB is used when its tint is visible; otherwise the original ember
fallback applies. They keep their scale, position and alpha until the simulated
zone expires. The effective depth is 2, matching the original zone parent's depth
1 plus its disc child's depth 1. Late join and migration display an existing zone
without a separate launch event.

Buffs emit the original warm 12-particle, 0.4-second burst at the wearer recorded
in the cast flash. A forward-observation tracker produces it once per new cast;
initial observations, epoch/run/floor replacement and rewind/replay stay silent.
It retains its highest observed tick so rewinding cannot replay an old burst.
Existing view-reset/floor/epoch cleanup retires the particles. If a flash begins
and expires between displayed observations, no burst is emitted afterward.
The existing bounded feedback pool owns and retires the emitter.

```sh
nix develop --command bash examples/replay_scrapyard/area_view_run.sh
REPLAY_PREBUILT=1 RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_AREA_CAPTURE=/absolute/existing/output/directory \
  GODOT=/path/to/Godot bash examples/replay_scrapyard/area_view_run.sh
```

The native fixture checks nova radius/color/expansion/fade, a zone's constant fill
through its last ticks and removal, and buff wearer/particle configuration,
single emission and cleanup, plus the disc from a slime landing. Browser acceptance records the corresponding nodes
on all three peers. Migration checks the restored filled zone on the promoted
host, alongside the existing restored-lob and continued-combat requirements.

[Cast paths](cast_paths.md) now cover cone tongues and recorded spread bolts.
Remaining impact details, broader devices,
audio listening and paired timing/feel evaluation remain work. See [evidence](../../docs/replay/results/scrapyard-areas-2026-09-08/README.md)
and the [port ledger](roadmap.md).


The renderer uses immutable ArrayMesh instances for procedural polygons.
Color/alpha use instance self modulation; arcs reuse one unit polygon and an affine
basis that preserves the existing kink, width and recorded endpoints. Node pools,
visibility, lifetimes and simulation formats remain unchanged. This avoids the
stock web renderer's Polygon2D index-update path, including during viewport resize.
See the [rendering audit](../../docs/replay/results/immutable-polygons-2026-09-13/README.md).

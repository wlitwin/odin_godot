# Actor presentation

Downed runners now freeze their idle frame, tilt 1.4 radians, dim, hide their gun
and reload/muzzle cues, and display a pulsing beacon. Revival and respawn restore
the upright pose. Disconnected living runners use the original gray ghost tint.
The logical rig and nameplate stay upright so camera tracking and names remain
stable; the body sprite carries the tilt and the beacon stays above it.

The existing weapons/UI sheets supply four muzzle cells and the overhead RELOAD!
flag. Shot and hurt journal changes drive short visual cues. Confirmation/update
does not restart a cue, cancellation only clears its current identity, and old
epoch/tick events cannot replace a newer cue. Generation/warp/epoch boundaries
reset transient state. The reload flag and downed pose derive from the displayed
player state, including local prediction and remote presentation.

Enemies now use attack rows when stopped near living prey or winding a boss slam,
face nearby prey, and use the original row frame counts and 12-FPS death playback.
Observed health loss produces a short hit flash and wobble. Initial observations,
rewinds and epoch/body replacements seed silently. The typed view adapter manages scene lifetime and gives a reused simulation slot
a fresh scene instance,
including when a zombie slot becomes a barrel; rotation/facing/cue state cannot
leak from the previous entity. Status
washes follow the original last-visible-status rule and damaging-status flicker.

```sh
nix develop --command bash examples/replay_scrapyard/actors_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_ACTOR_CAPTURE=/absolute/existing/output/directory \
  nix develop --command bash examples/replay_scrapyard/actors_run.sh
```

The gate uses the actual workbench/game and ordinary firing, damage, reset and
enemy lifecycles. It checks cue decay, hidden equipment while down, frozen body
animation, respawn, attack facing, death and fresh prop binding after slot reuse. Revival and
watched-host-crash fixtures also inspect downed/revived/ghost poses.

See [evidence](../../docs/replay/results/scrapyard-actors-2026-09-07/README.md).
Native captures use Dummy audio, and this slice has a WASM compile check.
[Combat feedback](feedback.md) now supplies bursts, debris and damage numbers.
[Wall contacts](walls.md), [grenade views](ordnance_view.md) and [glob discs](globs.md)
now have separate implementation/evidence. Remaining ability/UI presentation,
broader browser coverage, hardware listening, playtests and full comparison remain work.
No gameplay schema or checkpoint fields changed.

[Screen effects](screen.md) now cover lens kicks, vignette and transition veil.

Enemy/loot views now use the [typed bridge integration](bridge.md). The older linked
actor evidence predates this ownership change; current focused receipts are linked
from the bridge assessment.

# Rail and grenade presentation

Lance and mender beams emit the existing confirmed Wall occurrence when their
cover sweep clips the beam. The same resolved endpoint and normal drive the
warm spark fan and spatial Hit cue. A distinct rail event key separates player
lifetimes from projectile-pool lifetimes, including when both hit the same cover
in one tick. Rail piercing, first-friend healing and historical-query refusal
are unchanged; an unavailable body query still has a valid visible beam against
current static cover.

These cues use the existing content-45 Wall payload and wire contract. No world,
action, event or checkpoint schema changes. The extra Wall occurrences do not change simulation state. The existing conservative cosmetic capacity reservation also
covers rails. Unlike the original delayed cosmetic booking, rail sparks accompany
the confirmed hitscan result; timing/feel needs paired playtesting.

Grenades preserve their three-leg carom, arena-wall bounce, restitution and
flesh/fuse detonation. They draw the original six-point shell instead of a thick
line. They leave four-point ember motes sampled from confirmed flight positions
at three-tick intervals. Local shells retain prediction; trails follow authority.
Initial/restored observations are silent, duplicate ticks add nothing, skipped
snapshots do not generate invented intermediate motes, and reused projectile
slots get a new trail baseline.

The shell pool has 128 nodes. The ember pool has 512 nodes, with counted overflow;
motes stay stationary and fade over 0.4 seconds. Epoch, resync, floor/run changes
and shutdown clear them. The pure trail sampler also detects backward ticks and
rejects stale epochs. Grenade bounces emit no terminal wall sparks, matching the
original distinction between a bouncing shell and a stopped slug.

```sh
nix develop --command bash examples/replay_scrapyard/ordnance_view_run.sh
nix develop --command bash examples/replay_scrapyard/grenade_migration_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_ORDNANCE_CAPTURE=/absolute/existing/directory \
  nix develop --command bash examples/replay_scrapyard/ordnance_view_run.sh
```

The [browser UI gate](browser_ui.md) additionally selects both rail weapons and
the lobber through shop cards, drives normal firing controls, and records the
transient scene geometry on all three peers. It checks common whole-world hashes
after combat. See the [evidence](../../docs/replay/results/scrapyard-ordnance-view-2026-09-07/README.md)
for actual outcomes and limits. Broader platform coverage, hardware listening,
remaining actor/menu parity, playtests and full M9 comparison remain work.

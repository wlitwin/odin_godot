# Screen effects

The original health vignette, brief zoom kicks and floor veil render above
the yard and below the HUD. The copied vignette fills the viewport and both
overlays ignore mouse input. Health at 1–3 HP drives the red pulse; healing above
that range or becoming downed hides it.

Boss arrival and nearby kills can kick zoom, which eases to the authored base.
The existing setting is labelled “Camera motion” because it controls position
shake and zoom. Turning it off immediately clears both. The vignette and floor
veil remain separate informational effects. Initial/epoch observations establish
a silent baseline; later run/floor changes trigger the veil. Gameplay, settings
records and checkpoint schemas are unchanged.

```sh
nix develop --command bash examples/replay_scrapyard/screen_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_SCREEN_CAPTURE=/absolute/existing/output/directory \
  nix develop --command bash examples/replay_scrapyard/screen_run.sh
nix develop --command bash examples/replay_scrapyard/web_ui_run.sh
```

[Evidence](../../docs/replay/results/scrapyard-screen-2026-09-07/README.md) covers
health transitions, resizing, boss kick, motion-off combat, veil expiry and actual
browser behavior. Wall impacts, remaining actor/menu details,
other browsers/devices, hardware audio, playtests and full comparison remain work.

[Directional wounds](wounds.md) are implemented separately with historical geometry.

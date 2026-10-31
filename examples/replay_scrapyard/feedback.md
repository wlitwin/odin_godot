# Combat feedback

Hit/dash/pickup bursts, layered death/blast bursts, debris, enemy damage numbers
and pickup/healing text use bounded presentation pools. Journal effects
use Replay's one-shot ledger; enemy numbers use each target's observed HP loss
and generation/tick identity. No simulation or checkpoint fields are added.

Confirmation or an update does not restart an effect. Cancellation removes only the
matching identity; epoch/resync and floor/run changes clear old views. Initial or
restored enemy observations seed silently. Damage numbers can combine changes
between observations; pickup/heal totals follow the existing aggregated events.

The original 12-particle bursts and floating-text motion supply the basic look.
The pools cap burst/text/debris nodes at 256/128/256, with counted overflow. Their
lifetimes are 0.8/0.9/0.55 seconds respectively. These bounds limit visuals, not
gameplay damage or drops.

```sh
nix develop --command bash examples/replay_scrapyard/feedback_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_FEEDBACK_CAPTURE=/absolute/existing/output/directory \
  nix develop --command bash examples/replay_scrapyard/feedback_run.sh
```

[Evidence](../../docs/replay/results/scrapyard-feedback-2026-09-07/README.md) covers
live damage/pickup, expiry, floor changes, faulted stress and recovery. The frame timer includes deferred feedback/audio/social upkeep. Earlier
measurements used a narrower scope. Native captures use Dummy audio, and WASM is compile-checked.
Broader browser visuals, hardware listening, playtests and full comparison remain requirements.

[Screen effects](screen.md) restore lens kicks, vignette and transition veil.

[Directional wounds](wounds.md) use recorded geometry and correct the hurt
burst's placement at the victim rather than the origin.

[Wall contacts](walls.md) add confirmed ballistic/spit sparks from exact
collision endpoints and normals; terminal expiry and body hits do not invent
wall effects.

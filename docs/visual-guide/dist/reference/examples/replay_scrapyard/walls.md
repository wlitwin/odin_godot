# Wall contacts

Ballistic and enemy-spit sweeps now record the exact cover endpoint and outward
normal before removing the projectile. A body intercepted first suppresses the
wall event. TTL expiry and arena-boundary removal produce no cover impact.
`arena.contact` preserves Replay's existing clipping order, inclusive endpoints
and inside-cover forgiveness; X wins an exact corner-normal tie.

The confirmed `Wall` event identifies the projectile pool generation and slot
for slugs, or the shooter generation/shot serial for [rails](ordnance_view.md).
Rails use a distinct event key so the two identity spaces cannot alias.
Its detail byte encodes west/east/north/south plus a spit flag. It uses the existing
one-shot ledger, so confirmation does not restart a fan. Each contact draws three
original triangular slivers, angled -0.55/0/+0.55 radians about the outward normal,
travelling 170 pixels/second and fading over 0.3 seconds. Bullet sparks are warm,
spit sparks green; the spatial Hit cue plays at the same contact.

The 192-node spark pool counts visual overflow and clears on cancellation,
resync, epoch, floor/run changes and shutdown. Simulation scratch holds at most
32 contacts in simulation emission order (rail pulls, then swept projectiles). Optional contacts use only capacity left
after reserving every possible later action-feedback identity: five aggregate
kinds per player, Entered per player and Started. Existing occurrences reduce
that reservation. A quiet tick can carry seven contacts; denser ticks can omit
cosmetic contacts. Scratch `wall_dropped` reports that omission to model callers;
it is not a replicated statistic. Gameplay damage and later actions retain their
capacity. Future action event kinds must update this explicit reservation.

Scrapyard content advances to `0x5253435241503045`. World, control and action
schemas, gameplay protocol 7 and checkpoint layout 4 stay unchanged. The explicit
[run converter](saves.md#converting-older-replay-runs) now accepts content 42/43/44/45.
The content-44 fixture was captured with the actual old converter before adding
Wall; its state and assets survive conversion and fresh-process resume.

```sh
nix develop --command bash examples/replay_scrapyard/walls_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_WALL_CAPTURE=/absolute/output/wall.png \
  nix develop --command bash examples/replay_scrapyard/walls_run.sh
```

[Evidence](../../docs/replay/results/scrapyard-walls-2026-09-07/README.md) records
model, native, conversion and recovery checks. This covers terminal ballistic
and spit contacts with cover. [Ordnance presentation](ordnance_view.md) extends
that work to rail contacts, grenade shells/trails and browser views. Hardware
listening, broader platform tests, playtests and full comparison remain open.

<a id="the-counter"></a>

# Shop cards and purchase controls

The original bottom shop strip is an editable [scene](ui/shop.tscn), using
the copied steel UI theme. Nine cards show current prices, upgrade levels, health,
owned parts and the next weapon. Hover or keyboard focus supplies an explanation.
The panel follows the bottom center of the viewport and leaves the east gate visible.

Click a card, or use the original order: 1–4 for damage/rate/speed/healing and
5–8 for belt/plate/catalyst/magnet. Key 9 adds a shortcut for the final swap card.
Earlier port builds used 5-to-swap and 6–9-for-parts; this restores the original
purchase-key order.

Cards and shortcuts share one local submission function. The display uses the
local predicted player so a pending purchase updates the wallet and card state;
the authority still validates the action. Prices are the same constants used by
the simulation rule. Owned parts, unaffordable upgrades and overflowed upgrade levels
disable their cards; full-health healing is disabled as in the original card UI.
The same convenience checks apply to shortcuts. The existing simulation
purchase rules and content/checkpoint identity are unchanged.

The Escape menu disables purchasing. Pointer input over the counter blocks gun
fire and aimed abilities while leaving movement and shopping shortcuts available.
Observers do not receive a purchasing panel. Confirmed stage changes control the
panel's lifetime; no UI nodes or hover state enter the replicated world.

```sh
nix develop --command bash examples/replay_scrapyard/shop_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_SHOP_CAPTURE=/absolute/output/shop.png \
  nix develop --command bash examples/replay_scrapyard/shop_run.sh
```

The test uses a live solo world in the editor workbench and real input events:
clicks, held mouse buttons, shortcuts, heal/owned/affordability states, hover over
a different focused card, menu blocking and viewport resize. The normal
`run_loop.sh` also shops through card signals on host and client before comparing
the complete world with a spectator after two clears and a wipe.

See [recorded evidence](../../docs/replay/results/scrapyard-shop-2026-09-07/README.md).
Dummy audio isolates the previously reproduced local CoreAudio problem; it does
not establish hardware-audio or listening parity. The [combat HUD](hud.md)
restores health, magazine, boss and cooldown displays. Transition announcements
and broader visual/interaction parity remain work. This slice does not claim a
complete game port or a framework comparison.

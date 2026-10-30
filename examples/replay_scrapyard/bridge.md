# Using the new Replay bridge in Scrapyard

Scrapyard already used the original Replay runner, journals and audio pool. It now
also uses the new authoring bridge for **enemies, loot and gameplay audio**. The
original sibling game remains untouched. This is a substantial integration slice,
not a second full-game rewrite or a claim that every adapter is migrated.

## Data and lifetime boundary

`shared/presentation/mobs.odin` projects the selected observed World into detached
mob display values: appearance, health, telegraph, status tint and nearby-prey
information. No World or mutable catalog pointer enters a Godot rig. Existing
observed interpolation remains the sampling policy for enemies and loot; local
players and projectiles retain their current prediction policy.

`scripts/mob_bridge.odin` binds those values through `View_Pool2`. A PackedScene
supplies Body and Telegraph children; attach caches them once. Paint handles data
changes; frame handles animation. Generation, epoch, floor/run, observation reset
and backward-time boundaries retire stale rigs. Initial/late observations seed
health silently rather than inventing damage feedback. Loot uses the same typed
lifetime owner with its existing authored scrap scene.

Before, the game precreated 64 enemy sprites plus 64 telegraph rings and 128 scrap
scenes (three nodes each), then manually hid unused slots and reset their state.
The bridge removes those **512 eagerly reserved nodes**. Live entities instantiate
views on demand, and recycled simulation slots get new scene lifetimes. Existing
actor tests now check retirement and absence of stale state on the replacement,
rather than requiring the same engine object to survive unrelated entities.

This changes the pooling tradeoff: lifecycle safety and lower idle node count
come with scene creation/free on membership churn. The timing below measures
steady presentation, not that creation cost. High-churn projectiles should be
evaluated separately before migration.

## Improvements driven by actual use

Two missing shared primitives became apparent:

1. **Animation separate from changed-data painting.** A stationary enemy still
   animates. `View_Binding.frame` and `view_pool_frame` advance presentation time
   without putting a render delta/frame counter in the display payload or forcing
   every binding to repaint. It visits only live entries and animates children.
2. **Audio projection with occurrence context.** Scrapyard derives pitch from a
   stable event ID and reconstructs hurt positions at the event tick. The new
   `audio_route_init_change` callback receives the complete Change, removing the
   need for an implicit current-event side channel. It uses the existing route's
   policy, one-shot ledger, cancellation and epoch handling.

`scripts/audio.odin` now routes gameplay changes through Audio_Route. Music fades
and sounds inferred from state remain game-specific, sharing the route's voice
pool where appropriate. No audio or view state is added to World/checkpoints.

## Measured tradeoffs

An isolated headless benchmark compares the frozen previous game adapter with the
new adapter. Both paint the same detached frames through the real game paint
function, with identical catalogs, mixed enemy kinds and one drop per enemy.
Three alternating process pairs per size use warmup plus five 120-call batches.
Simulation state is checked unchanged after every benchmark. Builds do not overlap
measurement. These are native CPU presentation timings, not rendered FPS or GPU
measurements. Both builds use the same framework version and the build helper's default
`-debug` flags, with no `SCRIPT_BUILD_FLAGS` optimization override. Release-build
timings can differ.

| Enemies and drops, each | Previous paint | New paint |
| --- | ---: | ---: |
| 0 | 76.05 µs | 75.71 µs |
| 8 | 81.05 µs | 84.32 µs |
| 32 | 85.04 µs | 96.84 µs |

The 32-entity case adds about 11.8 µs, or 14% of this isolated paint call. Typed
projection, comparison and ownership work is measurable. This integration is
**not a general performance win**. Its value here is explicit lifetimes and a
smaller, testable Godot boundary, plus fewer unused nodes. It also adds setup and
projection code; animation rules remain game code. There is no line-count or human
productivity superiority claim.

The complete observed World is still used elsewhere in Scrapyard's paint function.
Detached mob values reduce what rigs receive; they do not remove all World copies
from the game or change history memory. Pure callbacks and shared ownership make
the seam easier to reason about, while future conversions should justify their
own costs.

## Verification and remaining scope

Focused checks pass for enemy attack/hit/death, fresh lifetime replacement, player
animation compatibility, damage/pickup effects and floor cleanup; contextual wound
audio position/pitch/once-only behavior; and host/client/observer combat with 120 ms
latency and equal whole-world hashes. The game scripts compile for WASM. Shared
Godot tests verify unchanged-value animation and contextual route cancellation.
The projection test verifies detached values and generation handles.

No existing gameplay/shared-model or Kit source changed. Native/WASM compilation
is not a new browser execution or hardware-audio listening claim. This increment
does not repeat the full migration/parity matrix.

Player rigs, predicted projectile selection, bespoke particles, input/UI bindings
and Resource catalog loading remain on their current adapters. Convert these only
where another concrete integration yields a useful simplification. In particular,
projectile selection may need multiple identity domains when predicted and observed
pools diverge; do not force that into one ambiguous view pool.

```sh
REPLAY_SCRAP_BRIDGE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_scrapyard_bridge/run.sh
```

[Source and test receipts](../../docs/replay/results/scrapyard-bridge-2026-09-20/README.md)
record the exact workload, initial fixture failures and preserved original sources.

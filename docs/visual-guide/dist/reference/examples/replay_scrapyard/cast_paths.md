# Igniter tongues and spread bolts

The igniter now draws the original ASCII `*` tongues: five on the caster's
predicted view at −0.5, −0.25, 0, 0.25 and 0.5 radians, one on remote observed
views. Each starts 18 pixels from the origin, advances 10 pixels per displayed
simulation tick and expires after 15 ticks. Those fixed visual constants match
the original even when a custom cone's gameplay range differs. Labels are centered
on their flight position. Forward observations sweep living observed mob circles
to retire contacted tongues; the instantaneous cone's damage/status rule is
unchanged. Original contact bursts/flashes and exact frame-time feel still need
paired evaluation.

Spread reactions now record an explicit `Flash.Arc` before each target re-enters
the status rulebook. It stores the actual source/destination, carried status and
credit in the existing bounded flash pool. The renderer uses the original four-
point kink with a seven-pixel displacement and two-pixel half-width, yielding an
eight-vertex polygon. It uses the payload RGB, base alpha 0.8 and depth 8, with
the original expansion/fade curve over the existing 17-tick flash lifetime.
Zero-length hops are retained as facts but draw no bolt, matching the original
renderer. All arcs use observed state, including on the causer's screen.

Flame/arc nodes are created on first use and reused within bounded pools. Hiding,
slot replacement, rewinds and epoch changes reset the relevant view state. Arc
positions are recorded facts, so later target motion or deletion cannot redirect
a bolt to a new occupant. Correction/removal/expiry controls visibility; recovery
continues the saved lifetime rather than replaying an old launch.

## Compatibility

Arc paths introduced content **`0x5253435241503046`**; [dash actions](controls.md)
subsequently introduced **`0x5253435241503047`**. Adding the Arc enum member changed
the canonical schema/contract while the World remained 52,600 bytes. Gameplay
protocol 7 and checkpoint layout 4 were unchanged by that transition. Older peers
fail admission; older saves require the explicit [offline converter](saves.md#converting-older-replay-runs).
The save guide records the current content identity and accepted input formats.

The converter paths for contents 42–45 use frozen old World/Flash and event/action
descriptors, map World fields and pending actions, and retain the existing
identity, outcomes, inputs and asset checks. The content-45 fixture was created
with the actual old converter before the enum changed. Existing destinations and
source files are never overwritten. Earlier shared value types remain reused
where their shape is unchanged; future changes must preserve those source shapes.

```sh
nix develop --command bash examples/replay_scrapyard/cast_path_run.sh
REPLAY_PREBUILT=1 RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_PATH_CAPTURE=/absolute/existing/output/directory \
  GODOT=/path/to/Godot bash examples/replay_scrapyard/cast_path_run.sh
```

The native scene chooses its loadout during staging, casts the cone, then primes
and shocks a player beside two static barrels through existing development actions.
It checks the fan, centered glyph flight, two actual target bolts and expiry.
Browser acceptance checks five local versus one remote tongue, then recorded hops
to two barrels and the two other players. Model tests cover exact geometry, actual
hop payload/credit, bounded dense spread and checkpoint restoration/expiry.

Remaining launch/contact feedback, broader platform coverage, audio listening and
paired feel/authoring/runtime comparisons remain requirements. See [evidence](../../docs/replay/results/scrapyard-cast-paths-2026-09-08/README.md)
and the [port ledger](roadmap.md).


The renderer now uses immutable ArrayMesh instances for procedural polygons.
Color/alpha use instance self modulation; arcs reuse one unit polygon and an affine
basis that preserves the existing kink, width and recorded endpoints. Node pools,
visibility, lifetimes and simulation formats remain unchanged. This avoids the
stock web renderer's Polygon2D index-update path, including during viewport resize.
See the [rendering audit](../../docs/replay/results/immutable-polygons-2026-09-13/README.md).

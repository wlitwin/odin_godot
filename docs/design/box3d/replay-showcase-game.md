# Dockyard Duo game proposal

Dockyard Duo is a working title for a two-player cooperative physics heist.
Two small salvage robots raid an automated loading dock and haul awkward cargo
onto an escape barge before it leaves. The user selected the cooperative heist
direction; the title, level layout and detailed tuning remain proposals.

The first release is a small, polished game with one memorable arena and short
jobs. Each player controls a separate robot. Native and browser builds use the
same Odin game model and authored content through Replay and the shared Box3D
backend. The implementation sequence is in the [web roadmap](web-showcase-roadmap.md).

## First release contract

The active goal uses a **150-second job**, three cargo deliveries and three job
variations in one colorful isometric loading dock. Start with a ramp, swinging
crane and barge delivery pad. Magnets use bounded fixed-tick impulses, leaving
the single joint for the crane. Decoration never enters the authoritative
solver. Solo practice is available; multiplayer gives each person a separate
robot and input seat. The optional visual-style question remains open; the
working default is a toy-like warehouse with readable silhouettes.

The first online cohort uses the same qualified Wasm build. A host disappearing
ends/pauses the round with a clear message and a rehost/new-round option. Seamless
authority migration and native/browser cross-play are outside this release.
Returning teammates, late observers and automatic full-state recovery remain
required. Public Internet connectivity needs actual Party/Room/ICE/TURN evidence;
a localhost pair is only local functionality.

[contract.json](../../../tests/box3d_web/contract.json) records the initial profile,
reference machine, browser matrix, performance/load/memory budgets and final
cases before browser measurements. A deploy-ready package is the publication
deliverable; no public server, paid service or external repository is created by
this choice. The native carrying prototype should be shown for human feedback
while web integration proceeds. Automated controllers are recorded separately
from human playtesting.

## The moment that sells it

One robot pulls a long crate around a corner while the other pushes its far end.
The crate catches a swinging crane arm, spins, and nearly knocks both players
into the water. They catch it with their magnets and slide it onto the departing
barge. Both screens show the same physical outcome, with responsive local input
and reconciled sound and particles.

This gives the showcase an understandable objective and physical comedy. Stacks,
contacts, mass, angular motion, a motorized hinge, sensors and queries all have a
visible purpose. Players can understand the game without opening a profiler.

## The first playable job

1. Host a private game and send an invite; the second player joins as a distinct
   colored robot. Solo practice starts immediately and allows learning controls.
2. Steal three marked cargo items, starting with a small crate and ending with a
   long, awkward load. Choose a safe ramp or a shorter route beneath the crane.
3. Move the cargo onto the barge's delivery area. A load counts after it settles
   inside the area; scoring and its effects occur once for that cargo identity.
4. Finish before the escape deadline. Cargo lost overboard reduces the payout;
   robots recover quickly so one mistake does not end the session.
5. See a short result screen, then retry or select another job using the same
   arena. Early playtests should tune round length around two to three minutes.

The initial prototype can omit the timer while movement and carrying are tuned.
Job variations change cargo arrangements and objectives before adding more maps.

## Controls and cooperation

| Input | Action |
| --- | --- |
| WASD or arrows | Drive the robot across the dock |
| Mouse aim and hold primary button | Attach a short magnetic tether to eligible nearby cargo; release to let go |
| Space | Brief boost with a readable cooldown |
| Escape | Settings, invite and leave controls |

A magnet applies bounded forces at the fixed simulation tick. Two magnets can
act on the same item. Targets come from validated Box3D queries; the camera and
mouse provide intent, while the simulation decides eligibility, distance and
occlusion. Boost and other one-shot requests use Replay's existing action and
outcome contracts where appropriate.

Cargo mass and shape create different jobs. A short box is easy to push alone;
a long load is easier with one robot at each end. Tethers have a limited reach
and visible tension. Heavy cargo can drag a robot, so teammates must cooperate.
Avoid fiddly inventory management or a separate physics interaction system.

The first magnet implementation can use existing impulse/force operations. If
that feels poor in playtests, evaluate actual joint-based grabs as a deliberate
game-profile extension. Do not preserve an unsatisfying mechanic merely to avoid
changing a previously measured constraint.

## First arena and production scope

Use a compact, readable 3D dock with an elevated camera, a ramp, a moving barge,
one swinging motorized crane and a cargo staging area. Give the robots distinct
silhouettes, expressive eyes and colored magnet beams. Large shapes, strong
contrast, restrained lighting and good impact audio suit the browser renderer.
Do not depend on subtle textures to explain objectives or hazards.

Start with two robots, roughly eight cargo bodies and one real hinge. Aim for a
scene around 24 bodies, inside the current 35-body/shape, eight-geometry-asset,
one-joint profile. Share geometry resources and keep decorative debris outside
the authoritative solver. These are starting production bounds, not Box3D's
general capability limits. Extend a named profile only for a demonstrated game
need, with complete-state, memory and performance checks for that profile.

The minimum release has one arena, a complete round, three cargo/objective
variations, onboarding, sound, clear win/fail feedback and fast retry. Defer
procedural worlds, destructible buildings, progression economies, combat, four
players, physical rope wrapping and general construction tools.

## What the framework showcase includes

| Visible feature | Integration demonstrated |
| --- | --- |
| Two separately controlled robots and shared cargo | Replay prediction and authority over the same actual Box3D world |
| Crates striking the swinging crane | Contacts, angular dynamics and captured joint/solver state |
| Magnetic selection and cargo delivery | Native queries, sensors and deterministic game rules |
| A late spectator or returning teammate | Complete-state bootstrap and recovery, with no replay of old cosmetics |
| Optional latency demonstration | Real delayed transport and Replay correction, with clear status and easy reset of the demonstration |
| Inspector-authored cargo and dock | Godot authoring resources baked through Odin into Box3D |
| A short code guide | Input, simulation, authoring and presentation boundaries that users can follow |

Keep the normal HUD about the game: objective, time, payout, tether and boost.
An optional developer overlay can show prediction/confirmation, correction depth,
memory and full-state comparison. It must describe actual observations. Effects
and smoothing consume Replay presentation data and never steer the solver.

Full replay playback, instant-replay cameras and authority migration are useful
later demonstrations. Do not promise them through a pose recording or treat
Replay's short rollback history as a full match recording. Their complete
checkpoint, input, asset and authority requirements remain explicit.

## How to decide whether it is good

Build a native greybox early, alongside the web integration. Have two people try
the first carrying puzzle before producing a large asset set. A successful
prototype gives each player a useful role, produces amusing shared outcomes and
makes retry attractive. Adjust grip, acceleration, cargo friction, camera and
layout from that playtest.

The shipping browser flow should be understandable from a link: enter a name,
host or join, learn the controls and complete a job. Validate actual internet
reachability and clear disconnect/rejoin behavior; two automated localhost tabs
alone do not establish that experience.

Preserve a native version of the same game for local development and comparison.
The initial online cohort should use the same WebAssembly build. Native-to-web
physics cross-play needs its own compatibility and state-transfer proof.

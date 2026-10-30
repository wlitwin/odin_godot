# Scrapyard source and asset provenance

Copied from the user-provided sibling repository `../scrapyard` at revision
`6bdef4f437d9a4e2c98f1d49472f840879301ccf`. Original project files remain unchanged.
These are project assets; this port does not claim to relicense the source art.
Generated imports and binaries are not copied.

| Unmodified copied path | SHA-256 |
| --- | --- |
| `assets/gz2/bg_floor.png` | `11fb37f81d0b2ca6da82c024bf85d361716f4894f76df1c44129a63d38e02e19` |
| `assets/gz2/objects.png` | `fd175645e4fa80a6fffb4bc33959b2d541959e73f6fa639c35ea073748121f94` |
| `assets/gz2/runner_becca_idle.png` | `fae92caa0a865f5d121a5a05356f368236978d768c97f87e9cda20260404ae63` |
| `assets/gz2/runner_becca_run.png` | `6e4da57d55c7ad8a2a9cc342512c3c7f1402eac85acdcfd0be4eeef7587712d0` |
| `assets/gz2/runner_joe_idle.png` | `d2fa4388a762f957cae09f07b97180421a95d179c9e76f64c7c063e8f4aaa4a1` |
| `assets/gz2/runner_joe_run.png` | `d385c01266d62f26a2e172f651f29d90909d696c49f629c9bc284de93f2bee40` |
| `assets/gz2/runner_unknow_idle.png` | `b1bfde91b10d17d0a756c4e5035d66431d8b45b1b0367a077baeca91c25c7194` |
| `assets/gz2/runner_unknow_run.png` | `ba5ad41a2cfce16d784038ccc37e6404c4363809f6d89560d2c572f5579f8f0e` |
| `assets/gz2/ui.png` | `d21b6cf12d5050b734cfb84d13bf51a94f89cf8ebbf5aa060e216a824b9a3b89` |
| `assets/gz2/weapons.png` | `55c69f4f282e451ea1df10c7b2774983223a8821f38833f93f0d96a62f4333b9` |
| `assets/gz2/zombie_cop.png` | `c541c91ee4c6a6402ffc1b7d9b14d2e8e1c4eae419e6fc2b586ccfcfdd9db40f` |
| `assets/gz2/zombie_heavy.png` | `4d187f15a138a33e5da95adaa82d6fcb303bee4c7324d7a510f12a5cf78fe03b` |
| `assets/gz2/zombie_puncher.png` | `5b25e3958552bc45541ce4a689c359b79f0cd91d7e3465fdfeb285ca405256ec` |
| `assets/ui/metal_btn_dark.png` | `47e4e97325326b32f2a9cbdbfc6ba36a90b2c28b2b637ddcfbb5373ad877d4c3` |
| `assets/ui/metal_btn_light.png` | `a33b4bdf997319351d98c303dcf08b15b52026b299048f60474cc037bacd21fd` |
| `scripts/defs/ability_def.odin` | `779dda2b706a15ecd424b8d7463a2daa5df8e827bf1bdd80dc99270e33139a8c` |
| `scripts/defs/combo_def.odin` | `d7d82e5c24c1720ca3b66981e610f6bfd46a55494943e73234a5539296d18551` |
| `scripts/defs/gun_def.odin` | `183ff9a3b4a2b72e91da0c6dace1893c99d9872c3ca981a6429bed4596940148` |
| `scripts/defs/mob_def.odin` | `e93d5761c39d13e93617889f3cd8d41427424f0d6e64161e8f0804848ed96bf8` |
| `scripts/defs/projectile_def.odin` | `e07f5b088446e85ac680cf57a1c1d83b44195cb720e98871c9caa5043b599e39` |
| `scripts/defs/status_def.odin` | `b8bbd70ec722dd1bc6bc46afd41dcede5ade4cdc291047cee33cb102930cba02` |

Resource data retains authored properties. Copied UID attributes are removed
where present so Godot resolves this project’s script paths. Hashes describe the
port files after normalization.

The copied `assets/ui/metal_theme.tres` has only UID attributes removed; its SHA-256
is `59f9a83ddb08fd53d85e2a37a4bd8cb0c6dfd19153008a4325a147bcd64d9eec`.
`ui/shop.tscn` adapts the original `ui/hud.tscn` Shop subtree into its own scene,
retaining anchors, card positions and texture regions, with 14-point card text.
Runtime labels and the action handler are reimplemented in `scripts/shop.odin`.

`ui/hud.tscn` also adapts the original HUD's Vitals/Ammo/BossPlate/Prompt subtrees,
sharing those textures and theme. Q/E/F labels follow this port's controls, and
the boss plate is moved below its selected-ability name line. The new
`scripts/hud.odin` supplies predicted/confirmed values without the original
framework's game pointers or HUD state handlers.

`ui/transitions.tscn` adapts the original `ui/flow.tscn` countdown, wipe and note
subtrees with the same steel assets, plus a current wave/rest panel. The countdown
box is widened, the recovery note moves below the combat HUD, and dynamic text
comes from `shared/flow` and `scripts/transitions.odin`.

Runner label scale (`0.45`), dim tint (`0.5` alpha), size and offsets come from
the original `fx/nameplate.tscn`. The downed camera selection derives from
`scripts/flow.odin`'s borrowed-eyes behavior; the camera remains owned by this
game's root and tracks displayed rigs through generation/warp identities.

`ui/chat.tscn` uses the original chat scene's steel theme and bottom-left placement,
with a scrollable plain-text history in place of its managed line widgets. Yard
message sources are the original `events.odin`, `run.odin`, `brains.odin`,
`combat.odin` and `succession.odin`; `shared/flow/news.odin` derives those messages
from confirmed state transitions, with updated parts/cores wording.

Ping diamond geometry, tint, scale pulse and 2.6-second fade come from original
`scripts/present.odin`. Floating names use the original `kit/fx` 0.9-second lifetime
and 46-pixel/second rise. `scripts/pings.odin` builds these as native scene nodes
and uses the existing copied ping sound.

Runner muzzle cells (`weapons.png`, 16×16 cells on row zero), the overhead reload
region (`ui.png`, 96,0,32,16), downed pose/beacon and enemy animation frame counts
come from original `skins.odin`, `runner.odin` and `mob.odin`. Hit colors/wobble
come from `present.odin`. The new actor view reuses those existing textures and
native geometry; no new bitmap assets were generated.

Feedback bursts and floating-text timing derive from original `kit/fx/fx.odin`;
layered death colors/offsets derive from `scripts/present.odin`. Debris uses native
polygon fragments, and damage/pickup labels are generated from observed values.

`assets/fx_vignette.png` is an unmodified copy of the original, SHA-256
`c99ae5bb0f3fd0fc354bc50b7f39fb38fd0814f5e3a3c125408e419232e28f83`.
The screen scene uses its alpha mask; zoom, health-pulse and floor-fade formulas
come from original `present.odin`/`run.odin` and are implemented in `shared/flow/screen.odin`.

| Resource path | SHA-256 |
| --- | --- |
| `data/abilities/battlecry.tres` | `e75d8ea3b6fba7003cb6a7fcc607531d78bb87613404a6083bb822991ff80303` |
| `data/abilities/frostwave.tres` | `cd3b84d5bac1c625c92c9584b1471446106ec2eeb7320e6ac68e672db74f68f9` |
| `data/abilities/ignite.tres` | `9aecd6d86afc7aff7add698d331acd89d8b5bef66ea0f0e10764178e6934f99c` |
| `data/abilities/salvefield.tres` | `3f6b4d79846b285ce7ad2ddc083a2e86c40298e7c45d917ee828f33c92fac48b` |
| `data/abilities/slime.tres` | `dc09c1737085c223f79453fa06a18341b327800d8f84ab2b6c8abeef31b8b8d3` |
| `data/abilities/sparkjar.tres` | `9aee154d700d3afa0880daee693a9b2afc85cc8bfaf1cfd85fbc76d6f14134b6` |
| `data/combos/10_detonate.tres` | `380820ee4ea23c117dbc68c62dc910c0bf4ba2aa63dcaaa225c1976999932a26` |
| `data/combos/20_freeze.tres` | `7d260c767ea57d4ac8a837f9430e17eebde8c5351d4c4deadff86f903b8aa008` |
| `data/combos/30_shatter.tres` | `fe87f917732b7a5b2c173c92c0c8f1d87f0f81071469768fa40ad956211404da` |
| `data/combos/40_douse_fire.tres` | `001f26bdc0f884c72fddebe2c31a0961d4772f5fa2a910abc7d174aa048c0e60` |
| `data/combos/41_douse_ice.tres` | `c35f9cc89f596c1cafd4b4105b41f93d616bcc07ee0059c2c707d0c775b300e8` |
| `data/combos/50_conduct.tres` | `3769097cefa9c01a00819e3c0be0b3eaee2d4ced4841b1b2799a535bf25f5d89` |
| `data/combos/60_surge.tres` | `7d84e3dcf79f21c759c1a919250bd656f13512839a424b3d05cd81e5c9a1f9a5` |
| `data/combos/61_surge_alt.tres` | `cc6d83999f32b05af367a658490f314a8d287f8e7b9f6893a4683d8d032ae494` |
| `data/guns/bolter.tres` | `9f3d8798e49465d2e72df29256d0a3b1315857f9bf2ae75f3b9ae36b2bec54c8` |
| `data/guns/lance.tres` | `a386e353fca0488b66b0dc72f8b47332fc54bba946278be41d01511d1495a0d3` |
| `data/guns/lobber.tres` | `1f00844f9478a98cdf1839dbba8b890007dc96f1ab876a80c41b3f550f5de4c6` |
| `data/guns/mender.tres` | `73e5587bc143386fc8c2abacf4686b43b776dc012bb9b8162f7190610f81c263` |
| `data/guns/nailer.tres` | `502c688485d0ac54729a6116c36a10bea48c7fab977c60d52159a288267247a3` |
| `data/guns/riveter.tres` | `93d9fd9f0d19887d1ac1195ce5eecf435f177dda04043cb9ae4c1bb7a40366ed` |
| `data/guns/scrapper.tres` | `d4ffafc10c6dd8aa7c1e66d5b42b8cffd8f76cf3d52b2e09d7e7f22aad7bdf20` |
| `data/mobs/barrel.tres` | `f53b2e6ee92c9b6a1682f484a073d5e30c92a1f3aa1af12b4cd16ede234ad574` |
| `data/mobs/hulk.tres` | `768d1ddc1cba52f220f7bce7f30c5bfdaa2b303ed49bb786caed9d25b02effc2` |
| `data/mobs/popper.tres` | `95f2fcfdadce41d23d3b2df05ad5f69ee8dbf3501d10b3bd5ae00a9e12e8a83b` |
| `data/mobs/scrapbot.tres` | `e1618950ac1283a8451a6a5bb5b5c133d45b1e43aa22a3fe49c71b444fcad9cc` |
| `data/mobs/spitter.tres` | `ea4f076e05b6f62d5fe7d1b703533284241d9fc99e5614a4ca5568bc436eb522` |
| `data/mobs/titan.tres` | `7edaf815e81435ef2742a2ab9f60a74cd54591f33e9e4bfd112a51419d124b8e` |
| `data/status/burn.tres` | `0a09fd785077ffd3e62e1be16fa123cf8adf8a3becd7f6422cd73d0eb850a749` |
| `data/status/chill.tres` | `a41ca572fca52019b16da7c67c46b8c3716db11e4a2fda2c4b90cb95cc5dd417` |
| `data/status/frozen.tres` | `22ce68e8cc6111163637632fe441518bb8a911dd76db577bfb0768af11a6614e` |
| `data/status/rally.tres` | `c0cedaccb279bccf42bc1c0987980dda7a5fa74a2b9e823d48d5447e9fead843` |
| `data/status/salve.tres` | `d31a9d7157fe9aa06c021ce832924b7ff6f96d6d14b0ba9da10a7495ad079fb2` |
| `data/status/shock.tres` | `25a7ce671bbcd41a9bc38f5603547fe883a36a1c11cde9a9bd9f54f77a4c0fe5` |
| `data/status/slimed.tres` | `4733079aa5f4f59a082a453889d23f722b414b6014c4938f412932e9dcd6ba8c` |
| `data/status/surge.tres` | `ddc16e17ca1394cf700a87c76f647d8e2f8abd15d1e2a8ea5603600d9059234a` |

`entities/scrap.tscn` retains original gear/hub geometry and colors, removing the
original script attachment and copied UID. Arena/scatter/collision rules come from
`scripts/arena.odin`; dirt/tuft placement and gate art/animation also come from that
file. The direction arrow's geometry/color come from `fx/gate_arrow.tscn` and its
visibility/placement rule from `scripts/flow.odin`. These are implemented in
`scripts/scenery.odin` using the existing copied floor/objects textures.
Movement comes from `scripts/input.odin`. Combat and ability rules
come from the original combat/brains sources and retained definitions. See
[combat](combat.md) and [abilities](abilities.md) for scope and comparison limits.

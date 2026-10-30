# Shared turret implementation receipt

Completed the [plan](turret-plan.md). The [feature guide](../../examples/replay_scrapyard/shared-turret.md)
covers controls, authoring, state ownership and compatibility. Original work logs
and the pre-feature source snapshot are in `/private/tmp/replay-turret-20260921`;
selected evidence is retained in [results](results/shared-turret-2026-09-21/README.md).

- Content51/K adds an eight-entry turret pool, authored TurretDef and targeted
  mount/release actions. Real content50 source checkpoint captured before edits;
  frozen catalog/action codecs and explicit conversions preserve previous state
  and pending actions, adding zero turret fields. Protocol remains 7.
- One generation/warp-checked operator credit lives in each turret. Shared ammo
  and cadence survive handoffs/recovery. The final bullet removes occupancy and
  the entity atomically; death/disconnect/warp/generation/floor cleanup release
  occupancy. Mounted movement/dash/revive/casting/handheld fire are blocked.
- Authored 24-round ability, composed turret scene, generated typed view binding,
  reliable T input, predicted turret presentation and HUD implemented. Existing
  workbench runs and validates it without a feature-specific framework API.
- **Seven pure tests pass**: shared claims/handoffs/exhaustion, stale handles and
  lifecycle, late correction, content50 import, occupied checkpoint/cadence
  continuation, mounted actions/projectile saturation, placement/cover/capacity.
  The last-round tick cannot double-fire the handheld weapon. A nearby wall
  catches the first turret bullet; operators cannot mount through cover.
- **Native/WASM corpus agrees: 15191278264882830483**, with zero retained native
  allocations after the test. This is correctness evidence, not a throughput
  benchmark; the harness includes complete takeover/checkpoint comparisons.
- **Real authored workbench and host/client/observer pass** at configured 120 ms
  latency: occupied rejection, first operator fires, second inherits remaining
  ammo and empties the turret, automatic dismount, scene cleanup and equal hashes.
- **Real occupied host-crash recovery passes**: member1 deploys/hosts, member2
  operates; after a backed-up occupied state, member1's process is killed.
  Members2/3 restore at epoch2 with the same operator and remaining ammo, hand
  it to member3, empty it and converge on a complete world hash.
- Existing **108 game model, four Stormcaller and six evolution tests pass**;
  six Godot editor/HUD scene tests pass. Historical upgrade CLI tests pass,
  including new zero-field checks and existing invalid-publication cases.
  Stock artifact matches the authored sources (digest 7605822622581753901).

Early fixture failures are retained in the work directory: one missing training
encounter selection and one spectator assertion that checked delayed visual
despawn against the authority clock. The latter was corrected to require immediate
logical dismount and bounded cleanup at the observed clock. Final evidence uses
the corrected fixtures and the final cover/muzzle rules.

No transport, rollback, recovery or codegen implementation changes were required.
The primary authoring cost beyond game/view code was extending the saved catalog
and action contracts; explicit enum mapping was necessary. Capacity is bounded
and snapshots now carry turret state, but no new performance comparison is claimed.
Interactive browser behavior and human balance/feel remain unmeasured.

All 65 pre-recorded Kit Odin-file hashes are unchanged. Sibling `../scrapyard`
remains clean at `6bdef4f437d9a4e2c98f1d49472f840879301ccf`.

# Shared turret ability

Replay Scrapyard only. Deploy a stationary, shared turret with authored ammunition
and cadence. One operator at a time; T mounts/releases a nearby turret, normal aim
and fire operate it. Empty turrets despawn in the same deterministic step and their
operator is immediately dismounted. Death, disconnect, generation/warp changes and
floor/run cleanup release occupancy. Another player cannot forcibly steal a seat.

Implementation gates:

1. Freeze content-50 catalog/action/world contracts and a real old checkpoint.
   Bump the content revision; convert old saves with no turrets and preserve prior
   fields/actions. Keep historical codecs and rules usable.
2. Pure replayable turret pool, generation-checked targeted mount/release actions,
   capacity/range/occupancy validation, bounded ammunition and shared projectile
   rules. No Godot timers or hidden ownership state.
3. Authored ability/TurretDef, composed scene and typed view adapter, T interaction,
   occupancy/ammo prompt, normal ability-picker/workbench integration. No Kit backport.
4. Deterministic tests for deployment, contention, handoff, final-shot removal,
   forced dismount, stale handles, blocked ordinary actions and pool saturation.
   Late correction and checkpoint takeover while occupied; native/WASM equality.
5. Real local peers exercising different operators and occupied authority recovery,
   relevant model/scene/old-save regressions, documentation and honest assessment
   of any framework gaps exposed. No full-game parity campaign.

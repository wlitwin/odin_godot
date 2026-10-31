# Replay Quickdraw

A separate port of [Kit Quickdraw](../quickdraw/README.md). The original project
remains runnable. Gameplay lives in [`shared/duel`](shared/duel/types.odin), a pure
Odin complete-world model; Godot supplies input, scene instances and presentation.

From the repository root:

```sh
nix develop --command bash examples/replay_quickdraw/play.sh
nix develop --command bash tests/replay_quickdraw/run.sh
nix develop --command bash examples/replay_quickdraw/run.sh
nix develop --command bash examples/replay_quickdraw/network_run.sh
nix develop --command bash examples/replay_quickdraw/migration_run.sh
nix develop --command bash examples/replay_quickdraw/early_claim_run.sh
nix develop --command bash examples/replay_quickdraw/early_claim_fault_run.sh
```

The interactive default opens the session menu. Choose Solo, Host, Join or Watch;
Host waits for the match leader to press Start. Name, address and port are editable.
Explicit roles retain the scripted automatic-start path, for example:

```sh
RQ_ROLE=host nix develop --command bash examples/replay_quickdraw/play.sh
RQ_ROLE=client nix develop --command bash examples/replay_quickdraw/play.sh
```

`RQ_ROLE` also accepts `server` (no local avatar) and `observer`. `RQ_PORT` defaults
to 49460. Direct native launchers use the configured address. The [party interface](online.md)
provides service-backed creation/invites/rejoin, native ENet and browser WebRTC;
public deployment remains unverified. The [Room driver](../../replay/godot/room.md) is enabled by `RQ_COORD_PORT`
with explicitly provisioned `RQ_MEMBER`, `RQ_INCARNATION`, `RQ_COORD_KEY` and
`RQ_TOKEN`. These credentials retain the existing automatic Room launch when
`RQ_ROLE` is omitted; `RQ_AUTO=0` leaves launch to the menu. The migration harness launches an isolated coordinator and provisions
three local members; the first two are trusted hosts. `RQ_LATENCY` injects
receive delay in milliseconds; `RQ_JITTER`, `RQ_LOSS` and `RQ_DUPLICATE` configure
the existing transport fault adapter (loss/duplication in ten-thousandths).

Enter focuses chat, Escape releases it, and Tab shows the scoreboard. Typing captures
movement, drone steering and combat/shop input while simulation continues.
WASD moves, mouse aims, left click fires, Space dashes, right click lobs, B buys
boots, and IJKL steers your independent drone. `RQ_GOLD=1` starts each player with
one coin for the shop scenario. Test bots are `strafer`, `deadeye`, `orbit` and
`lobber`; set `RQ_BOT` to select one. `RQ_NOREWIND=1` on the authority is the live
collision A/B control. `RQ_NOLOB=1` isolates hitscan.

## Authored rule correspondence

The port preserves the 640×360 arena, 12-pixel walls, two crates, four spawn points,
9-pixel body radius, movement/dash speeds and cadence, three HP, 120-tick respawn,
hitscan cover/range, one-gold boots and their 1.3× speed multiplier, independent
drone steering/clamp, and lob speed/lifetime/radius/cooldown. Hitscan kills award
one gold; lob kills award score without gold, as in the original. Gold uses the
original eight-bit storage. Death freezes body/weapon cooldowns and respawn retains
equipment and those cooldowns. Dedicated seats are numbered differently: a spawn
offset gives the first two clients the original dedicated duel's bottom lane.

The world owns HP, gold, score, respawn schedules, entity lifetime and collision
history in the same replayable state. The original mixes simulation and discrete
replication fields. Historical target life IDs deliberately reject hits against a
previous incarnation after respawn. The port defines a stable system order:
movement, proxy recording, existing lobs, then new fire/lobs in seat order.

Scene geometry and view assets come from the original; see [provenance](assets.md).
The HUD and session interface are a separate implementation. The [session UI](session-ui.md)
has named chat, a scoreboard, manual start, leave/rejoin and local identity/name
preferences. [Combat feedback](feedback.md) restores sampled hurt flashes and
independent material colors, and adds event-driven landing rings. [Native saves](saves.md)
support F5/Save, exact solo/host resume and fresh-process rejoin. Browser parties
pass combat, planned/crash migration, observer rejoin and durable Room publication.
[Browser-local slots](browser-saves.md) support durable solo save/resume,
stale-tab refusal and corruption preservation. Public/Steam deployment, human
visual/play-feel review and
a paired old/new benchmark remain pending. This is not full Quickdraw or M6 completion.

<a id="what-the-gates-establish"></a>

## Validation scope

- Native simulation: interpolated historical hit versus live miss, cover/history
  misses, respawn identity, dash/drone/cooldown/shop rules, stable predicted spawn
  IDs, and archive continuation during projectile flight/respawn/queued purchase.
  WASM is type-checked; cross-target deterministic execution is not claimed.
- Solo Godot: scene initialization, movement/combat loop and purchase.
- Three-process ENet: two 30-second hitscan phases at 120 ms injected delay per
  network leg, followed by a lob/purchase phase. The gate requires a clear
  historical/live hit gap, matching authoritative totals, one shot effect per
  authoritative shot on the shooter/observer, every lob predicted before authority
  acknowledgement, and the corresponding Godot node visible in less than 120 ms.
- Four-process migration: coordinator, host, successor and surviving shooter at
  240 ms gameplay RTT. Planned handoff and a killed host both restore an exact
  approved combat frame, including projectile flight and respawn/cooldown/history
  state, then continue shooting/purchasing. Clients compare canonical world
  digests at a common tick. The planned source rejoins with its original seat.

`RQ_METRICS` prints simulation correction/replay counts, application bytes and lob
input-to-node latency. That latency measures input sampling to scene-node presence;
it does not measure display scanout. Corrections are snapshot applications, not
necessarily visible positional errors. Detailed correction magnitude, CPU percentiles,
partial prediction, and broader competitive migration/fault scenarios remain acceptance work.

See [aim/view context](../../replay/net/view_time.md) for the authoring contract and
the limits of timestamp validation. Retain both projects when comparing them.

The early-claim gate exercises a rejected takeover while the owner is still live,
verifies that preparation resumes with a fresh backup, then crashes the owner
during a longer combat run. `REPLAY_MIGRATION_TRACE=1` logs coordinator/backup
frontiers; `REPLAY_KEEP_LOGS=1` retains process output. For focused diagnosis,
`REPLAY_MIGRATION_PHASE=crash` selects only the crash phase of `migration_run.sh`;
its sentinel distinguishes that subset from the complete migration gate.

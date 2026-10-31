# Scrapyard room recovery

The game uses the same model in standalone Session and coordinator-driven Room
modes. Room owns the gameplay session, authenticated control connection, lease and
prepared checkpoints. No alternate combat simulation is installed for migration.

The fixture starts three members, creates a long-lived zone and an airborne lob,
and waits for the designated successor to hold a coordinator-prepared combat
checkpoint. Planned handoff freezes at a final tick; abrupt mode kills the host
process. The successor must install exactly the approved frame, including catalog,
credit, cooldowns, effect/entity lifetime and query history, then continue the old
lob and issue new casts. Surviving participants compare the entire world at one
shared authoritative tick. In planned mode the old host returns as a client.

The shared Room driver separates gameplay freezing from control lease retirement.
Its phase-aware permit prevents authoritative steps/commands while it renews the
reservation long enough to transfer the final checkpoint. It drains unadmitted
gameplay traffic without changing the frozen state or action ledger, allowing
background acknowledgments through the shared router. Only the exact acknowledged,
prepared final point permits retirement/release. Failure or successor loss leaves
the old epoch fenced and enters the existing recovery policy.

```sh
nix develop --command bash examples/replay_scrapyard/migration_run.sh
RSY_SLOW_BACKUP=1 REPLAY_MIGRATION_PHASE=planned nix develop --command bash examples/replay_scrapyard/migration_run.sh
```

The migration fixture deliberately adjusts initial positions, target health and
ability duration/speed to keep observable combat state active. Slow mode reduces
final-transfer bandwidth after the ordinary backup is prepared and requires the
source to stay frozen for longer than one lease duration. These acceptance
scenarios do not establish complete game recovery coverage, deployment, or
full original-act parity.

## Lobby recovery

`lobby_migration_run.sh` runs planned and crash handoffs before starting the yard.
It compares the complete installed staging frame, preserves names/loadouts and
stable seats, gathers fresh readiness after reconnect, and starts the recovered
game. The old host rejoins the planned case; all survivors compare the whole world.

`World.host` is the lobby's Start permission, not proof of simulation authority.
A connected leader retains it. When that leader disconnects, the first connected
seat receives it through the ordinary replayed roster step. Returning players do
not preempt it. During current Room takeover the promoted seat remains connected
while remote seats rejoin, so it becomes the lobby leader. If a future policy
retains all memberships during recovery, this rule deliberately keeps the existing
connected lobby leader. Dedicated worlds keep `host == 0` and automatic start.

See [recorded recovery evidence](../../docs/replay/results/scrapyard-recovery-2026-09-06/README.md).

## Takeover timers

Content `0x5253435241503049` records the last observed authority epoch in `World`.
Its versioned `Model.authority` policy applies the original `succ_fixups` rule
on the first committed tick after a takeover: director rest and every existing
mob's attack/reinforcement deadline become restored tick + 150. An Over-stage
world also receives a fresh 150-tick dwell. Initial startup does not apply grace;
repeated ticks in the same epoch do not extend it. Dedicated authorities work the
same way even though both have playable seat zero.

Checkpoint installation remains exact. A second recovery before any resumed tick
retains the pending reset, and an aborted simulation tick commits neither the
reset nor the epoch stamp. Replaying recorded batches reproduces the policy.

This is a timer reset, not damage immunity. Movement, status effects, active boss
telegraphs and popper proximity damage continue normally. Replay also retains its
complete checkpoint projectiles, lobs and zones; the original's clearing of some
transient pools is not reproduced. The active-combat fixture checks exact restored
state followed by new shots, casts and kills in the same run, plus a new prepared
backup to the demoted or returning infrastructure process.

```sh
REPLAY_DEDICATED_COMBAT_OUT=/absolute/fresh/output nix develop --command bash tests/replay_dedicated_combat/run.sh
```

This covers local native/Chrome planned and crash/return takeover with two servers
and two players, forty enemies, 120 ms receive delay, and a maximum known rollback
of 120 ticks. It does not establish a public-network, arbitrary-load or loss-rate
guarantee. Original games remain separately runnable.

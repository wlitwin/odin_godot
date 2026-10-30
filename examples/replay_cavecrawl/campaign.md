# Full co-op campaign acceptance

Run this harness to check Replay Cavecrawl's scripted two-floor campaign. It
compares gameplay state across a host, client and observer; its result does not
establish visual parity or ordinary human play behavior.

```sh
nix develop --command bash examples/replay_cavecrawl/campaign_run.sh
REPLAY_CAVE_JITTER=20 REPLAY_CAVE_LOSS=500 REPLAY_CAVE_DUPLICATE=500 \
  nix develop --command bash examples/replay_cavecrawl/campaign_run.sh
```

The harness runs a real host, client and observer at the authored 20 Hz game rate,
with 120 ms receive delay per process. It drives ordinary movement/actions and
reads authority observations; it does not teleport players, edit HP/inventories,
spawn test-only enemies or assign director/victory state.

The story covers:

1. Loot the first chest, drop its gems and transfer the pickup to the other player.
2. Carry the relic, move with it and set it down.
3. Use ordinary rock throws to down the gem carrier; verify the inventory spill.
4. Approach and revive the player before the three-second respawn deadline.
5. Reject the old pickup generation after its slot has been reused, then reclaim
   the new pickup and heal from 30 to 55 HP.
6. Down the player again, wait for automatic respawn at the recorded deadline,
   verify the spawn position/full HP and reclaim the second spill.
7. Fight both first-floor waves through projectile hits, stamina and cooldowns.
8. Open the door and gather both live players to enter floor two.
9. Loot its five additional gems and fight both second-floor waves.
10. Open the final door, escape and compare the complete canonical world at a
    common tick from after all participants have observed victory.

The expected end state is two deaths for the client, 12 dwellers slain and all
eight collected gems retained. The driver uses separated firing lanes and ordinary
aiming to avoid unintended friendly fire during the wave phases. It checks both
wave numbers on both floors. This is a scripted campaign, not evidence that its
bot policy represents ordinary human play or matches original navigation exactly.

The additional public `heal`, `revive`, `carry`, `set_down` and generation-aware
`grab` methods are thin entry points to the existing validated actions. The
`campaign_probe` and `campaign_hash` methods provide read-only observations for
the harness; they confer no gameplay authority.

`campaign_verify.py` checks the saved phase receipts, conservation/slain totals,
respawn deadline, completion barrier and matching victory hashes. Faulted runs
must record actual packet drops/duplicates. The shim preserves reliable application
traffic; it does not model ENet's underlying retransmission/congestion behavior.
The output directory retains logs, phase receipts, fault configuration and summary.

The [campaign evidence](../../docs/replay/results/cave-campaign-2026-09-07/README.md)
records the verified normal/faulted runs. Original Cavecrawl remains separate.
Resource-driven definitions, navigation/visual equivalence, UI/chat/pings, broader
campaign recovery and paired human comparison remain requirements of full parity.

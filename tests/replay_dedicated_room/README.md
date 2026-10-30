# Avatarless Room authorities

```sh
REPLAY_DEDICATED_ROOM_OUT=/absolute/fresh/output nix develop --command bash tests/replay_dedicated_room/run.sh
```

Five native processes run a coordinator, two infrastructure servers, and two real
players using the actual Scrapyard model. The coordinator uses Dedicated policy
and grants hosting trust only to the infrastructure identities. Both request the
Server role and opt into complete checkpoint receipt. The standby follows as an
observer; it never occupies a playable seat.

Planned handoff, crash/returned-process recovery and repeated handoff check exact
checkpoint restoration, two retained playable seats, and seat zero for both
infrastructure processes through all role changes. Completion also requires a
prepared backup to the returned/demoted server. Ordinary player/observer metadata
cannot substitute for infrastructure hosting trust.

The fixture first waits for an approved checkpoint containing the ready party,
under the unchanged configured 120-tick rollback limit. An earlier fixture-only
20-tick age condition prevented triggering despite valid prepared backups; that
failed attempt is retained separately. It is not the framework’s supported bound.

The direct old/new gameplay comparison is in
`tests/replay_dedicated_comparison`. This Room gate focuses on infrastructure
membership, checkpoint and role behavior; its clients enter a quiet arena rather
than claim a combat-stress migration result.

Process launch waits for actual admission before starting the next participant.
A fixed sleep did not guarantee the fixture’s intended seat mapping under load.
The cooperative reverse-admission case separately verifies nonmatching member IDs
and playable seats.

The coordinator releases the exit barrier only after every actor has validated its
final state. Authorities keep serving during this barrier, so one process cannot
tear down the transport while another is still checking recovery.

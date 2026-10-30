# Claimball native migration acceptance

`run.sh` builds isolated game/coordinator projects and runs planned handoff and
owner-SIGKILL cases. Set `REPLAY_CLAIMBALL_MIGRATION_OUT` to a fresh output directory.
`RCB_MIGRATION_RENDER=1` renders the players and records screenshots.

`execute.py APP_OUTPUT COORDINATOR_OUTPUT RESULTS [planned|crash ...]` reuses verified
prepared builds. It records binary and driver hashes, watches exact child handles,
uses isolated coordinator/game ports, and gracefully cleans up surviving processes.
The authority database and raw save/checkpoint data are private test state.

The three-player fixture requires a committed moving/scored checkpoint before
migration. While predicting one avatar, the nominee must receive a complete world
with all three players. Promotion must restore that exact approved checkpoint.
Survivors retain seats, one-avatar prediction, previous chat and new epoch-two chat;
the new authority simulates the whole surviving roster. Two new spike commands and
a common authoritative world after those commands must agree. The lobby cannot
cover the game during the recovery interval. The rendered case additionally checks
that coordinated play rejects direct file saving without creating an output file.

The shared migration coordinator gained an isolated Claimball room/content selector.
Claimball's shared package was renamed to `claimball_pitch` because Odin rejects two
imported packages named `pitch`. `contract/` records state/control/action/event and
packet fingerprints plus the network contract; the before/after records are equal.
It can also decode an existing C3 checkpoint supplied as its argument. No C3 schema
or content change accompanies the package rename.

This is a local ENet/control-service fixture with 120 ms game receive delay per
process. It does not model packet loss, coordinator restart, public deployment,
observer migration or consecutive failures. Those require separate evidence.

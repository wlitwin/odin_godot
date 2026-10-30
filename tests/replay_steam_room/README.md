# Steam Room lifecycle contract

```sh
REPLAY_STEAM_ROOM_OUT=/absolute/fresh/output nix develop --command bash tests/replay_steam_room/run.sh
```

This fixture uses Steam-shaped API objects backed by **local ENet**, not Valve's
network. Its three synthetic Steam IDs route to distinct local ports. The Steam
virtual port remains zero, exercising the explicit endpoint codec rather than
using that number as an IP port. The coordinator, Room, checkpoint replication,
takeover, redirect and game models are the production implementations.

The existing four carrier cases run planned and killed-host recovery with either
successor or guest carrying the relic. Every surviving process must create a fresh
peer, member two must call `create_host`, other survivors must call `create_client`
with member two's exact Steam ID, and the carrier must move/release after recovery.
The ordinary gameplay/ownership/recovery predicates remain unchanged. Repeated
epoch-three handoff and fresh-process return additionally run at virtual port
65535 and verify their exact create-client destinations.

Pure checks cover canonical endpoints, full 64-bit IDs, virtual ports zero/65535,
invalid formats and wrong-local-host grants. A Godot failure fixture checks factory
return types, create-failure cleanup, invalid local provisioning and transactional
rejection of malformed redirect endpoints.

Passing this contract is not live Steam acceptance. Actual Steam networking still
requires configured app IDs, accounts/devices and the extension; use the separate
live runner when that environment is available. Do not relabel these local packets
as Valve relay/P2P traffic.

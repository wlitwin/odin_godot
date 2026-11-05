# Existing Pi deployment

The selected host is the existing NixOS Pi at `10.0.0.10`, reached as `pi` over
SSH port82. Deployment changes belong in `~/data/code/pi-nix`. Its existing
GameServers and Coturn services remain the shared infrastructure.

The deployed gateway preserves `wss://mc.laserturtle.net:62127/rtc` and forwards
legacy paths to GameServers.Signal on literal loopback port62129. The exact
`/replay-room/dockyard` path forwards to the existing Odin/Godot Replay Room
implementation on loopback49740. Nginx terminates TLS with the existing ACME
certificate. The Elixir `SIGNAL_LOCAL_PROXY=1` option explicitly binds its
private listener to loopback; the ordinary direct-TLS default is retained.
No new authority protocol implementation or router port is required.

The deployment and current same-network acceptance are recorded in
`tests/replay_dockyard/online/public-deployment-report.json`. Actual public WSS,
authenticated forced TURN, full state/acknowledgement/cleanup, observer and
reconnect checks passed. A STUN-only attempt did not establish direct gameplay
on the reference network; its diagnostics remain separate. Outside-network
acceptance and human co-op feedback are still required.

## Reproduce the service build

Use the deployment helper to snapshot current intended working sources into a
new persistent directory outside the repository. It verifies the pinned engine
archive, records every selected source hash and refuses overwriting a snapshot.
The snapshot retains the existing compiler/nixpkgs lock and uses the exact
Godot4.7.1 Linux ARM64 archive. A service build does not rebuild the client game.

```sh
python3 examples/replay_dockyard/deploy/stage_room_source.py \
  --engine-archive /ABSOLUTE/VERIFIED/CACHE/box3d.tar \
  --out /PERSISTENT/NEW/SERVICE/SOURCE
```

Point the `replay-room` input in pi-nix at that snapshot, then update only the
changed inputs. Build on the Pi through its remote Nix store, with bounded
parallelism, so the unrelated user VM is not used:

```sh
cd ~/data/code/pi-nix
nix flake update game-servers replay-room
NIX_SSHOPTS='-p 82 -o BatchMode=yes -o StrictHostKeyChecking=yes' \
  nix build .#nixosConfigurations.pi.config.system.build.toplevel \
  --store ssh-ng://pi@10.0.0.10 --eval-store auto --builders '' \
  --max-jobs 1 --cores 1 --no-link --print-out-paths -L
```

Check the actual native build, private service startup, authenticated Room flow,
complete-state agreement and shutdown before activation. The existing deploy-rs
workflow supports a remote build and automatic rollback:

```sh
cd ~/data/code/pi-nix
nix run github:serokell/deploy-rs -- .#pi --remote-build
```

The coordinated switch restarts the legacy signal listener and nginx; existing
connections can reconnect. Verify both protocol paths afterward. Nginx starts
after both private backends and does not race a reload against the previous
public62127 listener.

## State and credentials

`dockyard-room.service` uses private state and runtime directories. It runs a
writable private copy of the frozen SDK project because initial module loading
creates owned reload copies. The database remains under its state directory.
Initial database creation is explicit; if it disappears after initialization,
the service refuses to replace it silently. Recover the database as an operator.

Systemd supplies Coturn's existing server-only signing secret with
`LoadCredential`; it never enters a Nix derivation, client checkpoint, URL or log.
Room issues and refreshes authenticated member credentials with a600-second TTL.
The game content/cohort must match the selected frozen browser artifact.

## Resident room lifecycle

`REPLAY_ROOM_CAPACITY=16` limits resident crews. With
`REPLAY_ROOM_RECLAIM_IDLE_MS=30000`, a full cooperative, checkpoint-disabled
deployment may reclaim an idle crew when another player hosts. A live hosting
lease or connected signaling peer prevents reclamation. New/preloaded rooms get
the idle grace period; authenticated provisioning/control traffic refreshes it.

Reclamation first detaches the unused signaling bridge, then moves the exact
private admission bundle from `replay_provision` to `replay_provision_archive` in
one checked transaction. History remains private and archived room IDs remain
reserved. A failed/uncertain archive fences the hub. Active crews and other
deployment modes retain their existing behavior; reclamation is opt-in.
An expired disconnected crew may therefore stop appearing in Recent Crew;
players should Host a new crew in that case.

The original deployment retained every finished crew in the resident inventory,
so normal use and validation eventually filled all16 slots. The server-side
lifecycle update fixes that exhaustion without increasing the active-room limit.

## Acceptance scope

A check from this home's public address back into the same router is hairpin
traffic. Record that separately from a genuinely outside-network client.
Performance qualification remains on the declared M3/browser profile; building
a control service for Linux ARM64 does not admit native physics crossplay or
inherit that performance result. Human cooperative play feedback is separate.

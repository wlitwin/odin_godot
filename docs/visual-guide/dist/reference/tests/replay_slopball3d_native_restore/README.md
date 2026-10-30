# Slopball3D native published-party restore

```sh
REPLAY_SLOPBALL3D_NATIVE_RESTORE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball3d_native_restore/run.sh
```

The runner tests original-creator and trusted-seat-two restoration with native
ENet gameplay and WSS control. A temporary localhost certificate is trusted through
the normal CA option; plaintext development mode is disabled. Personal profiles,
Party credentials and gameplay ports are separate for every participant.

Each case publishes a scored, moving/spinning match, independently decodes its
world and pose/momentum, kills all four games and the service, checks SIGKILL exits,
and reopens the same database with creation disabled. The observer registers first
without authority or a running ball solver. The selected member restores the exact
world in epoch two; its actual first solver seed must preserve position, quaternion,
linear velocity and angular velocity. The original creator returns afterward in
the seat-two case.

Returning names/seats, a new authority kick/goal, fresh scoped samples, named chat,
guest-save refusal, a common continued world and independently validated publication
two complete the gate. The decoder checks the expected authority seat and publisher.

`RS3_RESTORE_OWNER=host` or `striker` selects one case for
`execute.py GAME_BUILD SERVICE_BUILD FRESH_OUTPUT`. `prepare_bridge.py` adapts the
browser observer to atomic local request/status files. Those raw files can contain
invites; exclude them, databases, profiles and TLS keys from shared evidence.
The fixture uses ordinary game/Room methods and does not inject synthetic worlds.
This is local WSS acceptance, not public-deployment or universal recovery evidence.

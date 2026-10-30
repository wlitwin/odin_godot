# Slopball native published-party restore

```sh
REPLAY_SLOPBALL_NATIVE_RESTORE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball_native_restore/run.sh
```

Three native players and an observer use ENet gameplay and WSS control, with a
localhost certificate trusted through the normal CA option. The plaintext
exception is disabled. Each process has separate gameplay ports, personal identity
and SQLite Party credentials.

The host publishes scored, moving play. An independent reader verifies the complete
checkpoint and ball pose/momentum. The fixture kills every game and the service,
checks each SIGKILL exit, then reopens the same database with creation disabled.
The observer registers first without authority or a running solver. The returned
host restores the exact tick/digest in epoch two and seeds the actual ball solver
from the independently decoded saved values. Players reclaim the original seats.
New kicks/goals, scoped observations, named chat, guest save refusal, a common
world and independently decoded publication two complete the gate.

`execute.py GAME_BUILD SERVICE_BUILD FRESH_OUTPUT` reuses prepared builds.
`prepare_bridge.py` adapts the browser probe to atomic request/status files.
Raw request/status files can contain invites; exclude them, profiles, databases
and TLS keys from published evidence. `events.json` omits invite values.
This tests local trusted WSS recovery; public deployment and broader failure/physics
coverage remain separate requirements.


The runner now executes both original-creator and trusted-seat-two restoration.
Use `RSL_RESTORE_OWNER=host` or `striker` with the execute helper to select one case.
In the latter, the creator remains absent until seat two restores the published
world and solver momentum, then rejoins seat one. Continued publication is checked
against the selected authority seat and publisher; the new authority must kick and
score for its own team. Guest publication remains refused.

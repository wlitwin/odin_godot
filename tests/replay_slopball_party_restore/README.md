# Slopball browser published-party restore

```sh
REPLAY_SLOPBALL_PARTY_RESTORE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball_party_restore/run.sh
```

Three browser players and an observer publish a scored, moving owner-streamed
match. Every source browser is SIGKILLed, with the exit signal checked. An
independent Odin reader decodes the actual service checkpoint, including complete
world validity, score, names, body scopes/samples, tick, digest and ball pose/momentum.
The service is then SIGKILLed and reopens its existing database with creation disabled.

The observer registers first and must remain without authority. The host restores
the exact saved world in epoch two; its first eligible actual solver seed must
match the independent archive's position, angle, linear velocity and angular velocity.
The other players reclaim seats two/three. Continued play requires a new kick and
goal plus new scoped body observations. Named observer chat, guest save refusal,
a common world digest and independently decoded publication two are checked.

RTC bytes, graphics traces, disjoint control rectangles and absence of browser-local
save slots are checked. All actions use the ordinary UI/game methods. The bridge
only observes the game; no checkpoint or synthetic world is installed by the fixture.

`execute.py WEB_BUILD SERVICE_BUILD FRESH_OUTPUT` reuses prepared exports.
`verify/` reads source/continued publications. Source browser profiles, service
SQLite data and credentials are private; archive redacted events and receipts only.
These loopback runs do not establish Internet deployment, cross-device physics or
preservation of solver contact caches and every live tick after publication.


The runner now executes both original-creator and trusted-seat-two restoration.
Use `RSL_RESTORE_OWNER=host` or `striker` with the execute helper to select one case.
In the latter, the creator remains absent until seat two restores the published
world and solver momentum, then rejoins seat one. Continued publication is checked
against the selected authority seat and publisher; the new authority must kick and
score for its own team. Guest publication remains refused.

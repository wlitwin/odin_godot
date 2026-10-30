# Cavecrawl social detail acceptance

```sh
REPLAY_CAVE_SOCIAL_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_social/run.sh
```

The runner builds an isolated Cavecrawl copy, runs native host/client/observer
processes with 120 ms receive delay, and exports a separate Chrome project with
the existing coordinator-backed migration fixture. The unchanged shared telemetry
and Comms unit gates can also be run with `tests/replay_telemetry/run.sh` and
`tests/replay_comms/run.sh`.

A native keyboard gate types F and submits invalid/valid names with Enter,
requiring continued editing on rejection and no ping/chat side effects.

Native checks require the authority's zero row and a measured remote RTT, hide
observer and departed rows, then leave/rejoin with a fresh measurement. A ping
stamped `Beta` stays `Beta` while a rename to `Scout [x]` is accepted; a subsequent
ping uses the new name. Both actual Label nodes must coexist and then expire. The
rendered host captures the scoreboard. An isolated zero-dweller floor keeps this
UI scenario free of unrelated combat.

Chrome retains the original three-player lobby/chat/loot/door/handoff/continuation
workflow. The fixture holds handoff until measurements are visible and the existing
durable gameplay condition is met. Only then does the guest send a marker, so its
pre-expiry removal at the epoch transition can be distinguished from ordinary
expiry. Every peer must adopt telemetry scope 2, display the new authority's zero
row and freshly measure the surviving guest. Test-only probes expose scope,
known/age status and marker TTL; they never set telemetry or simulation data.

`build.sh OUTPUT`, `execute.py PREPARED [LABEL]`, `web.sh PREPARED FRESH_WEB_OUTPUT`
and `execute_web.sh WEB_EXPORT FRESH_RUN` retain preparation hashes and exact
drivers. GDScript-only fixture revisions use separate exports/runs. Production
gameplay, canonical world data and original Cavecrawl files are unchanged.

# Named observer chat acceptance

```sh
REPLAY_OBSERVER_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_observer_names/run.sh
```

The isolated stock Scrapyard copy first runs the native host/client/observer chat
scenario. The fixture warms authoritative progress before retaining the existing
350 ms chat-input guard check. It then builds speed WASM and starts three Chrome
processes with local authenticated coordination: two players and one observer.

The observer receives late history, sends a Unicode display name, is denied a
ping, changes its label to match the host's text, and remains visibly marked as an
observer. Planned handoff promotes player 2 and rejoins player 1; the surviving
observer negotiates its display capability again and sends a new message. Both
historical labels remain unchanged. The fixture requires exact restoration, one
epoch-2 authority, only two player seats and one copy of every named message.

`report.py OUTPUT` checks source fingerprints and these receipts;
`verify_report.py OUTPUT` rejects altered labels, duplicated history, incorrect
seats/player count, inexact restoration and missing capability renegotiation.
`REPLAY_OBSERVER_MODE=crash` instead kills the host browser, returns member 1 in a
fresh process, then kills and returns the observer with a new display label.
`execute.sh BUILT_DIRECTORY FRESH_OUTPUT` reuses a prepared build and records its
binary hashes. The final histories must retain every original label and contain
the fresh observer message exactly once. Observer status text excludes player-only
controls. This is a local Chrome/ENet acceptance fixture, not public deployment or
full spectator parity. Original projects and saves remain
independently runnable. No messages are sent to external users.

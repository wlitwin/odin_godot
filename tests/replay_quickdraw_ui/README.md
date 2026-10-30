# Quickdraw session/UI acceptance

```sh
REPLAY_QUICKDRAW_UI_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_ui/run.sh
```

The runner builds an isolated copy, waits for editor-triggered builds and builds
again before launching three real Godot processes. It preserves prepared/source
hashes, native binary hashes, the executed driver and failed outputs. Explicit
fixture tokens disable ordinary profile storage.

The UI gate checks the editable menu, invalid names, leader-only manual Start,
continued simulation with typing input captured, literal player chat, negotiated
observer labels and late history. It produces a real kill and verifies nonzero
kills/deaths/gold in the scoreboard, round-trip rows, leave/rejoin, preserved scores
and continued named chat. The headless driver sizes its dummy window explicitly
before sending GUI input; controls still use the real button/signal path.

Additional runs against a completed build:

```sh
RQ_UI_RENDERED=1 nix develop --command python3 tests/replay_quickdraw_ui/execute.py /absolute/output rendered
nix develop --command python3 tests/replay_quickdraw_ui/profile.py /absolute/output
nix develop --command python3 tests/replay_quickdraw_ui/regressions.py /absolute/output network
nix develop --command python3 tests/replay_quickdraw_ui/regressions.py /absolute/output migration /absolute/prebuilt/coordinator
```

The last command requires a freshly built/imported/final-built copy of
`tests/replay_migration`. Its Quickdraw content is taken from `duel.CONTENT`.
Regression runners retain the original A/B, projectile and migration assertions;
only project/output paths and redundant build/import steps are adapted. The
migration subclass additionally requires named rows and chat before/after both
planned handoff and host loss, and checks that recovery does not show staging.

The profile fixture uses private scratch paths, checks a fresh-process name and
identity round trip, then verifies that corrupt name data is refused and preserved.
Do not archive its raw identity/profile files. Original Kit Quickdraw and the
original Scrapyard project are never changed or launched by these fixtures.

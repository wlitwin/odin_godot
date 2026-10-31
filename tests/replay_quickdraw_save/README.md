# Quickdraw native save acceptance

```sh
REPLAY_QUICKDRAW_SAVE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_save/run.sh
```

The test harness builds an isolated game and runs the existing UI/profile prerequisites.
It starts a named host/client pair, buys equipment, causes a real death, launches a
lob and uses F5 during the live combat window. A blocked staging path must fail
without changing the committed save. Only after that receipt does the harness kill
its exact writer processes.

An independent Odin reader decodes the actual archive and verifies combat state,
names, history, equipment and respawn timing. It creates valid policy-protected and
maximum-epoch archives for negative resume checks. Other cases cover wrong owner,
damaged/missing data, a configured Room path and exact solo restore.

Fresh host/client processes then restore and rejoin the retained seats, continue
respawn and commands, exchange named chat, drain projectiles and compare a complete
canonical world at a common tick. Committed saves and identity bytes must remain
unchanged throughout. Receipts retain integer hashes as strings.

`execute.py /absolute/output LABEL` permits a fresh labeled run against an existing
verified build. Each label requires a new result directory. Identity files, raw game
archives and derived negative archives are private test state; retain hashes and
decoded observations when publishing evidence, not their raw contents.

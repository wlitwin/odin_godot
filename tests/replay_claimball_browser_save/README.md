# Claimball browser-local save acceptance

```sh
REPLAY_CLAIMBALL_BROWSER_SAVE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_browser_save/run.sh
```

The fixture builds an isolated native app, runs UI/profile/WASM checks, exports Web
with speed optimization and drives Chrome against an isolated HTTP origin/profile.

It scores through gameplay, saves a moving match, attempts Leave during the write,
waits for the durable receipt and SIGKILLs Chrome. A fresh process must retain its
identity/name and restore the exact saved tick/digest in a new epoch. New spikes,
match completion, Play again, a second save and automatic URL resume are checked.

Two tabs load the same revision. One writes revision three; the other's stale write
must fail without changing the committed bytes. Further checks preserve corrupt
slot data, reject malformed labels, write an alternate slot, and preserve a corrupt
identity until the fixture restores its original bytes. These mutations occur only
inside the isolated test profile.

`execute.sh WEB_OUTPUT FRESH_RESULTS` reuses an existing prepared export. The bridge
reports file restore as `restored_exact`; its `exact` field describes migration.
The initial fixture used the wrong flag and timed out despite exact file restore;
the final fixture checks the correct receipt and keeps all restore assertions.

Published receipts exclude raw browser profiles and identity/checkpoint bytes.
The companion Party regression verifies that service publication creates no local
save slots. Browser-local and Party checkpoint stores remain separate.

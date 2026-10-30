# Quickdraw browser-local save acceptance

```sh
REPLAY_QUICKDRAW_BROWSER_SAVE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_browser_save/run.sh
```

The runner builds an isolated native game and web export, then serves it locally.
The browser fixture saves during movement, firing, projectile flight and equipment
use; checks that Leave cannot close a pending write; SIGKILLs the exact browser
process after a completed receipt; and restores in a fresh process with the same
identity/name and exact saved frame. It continues projectiles and saves again.

Further cases cover asynchronous deep-link resume, two tabs competing for one slot,
corrupt archive preservation, invalid/alternate slot names and corrupted identity
preservation. Direct IndexedDB mutation is limited to these negative fixtures; it
does not implement game saving or restoration. Published evidence must omit browser
profiles, raw identity/archive bytes and include only receipts/hashes.

`execute.sh WEB_OUTPUT FRESH_RUN_OUTPUT` reruns the browser gate against a prepared
export. The bridge is shared with the party fixture, but this gate uses the standalone
solo path and no party service. Native file-save and party publication regressions
remain separate checks.

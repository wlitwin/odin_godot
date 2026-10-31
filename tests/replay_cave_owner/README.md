# Cavecrawl owner-motion acceptance

`run.sh` builds a fresh owner-profile app and an isolated coordinator. It runs
model/WASM checks, menu/default-isolation checks, two-player loot/door play with
and without faults, a three-process relic handoff, and the existing four carrier
migration cases (planned/crash, carrier in seat 2 or 3).

The live drivers use ordinary movement/actions and read-only probes. They never
edit a running world. Faulted cases retain 120 ms receive delay, 0–20 ms jitter,
10% unreliable loss/duplication and require observed drops/duplicates. The relic
flow checks owner sequence 1 → 1 → 0 → 2 → 2, increasing ownership revisions,
fresh sample sequences, continued movement and inventory conservation.

```sh
REPLAY_CAVE_OWNER_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_owner/run.sh
```

`execute.py PREPARED FRESH_OUTPUT network|fault|flow` runs an individual case.
Preparation/framework and binary hashes identify the actual source/build. Native
coordinator migration uses the common carrier assertions with the distinct owner
content ID. Model tests verify exact whole-frame restoration; live migration gates
verify carrier/identity retention and continued movement/release.

The standalone service checkpoint gate is separate:

```sh
CHECKPOINT_GAMES=cavecrawl-owned CHECKPOINT_RESTORE=1 REPLAY_CHECKPOINT_OUT=/absolute/fresh/checkpoints nix develop --command bash tests/replay_room_checkpoint/run.sh
```

The real Chrome gate is separate from the native/WASM type checks:

```sh
REPLAY_CAVE_OWNER_WEB_OUT=/absolute/fresh/browser nix develop --command bash tests/replay_cave_owner/browser_run.sh
```

`browser_build.sh OUTPUT` builds/exports the instrumented owner game and an isolated
native WebSocket authority/rendezvous service. `browser_execute.py BUILD FRESH_RUN
planned|crash|save` runs one case. `browser_verify.py RUN MODE` independently checks
recorded ownership, scope revisions, RTC traffic and saved-frame/storage evidence.
The browser marker check preserves planned retirement-before-expiry acceptance;
crash checks absence at the new epoch, since the mark may already be gone during
fencing/lease recovery. It does not claim that every crash retires an unexpired mark.

The save gate uses the actual default owner namespace, preserves a synthetic record
in the server-profile namespace, and exercises fresh-process restore, concurrent
writers, archive corruption and identity corruption. Captures contain isolated test
identities and game packets. Runtime databases, browser profiles and service secrets
must not be published as evidence.

These cases establish the behavior listed above. Full owner-profile parity,
public deployment, and paired comparison require separate evidence. WASM type
checking alone does not establish browser execution.

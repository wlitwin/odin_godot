# Owner movement audit

This audits the movement discrepancy observed in the mixed Scrapyard comparison.
It preserves the original Kit and both game projects. The candidate repair exists
only in an isolated copy of `kit/net/registry.odin`; other framework directories are
read-only links to the current checkout.

```sh
nix develop --command bash tests/replay_movement_audit/core_run.sh
REPLAY_MOVEMENT_OUT=/private/tmp/owner-movement-new \
  nix develop --command bash tests/replay_movement_audit/run.sh
```

The engine-free regression predicts two ammo changes, advances owner-streamed and
simulation-lane coordinates between them, then applies an unrelated authority clock
delta. The original implementation restores the owner's old coordinate during
pending-command unwind. The test intentionally fails its owner-preservation assertion
against that implementation; the wrapper requires the specific failure. The isolated
control skips live owner fields during unwind and must pass, as must the existing
Kit networking test suite. The actual-owner and predicted-owner cases are both checked.

The live audit prepares the same mixed movement/status swarm for two Kit variants,
with byte-identical authored game/content/adapters. It adds read-only local-position
samples immediately before/after `boot_pump` and before/after normal owner movement.
The only shared-framework source difference is the candidate unwind change.
Three original/control pairs run in alternating order with the mixed contract's
20-second, 60 Hz / 60 FPS, two-player, 120 ms receive-delay settings.

The report checks live cooldown/status work, intent schedules, population, HP,
conservation and settled convergence. Away from turn boundaries it projects each
packet-processing position change onto the active input direction. Original clients
must reproduce backward changes with pending predictions; repaired clients and hosts
must have none. The movement step itself must not reverse the active input. Actual
path lengths and kills remain descriptive outputs, not assumed identical.

This is a causal control for the measured Scrapyard case, not a production Kit
upgrade or a general guarantee for every command that can write owner fields.
Broader cross-lane command semantics and any decision to update the original
framework require their own review. The Replay library/game is not changed by this
control. Timing numbers from the instrumented audit are not used as an adoption
benchmark; the previous mixed cohort remains a separately recorded observation.

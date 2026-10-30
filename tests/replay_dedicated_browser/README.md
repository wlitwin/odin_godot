# Browser infrastructure Room acceptance

```sh
REPLAY_DEDICATED_BROWSER_OUT=/absolute/fresh/output nix develop --command bash tests/replay_dedicated_browser/run.sh
```

A native coordinator with authenticated WebSocket signaling serves four separate
Chrome processes: two infrastructure identities and two real players. The game
is the actual Scrapyard model in a quiet arena. Infrastructure requests Server,
follows as Observer, opts into complete checkpoints, and must always have seat
zero. The players must retain seats 1/2.

The isolated fixture derives from `tests/replay_dedicated_room`. It replaces native
file barriers with browser-controller barriers and ENet with authenticated RTC.
The controller never supplies game state, ownership or checkpoint data. Admission
is ordered by real acknowledgements; shutdown waits for all four actors' final
state checks. Room retains its normal lease, role, checkpoint and recovery logic.

Planned handoff, host-process kill with fresh-process return, and repeated handoff
compare the exact restored authority frame, require prepared backups to the
returned/demoted server, and validate each final role. Browser RTC statistics must
show actual connected transports with sent and received bytes. The service uses
the existing Scrapyard browser profile's 5,000 ms lease and the unchanged 120-tick
known-rollback limit; each game adds 120 ms receive delay.

`build.sh OUTPUT` prepares native import/export inputs and a separate service.
`execute.py OUTPUT MODE [LABEL]` requires a fresh run directory and checks prepared
hashes before launch. Receipts retain sources, export/service identities, logs and
browser events. Do not publish runtime DBs or profiles with the receipts.

This is a local browser infrastructure acceptance gate. It does not establish
Steam support, public deployment, broad hardware coverage, or combat-stress
migration performance.

The browser observer splits checkpoint bookkeeping into a helper and copies the
complete frame into disjoint owned storage with `mem.copy_non_overlapping`.
The ordinary aggregate assignment expanded into more than 22,000 raw WASM locals
and made optimization slow. The equality assertion is unchanged. `wasm_locals.py`
records code-local counts for diagnosis; actual Chrome execution remains the
runtime acceptance check.

Final RTC inspection retains connection/ICE states and polls for at most ten
seconds for connected traffic before failing. The same traffic predicate applies
on every attempt. One earlier crash case passed game-state checks but failed a
single immediate RTC sample; it remains a separate failed receipt, not proof that
its cause was a transient reconnect. The successful observed run required one
sample for each participant.

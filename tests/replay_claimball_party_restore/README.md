# Claimball browser published-party restore

```sh
REPLAY_CLAIMBALL_PARTY_RESTORE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_party_restore/run.sh
```

The fixture starts three browser players and an observer, then publishes a
checkpoint while the scored match and ball motion continue. Before shutdown, an
independent reader checks the first publication's complete world, motion, score,
names, tick, and digest. The fixture then kills every browser process and the
service and reopens the existing database with creation disabled.

The observer registers first without becoming authority. The returning owner must
restore the published tick/digest in epoch two with its personal identity and seat
intact. Other players reclaim seats two/three and each continues predicting only
its own avatar. They execute two new spikes and exchange named observer chat.
An independent reader decodes the second publication, and all peers compare the
authority world at a common tick after recovery.
RTC traffic, graphics-buffer conflicts, control layout and absence of browser-local
save slots are checked.

`execute.py WEB_BUILD SERVICE_BUILD FRESH_OUTPUT` runs against existing prepared
exports. `verify/` reads the actual source/continued publication and emits only
noncredential observations. Raw browser profiles, service databases and invite
material are private test state and must be excluded from published receipts.

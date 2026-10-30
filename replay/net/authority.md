# Recorded authority observations

`Model.authority` opts a game into a pure simulation policy:

```odin
authority = {id = 1, apply = observe_authority}
```

The server records `Authority_Observation{known=true, seat=local_seat}` in each
`Batch`. Seat zero identifies a dedicated authority with no local player. The
policy runs after fresh-player resets and before the ordinary model step, under
the same commit gate and rollback transaction. It may change state and emit game
events, or abort the entire tick. The policy's nonzero identifier participates in
the negotiated model/checkpoint contract; change it when its semantics change.

The callback receives a recorded fact, not live process-role access. Keep the
previous observed authority in the game state when you need a transition. That
makes repeated observations idempotent and restores the previous identity with
the rest of the world during correction. Cavecrawl uses this to adopt a departed
host's carried relic while leaving avatars with their returning player identities.

Clients record an unknown observation and do not predict authority-policy calls.
They receive the resulting world/effects through normal authoritative snapshots
and facts. Gameplay packets expose no client-supplied authority observation. An
unknown observation must have seat zero; known observations require an enabled
policy and an in-range seat. Recording preflight checks these rules before any
simulation. Other simulation inputs continue predicting normally.

## Recovery and compatibility

`server_restore` retains the exact checkpoint frame. On the first subsequent
committed tick, the server records its newly authorized local seat. No hidden
checkpoint edit or unrecorded gameplay callback runs during restore. A checkpoint
captured before that first tick still contains the old game-state observation and
the current host seat in its existing header; another restore therefore does not
lose a pending identity transition. The game decides how a dedicated successor or
an initially unknown authority affects its entities.

Existing gameplay packet and checkpoint envelope formats are unchanged. Models
with the policy disabled retain their previous negotiated contract. An enabled
policy has a distinct contract, and games adding observation fields to their
worlds must explicitly convert their old state schemas.

`Batch` is also the diagnostic recording input type, so its schema fingerprint
has changed for all network recordings. Normal recording decode rejects the old
fingerprint. `recording_upgrade_without_authority` explicitly maps older inputs
only for models whose authority policy remains disabled; it cannot fabricate
missing host observations. It preserves the source context, frames, decisions
and events. Verification remains separate from conversion. See
[recording conversion](recording.md#older-network-recordings).

This observation identifies the runner's local player seat. It does not represent
all shared-authority object ownership, grant permission to host, or replace the
lease/coordinator checks that authorize a runner to commit.

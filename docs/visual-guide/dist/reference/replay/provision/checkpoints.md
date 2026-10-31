# Durable room checkpoints

Use durable room checkpoints to retain progress after every game process exits.
The native `replay/provision/sqlite` store retains one complete checkpoint per
provisioned room. Godot Room handles manual and optional automatic publication
through the [authenticated checkpoint protocol](checkpoint/README.md), which
provides client/server endpoints and a typed SQLite adapter.

A separate [published restore API](checkpoint/restore.md) grants fresh-process
authority. Room/Party drives that lifecycle, with native and browser Cavecrawl
rejoin UI acceptance. Scrapyard includes declared external assets in atomic room
packages. Native/browser tests verify restoration with an empty asset cache.
Broader asset profiles and game paths require separate integration.

Live host migration uses replicated recovery checkpoints. The standalone service
connects durable storage through a bounded room hub for three compiled game models,
with native TLS restart acceptance. [Room save handling](../godot/room_save.md)
integrates status, capture, publication and exact lost-reply recovery with normal
authority renewal.

## API and ownership

```odin
publication, error := storage.checkpoint_publish(
    &store, room.bundle.record, expected_publication_revision,
    prepared.point, prepared.bytes, game_model,
)

saved, found, load_error := storage.checkpoint_load(
    &store, room_id, content_id, game_model,
)
defer storage.stored_checkpoint_destroy(&saved)
```

Check every error before using outputs. The model and content ID come from the
trusted deployment, not uploaded metadata. Keep the Store at a stable address,
serialize its calls, and retain immutable input bytes until publication returns.
Loads return an owned copy that remains valid across later writes and Store close.
Destroy it once by pointer. A failed typed load returns no usable checkpoint.

`checkpoint_publish` is a trusted storage call, **not an authentication endpoint**.
The protocol server authenticates the requesting current host and authorizes
the operation against its live coordinator before calling it. Supplying an
`authority.Record` does not prove possession of credentials or a live lease.
Complete archives contain authority-only world data; downloads must be
restricted to eligible trusted hosts (infrastructure for dedicated games).

## Persistence contract

- Archives are bounded by `net.MAX_CHECKPOINT_BYTES` (currently 1 MiB). The typed
  decoder checks the complete current checkpoint schema and model contract,
  permit requirement, epoch and tick. Point room/content/epoch/size/SHA must agree.
  A cooperative checkpoint's local seat must belong to the recorded owner by
  game-token digest. A zero local seat requires dedicated authority policy.
- A write acquires `BEGIN IMMEDIATE`, reloads the durable private room Bundle and
  compares its entire authority Record to the supplied expected Record. A newer
  coordinator decision or competing coordinator restart fences the old writer.
  Released authority cannot publish a new checkpoint through this call.
- Publication has its own monotonically increasing revision. The caller supplies
  zero for the first publication, then the last known publication revision. In
  the same authority epoch, archive sequence must increase and tick cannot move
  backward. A later epoch may contain the explicit rollback approved by authority
  recovery. Storage itself does not approve that recovery or choose its limit.
- An exact retry of the currently stored publisher/Point/model contract returns
  the existing publication without writing, including after coordinator changes.
  This acknowledges a lost reply; it does not renew or reactivate the old host.
  Once superseded, an older publication is no longer an idempotent retry target.
- Metadata and bytes enter one transaction on the existing checked SQLite
  FULL/WAL connection. Publication does not mutate the authority Record, grant a
  lease, or change membership. A write error may be resolved by reloading/exact
  retry; callers must not assume an uncertain commit did not happen.
  The protocol's typed adapter supplies the expected contract and a commit guard;
  the guard rechecks live authorization after validation/update immediately before
  COMMIT. Rejection rolls the transaction back. Direct trusted storage calls may
  omit the guard, retaining the original storage-only API contract.
- Loads validate metadata framing and context, archive SHA, envelope checksum,
  kind, epoch and tick before returning bytes. `checkpoint_load` also validates
  the game-specific archive and stored contract. `publication_load` provides the
  envelope/integrity-only variant for trusted tooling; it is insufficient for
  starting a game.

The additional `replay_room_checkpoint` table uses publication metadata version 1.
The private Bundle version 1, authority Record version 3, gameplay protocol and
checkpoint version remain unchanged. Existing databases gain an empty table when
opened. Corrupt rows fail closed; they are not interpreted as absent saves or
silently overwritten. File privacy and backup requirements match the room store.

<a id="remaining-all-members-gone-recovery-work"></a>

## Recovery coverage and remaining integration

The following list records implemented service and game coverage, required
recovery invariants, and the cases still needing acceptance.

1. The standalone room service integrates authenticated upload/download/status
   with deployment-selected Cavecrawl, Speedball and Scrapyard models and bounded
   per-room endpoint ownership. The library binds exact requests,
   content/contracts and revisions to registered identity/nonce/connection
   generations, reusing bounded blob transfer. It never exposes a private Bundle
   or trusts a client-supplied authority Record.
2. Room publication is tested with the game models and scenarios below;
   additional game ports need their own acceptance. The library rechecks live ownership during transfer and at final commit,
   rejects revocation/expiry/competing durable CAS, and resolves exact committed
   retries. Native TLS verifies the three actual game models' tick-1 archives
   followed by service restart and a fresh trusted incarnation's identical download.
   Room/Party support save cadence/status and Cavecrawl's active-game save path;
   native acceptance preserves actual loot across host and successor publications.
   Cavecrawl's browser gate also publishes before and after RTC host migration while
   preserving room isolation and stable rejoin. The remaining ports, broader browser
   acceptance and broader asset profiles still need
   integration before treating these checkpoints as complete resumable game saves.
3. The durable restore decision binds an exact publication and an eligible
   member's registered process to a newer epoch. A recovery-enabled service permits
   expired-owner Rebind only after lease expiry/quarantine; this grants no lease.
   The separate Restore operation atomically compares the publication and Record,
   persists epoch/request outcome together, and applies trust, seat reservation,
   release and rollback rules. Native TLS restores all three actual game models.
4. Preserve lease expiry/restart quarantine and known rollback limits. A competing
   live migration or restore must win one CAS; old uploads, registrations and
   gameplay packets must not mutate the new epoch. Exact retries after a lost
   recovery grant must retain the already approved source point.
5. Room downloads/validates and owns the checkpoint, waits for the existing
   asset-preparation callback, requests the guarded grant and creates Session only
   under its live newer epoch. It preserves stable seats/tokens and the normal
   explicit pending-action disposition, separates profiles, and reports the saved
   tick plus service-known rollback. Complete asset packages commit atomically
   with the checkpoint; typed collectors and content validators reject missing or
   extra dependencies. Restore compares the package descriptor again at commit.
6. Cavecrawl's Room/Party resume/retry UI passes native and fresh-browser
   service-kill/rejoin tests with continued play, new guests and a new publication.
   Continue broader native and browser
   service/client restarts with every participant absent, competing resumes,
   partial uploads, lost replies, stale credentials, changed assets/content,
   corrupt storage and dedicated-policy restrictions. Port and compare Cavecrawl,
   Speedball and Scrapyard while keeping their original games runnable.

## Validation

`nix develop --command bash tests/replay_provision_sqlite/run.sh` covers ownership,
reopen, exact retries, publication/coordinator CAS, sequence/tick monotonicity,
model mismatch, wrong owner/context/hash, read-only storage and corruption.
Real subprocesses are killed at SQLite's
[commit hook](https://www.sqlite.org/c3ref/commit_hook.html) before publication
commit completes, and after successful commit. Fresh processes verify either the
entire old or entire new publication and that coordinator reopening does not
activate authority. These are process-crash tests, not power-loss or disk-failure
certification. See [captured evidence](../../docs/replay/results/room-publication-2026-09-09/README.md).

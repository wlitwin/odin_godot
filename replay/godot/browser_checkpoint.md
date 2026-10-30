# Browser identities and local checkpoints

`Browser_Identity` reads or creates a persistent 16-byte Session token through
IndexedDB. Keep it at a stable address, poll it before opening a runner, and obtain
the token through `browser_identity_token`. A token is published only in Ready.
Missing records are created with CAS(0); a competing creator reads the winning
record. Malformed data and storage failures never produce a volatile replacement.
Explicit test tokens can bypass this helper; they are not account authentication.

`Browser_Checkpoint(S,C,A,E,N)` owns a local self-contained authority archive and
its observed storage revision. It uses the same canonical checkpoint codec as
native save/resume. Open it before a new run or explicit resume:

```odin
storagegd.browser_identity_open(&identity, "my-game")
// On subsequent frames:
storagegd.browser_identity_frame(&identity)
token, ready := storagegd.browser_identity_token(&identity)
// Once ready, open one token-scoped slot with your model/content.
rgd.browser_checkpoint_open(&slot, "my-game", slot_key, model, content, token)
rgd.browser_checkpoint_frame(&slot)
```

Ready means the initial read completed. `has_checkpoint` distinguishes a missing
slot from a validated archive. The loader checks the complete model/content
contract and owning seat credential. This helper refuses permit-protected and
custom-admission-policy archives: a local save is not a shortcut around Room
approval. External asset dependencies need an application bundle, as Scrapyard
already uses; they are not inferred from World.

During play, call `browser_checkpoint_save(&slot, &session)` on a local authority.
The function captures the complete frame and session ledgers once and submits an
asynchronous write. A true return means submitted, not saved. Keep pumping the game
and `browser_checkpoint_frame`. `receipt_serial` advances after a completed write
attempt; `last_success`, `saved_tick`, `saved_hash` and `revision` report the result.
The saved hash includes the frame tick. Storage and codec failures are reported
separately. At most one write is outstanding in a slot.

Writes use the slot's previously observed revision. They do not fetch a newer
revision merely to enable replacement. A stale tab receives Conflict and retains
the prior loaded archive; the stored winning archive is unchanged. Failed slots
cannot write or resume until an explicit reopen/reload decision. An application
can still permit a new unsaved run while clearly reporting that storage failed.

The `checkpoint` is owned by the slot. Borrow it only while Ready for a synchronous
`session_resume`, which copies the required state into the new runtime. Resume
still requires the owning token and a newer authority epoch. Do not destroy the
borrowed checkpoint. Keep the supplied model and any immutable model.user data
alive for the slot's lifetime.

Close with `browser_checkpoint_close` and `browser_identity_close` when their
owner is released. Closing a pending write may discard a receipt after a commit
has happened; it is not proof of rollback. Cavecrawl disables Leave while saving
and reports success only after transaction completion. Browser termination can
still interrupt a write, so reopening reads whichever revision actually committed.

These helpers inherit the [browser store](storage/browser_store.md) limits and durability
boundary. Identity and save slots are separate transactions; a confirmed identity
precedes session creation, so a completed save does not refer to an uncommitted
new credential. Browser deletion/eviction and same-origin access still apply.
There is no claim of portable power-loss durability or public identity provisioning.

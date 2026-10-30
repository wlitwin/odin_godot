# Browser blob storage

Use the browser store to persist bounded opaque bytes in IndexedDB, such as a
profile or encoded save. `browser_store.odin` provides asynchronous operations. Keep I/O outside simulation steps. An operation has one owner and three
phases: Idle, Pending, Complete. Submission returning `true` means work started;
only Complete with error None is a success receipt. Close each operation after
consuming its result.

```odin
write: storagegd.Browser_Store_Op
if storagegd.browser_store_write(&write, "my-game", "profile", bytes, revision, 4096) {
    // Continue rendering/pumping. Poll on later frames.
}
if storagegd.browser_store_poll(&write) == .Complete {
    if write.error == .None {revision = write.revision}
    storagegd.browser_store_close(&write)
}
```

Read with `browser_store_read`. A successful read exposes its revision and
`browser_store_bytes`, which returns owned bytes using the requested allocator.
Missing is distinct from an unreadable or corrupt record. Decode and validate
application content before installing it. Native calls return Unsupported; the
existing staged-file storage functions remain available there.

Writes compare the supplied revision with the stored revision inside one
read/write transaction. Revision zero creates an absent key. Success increments
the revision; a mismatch returns Conflict without replacing another writer's
value. The revision range is 1 through 2^53−1. After a conflict, load the current
record and decide how to proceed. The API does not merge profiles or inventories.

Records hold a revision and a Blob. Reads validate shape and Blob size before
materializing bytes, then check the copy again on the Godot side. Limits are
1 byte–16 MiB per operation, 16 retained operations and 64 MiB of reserved operation
capacity per page. Namespace/key strings use 1–128 ASCII letters, digits, dots,
underscores, hyphens and slashes. Each namespace maps to an origin-local database
named `replay/<namespace>` with a version-1 `blobs` store. Namespace separation is
organizational; other code on the same origin can access these records.

The writer uses a bounded base64 string because Godot's generic JavaScriptObject
method call did not convert PackedByteArray in the tested engine. This incurs
temporary encoding/string copies beyond the reserved payload budget. Reads use
the [JavaScriptBridge buffer conversion](https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html).
The payload limit is not a total process memory bound.

Success is published from transaction completion, after all requests commit;
request success alone is insufficient. Writes request `strict` durability. These
semantics follow the [IndexedDB transaction contract](https://w3c.github.io/IndexedDB/#transaction-concept).
The tested configuration is Chrome on arm64 macOS, including a killed browser after
a completion receipt. Browser quota, eviction and user deletion remain applicable;
portable power-loss durability is not claimed. Storage errors are surfaced
without an automatic volatile fallback.

Closing a pending operation discards its receipt and attempts to abort an active
transaction. A write may already have committed. Read its record to determine the
result; closing is not proof of rollback. A pending operation does not become successful merely because time has elapsed. A blocked database open reports Open, and a caller may close an operation
it no longer wants to await.

`tests/replay_browser_store/run.sh` exercises the real Godot/WASM bridge and
IndexedDB: 1 MiB and 16 MiB exact-content round trips, fresh browser recovery,
two tabs writing from the same observed revision, size/corruption rejection,
an aborted transaction preserving the old record, and recovery after SIGKILL.
It also forces a synchronous request failure followed by completion of the empty
transaction; the failed save must remain failed and retain the previous record.
The tabs are focused while their Godot loops run; this is stale-tab conflict
coverage, not every browser suspension or simultaneous scheduling case.

Scrapyard's [profile integration](../../../examples/replay_scrapyard/profiles.md)
creates its identity before opening the session, saves confirmed preferences and
upgrades, and exposes pending/failed saves to the player. A complete run bundle
is serialized into one blob by its [browser run-save integration](../../../examples/replay_scrapyard/saves.md).
Checkpoint and image dependencies commit together. The separately stored spray
preference applies to fresh runs; it cannot silently replace a resumed image.

The JS helper is installed once per page. Reload the page to apply changes to
that helper's implementation; operations do not retain pointers into Odin memory.


[Cavecrawl's browser checkpoint flow](../browser_checkpoint.md) uses the same service
for persistent Session identities and token-scoped self-contained archives. It
validates ownership and content before resume and retains the initially observed
slot revision to reject stale-page replacement.

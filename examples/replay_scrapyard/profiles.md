# Local co-op profiles

Browser play uses the shared [asynchronous IndexedDB store](../../replay/godot/storage/browser_store.md).
The game waits for its identity and profile before opening the Replay runtime,
which schedules simulation steps and retains input/history. Identity
creation uses a create-only transaction; a competing creator's identity is loaded
instead of overwritten. Profile writes compare the last loaded revision and only
mark progress saved after a transaction completion receipt. A competing write
stops local saving and reports unsaved progress. It never replaces newer storage
automatically. The HUD distinguishes saving from saved loadout/upgrades.

The default browser database is `replay/scrapyard`, scoped to the page's origin.
`profile_namespace` selects a separate database for fixtures. As on native,
explicit `token` values disable persistence unless `persist=1` is supplied.
The browser uses the same validated profile codec and cooperative owner-claim
policy described below. It does not import a native profile. Runs and spray
preferences use separate [save operations](saves.md); an upgrade receipt does not
save the current run. Browser eviction/deletion can remove
local progress; portable power-loss durability is not claimed.

`web_profile_run.sh` earns two floor-clear cores, buys a plate, kills Chrome and
starts a new browser with the same isolated disk profile. It checks the unchanged
identity/profile bytes, restored choices and 14-HP plate entry. It also preserves
the competing record after a revision conflict, and refuses a corrupted profile
before a session opens. Original Scrapyard data remains separate.

Native interactive play keeps a stable random reconnect identity in this project's
`user://replay_identity` and a separate canonical profile record keyed by its token
hash. The Godot project uses the `replay_scrapyard` user-data directory; no original
Scrapyard profile is imported, overwritten or cleared. Explicit fixture tokens
disable persistence by default. Tests can opt in with `RSY_PERSIST=1` and an isolated
`RSY_PROFILE_DIR`. Two local player processes need different identities: use
different existing profile directories, or an explicit fixture token for a temporary
second player. Reusing one identity concurrently is deliberately rejected.

The version-2 record stores [automatic/explicit choice modes](automatic.md),
the identity binding, cores/parts, accepted staging preferences,
and the epoch/tick of the last saved change. Version-1 records remain readable
as explicit choices. Checksums, schema/version and value
validation reject malformed records. Identity mismatch rejects a record copied to
another account path. A malformed existing identity/profile fails opening instead
of silently creating a replacement identity or resetting progress.

This preserves the original **cooperative owner-claim trust model**. The host accepts
an opening meta claim once per occupant. Later lobby declarations cannot restore
spent cores or replace earned state; reconnect/migration keeps the existing claimed
state. This local file is editable by its owner and is not a competitive economy
service or an anti-cheat mechanism.

Only authority observations are saved—never speculative purchases or predicted
rewards. The owner writes a staged file, flushes/closes it, then renames it over the
previous record. The previous file and in-memory saved record remain unchanged if
writing fails; the game reports that failure visibly. This is a process-crash
boundary, not a portable power-loss/fsync guarantee. After recovery, the installed
authority state wins over an older local claim; possible checkpoint rollback remains
part of the room's declared recovery policy.

Lobby settings are idempotent declarations. Stale/future rejections of the latest
local declaration or Ready setter trigger a new declaration; updates preserve the
owner's desired readiness. Other players' action sequences do not trigger retries.
Casts and purchases keep their explicit action outcomes rather than being blindly
reissued as new transactions.

`profile_run.sh` earns cores through two real floors, buys a plate, closes Godot and
opens a fresh process with the same identity. It verifies the restored part, health
and loadout, then checks both corruption rejection and preservation of the old file
when a staged write cannot open. Its files live in a temporary directory.

# Live recovery-backup status

Run `run.sh` inside `nix develop`; `REPLAY_BACKUP_STATUS_OUT` selects fresh output.
The fixture prepares an isolated Slopball app and typed Room service. A test-only
callback delays the existing `preparation_ready` barrier, as an external dependency
could; it does not fabricate an approved checkpoint or authority.

Three native peers exercise waiting for a candidate, unapproved preparation,
approved/locally retained copies, cached approval while RPC is pending, age beyond
the unchanged rollback bound, refreshed preparation, planned handoff and loss of
the next nominated peer. UI text must reflect those observations. The observer
remains seat zero.

`execute.py APP_BUILD SERVICE_BUILD FRESH_OUTPUT` reuses prepared builds. Atomic
request/status files can contain invite text and must stay private; `events.json`
omits it. The focused Room status tests separately cover invalid clocks, epochs,
trust, disconnected/mismatched host connections and exact freshness boundaries.

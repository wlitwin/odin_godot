# Replay Godot storage

Import this package when a game needs native files, browser persistence, local
profiles, or an explicit recording-file chooser:

```odin
import storagegd "godot:replay/godot/storage"
```

It depends on Godot and Replay's engine-free codecs and value types. It does not
open a gameplay transport, select session authority, or drive a simulation.

| Task | Public operations |
| --- | --- |
| Bounded native files | `storage_write`, `storage_read` |
| Native authority checkpoints | `checkpoint_write`, `checkpoint_read` |
| Checkpoints with immutable asset dependencies | `checkpoint_bundle_write`, `checkpoint_bundle_read`, `checkpoint_bundle_encode`, `checkpoint_bundle_decode` |
| Native reconnect credential | `session_profile`; `session_token` creates an explicit token without persisting it |
| Browser key/value transactions | `Browser_Store_Op`, `browser_store_read`/`write`, `browser_store_poll`, `browser_store_bytes`, `browser_store_close` |
| Browser reconnect credential | `Browser_Identity`, `browser_identity_open`, `browser_identity_frame`, `browser_identity_token`, `browser_identity_close` |
| Persistent display name | `Name_Profile`, `name_profile_open`, `name_profile_set`, `name_profile_frame`, `name_profile_close` |
| Explicit recording-file selection | `File_Import`, `file_import_init`, `file_import_begin`, `file_import_poll`, `file_import_take`, `file_import_destroy` |

`storage_read` and successful bundle reads return owned bytes. Release them with
the allocator supplied to the read; bundle views borrow those bytes. Native
writes stage a complete file before renaming it over the destination. Keep one
writer per path; this is not a portable power-loss guarantee.

Browser operations are asynchronous. Keep each owner at a stable address, pump
it until completion, inspect its error/receipt, then close it. Submission does
not mean a write committed. `browser_store_write` uses the previously observed
revision for compare-and-swap; closing an outstanding operation discards its
receipt and does not prove the transaction rolled back. Native/browser profile
namespaces share the validation exposed by `browser_store_key_valid`.

`File_Import` owns its dialog and callbacks while its parent node remains alive.
Read only after explicit user selection. `file_import_take` transfers the returned
bytes to the caller; free them with the importer's allocator. Reset cancels the
current selection/read, and destroy closes the complete owner.

The root `replay/godot` package keeps `Browser_Checkpoint` and its Session-specific
save/restore policy. It builds on this package, as do enrollment and Room flows.
See [browser storage](browser_store.md) and
[local Session checkpoints](../browser_checkpoint.md) for their detailed contracts.

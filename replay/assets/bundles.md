# Self-contained save bundles

A bundle combines an opaque checkpoint/root document with the exact asset payloads
it requires. The root remains independently encoded; assets are sorted by reference
and deduplicated. Capturing gameplay state does not silently capture an entire cache.

`bundle_encode(root, refs, cache, meta)` validates references, availability and total
size before allocating the output. Missing content fails before any file write.
The format permits a 1 MiB root, 32 assets and a 16 MiB total file. A small canonical
header stores version, lengths, asset count and the body's SHA-256; the appended
body contains the root followed by canonical references and payloads. This supports
files larger than the network envelope limit without weakening that limit.

`bundle_decode` checks the header, exact lengths, body digest, sorted/unique
references and each asset's content ID. It returns read-only views into the supplied
file bytes and changes no cache. Keep those bytes alive until the views are no
longer used. `bundle_install` checks every asset, optional format validators and
aggregate cache capacity before installing anything. Invalid data, validation
failure or capacity exhaustion preserves existing entries and pins.

The Godot helpers `checkpoint_bundle_write` and `checkpoint_bundle_read` connect
the format to the existing checkpoint codec and staged file writer. Read returns
owned file bytes plus a borrowed view; the caller must check identity/authority
policy and dependency completeness before installing assets and resuming. Outer
and inner content/epoch/tick metadata must agree. Callbacks, reconnect credentials
and live transport objects remain outside the archive.

`checkpoint_bundle_encode` returns owned bundle bytes without performing I/O.
`checkpoint_bundle_decode` validates supplied bytes and returns a borrowed view.
Both share the same checkpoint/metadata validation with the file helpers. This
lets an asynchronous backend store one complete bundle and report its own commit
receipt. Scrapyard uses these helpers with IndexedDB for browser solo saves.

Plain checkpoint files are also readable, with an empty asset set. A game that
requires external assets must reject such a file unless those dependencies are
actually included by an explicitly supported alternate mechanism. Scrapyard checks
every player's image reference and requires it to be in the bundle, even if an
unrelated local cache happens to contain the same image.

The writer encodes everything before opening the staging file and then uses the
existing flush/close/rename path. This is a process-crash boundary, not a portable
power-loss guarantee. One writer owns a save path. The format does not grant a
coordinator lease or authorize loading another player's local seat.

`bundle_replace_root(original, new_root, content)` supports explicit application
upgrades. It validates the entire original bundle, preserves its metadata and
asset records/payloads, and returns owned bytes with new lengths and a new body
digest. The source is unchanged. The replacement root must be 1 byte–1 MiB and
the complete output must remain within 16 MiB. This generic operation does not
validate the replacement root's semantics, metadata or dependency completeness;
the application must do that before publication. See the
[protocol-6 checkpoint bridge](../net/checkpoint_upgrade.md).

The optional `target_content` argument explicitly updates the outer content ID for
an application-schema conversion. Zero (the default) preserves the source content.
The source is always validated against the required `content` argument first.
Epoch and tick remain unchanged. The caller must validate that the converted root
actually declares the new content before writing or restoring the bundle.

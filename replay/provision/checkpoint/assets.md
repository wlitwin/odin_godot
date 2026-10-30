# Durable checkpoint assets

A room publication can now include its complete external asset set in the same
transaction as its checkpoint. The authority Point continues to name the raw typed
checkpoint. A separate signed payload descriptor names the transferred package;
the package verifies its root against that Point and checks every asset's content
hash. Restore grants still select the exact checkpoint publication.

## Dependency policy

The deployment and game supply the same `Asset_Policy`:

```odin
policy := checkpoint.Asset_Policy{
    collect = game.checkpoint_assets,
    validate = scenegd.asset_png_valid,
}
backend.assets = policy
room_options.checkpoint_assets = policy
room_options.checkpoint_cache = &asset_cache
```

`collect` receives the raw checkpoint, a bounded reference buffer and an optional
borrowed checkpoint codec. It must
enumerate all required assets, including executable pending work. Return false on
overflow or invalid input. Zero references and duplicates are normalized; malformed
references fail. The callback may decode the checkpoint with its deployment-selected
model but must not mutate it or call back into storage. `validate` checks actual
asset content and is mandatory for a nonempty dependency set.

Room builds reusable schema metadata before acquiring authority and shares it with
checkpoint encoding, decoding and dependency collection. Collectors may use that
codec for their declared model while it remains borrowed; they must not destroy or
retain it. Packaging enumerates dependencies once and validates the encoded entries
without decoding the root again solely to repeat the same enumeration.

Scrapyard's collector includes current player sprays and accepted executable
pending `Set_Spray` declarations. Its service and Room validate PNG data through
the existing bounded Godot image decoder. Rejected/retired declarations do not
require an asset that will never be installed.

The service requires an exact asset set: missing, extra, corrupt and semantically
invalid entries are refused before publication. A game without declared external
dependencies continues to use raw checkpoints. Undeclared extra uploads are not
accepted as a general-purpose storage bucket.

## Package and persistence

The transfer package is a canonical envelope around the existing asset bundle.
The full payload, including checkpoint and assets, is limited to **1 MiB** and **32
unique references**, matching the room transfer profile. Each asset remains subject
to its game/cache limits. The local-file bundle profile retains its separate 16 MiB
limit. `bundle_encode` now accepts a lower caller-selected bound and checks it before
allocating the output; room packaging uses that preflight.

The SQLite store adds `replay_room_checkpoint_package`. Raw checkpoint, publication
metadata and package are written/removed atomically. A single joined read obtains
one coherent publication/package snapshot. Package framing, root identity, asset
hashes and model dependency policy are checked before a typed load returns data.
A zero-length or corrupt package row is not treated as an absent package.

Restore's commit guard compares the package descriptor as well as the publication,
so the package cannot disappear or change between validation and the authority
decision. Existing raw checkpoint publications remain readable for models that
require no assets. A legacy raw checkpoint that requires missing assets fails
validation; it is not silently acknowledged as complete or repaired with guessed
data. Back up the complete private database, including this table.

`Saved.bytes` owns the raw checkpoint and `Saved.payload` owns the optional package.
Destroy them together with `saved_destroy`. The stored package duplicates its root,
so on-disk root-plus-package data is bounded by twice the 1 MiB root limit per room;
transfer bytes remain at most 1 MiB. Repeated publications replace the previous
package; there is no unbounded asset history or cross-room asset sharing.

## Room integration

Room packages assets from the borrowed cache after capturing its immutable root.
Missing cache data prevents upload. The transfer owns its accepted bytes, so later
cache changes cannot alter that in-flight package. A lost reply is resolved through
the current validated publication, as with raw checkpoints.

During recovery, Room validates dependency completeness and installs the package
into its cache before the existing preparation callback and restore request.
`bundle_install` preflights the complete set and cache capacity before mutation.
The cache must outlive Room; the game still owns texture/material construction.
Installing bytes does not grant authority.

Checkpoint-transfer protocol **3** adds the payload descriptors and v3 HMAC domain.
Clients and services must upgrade together. Publication metadata, authority Record,
private Bundle, gameplay protocol and raw checkpoint formats remain unchanged.

Bundled transfer deliberately starts with one complete durable snapshot. It does
not implement cross-publication deduplication, independent asset uploads or saves
beyond this transfer bound. Save age, transfer duration and the room's existing
rollback policy remain separate: a durable checkpoint can still be too old for a
restore grant. No recovery-policy limit is relaxed by asset publication.

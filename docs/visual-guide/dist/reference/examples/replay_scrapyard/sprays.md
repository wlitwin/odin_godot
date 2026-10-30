# Spray images and decals

Choose a PNG in staging, or place it at this project's `user://spray.png`. G stamps
it at the runner's simulated position. One decal belongs to each runner: stamping
again moves it, and selecting a replacement image repaints the standing decal.
Floor transitions remove the placement but keep the signature. Missing image bytes
show a diamond until delivery finishes. PNGs are limited to 128 KiB, 2048 pixels
per dimension and 1,048,576 total pixels before Godot decodes them.

`RSY_SPRAY` selects an initial file; `RSY_SPRAY_STORE` overrides the picker save
location on native. Browser picks use an IndexedDB record bound to the loaded
profile identity. With persistence enabled, the PNG is validated and pinned in
cache before submission, and replaces the active preference only after the commit
receipt. The HUD shows **Saving spray…** while waiting. Revisions protect against
competing writes. Fresh runs load this preference; resume uses the checkpoint's
image. With `persist=0`, picks stay in memory. Explicit fixture tokens do not
implicitly read a user's spray. The
original game's files and user-data directory remain separate.

The simulation holds only `assets.Ref` (SHA-256 and byte count), position, stamp
counter and floor. Set-image/stamp are normal reliable actions. The application
announces its local upload outside gameplay; the authority admits Set_Spray only
once the bytes have passed content validation and entered its cache. That decision
is recorded by the runner and is not re-evaluated during prediction/replay. The
stamp origin is taken from the world, not claimed by a caller.

The [asset service](../../replay/assets/README.md) handles transfer, caching and
late join through the Session's optional application lane. It shares the transport
budget with gameplay and checkpoint replication. Peer bindings come from the
admitted roster. Images are validated before cache installation, and failed local
picks leave the prior accepted image and saved file intact.

Room preparation checks the image references in each candidate checkpoint before
advertising it to the coordinator. Current and prepared dependencies stay pinned;
earlier cached public images can fill a retained checkpoint. Incomplete newer
candidates can be refreshed from newer received checkpoints without discarding the
previously approved point. Recovery can use that older point if necessary.

`spray_run.sh` exchanges two different images, joins observers before and after
replacement, checks decoded texture sizes and exact content IDs, moves a standing
decal and rejects a malformed replacement. `spray_migration_run.sh` pauses the
successor's asset service until a candidate is demonstrably waiting on its image,
then resumes delivery and tests planned/crash combat takeover with a visible spray.

```sh
nix develop --command bash examples/replay_scrapyard/spray_run.sh
RSY_JITTER=20 RSY_LOSS=1000 RSY_DUPLICATE=1000 nix develop --command bash examples/replay_scrapyard/spray_run.sh
nix develop --command bash examples/replay_scrapyard/spray_migration_run.sh
```

Manual saves now bundle the downloaded images referenced by the saved world.
They can restore and serve an offline owner’s spray without its original file.
A browser picker, persistent preference, WebRTC exchange and browser/native save
bundles now have acceptance gates. A persistent general-purpose network cache,
public web deployment, Steam, full presentation/audio parity and broader quota/
recovery cases remain work.
This port adds explicit pixel limits beyond the original compressed-byte limit.

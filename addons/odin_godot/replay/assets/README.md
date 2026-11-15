# Asset references, caches and exchange

Use `assets.Ref` to refer to immutable payload bytes from gameplay state without
copying those bytes into every frame. It contains a SHA-256 ID and byte count,
and is suitable for a frame, canonical schema or checkpoint. Payload bytes live
in a separately owned `Cache`. A new payload gets a new ID; receiving an asset
does not change simulation state.

`cache_put` owns a copy and validates an expected reference when supplied.
`cache_read` / `cache_copy` return copies so ordinary reads cannot mutate content
under an existing hash. Cache capacity and invalid data leave previous entries
intact. Pins protect current dependencies; release pins and explicitly discard
entries that are no longer needed. Destroy the cache when its lifetime ends.

`Mesh` exchanges missing watched references with explicitly bound peers. Its name
does not require a full network mesh: bind only the authority on clients, and the
admitted client connections on the authority. Simultaneous requests travel in both
directions. Once the authority caches a player's asset, it can supply later joiners;
a surviving cached copy can serve after a new authority/binding is installed.

```odin
assets.mesh_init(&mesh, &cache, application_wire)
assets.mesh_bind(&mesh, admitted_peer, scope)
assets.mesh_watch(&mesh, needed_references[:])
assets.mesh_frame(&mesh, monotonic_ms)
```

Mesh requests missing references in its watched working set and makes that set
public to bound peers. `mesh_publish` keeps earlier cached revisions available
without pinning or requesting them. An optional per-peer authorizer can further
restrict serving. It is checked again during a transfer, and revocation cancels
the remaining output. An optional content validator runs before installation.
The frame reference identifies expected content, independently of any file path
supplied by a sender.

The default profile has 32 cached entries, 128 KiB per asset, a 4 MiB cache and 32
watched references. Up to 16 bound peers share 64 KiB/s output, 16 KiB per update,
a 32 KiB burst, at most four requests per update and one new payload encoding per
update. Ingress is limited to 64 packets/128 KiB per update. Each bound receiver
allocates only the configured asset limit plus framing. Cache exhaustion is explicit;
there is no implicit eviction of assets used by another subsystem.

`mesh_watch` pins cached dependencies without duplicating pins on repeated calls.
Supply retained-history/checkpoint references as well as the current visible set
when those lifetimes require them. `mesh_complete` reports byte availability for
the working set. A missing asset remains missing rather than becoming guessed
content. Applications can display a placeholder while requests retry.

The Godot `Session_Assets` facade sets up the optional application lane, binds the
admitted roster and rebuilds peer workers on transport/authority changes while
keeping the cache. Call `session_assets_enable` on options before opening Session
or Room, and `session_assets_frame` after its frame pump, including fenced frames.
It does not infer dependencies from arbitrary game types. Use a [save bundle](bundles.md)
with the complete dependency set when persisting a world and its payloads.

`png_info` preflights PNG signature, IHDR CRC, dimensions and encoding fields before
pixel allocation. It does not replace a full decoder. Godot's `asset_png_image`
then validates/decodes the complete image. Defaults cap compressed bytes at 128 KiB,
dimensions at 2048 and pixels at 1,048,576; bounds are configurable. The header and
CRC rules follow the [W3C PNG specification](https://www.w3.org/TR/png-3/#11IHDR).

Native fault tests cover bidirectional transfer, late caches, source loss/new epoch,
stale requests, private unadvertised cache entries, per-peer policy and content
rejection. `mesh_announce` offers locally cached content before its ID enters
gameplay. Offer acceptance is opt-in per admitted peer, with one pending offer
per peer, bounded requests and a timeout. The Godot facade accepts offers from
admitted players, not observers; its cache is specifically for public room assets.
Earlier cached revisions remain available through the facade after a working-set
change. Use a separate cache or a per-peer authorizer for private content.

The network model's authority-only `action_admit` hook can require the validated
bytes before accepting a reference-setting action. Its decision enters the action
ledger; prediction/replay do not consult mutable caches. Scrapyard uses that hook,
then gates coordinator preparation on the checkpoint's image dependencies.

These guarantees cover transport and cache behavior. Each game must supply
complete save dependencies and test its recovery/browser behavior through
integration gates.

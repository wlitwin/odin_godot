# kit/save — quit and resume a run

Use `kit/save` to save an authority's run to disk and restore it later. It uses
the [session](session.md) backup snapshot and `session_host_resume`, which also
support recovery after host loss. The backup sent every few seconds contains
the session state needed to rehost; `kit/save` stores it in a versioned file
alongside game-specific data. The package also creates persistent player tokens
so returning players can reclaim their identities.

Saving operates at the session level for either replication model. The file
contains delta-lane state and `gd:"backup"` data. It excludes simulation runtime
history and inputs in flight: resuming a simulation save restarts the authority
and initializes a fresh lane from saved authoritative fields. Live host
migration supports only the cooperative lane; see [sim.md](sim.md).

```odin
import ksave "godot:kit/save"
```

<a id="mental-model"></a>

## Save layout and restored identities

The file layout:

```
[magic u32][format u16][game_version u16][saved_by u64][game blob][session snapshot]
```

- `format` is the SDK's file-layout version, currently `FORMAT :: u16(3)`.
  It changes with the session snapshot layout: version 2 added entity blobs
  and wire codecs; version 3 added the roster's admission state, `locked` and
  `denied`. Files from incompatible SDK versions return `Bad_Envelope` before
  their contents are interpreted.
- `game_version` is the game's content version. The game supplies the value
  and decides which content changes require a new one.
- `saved_by` records the saving host's `Player_Id` so it can resume under the
  same identity. Hosts have no reconnect token because they did not join as
  clients.
- The game blob contains host-local data outside session identity, stats, and
  entities, such as wave directors, AI clocks, and quest flags. The game is
  responsible for saving that state.

Restore seats the caller as host in a lobby with the saved world loaded. Other
players are disconnected but retain reclaimable identities. When they rejoin
with persisted tokens, they recover their ids, stats, and owned entities
through the normal reconnect path.

Envelope encoding and decoding are independent of Godot and can be unit-tested
as bytes. File helpers wrap FileAccess so `user://` paths work on every
platform, including web.

## Declaring the game blob

Save the same host-local fields used for migration; see [session](session.md).
Tag them `gd:"backup"` on the game class. Scriptgen generates
`<class>_backup_write` / `_read` with a field-layout version hash. Both takeover
and disk resume can use that pair, keeping the write and read field lists in
sync:

```odin
CaveLobby :: struct {
	host_ticks: int                           `gd:"backup"`,
	director:   kai.Director                  `gd:"backup"`, // serialize the complete POD struct
	brains:     map[knet.Net_Id]Dweller_Brain `gd:"backup"`, // map[POD]POD: serialize length, then entries
	respawn_at: map[knet.Net_Id]int           `gd:"backup"`,
	// ...
}

// the migration half (kboot.boot_migration's table calls it, host only):
@(gd_half)
cave_lobby_backup :: proc(self: ^CaveLobby, w: ^knet.Writer) {
	if self.started {cave_lobby_backup_write(self, w)}
}
// Read from a save file or the successor's `<game>_took_over(r)` half:
if !cave_lobby_backup_read(self, &r) { /* abort restore for incompatible or truncated data */ }
```

Supported fields are plain-data (POD) scalars, structs, fixed arrays,
`map[POD]POD`, and `[dynamic]POD`, including fields reached through `using`
and embeds as with `replicate`. Slices, strings, and non-POD elements produce
build errors. The field-set hash lets a reader reject data from an incompatible
build before interpreting it. For manually serialized fixed-layout state,
`knet.write_pod`/`read_pod` expose the same primitive.

<a id="versioning-what-crosses-time-what-crosses-the-wire"></a>

## Save, schema, and protocol versions

The repository uses three version checks for different data lifetimes:

- Saved field data, including save files, `gd:"backup"` blobs, and succession
  payloads retained from an older build, uses a generated FNV field hash.
  A reader compares its layout with the writer's because the writer may no
  longer be available for negotiation. Scriptgen's
  `<class>_backup_write`/`_read` pair applies this check;
  `knet.write_pod`/`read_pod` expose it for manually serialized state.
- Network messages use revision constants checked during admission. These
  include `ksess.PROTOCOL_REV`, `knet.WIRE_REV`, and revisions from each
  wire-bearing package, covering `SES_*` messages, the lane wire, and netgd
  frames. They contribute to the `NET_FINGERPRINT` sent in `SES_JOIN`.
  Incompatible peers receive `Ev_Join_Denied{.Version}` before exchanging
  deltas. Change the affected package's revision in the same commit as its
  wire format, and document the change beside the constant.
- `ksave.FORMAT` versions the outer file envelope. It is maintained manually
  because it describes the fixed header and length-prefixed ranges rather
  than a generated field set: magic, format, game version, saving player id,
  game blob, and snapshot. Its format and changelog must remain readable before
  any inner version checks can run.

The [migration wire](session.md#backup-hosting-and-resume) wraps
`session_snapshot` bytes as `[blob_len u32][game blob][snapshot]` without a
second version field. `PROTOCOL_REV` already gates admission, and only admitted
peers receive backups. The same snapshot stored on disk needs the save envelope
because reading a file has no preceding join handshake.

Keep the two file-version errors distinct. `Bad_Envelope` means the SDK cannot
read the `FORMAT` of the file. `Wrong_Version` means the game's `game_version` differs.
A content-version change should not be reported as corrupt file data.

## API by task

**Save** (host only):

```odin
save_write :: proc(s: ^ksess.Session, w: ^knet.Writer, game_version: u16, game_blob: []u8 = nil)
```

**Resume** reads the file, validates the envelope and game version, and restores
the run. It returns a temporary game-blob slice; parse it immediately:

```odin
resume :: proc(s: ^ksess.Session, name: string, path: cstring, game_version: u16) -> (game_blob: []u8, err: Resume_Error)

Resume_Error :: enum {
	Ok,
	No_File,       // nothing saved at `path`
	Bad_Envelope,  // incompatible magic or envelope format
	Wrong_Version, // a different game (or older content) wrote it
	Corrupt,       // the session snapshot didn't parse
}
```

Handle the error cases separately in player-facing status text; see the excerpt
below. Custom slot UIs and save browsers can use the lower-level operations:

```odin
save_read_header :: proc(r: ^knet.Reader) -> (h: Header, ok: bool)
save_restore :: proc(s: ^ksess.Session, name: string, r: ^knet.Reader, h: Header) -> bool
```

`save_read_header` leaves the reader at the session snapshot for `save_restore`.
It returns ok=false for incompatible magic or format, while the game must
check `game_version`. `save_restore` requires a fresh session with its entity
factory installed.

**Identity** uses a persisted token for reconnects, resumed saves, and entity
reclamation:

```odin
persistent_token :: proc(path: cstring) -> u64
```

This loads the 8-byte token at `path`, or generates and persists one if needed.
Retain the file and pass the same token to `session_client_start` on each run.
The token is intended to resist guessing among invited friends; it is not a
cryptographic authentication credential.

**Files** (`user://` on every platform):

```odin
write_file :: proc(path: cstring, bytes: []u8) -> bool
file_exists :: proc(path: cstring) -> bool
read_file :: proc(path: cstring, allocator := context.allocator) -> (bytes: []u8, ok: bool)
```

## Worked excerpt (cavecrawl)

Saving writes the game blob first, then wraps the envelope around it.

```odin
blob := knet.writer_make()
defer knet.writer_destroy(&blob)
write_game_blob(self, &blob)
w := knet.writer_make()
defer knet.writer_destroy(&w)
ksave.save_write(&self.ses, &w, GAME_VERSION, knet.writer_bytes(&blob))
ok := ksave.write_file(save_path(), knet.writer_bytes(&w))
```

On resume, handle errors first, restore the game blob, then start the transport:

```odin
blob, err := ksave.resume(&self.ses, my_name(self), save_path(), GAME_VERSION)
switch err {
case .No_File:
    kui.lobby_set_status(&self.ui, "No saved run to resume")
    return
case .Bad_Envelope, .Wrong_Version:
    kui.lobby_set_status(&self.ui, "That save is from another cave")
    return
case .Corrupt:
    return
case .Ok:
}
if !read_game_blob(self, blob) {return}
if !gd.host(self.owner, port()) {return}   // transport starts after restore; see ordering constraints
```

Identity gets wired at join time (`net.odin`):

```odin
ksess.session_client_start(&self.ses, my_token(), my_name(self))
// my_token() -> ksave.persistent_token("user://cave_token")
// (tests choose an identity via a CAVE_TOKEN env override instead)
```

<a id="gotchas"></a>

## Restore ordering and data lifetime

- **Transport order is flexible.** `ksave.resume` can run before or after
  transport setup because nothing sends until the session ticks. If transport
  setup fails after resume, the restored session can be abandoned. The next
  `session_host_start` / `session_client_start` reinitializes it.
- **Save private host state in the blob.** Without it, Cavecrawl restarts
  wave 1 alongside the saved dwellers because the session restores entities
  without restoring the wave director.
- **Parse the temporary blob promptly.** The slice returned by `resume` views
  temporary file bytes and becomes invalid when the temporary allocator resets.
- **Install the factory before restore.** Restore recreates every entity
  through `session_set_factory`; a fresh session needs that factory first.
- `save_write` asserts `is_host`: only the authority saves the run.
- Bump `game_version` when game content changes; Cavecrawl uses
  `GAME_VERSION :: u16(9)`. SDK envelope mismatches return `Bad_Envelope`;
  game-version mismatches return `Wrong_Version`.

Siblings: [session.md](session.md) (snapshot, `session_host_resume`, reconnect tokens) ·
[net.md](net.md) (Writer/Reader for the game blob) · [comms.md](comms.md) (narrate the resume:
`comms_system(&comms, "the cave remembers")`).

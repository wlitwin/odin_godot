# kit/save — quit and resume a run

Save a run to disk, resume it later, and mint the persistent identity token that makes
"later" work. The [session](session.md) snapshot that ships to the backup host every few
seconds is already a complete re-hostable world, and `session_host_resume` already rebuilds
one. **Saving a run and surviving a dead host are the same contract.** kit/save points it at
a file and wraps it in a versioned envelope.

**Lane compatibility: lane-agnostic (session-level).** The envelope wraps the session
snapshot: delta-lane and `gd:"backup"` state. Sim-lane runtime state (ledgers, inputs in
flight) is not saved: a resumed sim restarts its lane fresh from the saved authoritative
fields, the correct semantics for a server-authority run. The sim lane refuses host
*migration* (see [sim.md](sim.md)); resuming from disk restarts the authority.

```odin
import ksave "godot:kit/save"
```

## Mental model

The file layout:

```
[magic u32][format u16][game_version u16][saved_by u64][game blob][session snapshot]
```

- `format` is the **toolkit's** layout version (`FORMAT :: u16(3)`, bumped with the
  session snapshot layout: version 2 added entity blobs and wire codecs, and version 3 added
  the door, `locked` and `denied`, which rides the roster). A mismatched save refuses to parse
  instead of reading garbage: a file from an older toolkit comes back `Bad_Envelope`, cleanly,
  by version.
- `game_version` is the **game's** own stamp. You pass what you like and check what you get;
  content changes are the game's problem to detect.
- `saved_by` fixes the who-am-I question on restore: the host that saved resumes under its
  own old `Player_Id`. Hosts have no reconnect token (they never JOINed), so the file
  remembers for them.
- The **game blob** carries host-side state the session cannot know about: wave directors,
  AI clocks, quest flags. The snapshot covers identity/stats/entities; anything else the game
  owns, the game saves.

Restore is **restore-into-lobby**: the caller is seated as host of the live world with every
other player disconnected-but-reclaimable. Friends rejoin with their persisted tokens and get
their ids, stats, and owned entities back, exactly like any reconnect.

The envelope is engine-free (bytes in, bytes out, unit-testable without Godot); the file
helpers are thin FileAccess wrappers so `user://` paths work on every platform, web included.

## Declaring the game blob

The game blob is the same host-local state host migration ships (see [session](session.md)),
and you don't hand-serialize it. Tag the fields on your game class `gd:"backup"` and scriptgen
generates a version-hashed `<class>_backup_write` / `_read` pair over them, so a takeover or a
resume restores the campaign with no second, hand-kept read list to drift out of order:

```odin
CaveLobby :: struct {
	host_ticks: int                           `gd:"backup"`,
	director:   kai.Director                  `gd:"backup"`, // a POD struct rides whole
	brains:     map[knet.Net_Id]Dweller_Brain `gd:"backup"`, // map[POD]POD: length + loop
	respawn_at: map[knet.Net_Id]int           `gd:"backup"`,
	// ...
}

// the migration half (kboot.boot_migration's table calls it, host only):
@(gd_half)
cave_lobby_backup :: proc(self: ^CaveLobby, w: ^knet.Writer) {
	if self.started {cave_lobby_backup_write(self, w)}
}
// resume from a FILE / the heir's `<game>_took_over(r)` half:
if !cave_lobby_backup_read(self, &r) { /* stale or truncated — bail */ }
```

Supported: POD scalars, POD structs, POD fixed arrays, `map[POD]POD`, and `[dynamic]POD` (rides
`using`/embeds like `replicate`). Anything else (a slice, a string, a non-POD element) is a
build error, spelled out. The version const is a hash of the field set, so a blob from a
mismatched build fails the read cleanly instead of misreading bytes. `knet.write_pod`/`read_pod`
are that same primitive, exposed for any fixed-shape state you still serialize by hand.

## Versioning: what crosses time, what crosses the wire

Three versioning conventions live in this repo. Which one you want is decided by what your
bytes cross.

- **Bytes that cross TIME** (a save file, a `gd:"backup"` blob, a succession payload
  authored by a build you may not be running anymore) take an **FNV field hash**, generated
  from the shape itself. There is no peer to negotiate with; the reader's only check is that
  the writer's shape matches its own. scriptgen's `<class>_backup_write`/`_read` pair is the
  worked example; `knet.write_pod`/`read_pod` is the same primitive for hand-serialized state.
- **Bytes that cross THE WIRE** (every `SES_*` message, the lane wire, the netgd frame)
  take a **rev constant at the join door**: `ksess.PROTOCOL_REV`, `knet.WIRE_REV`, and each
  wire-bearing package's own, all folded into the `NET_FINGERPRINT` a `SES_JOIN` carries. A
  skewed peer is refused with `Ev_Join_Denied{.Version}` before it can misparse a single
  delta. Bump the rev in the package whose wire you changed, in the same commit, and log what
  moved beside the constant.
- **`ksave.FORMAT`** is the third, and it is hand-maintained. It versions the *envelope*, not
  a field set: there is nothing to hash (magic, format, a game stamp, an id, two
  length-prefixed byte ranges), and it is the outermost gate, so it must be readable by a
  reader that has agreed to nothing yet. Its changelog comment beside the constant is the
  contract.

Two points that follow from the split:

**The backup wrapper is unversioned.** The identical `session_snapshot` bytes get kit/save's
versioned envelope on disk and a bare `[blob_len u32][game blob][snapshot]` on the
[migration wire](session.md#backup-hosting-and-resume). The snapshot crossing the wire is
already covered: `PROTOCOL_REV` gates the join, and a peer that never got a seat never gets
a backup, so a second stamp on the wire would version bytes that cannot arrive from a build
that disagrees. The file has no such join door, which is why it carries an envelope.

**A `game_version` mismatch is not a `FORMAT` mismatch.** `Bad_Envelope` is the toolkit's
verdict; `Wrong_Version` is yours. Keep them separate: a content bump should never look like
a corrupt file.

## API by task

**Save** (host only):

```odin
save_write :: proc(s: ^ksess.Session, w: ^knet.Writer, game_version: u16, game_blob: []u8 = nil)
```

**Resume, the whole button in one call**: it reads the file, validates the envelope, checks
the version stamp, and restores the run. It returns the game blob (temp-allocated; parse it
immediately):

```odin
resume :: proc(s: ^ksess.Session, name: string, path: cstring, game_version: u16) -> (game_blob: []u8, err: Resume_Error)

Resume_Error :: enum {
	Ok,
	No_File,       // nothing saved at `path`
	Bad_Envelope,  // wrong magic/format — not one of ours
	Wrong_Version, // a different game (or older content) wrote it
	Corrupt,       // the session snapshot didn't parse
}
```

Each case is a different sentence to the player; see the excerpt below.

**The pieces**, if you need them separately (custom slot UI, save browsers):

```odin
save_read_header :: proc(r: ^knet.Reader) -> (h: Header, ok: bool)
save_restore :: proc(s: ^ksess.Session, name: string, r: ^knet.Reader, h: Header) -> bool
```

`save_read_header` leaves the reader positioned on the session snapshot (hand it to
`save_restore`) and returns ok=false only on wrong magic/format, never on a merely different
`game_version`; that verdict belongs to the game. `save_restore` needs a **fresh** session
with the entity factory installed.

**Identity** (the mint-once-keep-forever token that reconnects, resumed saves, and reclaimed
entities all ride on):

```odin
persistent_token :: proc(path: cstring) -> u64
```

Loads the 8-byte token from `path`, or mints one and persists it there. Keep the file, keep
the identity: pass the result to `session_client_start` every run. Unguessable-by-friends is
the bar, not cryptographic strength.

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

Resuming handles the per-case UX first, then the game blob, then the transport:

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
if !gd.host(self.owner, port()) {return}   // transport comes up AFTER — see gotchas
```

Identity gets wired at join time (`net.odin`):

```odin
ksess.session_client_start(&self.ses, my_token(), my_name(self))
// my_token() -> ksave.persistent_token("user://cave_token")
// (tests choose an identity via a CAVE_TOKEN env override instead)
```

## Gotchas

- **Transport order is flexible.** `ksave.resume` can run before OR after the transport is
  up: nothing sends until the session ticks. A resume that succeeds before a transport that
  fails is safe to abandon: session re-init is re-entrant; the next `session_host_start` /
  `session_client_start` re-inits.
- **Forget the game blob and the session won't miss it; your game will.** Cavecrawl without
  it restarts wave 1 on top of the saved dwellers. If the host owns state outside entities,
  it goes in the blob.
- **The blob from `resume` is temp-allocated** (it views the temp-allocated file bytes).
  Parse it before the temp allocator resets.
- **Install the factory first.** Restore recreates every entity through the session's factory
  (`session_set_factory`); a fresh session without one has nothing to build with.
- `save_write` asserts `is_host`: the authority saves the run.
- `Wrong_Version` vs `Bad_Envelope`: the envelope check is the toolkit's; the version check is
  yours. Bump your `game_version` when content shifts (cavecrawl: `GAME_VERSION :: u16(9)`).

Siblings: [session.md](session.md) (snapshot, `session_host_resume`, reconnect tokens) ·
[net.md](net.md) (Writer/Reader for the game blob) · [comms.md](comms.md) (narrate the resume:
`comms_system(&comms, "the cave remembers")`).

# kit/save — quit and resume a run

Saving a run to disk, resuming it later, and the persistent identity token that makes
"later" work. Deliberately cheap: the [session](session.md) snapshot that ships to the backup
host every few seconds is already a complete re-hostable world, and `session_host_resume`
already rebuilds one. **Saving a run and surviving a dead host are the SAME contract** —
kit/save just points it at a file and wraps it in a versioned envelope.

```odin
import ksave "godot:kit/save"
```

## Mental model

The file layout:

```
[magic u32][format u16][game_version u16][saved_by u64][game blob][session snapshot]
```

- `format` is the **toolkit's** layout version (`FORMAT :: u16(1)`) — a mismatched save
  refuses to parse instead of reading garbage.
- `game_version` is the **game's** own stamp — pass what you like, check what you get;
  content changes are the game's problem to detect.
- `saved_by` fixes the who-am-I question on restore: the host that saved resumes under its
  own old `Player_Id`. Hosts have no reconnect token — they never JOINed — so the file
  remembers for them.
- The **game blob** carries host-side state the session cannot know about — wave directors,
  AI clocks, quest flags. The snapshot covers identity/stats/entities; anything else the game
  owns, the game saves.

Restore is **restore-into-lobby**: the caller is seated as host of the live world with every
other player disconnected-but-reclaimable. Friends rejoin with their persisted tokens and get
their ids, stats, and owned entities back — exactly like any reconnect.

The envelope is engine-free (bytes in, bytes out — unit-testable without Godot); the file
helpers are thin FileAccess wrappers so `user://` paths work on every platform, web included.

## API by task

**Save** — host only:

```odin
save_write :: proc(s: ^ksess.Session, w: ^knet.Writer, game_version: u16, game_blob: []u8 = nil)
```

**Resume, the whole button in one call** — read the file, validate the envelope, check the
version stamp, restore the run. Returns the game blob (temp-allocated — parse it
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

Each case is a different sentence to the player — see the excerpt below.

**The pieces**, if you need them separately (custom slot UI, save browsers):

```odin
save_read_header :: proc(r: ^knet.Reader) -> (h: Header, ok: bool)
save_restore :: proc(s: ^ksess.Session, name: string, r: ^knet.Reader, h: Header) -> bool
```

`save_read_header` leaves the reader positioned on the session snapshot (hand it to
`save_restore`) and returns ok=false only on wrong magic/format — never on a merely different
`game_version`; that verdict belongs to the game. `save_restore` needs a **fresh** session
with the entity factory installed.

**Identity** — the mint-once-keep-forever token that reconnects, resumed saves, and reclaimed
entities all ride on:

```odin
persistent_token :: proc(path: cstring) -> u64
```

Loads the 8-byte token from `path`, or mints one and persists it there. Keep the file, keep
the identity: pass the result to `session_client_start` every run. Unguessable-by-friends is
the bar, not cryptographic strength.

**Files** — `user://` on every platform:

```odin
write_file :: proc(path: cstring, bytes: []u8) -> bool
file_exists :: proc(path: cstring) -> bool
read_file :: proc(path: cstring, allocator := context.allocator) -> (bytes: []u8, ok: bool)
```

## Worked excerpt (cavecrawl)

Saving: game blob first, then the envelope around it.

```odin
blob := knet.writer_make()
defer knet.writer_destroy(&blob)
write_game_blob(self, &blob)
w := knet.writer_make()
defer knet.writer_destroy(&w)
ksave.save_write(&self.ses, &w, GAME_VERSION, knet.writer_bytes(&blob))
ok := ksave.write_file(save_path(), knet.writer_bytes(&w))
```

Resuming — per-case UX, then the game blob, then the transport:

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

And identity, wired at join time (`net.odin`):

```odin
ksess.session_client_start(&self.ses, my_token(), my_name(self))
// my_token() -> ksave.persistent_token("user://cave_token")
// (tests choose an identity via a CAVE_TOKEN env override instead)
```

## Gotchas

- **Transport order is flexible.** `ksave.resume` can run before OR after the transport is
  up: nothing sends until the session ticks. A resume that succeeds before a transport that
  fails is safe to abandon — session re-init is re-entrant; the next `session_host_start` /
  `session_client_start` re-inits.
- **Forget the game blob and the session won't miss it — your game will.** Cavecrawl without
  it restarts wave 1 on top of the saved dwellers. If the host owns state outside entities,
  it goes in the blob.
- **The blob from `resume` is temp-allocated** (it views the temp-allocated file bytes).
  Parse it before the temp allocator resets.
- **Install the factory first.** Restore recreates every entity through the session's factory
  (`session_set_factory`); a fresh session without one has nothing to build with.
- `save_write` asserts `is_host` — the authority saves the run.
- `Wrong_Version` vs `Bad_Envelope`: the envelope check is the toolkit's; the version check is
  yours. Bump your `game_version` when content shifts (cavecrawl: `GAME_VERSION :: u16(9)`).

Siblings: [session.md](session.md) (snapshot, `session_host_resume`, reconnect tokens) ·
[net.md](net.md) (Writer/Reader for the game blob) · [comms.md](comms.md) (narrate the resume:
`comms_system(&comms, "the cave remembers")`).

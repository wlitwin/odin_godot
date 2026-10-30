# Replayable party lobbies

`Lobby(N)` is a value inside the game's World. It contains bounded display names,
present/ready masks, a party leader, Waiting/Playing phase and a run counter.
Transport ownership and credentials stay in Session/Room. A party leader is a
game permission; becoming a network authority does not itself execute Start.

```odin
import lb "godot:replay/lobby"

party := lb.initial(4) // waiting; leader seat 1
lb.roster(&party, joins, leaves) // recorded simulation roster changes
name, ok := lb.name("Torch keeper")
result := lb.apply(&party, seat, {verb=.Ready, name=name, ready=true})
result = lb.apply(&party, seat, {verb=.Start})
if result == .Started {
    // Initialize this game's encounter and clocks at the current simulation tick.
}
```

Commands are ordinary game actions, validated by the game's model and admitted
through the existing network runner. `Ready` can set a name and readiness atomically.
A separate `Profile` command clears readiness only when its name actually changes;
repeating the same profile is a no-op on readiness. Names are trimmed, clipped to
48 UTF-8 bytes without splitting a rune, and reject empty/control/line-separator
values. Stored names require canonical zero tails. Names are cosmetic, not accounts
or authorization identities; games can impose additional naming policy.

Only a present party leader can Start, and every present player must be ready.
A recorded departure removes readiness. A newly present/reconnected seat must
ready again. If a leader departs, the lowest present seat becomes leader. There
is no out-of-band election of game permissions. `reset_member` clears a freshly
assigned seat's profile/readiness; it should accompany the game's existing fresh
player reset callback, not every reconnect.

`initial(N, automatic=true)` uses leader zero and lets `auto_start` transition once
all present players are ready. This suits dedicated-server staging. Automatic
restart is an application policy. `Restart` requires the party leader and explicit
`can_restart=true` from the game's completed-run condition. It increments the run
counter and leaves names/roster intact; the game decides which inventory, entities,
clocks and cumulative statistics to reset. Check `Result` before applying those
consequences. Observers do not occupy these player seats.

`valid` checks bounds and name representations. The caller supplies valid roster
masks/seat counts and integrates the lobby with its own gameplay predicates. The
component allocates no heap storage in roster/command processing. Its name helpers
use borrowed views over fixed value storage; do not retain `text(&name)` after that
value moves or dies.

## Local name preferences

`profile_encode` / `profile_decode` provide a bounded version-1 preference format.
It stores a display name, not a credential or gameplay checkpoint. Godot's
`Name_Profile` adapter reads/writes that preference outside simulation:

```odin
storagegd.name_profile_open(&profile, "user://display_name", "my-game", true, initial_name)
// Poll even while a session is connecting or while the main menu is showing.
storagegd.name_profile_frame(&profile)
storagegd.name_profile_set(&profile, edited_name)
// At owner teardown:
storagegd.name_profile_close(&profile)
```

Native storage uses a flushed staging file and rename, with one writer per path.
Browser storage uses the existing IndexedDB service and revision-checked writes.
Reading/writing is observable through `phase` and `dirty`; malformed data and CAS
conflicts set `failed` and preserve existing storage. An application may still use
an explicitly entered name for the current session while reporting that preference
failure. Wait for pending writes when persistence matters before teardown.

The native Cavecrawl gate drives real buttons and reloads the name in a fresh
process, including corrupt-file preservation. The browser gate closes and launches
a new Chrome process with the same isolated profile, removes the URL name override,
and reads the persisted name through the actual menu.

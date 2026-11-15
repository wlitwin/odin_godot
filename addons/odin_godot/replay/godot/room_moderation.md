# Removing a Room participant

`room_remove(&room, seat)` resolves the authenticated member behind a live remote
seat and queues coordinator removal. A successful call means queued, not removed.
Read `room.removal.phase`: `Queued`, `Waiting`, `Removed` or `Failed`, with the
target identity, epoch and error retained for presentation. Self-removal and
non-host requests are refused. Planned handoff cannot begin while removal is
pending.

Room renews its lease first if necessary, then uses a bounded removal timeout.
After a lost reply it obtains fresh ordinary control state before retrying; a
disabled roster entry resolves the operation as committed. Two failed attempts
stop automatically. An old coordinator can therefore leave the operation failed
while ordinary gameplay and lease renewal continue.

Before stepping authority gameplay, Room mirrors disabled token digests into the
network ban ledger, removes their live bindings and stops checkpoint delivery to
an invalid successor. This also runs after restoring a checkpoint older than the
removal. Admission and successor selection remain constrained by the authenticated
roster. A locally disabled member is marked `room.removed`, fenced and rejected.

For an uncoordinated Session, use the authority-side
`server_kick(&session.server, seat, ban=true)`. That ban belongs to the Session's
checkpoint and has that checkpoint's durability window. `server_ban_identity`
accepts an already authenticated token digest for trusted service integration.

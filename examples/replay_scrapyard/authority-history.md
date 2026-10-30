# Authority-only rewind history

Introduced in content `0x5253435241503048` and retained in current content 49, Replay keeps the 32-tick `hit_history` in the authority's
complete world and checkpoints, while omitting it from ordinary public snapshots.
Current players, mobs, projectiles, health, equipment and other gameplay state
remain public. The captured loaded-workload delta that motivated this change had
7,581 of its 7,861 changed bytes in this historical cache.

The model explicitly declares its public replication and prediction policies.
Its prediction world contains all visible actors and uses neutral remote-player
controls; remote displayed poses continue to use authoritative observations.
A historical ray or mend query whose history is unavailable cannot judge a hit
locally. Its beam/wall preview still appears, and the server's confirmed outcome
supplies actual damage/healing. Singleplayer and the authority retain the original
history and historical judgment rules. No unavailable query falls back to live
geometry.

Checkpoint capture uses the complete authority projection. Host migration,
saves and offline conversion therefore retain the history needed for subsequent
rewind queries. Tests compare complete restored history and continue simulation.
The game version changes because projection/schema contracts changed. Content-47
rooms require matching old clients; content-48 clients use new rooms/databases.
Older offline saves use the explicit converter, which now accepts contents 42–48 and seeds the recorded takeover epoch.
It verifies full-world preservation and reports the new public digest separately.

The loaded fixture checks public payload reduction and real compression support
and delivery. Adaptive compression is allowed to choose sparse or ordinary LZ4
deltas when grouping would not help; it does not require a larger encoding to be
selected merely to satisfy a counter. Dedicated grouping/transfer tests remain,
and complete recovery archives still exercise their grouped compression path.

Cosmetic wound placement now has an explicit adapter: the authority uses its private
rewind cache; clients read an exact retained public event-tick frame and verify the
victim generation. That frame may be corrected or predicted, and missing history
refuses placement. These coordinates do not grant hit authority or transmit the
private rewind cache. The editor-first migration's revive gate exposed and verified
this correction to the older presentation path.

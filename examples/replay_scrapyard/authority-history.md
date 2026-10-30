# Authority-only rewind history

Introduced in content `0x5253435241503048` and retained through content 49 and
later revisions, Replay keeps the 32-tick `hit_history` in the authority's
complete World and checkpoints, while omitting it from ordinary public snapshots.
The [save guide](saves.md) records the current content and conversion contract.
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
The content-48 transition changed the projection/schema contract: content-47
rooms required matching old clients, while content-48 clients used new rooms and
databases. The converter paths for contents 42–48 retain those source contracts
and seed the recorded takeover epoch. They verify full-world preservation and
report the new public digest separately. Use the [current offline conversion
procedure](saves.md#converting-older-replay-runs) for the complete accepted format list.

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

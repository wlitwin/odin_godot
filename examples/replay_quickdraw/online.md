# Quickdraw parties

A configured `RQ_ROOM_SERVICE` enables Create party, Join party and Rejoin recent.
The shared Replay Party component durably stores enrollment and invitations before
opening the game. It configures Room, authenticated signaling and the appropriate
native ENet or browser WebRTC backend. Personal identity/name preferences remain
separate from each party's gameplay credential.

Invited members are trusted peers by this example's explicit policy: they may receive
complete checkpoints and host a successor session. Watch-only play retains seat zero
and disables checkpoint reception. The watch preference does not revoke membership
permissions granted by the invite. This is a player-hosted model, not a claim of
cheat-resistant hosting or public account authentication.

The scene uses the same typed Quickdraw world, controls/actions and presentation on
native and browser builds. The first connected player starts the waiting duel.
Planned handoff is available to the active authority once a successor is prepared.
Unexpected authority loss uses Room's existing lease, rollback and recovery policy.
A returning host can use its retained profile and Rejoin recent in a fresh process.

Browser identities, display names and party credentials use their existing shared
IndexedDB components. Native parties use the optional SQLite adapter; `RQ_ROOMS_DB`
selects its database. `RQ_PROFILE` still selects the separate native personal profile.
Native direct-address and file-save paths remain available when no service is configured.
Browser direct ENet launch is refused with an explanation; use a configured party.
Browser solo play shares the model and now has separate [local save slots](browser-saves.md)
in the standalone menu. Party publication does not write those slots.

Defaults require verified WSS. `RQ_ROOM_LOCAL=1` permits explicit loopback WS development.
`RQ_ROOM_ADDRESS` and `RQ_PORT` define the advertised native endpoint. ICE settings
come from `RQ_ICE_JSON`, or `RQ_ROOM_RELAY=1` requests authenticated relay credentials.
Do not combine both ICE sources. Public deployment and non-loopback routing need their
own acceptance; localhost success does not establish reachability across the internet.

The bundled room service recognizes Quickdraw content D2 when selected by the operator
and supplies its typed checkpoint backend. A live online authority's Save/F5 publishes
through Room rather than writing a local file. `RQ_ROOM_CHECKPOINT_MS` optionally sets
the shared publication interval; zero keeps it manual. Native file resume still refuses
coordinated archives. No gameplay content/schema change is introduced by this integration.


Published checkpoints also support an abandoned party. A fresh trusted player uses
Rejoin recent; if no authority remains, Room loads the saved publication and requests
a guarded restore grant before creating a new session. The same published tick is
retained under a new epoch, and other saved members can reclaim their seats. An
observer must explicitly select Watch only and waits for a restored host rather than
restoring authority. The UI distinguishes saved-party restoration from a live handoff.
This path is covered by `tests/replay_quickdraw_party_restore/run.sh`, including a
service restart on the existing database. Public deployment and broader restore
races remain separate acceptance work.

The native whole-party path is also covered by
`tests/replay_quickdraw_native_restore/run.sh`, using individual SQLite credential
stores, a trusted local WSS certificate and separate ENet gameplay endpoints. Both
the native and browser fixtures kill all game processes and restart the service on
its existing database before restoring and republishing.

The recovery notice uses the shared [backup-status observation](../../replay/godot/room_backup.md).
It distinguishes an approved backup from preparation, stale progress or uncertain
control; a prior host change does not imply the next backup is ready.

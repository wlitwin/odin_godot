# Dedicated Room authorities

An authenticated room member and a playable game seat are separate identities.
Set `Room_Options.session.role = .Server` for an infrastructure process that must
never acquire an avatar:

```odin
session := replaygd.SESSION_OPTIONS
session.role = .Server
session.replication.accept_checkpoints = true
options := replaygd.Room_Options{
    identity = identity, key = key, room = room_id,
    coordinator = address, control_port = port,
    bootstrap = first_server, automatic_successor = true,
    session = session,
}
```

The provider must separately mark hosting infrastructure as enabled, `can_host`,
`trusted_authority`, and `infrastructure`. Dedicated coordinator policy admits
only infrastructure as authorities. Game initialization still chooses its own
readiness/progression rules; Scrapyard's dedicated initial state starts when its
real clients are ready.

Room preserves Server when bootstrapping or restoring authority, using local
player seat zero. While following another authority, that process uses Observer
and keeps seat zero. A takeover returns it to Server. A departed server rejoins
as an observer; player-hosted rooms retain their player/host behavior.

Automatic successor selection keeps the existing playable-seat ordering, then
considers authenticated infrastructure observers in roster order. Receiving
complete checkpoints requires the receiver's explicit opt-in. Selection verifies
hosting trust, policy, token hash, incarnation and a live admitted connection.
An ordinary observer is not an infrastructure successor. Explicit selection uses
`successor` identity with `successor_seat = 0` to resolve its current admitted
connection independently of playable-seat assignment. A nonzero seat remains an
optional additional constraint.
Backup diagnostics resolve the same connection.

For lower-level embedding, `session_backup_peer` explicitly authorizes a live
admitted connection to receive complete checkpoints; the caller supplies its
trust policy. `session_backup_seat` remains the player-seat convenience wrapper.
`session_takeover(..., dedicated=true)` restores seat zero without requiring a
playable token in the checkpoint. It still requires the approved prepared point
and a live authority lease. An already-Server Session preserves that role by
default. Neither helper grants hosting authority.

Native tests cover bootstrap, planned handoff, crash with fresh-process return,
and repeated handoff between two infrastructure processes with two real players.
The exact authority frame is restored, the players retain seats 1/2, and both
infrastructure processes remain at seat zero. The returned server receives a new
prepared backup. The [browser gate](../../tests/replay_dedicated_browser/README.md)
now also runs two infrastructure browsers and two real players over authenticated
RTC through planned, crash/return and repeated takeover, with exact restored frames
and actual RTC traffic. This is local browser acceptance using the existing
Scrapyard browser lease profile. Steam infrastructure, public deployment and
combat-heavy dedicated failover remain separate acceptance work.

# Party moderation

The current host can open the party panel with Escape, select a remote player by
name/seat and press **Remove and block rejoin**. Guests cannot invoke the operation
for another player, and the host is excluded from the selector. The panel reports
pending, completed or unconfirmed removal. The selector follows authoritative
name changes and checks that the chosen connection still matches before submitting. Removed clients close gameplay and see
an explicit notice. The existing `kick(seat)` method follows the same permission
and removal path as the button.

Direct sessions store the token ban in complete gameplay checkpoints. Coordinated
Room sessions first disable the exact enrolled member at the coordinator, then
retire gameplay and successor eligibility. An already prepared removed successor
cannot take over. A replacement trusted member may receive the next checkpoint
and continue through planned or abrupt host loss. Old saves do not restore the
disabled enrollment's permission.

The block applies to this session/party identity, not a person's account. A fresh
independently authorized identity is separate, and existing invites are not revoked
automatically. Coordinated removal requires a service supporting the new optional
operation; unsupported services produce a bounded failure without silently
claiming removal. Re-enabling an enrollment is a trusted service-administration
operation; this game does not expose an unban control.

Game content, World, gameplay actions and save formats are unchanged. The owner
profile shares this frontend; the moderation acceptance fixture currently exercises
the C9 profile with native ENet and Chrome/WebRTC.

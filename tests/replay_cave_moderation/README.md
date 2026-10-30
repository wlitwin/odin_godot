# Cavecrawl moderation acceptance

The fixture uses copied projects, three explicitly trusted coordinator members,
and automatic successor selection. Production permissions are not widened by the
test: only its isolated provisioning code trusts member three.

Native cases check guest refusal, the actual removal UI, immediate gameplay
retirement, fresh-process denial with the same identity, removal of an already
prepared successor, selection of member three, planned/crash takeover, preserved
ban state and new loot. An old-service emulation discards only the extension kind
and requires bounded failure while all three players and the host lease survive.

Chrome checks use actual WebRTC gameplay. All three peers must exchange RTC bytes
before removal. Planned takeover also requires traffic afterward; the crash case
has only one surviving admitted player, so no live peer channel is expected then.
Gameplay and ban predicates remain the same in both cases.

The standalone SQLite fixture kills the process before committing removal and
immediately after commit but before the service can reply. Fresh readers verify
member enablement, successor preparation, request frontier and join retry outcome.
Unit tests separately cover authorization, incarnation scope, replay protection,
storage failure, denial-only replies and provisioning hub routing. Frozen old/new
authority peers exercise unchanged ordinary RPCs and rejection of unsupported
removal packets.

The coordinator blocks this stable room enrollment. It cannot stop someone from
obtaining an independently authorized new identity. Invitations and their
revocation remain separate controls. No self-unban or public moderation service
is introduced.

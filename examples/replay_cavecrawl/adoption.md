# Old-host prop adoption

Introduced in C8, this policy observes the authority's local player seat through Replay's
[recorded authority policy](../../replay/net/authority.md). World keeps the last
known seat independently of lobby leadership. On a change from one player-host
to another, a relic carried by the former host transfers to the successor and
advances its version once. Other carriers and all avatars retain their identities.
A dedicated successor has no avatar, so that transition releases the relic.

This follows Kit's host-takeover orphan sweep for non-avatar entities. This
policy runs on the first committed simulation tick after restore. The checkpoint
frame itself remains exact; gameplay and the Carry event are recorded together,
can be audited/replayed, and roll back together on failure. Repeated observations
of the same authority do not repeat the transfer. Version overflow aborts the tick.

The successor's ordinary player step attaches the adopted relic at `(10, -12)`.
Clients receive that state and effect through replication; they do not guess an
authority change during prediction. The old host can return to its original
avatar/seat. Its authority role and possession of the relic are distinct.

## Compatibility

Current content is C9 with authority policy revision 1. World stores
`authority_known` and `authority_seat`; adoption uses the recorded observation,
not lobby leadership. A new host's first committed tick applies adoption.

The retained host-carrier checkpoint uses the current schema. Its migrated frame
and peer ledger are pinned by [the receipt](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json) and exact-resume checks.
Old source readers were retired after migration. Network protocol 7 and checkpoint
envelope version 4 remain unchanged.

## Evidence and boundaries

Pure tests check once-per-change adoption, other-carrier preservation, complete
corrected-input state/events, dedicated successors and overflow rollback. Real
native planned/crash takeovers check adoption in the first committed frame and
continued movement/release. A three-browser planned takeover checks the same
ownership transfer alongside the existing party/social recovery story. The four
successor/guest carrier cases remain regression gates.

The policy covers relic possession after a player-host change. Original
owner-streamed motion, disconnected-avatar floor gating, and broader
visual/human comparisons require separate work. This policy is specific to Cavecrawl's non-avatar relic; other
games choose their own response to the recorded observation.

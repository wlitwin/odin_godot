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

Current content is `0x4341564552504c39`, with authority policy revision 1. C8 adds
`authority_known` and `authority_seat` to World. The old C3–C7 world descriptor is
frozen in the converter; C1/C2 retain their earlier descriptors.

For C1–C7 imports, `tools/upgrade_save` preserves previous world/peer fields and
seeds the new observation from the validated checkpoint header's `local_seat`.
C8 imports already contain that observation and retain it unchanged. See the
[current conversion guide](authoring.md#existing-replay-saves) for accepted
formats and the command. Conversion requires a new destination; it neither
infers authority from the party leader nor edits the old file. A new host's first resumed tick applies adoption. Network protocol
7 and checkpoint envelope version 4 remain unchanged; the world schema and
negotiated policy contract change explicitly.

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

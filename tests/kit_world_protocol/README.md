# Kit World protocol v2 focused proof

Uncompiled source, bound to the World owner's `early-api-v1.md` (rev130).
No compilation or test execution is authorized until the coherent source freeze
and Root's explicit grant.

These tests reuse `tests/kit_box3d_net`'s actual Session, Lane, typed control and
action codecs, three-body Box3D world, and complete canonical diagnostics. The
transport is an owned in-memory packet queue, not ENet or a Core/SDK fixture.
Live fixtures are initialized in place and destroyed through their typed public
cleanup paths. No test assigns simulation heads, accepted rows or recovery flags.

The matching-signature group bootstraps with Welcome, then rejects automatic
CHUNK traffic during normal execution. At confirmed prefixes it compares every
canonical part and the public signatures. Its known tick1 action and tick5
periodic effect are checked at successive confirmed prefixes; replaying the
original packets must not deliver either effect again.

Eight focused groups cover:

1. Matching 480-byte signatures, reliable small traffic, all five canonical
   parts, no automatic CHUNK messages and effects unchanged on packet replay.
2. Signature arrival before all accepted evidence: no confirmation or effect
   publication from predicted input; the retained signature completes afterward.
3. Three-tick accepted catch-up from an actual stationary client, using complete
   simulation state comparison within the existing eight-tick bound.
4. Malformed complete INPUT: no partial control/action admission.
5. Old revision, corrupt signature encoding and foreign peer: no confirmation.
6. A well-encoded but mismatching Side signature: last confirmed publication and
   effects stay intact, followed by genuine public Reset and a valid suffix.
7. Old bootstrap scope and obsolete epoch feedback/signatures cannot reactivate
   timing after actual Reset; fresh current-epoch traffic continues normally.
8. Actual late class0 receipt distinct from an already accepted Held decision,
   stale authority feedback ignored, and newer malformed feedback transactional.

The small ACCEPTED inspector checks only this fixture's declared four-driver
wire shape to locate actual receipt evidence. Receiver acceptance is always
asserted separately through public Lane status/input/diagnostic getters. Packet
mutations are explicit adverse deliveries through the real Session handler;
they do not fabricate authoritative state or install accepted rows.

Half-tick positive calls accommodate the declared scale without changing ticker
state. Each helper advances one real tick in at most four calls and checks that
scale remains stable within every positive call. No control receipt is inferred
from Held and no logical action is reissued under a new identity. Effect checks
use the existing fixture's known tick1/key102 and periodic key1 events, confirmed
prefixes, canonical Occurrences comparison and original packet replay.

This suite will require a coherent selected Native artifact and a separate Root
compile/run grant. Historical wire-v1 results do not certify this protocol or
establish Gate B, CPU budgets, ENet behavior or Core ownership.

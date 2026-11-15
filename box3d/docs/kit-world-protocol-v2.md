# Kit World protocol v2

Status: the cleaned implementation passes eight focused World groups, four
caller groups, a real32-body Core/SDK short pair and the primary impaired
600-second Kit policy. Remaining Gate B matrix and CPU validation are open.

The normal World route must not depend on a reliable full checkpoint every
three ticks. Its roughly 130 KB checkpoints produced about 2.6 MB/s per client
and made confirmation wait for bulk reconstruction. This revision replaces
that normal traffic with accepted inputs and complete canonical signatures.
Replay and the shared Box3D solver are separate and remain unchanged.

## Normal traffic and confirmation

- Bump `WORLD_NETWORK_REV` and the input-catalog identity to v2. Reject old
  peers explicitly; do not reinterpret v1 packets.
- Keep client INPUT batches bounded to the existing eight-tick redundancy
  window. Bind them to the actual player's current validated bootstrap scope.
- Send small authoritative ACCEPTED batches reliably, including their bounded
  receipt-feedback entries. Keeping accepted decisions ordered and delivered
  is affordable once bulk state leaves the normal stream.
- At the existing three-tick cadence, send a small reliable SIGNATURE message
  containing the existing complete `bd.Signature`. It covers identity, epoch,
  tick and all five canonical parts: Solver, Game, Side, Observations and
  Occurrences. The Game part includes the canonical accepted-input window.
- Welcome, Reset and mismatch recovery retain complete canonical states.
  Explicit diagnostic checkpoint APIs remain distinguishable from normal
  transport; automatic normal full Correction broadcasts stop.

Receiving a signature is not permission to advance confirmation. The client
must have every accepted driver for every tick from its confirmed frontier
through T, the canonical accepted prefix needed to sign T, and a locally
simulated frame T. Missing data stays pending or requests bounded recovery;
Held/Unknown predictions cannot fill a gap in authoritative evidence.

Reuse `world_operation` staging and pre-publication verification. When accepted
values require repair, verify the staged frame T before publishing. When the
local state already agrees, a confirmation transaction must still verify before
advancing its frontier. Catch-up uses real accepted-input simulation, within
eight ticks, rather than a ticker assignment. On mismatch, preserve the last
confirmed publication and use the existing Reset request path. Confirmation
must not replay already confirmed effects.

`World_Frame` currently stores no canonical signature. The existing signer
encodes the complete parts and produces a 480-byte signature. Compute at the
declared cadence; do not introduce an invalid cache over mutable accepted
metadata or claim that signing is free. Measure the resulting operation.

## Receipt feedback and caller timing

Authority feedback reports the newest fully validated class0 proposal received
from each actual player. It is distinct from the tick accepted by the authority.
Validate every typed row, sender, schema, epoch, scope, sequence and trailing
byte before changing receipt state. A valid late receipt can inform timing
without rewriting an already accepted Held decision.

Use the actual Welcome/Reset CHUNK sequence as bootstrap context. The host's
expected scope is the identifier it generated for that bootstrap, not a claim
that a void transport callback delivered it. The client adopts a scope only
after validating and applying the complete state. Old-scope proposals and
feedback cannot steer the replacement timeline; rejoin binds the real peer.

Reuse the existing fine lead-control math with a bounded scale near 1
(approximately 0.98–1.02). Apply scale changes at the zero-delta ingress boundary
used by the example, and keep it stable during its positive NORMAL call.
Adapt the tested scale-aware offer/receipt calculations without reviving the
abandoned TIMING1/INPUT2 checked-send and retirement feature stack. Preserve
the eight-tick credit bound, exact offered debit, end limits and unresolved
receipt quarantine. No wall clock enters simulation identity or admission.

An unavailable or deep deficit is explicit. Re-anchoring must run real bounded
simulation/bootstrap or a validated Reset, never skip physics or input callbacks
by assigning a head. Prediction8, ordinary repair8, H128 and the tracked64MiB
limit remain unchanged.

## Actions, proof and cleanup

An input receipt acknowledges a proposal, not a unique gameplay outcome.
Preserve original action identity and the actual accepted/rejected result.
Do not turn a Held row into a second logical action. Any retry beyond existing
packet redundancy needs an explicit stable identity, authority deduplication
and outcome acknowledgement, with exactly-once effects across recovery.

The first actual pair completed tick300 with ten complete five-part comparisons,
no recovery or missing decisions/effects, final acknowledgement and natural
cleanup0. Normal Host FLOW samples were about40 KB per completed wire window;
the last sampled counters showed one full bootstrap and96 signatures through
tick288. These are short-run observations, not final-counter extrapolation or
a600-second gate pass. The original report SHA is
`5b2cd04d79e13eb9285fe8168def3c934af58df35821ffe5f81b63910018acc6`.
Its source/binary closure was secured before cleanup; old v1 and experimental
results remain separate evidence.

After cleanup, the same focused groups and rebuilt SDK short pair passed.
Runtime's actual size and requested/live Meter deltas are21,560 bytes per side,
down from113,328 with the experimental observers. The cleaned primary impaired
pair then completed610.0597 observed seconds through tick36,600 under the
unchanged original policy:152/152 contested cycles,152 consecutive cycles,
1,220 complete state comparisons, no recovery or missing decisions/effects,
final acknowledgement and natural cleanup0. Host emitted one full bootstrap
and12,200 signatures; normal FLOW median output was40,802 bytes per wire window.
The report SHA is
`15f851a0e451161a0a3b4ebea3f0ca9efabab8c267b48dd255a2f9d20883906b`;
the coverage audit SHA is
`007defa8445d647f194ecffdc4774ad32a3947ff0296ebda73e2deb7854a0626`.
This establishes that Kit primary impaired case, not the whole two-framework
gate, cross-platform determinism or the affected CPU ceilings.

Prove signature-only confirmation, gap/mismatch/old-version rejection and full
Reset recovery through public Session/Lane fixtures; then prove real Core/SDK
input fidelity, full-five-part agreement, effects, ownership, budgets and the
long matrix on the new wire identity. Historical v1 results remain historical.

After focused and real functional validation, remove superseded throttle
experiments, temporary observers and unused prototype paths, retain useful
regressions and evidence, and update documentation and builds. Audit usage
before removing any shared Core capability. Certify Gate B on the cleaned graph.

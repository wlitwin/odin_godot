# RTC continuation during a gameplay reconnect

Use RTC continuation to preserve an authenticated signaling reservation when
replacing a gameplay transport within the same authority term. `Rtc_Continuation`
contains
the existing logical peer ID, opaque room code, resume token and host/client role.
It is in-memory transport state, not a membership credential, checkpoint or save.

`rtc_continuation` exports it only from a registered context without a terminal error,
with authenticated resumption enabled. `Rtc_Config.continuation` accepts it only
for the exact room and role, with a nonzero token and a valid peer ID. Opening
still performs the provider's fresh challenge and authorization proof. The provider
checks the current registered member identity and reservation token before accepting
the old logical ID. Knowledge of a peer ID or room name alone grants nothing.

`session_redirect` uses this path only when the authority epoch, member incarnation,
signaling URL and room code match the previous RTC context. New authority terms
and different destinations use normal fresh connections. The new adapter asks to
replace the old channels; it does not treat incomplete fragment/channel state as
delivered. The client runtime remains in place, preserving action IDs and old
presentation history for normal Welcome reconciliation.

An expired or rejected continuation does not confer a lease or revive an old
identity. Ordinary coordinator, registration, packet-generation and authority
checks remain in force. A subsequent retry may establish a fresh signaling
reservation under those rules. This is distinct from the existing signaling-only
reconnect, which can preserve healthy data channels without replacing them.

## Relay outage evidence

The real relay-outage fixture keeps the coordinator and both game processes alive,
stops Coturn, restarts it with the same configuration and requires a newly selected
relay connection with traffic in both directions. It then verifies a new guest
action from the authority, unchanged incarnations/epoch and retained inventory.
Logical RTC peer identity and signaling continuation are checked separately from
the browser's newly constructed peer-connection index.

The initial implementation already recovered correctly, but full reconnect dropped
the signaling token and could wait through the provider's reservation window. The
continuation path avoids that unnecessary re-admission. Individual measured runs
are recorded, not treated as a latency benchmark or an Internet guarantee. The
existing 10-second gameplay timeout and platform ICE failure detection still
contribute to interruption.

See [recorded outage results](../../../docs/replay/results/relay-outage-2026-09-07/README.md)
and [TURN fixture commands](../../../tests/replay_turn/README.md). Credential refresh,
ICE restart, combined coordinator/relay outages, public deployment and other
platform/browser envelopes remain separate work.

## Replacing a peer connection under the same ID

The public and raw RTC transports expose the peer-connection serial as local
connection-generation metadata. Fragment assembly/delivery state and outer Replay
Delay/Router queues retire work from the old generation. A provider's replacement
introduction can therefore create fresh channels under the same numeric ID without
splicing old fragments or treating old delivery frontiers as belonging to the new
connection. Signaling-only continuation of healthy channels retains its generation.

The authenticated Duel tests creator recovery: the creator saves and pauses,
its browser is killed, and a fresh authenticated browser restores its file. The
joining browser retains its runner through timeout and reconnects when creator
ID 1 changes generation. Both reach the reference world with correct occurrences.
The admission service and fixed match remain alive; this does not elect another
player to supply the missing creator's inputs or recover an incompatible archive.

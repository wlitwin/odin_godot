# Authenticated short-lived relay credentials

`replay/relay` issues Coturn-compatible, time-limited credentials to an enabled
room member. The provider retains its signing secret; clients receive only TURN
URLs, a temporary username/password and expiry. This is independent of gameplay
authority, process registration, room admission and checkpoint storage.

## Protocol

The client authenticates with its already-provisioned member control key. A fresh
client nonce and increasing request sequence identify each acquisition. First it
requests a challenge; then it authenticates an Acquire containing the returned
challenge. Challenges belong to the physical transport connection and expire after
five seconds. An Acquire captured on another connection, after expiry, or before a
provider restart cannot mint a new credential.

An exact Acquire retry on the original connection returns the same issued expiry
within the challenge window. It does not extend the credential lifetime. Membership
is checked again on every request. `hub_authorize` uses the room's current enabled
member and private control key; poisoned/unknown rooms do not issue credentials.
This authorizes relay use, not possession of an active gameplay lease. Actual game
participation still passes current incarnation, rendezvous and authority checks.

Canonical request/reply envelopes use version 1 and kinds `0x5451`/`0x5452`, with
direction-separated HMAC-SHA256. Replies bind the exact request hash, nonce,
sequence, room, content and member. Fixed message bounds are 2048 bytes, four TURN
URLs, a 96-byte username and a 64-byte password field. The provider retains at most
128 connection challenges, with global and per-connection work budgets.

**Transport must authenticate the provider and keep replies confidential.** HMAC
does not encrypt a credential. The room service uses verified WSS deployments or
its explicit loopback-only test mode. No relay secret or temporary password belongs
in a URL, invitation, gameplay checkpoint or public log.

## Coturn and time

Coturn's REST-style credential is a timestamp-prefixed username and a Base64
HMAC-SHA1 password. Only this compatibility calculation uses legacy SHA-1;
Replay request/reply authentication uses HMAC-SHA256. Known short-key and long-key
vectors are checked independently, and real Coturn accepts the issued credentials.
[Coturn configuration](https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf).

The provider's clock supplies Unix seconds for TURN expiry and monotonic milliseconds
for request budgets/challenge deadlines. Backward wall/monotonic samples poison the
provider. Issuer and TURN-server clocks must be synchronized; the protocol cannot
prove the clock of a separately operated relay. TTL is configured from 5–3600 seconds
(the example service defaults to 600). Existing issued credentials may remain usable
at TURN until expiry even if membership is later disabled.

The client does not trust its own wall clock to determine expiry. It starts the
usable lifetime at its local request time and subtracts a one-second safety margin,
never adding response latency. The client refreshes halfway through that interval.
An unexpired credential remains available during a temporary refresh failure;
an expired one does not. A membership denial retires the client cache immediately.
Old replies cannot satisfy a different acquisition.

## Godot integration

`Relay_Connection` owns a verified WebSocket and the client protocol. It reconnects
with a new connection-bound challenge, refreshes credentials while pumped, and
builds validated ICE JSON from a usable grant. Its `relay_ice_source` returns nothing
after expiry. `Rtc_Config.ice_source` is consulted before each new peer connection;
an unavailable source fails that connection instead of falling back to direct ICE.
Existing peer connections are not renegotiated merely because a credential refreshes.

`Party_Config.relay_credentials=true` enables this flow after durable enrollment.
Party waits for a usable initial credential, then continues pumping refresh while
the game is running. Room carries the source callback through migration/reconnect.
Party and its relay owner must outlive any Room using that callback. Static
`ice_json` and the provider option are mutually exclusive. Games opt in with
`REPLAY_CAVE_ROOM_RELAY=1` / `RSY_ROOM_RELAY=1` or browser `room_relay=1`.

The standalone room service accepts:

| Setting | Meaning |
| --- | --- |
| `REPLAY_ROOM_TURN_SECRET_FILE` | Private file containing the same strong secret configured in Coturn |
| `REPLAY_ROOM_TURN_URLS` | One to four comma-separated TURN URLs |
| `REPLAY_ROOM_TURN_TTL` | Credential lifetime in seconds, default 600 |
| `REPLAY_ROOM_TURN_RELAY_ONLY=1` | Require relay-only candidate selection in issued ICE settings |

Configure Coturn with `use-auth-secret` and the matching server-only secret. The
fixture does this inside a private temporary directory. The service must be pumped
serially with its shared transport/room hub; credentials are not durable authority
decisions and do not alter their record formats or epochs.

## Verification and remaining limits

```sh
nix develop --command bash tests/replay_relay/run.sh
TURNSERVER=/path/to/turnserver REPLAY_TURN_PROVIDER=1 \
nix develop --command bash tests/replay_turn/run.sh
```

The provider fixture uses a short TTL, waits beyond the credential used for the
initial selected connection, then migrates/rejoins with later credentials. See
[recorded evidence](../../docs/replay/results/relay-credentials-2026-09-07/README.md).

This is not instant revocation of credentials already known to a client, encrypted
credential storage, a public relay deployment, or per-account billing enforcement.
Operator clock synchronization, provider/relay quotas, public WSS/TLS, long-duration
and combined-outage coverage remain required deployment work. The optional source
does not implement in-place ICE restart; it supplies current credentials when a
new connection is created.

# ICE settings for party and Room connections

`Party_Config.ice_json` supplies a bounded RTC configuration, copied when Party
opens and carried into `Room_Options.session.rtc.ice_json`. Room keeps that copy
through authority changes and reconnects. Direct `Rtc_Config` / `Session_Options`
users can continue supplying `ice_json` themselves. An empty value retains the
local-only default with no ICE servers.

The validator rejects oversized/deep JSON, non-dictionary roots, invalid server
arrays, malformed URLs, missing TURN username/password fields and invalid transport
policies before opening signaling. It allows at most 8 servers, 8 URLs per server
and 8192 JSON bytes. URLs use `stun:`, `stuns:`, `turn:` or `turns:` with bounded
host/port and optional TURN UDP/TCP transport. Other RTCConfiguration fields are
passed to the platform; this validator does not certify arbitrary platform options.

Relay-only mode requires at least one authenticated TURN entry:

```json
{
  "iceTransportPolicy": "relay",
  "iceServers": [{
    "urls": ["turn:relay.example.com:3478?transport=udp"],
    "username": "issued-user",
    "credential": "issued-password"
  }]
}
```

Godot forwards the configuration dictionary into its browser peer-connection
constructor. Relay-only selection is a browser policy; the test harness verifies
the actual selected pair rather than treating the configuration alone as evidence.
[Godot implementation](https://github.com/godotengine/godot/blob/4.7.1-stable/modules/webrtc/webrtc_peer_connection_js.cpp),
[WebRTC configuration](https://www.w3.org/TR/webrtc/#rtcconfiguration-dictionary).

## Supplying settings

Native Cavecrawl reads `REPLAY_CAVE_ICE_JSON`; native Scrapyard reads `RSY_ICE_JSON`.
These settings matter when using a native RTC extension; ordinary native ENet does
not gain NAT traversal from an ICE configuration.

Browser hosts set `globalThis.replayIceConfig` before starting Godot. It may be the
configuration object or its JSON string. The game calls `rtc_ice_settings`, validates
and copies the value during setup. It is intentionally not read from URL query
parameters, party invitations or saved enrollment records.

The optional [authenticated relay provider](../relay/README.md) now mints short-lived
TURN credentials for enrolled members. `Party_Config.relay_credentials` enables
background refresh and a source that refuses expired credentials when building new
connections. Static ICE JSON remains available for other provider channels. Never
ship the provider's shared signing secret to clients. In-place ICE restart, broader
expiry/outage combinations and public deployment remain separate integration work.

The configuration is runtime connection data, not gameplay state. It does not enter
authority checkpoints, recipient snapshots, saved progression or invitation codes.
Errors shown by the games describe the configuration failure without echoing the
JSON. The configuration's strings are owned by Party/Room/Rtc for their respective
lifetimes; changing the caller's original buffer cannot alter a live configuration.

Same-term gameplay reconnect now retains the authenticated RTC reservation in
memory when scope/incarnation match. Actual relay-stop/restart gates preserve the
logical peer ID and action ledger while rebuilding data channels. See
[RTC recovery](rtc-recovery.md). This does not renew expired TURN credentials.

## Reachability and limits

Actual Coturn UDP and TCP relay fixtures exercise party gameplay, handoff and rejoin.
The authentication fixture proves a bad password cannot silently fall back to a
direct candidate when relay-only mode is selected. See
[relay tests](../../tests/replay_turn/README.md) and
[recorded evidence](../../docs/replay/results/turn-relay-2026-09-07/README.md).

These local tests are not public Internet deployment acceptance. Public DNS,
HTTPS/WSS certificates, firewall/NAT rules, provider credentials/quotas, additional
browser engines, relay TLS (`turns:`), long-session expiry and combined outages
need their own evidence. Coturn's loopback-peer exception is enabled only in the
isolated local fixture, not prescribed for production.

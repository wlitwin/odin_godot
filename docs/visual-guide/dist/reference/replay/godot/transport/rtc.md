# Replay WebRTC adapter

Use `Rtc` for Replay packets over WebRTC data channels, including browser
gameplay. It owns raw Godot `WebRTCPeerConnection` and `WebRTCDataChannel` objects.
It does not install `MultiplayerAPI`, use scene RPCs, or share a global session pool.
Keep its address stable while open. `rtc_transport` exposes the same copied-packet
interface used by ENet, server/client sessions and the P2P runner.

```odin
rtc: transportgd.Rtc
assert(transportgd.rtc_open(&rtc, {url = "wss://your-relay/rtc", host = true}))
wire := transportgd.rtc_transport(&rtc)
defer tr.close(&wire)
// Each frame: tr.poll(&wire), then drain tr.receive. rtc.room becomes available
// after registration. Join with {url = ..., room = shared_code}.
```

For the gameplay facade, start from `SESSION_OPTIONS`, set `backend = .Rtc`,
`rtc = {url = ..., room = ...}`, and choose `Host`, `Server`, `Client` or `Observer`.
`session_frame` pumps the transport; read the assigned code from `session.rtc.room`.
Role controls whether registration creates or joins a room. Options' strings are
copied by the adapter during opening and released on close. `session_close` owns
transport teardown, including optional delay and recovery routing wrappers.

## Connections and signaling

The JSON signaling protocol uses `create`, `join`, `signal` and `leave` requests;
responses are `created`/`joined`, `peer`, `peer_left`, `signal` and `error`.
Introductions carry numeric peer IDs, and the lower ID creates the offer. The
relay must introduce both endpoints before forwarding SDP/ICE and assign `from`
from the authenticated socket, never a client-supplied sender. IDs must not be
reused within a live room. A star relay gives host/client connections; a mesh
relay gives direct connections between all introduced peers. There is no automatic
game-packet forwarding between unconnected peers.

SDP uses `{kind:"sdp", sdp_type:"offer"|"answer", sdp:...}` under `data`.
ICE uses `{kind:"ice", media:..., index:..., name:...}`. Incoming ICE waits until
the remote description has actually been installed, including Godot's async
answer path. Callback contexts remain alive through the custom Callable's final
reference, are marked inactive before disconnect, and cannot target a reused
connection slot after teardown.

The adapter has 16 remote slots, 32 KiB signaling messages, nesting depth 16,
64 pending ICE candidates per peer, a 15-second registration deadline and a
45-second handshake deadline. Signaling uses a bounded 128 KiB socket buffer and
64-message poll budget. It preserves healthy direct channels when signaling is
lost and reports `signaling_lost`. Authenticated grant configuration enables
bounded-identity signaling continuation; plain relays retain explicit failure
handling. It does not silently create another room.

`ice_json` supplies the WebRTC configuration, including deployment-specific
STUN/TURN servers and credentials. The default is an empty ICE-server list for
local testing. The local fixture in `tests/replay_rtc/signal_server.mjs` binds only
to loopback; it is not a public authenticated room service. Browser-native WebRTC
is the tested target. Native use explicitly requires `native_extension = true`
and an installed Godot WebRTC extension; native ENet remains the default.

Party and the Cavecrawl/Scrapyard menus carry bounded, validated ICE settings
through Room migration/rejoin. Actual Coturn UDP/TCP fixtures inspect selected
relay candidates and transferred bytes; wrong credentials cannot fall back to
direct gameplay in relay-only mode. See [ICE deployment settings](ice-deployment.md).

## Packet limits and flow control

Reliable and unreliable traffic use separately negotiated channels (IDs 0 and 1).
The unreliable channel is unordered with zero retransmissions. Each physical
packet is at most 1,200 bytes: a 16-byte credit envelope plus at most 1,184 bytes
from the fragmentation layer. Logical Replay packets retain their 65,536-byte
limit. The fragment header is 20 bytes, with a message ID, total length and part
index/count; all integers are little endian. Fragments validate bounds before
allocation and deliver reliable logical messages in send order.

New peers advertise `control_stream: 1` alongside their SDP and use negotiated
channel 2 (`replay-control-v1`) for cumulative credit acknowledgments and fences.
This channel is reliable and unordered: older cumulative acknowledgments can be
ignored safely, and fences already use a monotonic receive frontier. Application
data remains on IDs 0/1 and keeps its existing ordering and sequence validation.
The separate stream avoids waiting for ordered checkpoint messages to be delivered
before credit messages become available. It still shares SCTP congestion control;
it does not guarantee latency or solve all snapshot-freshness stalls under loss.

Absent the peer capability, controls retain their original reliable channel-0
path. `Rtc_Config.legacy_control` explicitly omits the capability and third channel.
Receiving application data on control stream 2, control on unreliable stream 1,
or an acknowledgment beyond the sender's issued sequence remains a protocol error.
Channel 2 is required to open only after both local support and remote capability
are known. This capability does not change the packet header, gameplay protocol,
checkpoint format, identity or authority checks. Real mixed-version loaded-game
handoffs cover both offerer/answerer directions; native-extension deployment and
broader platform validation remain additional coverage.

The browser adapter requires Godot's `network/limits/webrtc/max_channel_in_buffer_kb`
to be at least its default 64 KiB; smaller settings fail opening explicitly.
The adapter limits each channel to 16 unacknowledged data packets and 32 KiB of
local queued channel bytes. Acknowledgments follow application receipt, not merely
SCTP delivery. This matters because Godot's JS data-channel ring can drop data even
on a reliable channel when it fills. A reliable credit probe releases lost
unreliable packets' window; it does not retransmit their gameplay payloads. An
unacknowledged window closes after 15 seconds without credit progress, exposing a
disconnection instead of silently claiming reliable delivery. Applications should
continue polling/draining during menus; prolonged suspension requires reconnect.

Fragment queues default to 32 messages, 1 MiB outgoing and 2 MiB incoming logical
bytes. Unfinished unreliable assemblies expire after two seconds. Reliable
assemblies remain until consumed or disconnected; receive backpressure retains the
next fragment. `Buffer_Too_Small` retains a complete logical packet for retry.
Closing `Fragments` alone releases only its storage, borrowing its base transport;
closing the public `Rtc` transport also closes its owned Godot objects.

## Acceptance and remaining work

Run `nix develop --command bash tests/replay_rtc/run.sh` with the Godot web templates,
Chrome and the existing `tests/web/node_modules` dependencies installed. Failures
retain logs; missing browser dependencies fail rather than report a green gate.
The fixture uses separate Chrome processes and real data channels, without public
STUN/TURN. It exchanges 64 KiB reliable messages followed by smaller messages,
unreliable data, direct client-to-client traffic, departure, replacement and
closing/reopening the same adapter address.
A second scenario uses the ordinary Hello simulation through `Session` and compares
canonical world hashes after movement and a reliable firing action.

`Room` supports challenged RTC destinations through `Migration_Transport`,
using a trusted provider URL and a code derived from the signed authority view.
Planned and killed-host Cavecrawl browser gates pass. Wider failure cases, public
provisioning/TURN and additional browser engines remain open. See the
[authenticated signaling frontend](../rendezvous.md). Replay Duel also provides
P2P gameplay/spectator/archive gates; other ports still need browser acceptance.

Same-term Room reconnection can retain an authenticated RTC continuation
across transport replacement, while requesting new channels and preserving the
client's action ledger. Real Coturn outage tests exercise recovery without replacing
the game processes or authority. See [RTC recovery](rtc-recovery.md).

Engine contracts: [WebRTCPeerConnection](https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html),
[WebRTCDataChannel](https://docs.godotengine.org/en/stable/classes/class_webrtcdatachannel.html),
and [Godot's JS receive/send implementation](https://github.com/godotengine/godot/blob/master/modules/webrtc/webrtc_data_channel_js.cpp).


Authenticated signaling recovery uses `resume_signaling` and the provider's
continuation token. `signaling_resumes` counts completed resumptions;
`rtc_connection_serial` reports local peer-connection generations for diagnostics.
`rtc_drop_signaling` closes only the signaling socket and is useful for embedding
lifecycle controls or fault tests. If every existing channel is healthy, a resume
preserves those generations and all data/fragment state. See [rendezvous](../rendezvous.md)
for challenge, grace-period and provider compatibility requirements.

An authenticated provider may attach exact 64-bit `member` and `incarnation`
metadata to introductions. `Rtc_Config.require_identity` requires an authorization
callback and refuses introductions missing valid identity metadata.
`rtc_peer_identity` exposes that identity for a connected physical peer on an
authenticated signaling connection. Applications still validate the member against
their roster before creating a logical binding. See [P2P admission](../../p2p/admission/README.md)
for the fixed-match provider and rejoin integration.

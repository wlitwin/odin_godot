# kit/xfer — chunked large payloads

Use a transfer to send a large payload, such as a user-drawn spray, custom
skin, or shared level file. `kit/xfer` splits it into chunks, limits the number
sent per tick, and reassembles it at each receiver. This bounds transfer work
per tick and avoids submitting the entire payload as one transport message.
For WebRTC without SCTP message interleaving,
[RFC 8831](https://www.rfc-editor.org/rfc/rfc8831.html#section-6.6) recommends
limiting messages to 16KB to avoid monopolizing the association; this is not
a universal WebRTC message-size cap.

An [entity blob](session.md) sends its complete contents on each version
change and is included in snapshots for joiners. A transfer sends a payload
once. Use the Album described below when late joiners also need that payload.

Transfers use the session's app channel independently of either simulation
model. Consume arrivals in frame code, then use events or fields to represent
their consequences. Do not consume them inside a simulation tick: network
arrival timing is not deterministic simulation input.

## How it routes

All transfers route through the host. A client sends paced 8KB frames; the
host assembles its own copy and relays each frame with the sender identity.
Other peers accept these broadcasts only from the host. The sender already
holds the original bytes and does not receive a completion event for its own
transfer.

[`ksess.Host_Relay`](session.md#host-relay) handles sender identity, source
checks, echo policy, and delivery to individual peers. Xfer adds chunk
encoding, assembly, and replacement of superseded payloads. It sets
`echo = false`, suppressing returned copies of client uploads and local
delivery of the host's own broadcasts.

## Sending and receiving

```odin
import kxfer "godot:kit/xfer"

kxfer.xfer_init(&self.xfer, &self.ses, MY_TAG) // once; choose a unique tag: the
                                               // default (2) collides if the
                                               // game already claimed it
kxfer.xfer_send(&self.xfer, PAYLOAD_ID, bytes) // anyone; ≤512KB; copies
kxfer.xfer_pump(&self.xfer)                    // once per net tick; sends at most
                                               // 2 x 8KB chunks/tick
                                               // ≈ 320KB/s at the default 20Hz;
                                               // the cap scales with tick_hz, and
                                               // transfer work per tick is bounded.
for {                                          // every frame
    ev, ok := kxfer.xfer_poll(&self.xfer)
    if !ok { break }
    #partial switch e in ev {
    case kxfer.Ev_Done: // e.from, e.id, e.bytes — decode/copy this frame
    }
}
```

Payloads are keyed by `(sender, id byte)`. Sending the same ID again replaces
the queued copy and restarts assembly at receivers. Because the reliable
channel preserves per-sender order, sequence gaps indicate a restart rather
than packet loss. Receivers discard an assembly if its total exceeds
`MAX_PAYLOAD` (512KB) or its chunk count is inconsistent. Senders do not
receive their own `Ev_Done`; the
[album](#the-album--kept-payloads-late-joiners-included) can retain a local copy
and report it through the same polling API as received payloads.

**Worked example.** In scrapyard's spray-wall integration test, act 12 reads a
PNG from `user://spray.png` and transfers it to peers at startup. Pressing `G`
then places the spray on the floor. Placement uses a 13-byte kcomms marker
because peers already hold the image. The test injects 120ms latency and
requires the byte counts printed on both sides to match exactly.

<a id="the-album--kept-payloads-late-joiners-included"></a>

## Retain payloads for late joiners with Album

A raw transfer is not retained for later joiners. `Album` caches payloads by
player and kind, stores local submissions immediately, and reports arrivals
for the game to decode and display. The host can replay its cached payloads
to late joiners through the same paced transfer mechanism:

```odin
kxfer.album_init(&self.album, &self.ses, MY_TAG)  // instead of xfer_init
kxfer.album_put(&self.album, SPRAY_ID, png)       // cache locally now; send through album_pump
kxfer.album_pump(&self.album)                     // once per net tick
for {                                             // poll each frame for changed payloads
	from, id, ok := kxfer.album_poll(&self.album)
	if !ok {break}
	bytes, _ := kxfer.album_get(&self.album, from, id) // owned by the album; decode, don't retain
}

// Host, on Ev_Player_Joined, including rejoins that may have lost their cache:
// replay retained payloads to this player using the live-send chunk budget.
kxfer.album_welcome(&self.album, e.id)
```

Putting the same key again replaces the payload and cancels in-flight catch-up
of the older copy, preventing two chunk streams from competing for one
assembly. Album stores bytes; the game owns decoded images or other artifacts
and uses `album_poll` to decide when to decode again. Headless tests in
`tests/kitxfer` cover chunked convergence, replacement, and addressed catch-up.

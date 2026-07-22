# kit/xfer — chunked large payloads

Reach for a **transfer** when you need to ship one big thing — a user-drawn
spray, a custom skin, a shared level file — to every peer once. A transfer
chunks the payload, paces it, and reassembles it on the far side, so gameplay
traffic never stalls behind one giant packet and the payload fits transports
that cap message size (WebRTC data channels cap a message around 16KB).

A transfer is not an [entity blob](session.md): a blob rides whole on every
version bump and carries state a joiner must see; a transfer is a one-shot
shipment of something big.

**Lane compatibility: lane-agnostic.** Transfers ride the session's app channel;
neither lane's tick machinery is involved. Never *consume* a payload inside a
sim tick — arrival timing is wall-clock, not sim-deterministic. Land it in frame
code and let facts or fields carry the consequences.

## How it routes

Everything routes through the host. A client sends paced 8KB frames up; the host
assembles its own copy AND relays each frame to everyone, stamped with the
sender — every peer receives every payload exactly once, on any transport, and a
spoofed cast from a non-host peer drops on the floor.

xfer is a payload codec — chunking, assembly, supersede — layered over
[`ksess.Host_Relay`](session.md#the-host-relay-host_relay),
which supplies the stamp, spoof-drop, echo policy, and addressed replay. xfer
runs the relay with `echo = false`: you already hold the bytes you sent, so your
own upload coming back around is dropped on both roles.

## Sending and receiving

```odin
import kxfer "godot:kit/xfer"

kxfer.xfer_init(&self.xfer, &self.ses, MY_TAG) // once — PICK YOUR TAG: the
                                               // default (2) collides if the
                                               // game already claimed it
kxfer.xfer_send(&self.xfer, PAYLOAD_ID, bytes) // anyone; ≤512KB; copies
kxfer.xfer_pump(&self.xfer)                    // once per NET TICK — the pacing
                                               // is the point (2 x 8KB chunks/tick
                                               // ≈ 320KB/s at the default 20Hz;
                                               // the cap scales with tick_hz, and
                                               // gameplay traffic never queues
                                               // behind a spray)
for {                                          // every frame
    ev, ok := kxfer.xfer_poll(&self.xfer)
    if !ok { break }
    #partial switch e in ev {
    case kxfer.Ev_Done: // e.from, e.id, e.bytes — decode/copy this frame
    }
}
```

Payloads key by `(sender, id byte)`. Re-sending an id supersedes the queued copy
and restarts every receiver's assembly — the reliable channel is ordered per
sender, so a sequence gap means RESTART, never loss. Hostile totals past
`MAX_PAYLOAD` (512KB) or lying chunk counts drop the whole assembly. A sender
never receives its own `Ev_Done`; you already hold the bytes you sent, and the
[album](#the-album--kept-payloads-late-joiners-included)'s own-copy shelf covers
the case where you want them back.

**Worked example.** scrapyard's spray wall (integration test act 12): drop a PNG
at `user://spray.png`, it ships to every friend at start, and `G` stamps your
tag on the floor — the stamp itself is a 13-byte kcomms marker, because the image
already lives on every screen. The byte counts printed on each side of the
120ms-latency test must match exactly.

## The album — kept payloads, late joiners included

A raw transfer is one-shot: whoever joins after it shipped never sees it.
`Album` keeps payloads and replays them to late joiners, owning the own-copy
short circuit, the per-(player, kind) cache, and the arrived-repaint hook — it
closes the late-joiner hole a one-shot transfer can't:

```odin
kxfer.album_init(&self.album, &self.ses, MY_TAG)  // instead of xfer_init
kxfer.album_put(&self.album, SPRAY_ID, png)       // mine: on my shelf NOW, shipped over the pumps
kxfer.album_pump(&self.album)                     // once per net tick
for {                                             // every frame: the repaint hook
	from, id, ok := kxfer.album_poll(&self.album)
	if !ok {break}
	bytes, _ := kxfer.album_get(&self.album, from, id) // owned by the album; decode, don't retain
}

// HOST, on Ev_Player_Joined (rejoins included — their cache died with
// their process): replay every kept payload to the newcomer, addressed,
// paced by the same chunk budget as live sends.
kxfer.album_welcome(&self.album, e.id)
```

A re-put supersedes everywhere and cancels any in-flight catch-up of the stale
copy — two chunk streams for one key would tear the assembly. Decoded artifacts
stay the game's cache; the album keeps BYTES and
`album_poll` marks exactly when to re-decode. Headless-proven in
`tests/kitxfer` (chunked convergence, supersede, the addressed catch-up).

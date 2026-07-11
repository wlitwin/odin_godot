# kit/xfer — chunked large payloads

The piece [entity blobs](session.md) deliberately are not: a blob rides whole on
every version bump and is meant for state a joiner must see; a **transfer** is a
one-shot shipment of something big — a user-drawn spray, a custom skin, a shared
level file — that must not stall the reliable channel behind one giant packet,
and must fit the web transport at all (WebRTC data channels cap a message around
16KB).

The shape is [kit/comms](comms.md)' shape, sized up: everything routes through
the host. A client sends paced 8KB `XF_CHUNK` frames to the host; the host
assembles its own copy AND relays each frame to everyone as `XF_CAST`, stamped
with the sender — every peer receives every payload exactly once, on any
transport, and a spoofed cast from a non-host peer drops on the floor.

```odin
import kxfer "godot:kit/xfer"

kxfer.xfer_init(&self.xfer, &self.ses, MY_TAG) // once — PICK YOUR TAG: the
                                               // default (2) collides if the
                                               // game already claimed it
kxfer.xfer_send(&self.xfer, PAYLOAD_ID, bytes) // anyone; ≤512KB; copies
kxfer.xfer_pump(&self.xfer)                    // once per NET TICK — the pacing
                                               // is the point (2 chunks/tick ≈
                                               // 960KB/s at 60Hz, gameplay
                                               // traffic never queues behind it)
for {                                          // every frame
    ev, ok := kxfer.xfer_poll(&self.xfer)
    if !ok { break }
    #partial switch e in ev {
    case kxfer.Ev_Done: // e.from, e.id, e.bytes — decode/copy this frame
    }
}
```

Payloads key by `(sender, id byte)`; re-sending an id supersedes the queued copy
and restarts every receiver's assembly (the reliable channel is ordered per
sender, so a sequence gap means RESTART, never loss). Hostile totals past
`MAX_PAYLOAD` (512KB) or lying chunk counts drop the whole assembly.

Proven in scrapyard's spray wall (acid act 12): drop a PNG at
`user://spray.png`, it ships to every friend at start, and `G` stamps your tag
on the floor — the stamp itself is a 13-byte kcomms marker, because the image
already lives on every screen. The byte counts printed on each side of the
120ms-latency acid must match exactly.

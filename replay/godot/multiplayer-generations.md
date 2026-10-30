# MultiplayerPeer connection generations

The shared Godot MultiplayerPeer adapter assigns a nonzero, increasing generation
to each accepted connection within one open adapter lifetime. A reused numeric
peer ID receives a new generation. Duplicate connect notifications for an active
ID are idempotent. Unknown/disconnected peers report zero; exhaustion refuses a
new connection instead of wrapping the counter.

`Transport.generation` and `Received.generation` expose this local metadata. ENet
uses it directly; the Steam wrapper forwards it. Delay, Router, Fragments and
Remap can therefore retire buffered work from a replaced connection using their
existing generation checks. It is not transmitted identity or authentication.

A packet kept after `Buffer_Too_Small` retains its original generation. Disconnect
retires that pending copy. Packets may also remain in the backend's FIFO when a
connection changes. At each new connect notification, the adapter records how many
packets are already queued. Packets from that ID within the earlier queue prefix
are discarded; other peers' packets remain deliverable. Only subsequent packets
can receive the new generation. Metadata storage remains bounded by the configured
live-peer capacity and does not retain a growing set of disconnected IDs.

Backends must expose a FIFO packet queue and notify connection transitions before
queueing that connection's packets. The adapter owns polling and reading while
attached; external consumers must not remove or reorder its backend packets.
Godot's upstream [ENet implementation](https://raw.githubusercontent.com/godotengine/godot/master/modules/enet/enet_multiplayer_peer.cpp)
queues received packets separately from its peer registry, which is why the
queued-prefix boundary is necessary rather than assuming disconnect purges them.

Closing the adapter ends all borrowed handles and resets its generation namespace.
Close outer wrappers as well before reopening an owner; an old borrowed handle
must not be reused against a new owner lifetime. The native creator-rejoin path
still explicitly replaces its complete transport when server ID 1 is reused.

This changes local adapter metadata only. Gameplay wire formats, content hashes
and checkpoint layouts do not change. Public admission, account identity and
provider-specific authentication remain separate requirements.

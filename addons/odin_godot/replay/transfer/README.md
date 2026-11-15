# Bounded blob transfer

`replay/transfer` moves a canonical envelope over a borrowed packet transport.
It is independent of gameplay models and checkpoint codecs. Recovery, P2P archives
and public asset exchange can reuse its pacing, retries and integrity checks.

A `Sender` owns one active encoded value. A `Blob_Receiver` allocates its configured
byte cap and calls a validator only after source/scope, chunk assembly, SHA-256 and
envelope checks pass. The callback must validate and install atomically, borrow the
bytes only during that call, and leave the previous value intact on rejection.
Receipts make lost acknowledgments and repeated chunks idempotent. Application
values themselves remain caller-owned.

```odin
transfer.sender_init(&sender, scope, peer, wire,
    archive_kind = MY_CONTENT_KIND, max_bytes = 128 * 1024)
transfer.blob_init(&receiver, scope, peer, wire, MY_CONTENT_KIND,
    install_candidate, user, max_bytes = 128 * 1024)
transfer.sender_begin(&sender, encoded_envelope, now_ms)
```

Service each endpoint with `sender_update` / `blob_update`, dispatching received
packets to `sender_receive` / `blob_receive`. `destination` is an untrusted routing
hint; each consumer performs validation again. Keep owners/callback data at stable
addresses and destroy them explicitly. Borrowed transports are never closed by
these owners.

`Scope{room, epoch, binding, content}` is supplied after admission. Change the
binding when a connection incarnation changes. Scope identifiers reject stale or
misrouted packets; they are not authentication or authority election. Envelope tick
is a monotonic application stamp within this transfer stream; checkpoint adapters
use simulation ticks, while assets use transfer sequence stamps.

The default packet-kind base is `0x5200`, reserving seven following kinds. Callers may
choose a disjoint base. The archive kind is independently checked inside the
reassembled envelope. `replay/recovery` keeps its public facade, `0x5100` base,
checkpoint default and existing wire representation. A golden packet test compares
its complete offer digest against bytes captured before the extraction.

Limits: at most 1 MiB per envelope, 1 KiB chunks, a configured sliding window,
per-update/per-second output budgets, retry and timeout bounds. A smaller
`max_bytes` bounds receiver allocation and rejects large offers before assembly.
Use a shared transport budget when several senders/receivers operate together;
per-worker budgets alone do not bound their sum. `replay/assets` does this for its
peer workers, and the Session router also shares bandwidth with gameplay/recovery.

Optional compression uses a distinct sixth offer kind. Set `sender.compress` only
when the recipient has advertised support; its default is false. Recovery Link
selects it from the admitted connection's Features bit 128, which resets on
reconnection. Existing offer/chunk/reply schemas and canonical checkpoint formats
are unchanged. Incompressible archives use the original offer.

Compression splits archives into at most 17 independent LZ4 blocks of 65,535 bytes.
The offer still names the raw archive size and SHA-256; its additional wire size
must be smaller and remains subject to the raw byte cap. Receivers validate the
complete block stream, raw hash, canonical envelope and typed callback before
publishing a receipt. Compression never changes the authority recovery Point or
its rollback policy.

The sender retains the raw archive and, when smaller, a compressed copy. Encoding
uses one raw-size temporary buffer and a block workspace. The receiver keeps its
original `max_bytes` wire buffer and lazily allocates two additional `max_bytes`
buffers for atomic decompression. The block decoder also uses 65,535 bytes of
stack scratch. No allocation occurs per block; destroy releases all owned buffers.


`sender_update(sender, now_ms, max_output_bytes)` can further restrict one call's
output allowance. The default keeps the configured allowance; zero suppresses
output while still checking timeouts. A caller splitting one update across
scheduling phases must subtract earlier transmitted bytes from its later
allowance. This parameter does not reserve transport capacity or change packet
priority.


Schema-aware compression additionally uses the seventh offer kind. Set
`sender.shuffle` only after the recipient advertises support, and supply
`Layout{schema, offset}` for one fixed canonical section. Both endpoints borrow
an immutable ready schema at a stable address. The receiver needs the same layout;
it does not accept array offsets or programs supplied by a peer. Its fingerprint
binds the schema's shuffle version, canonical fingerprint, ordered array regions,
section offset and size. Unsupported or mismatched plans reject before assembly.

The sender compares ordinary block compression with a schema-grouped candidate
and selects the grouped form only when it is smaller, including an allowance for
the extra offer metadata. Original canonical bytes and archive hashes remain the
identity. Receiver decompression reuses its existing two scratch buffers, undoes
the grouping, then validates raw SHA-256, canonical envelope and typed acceptance.
Failed candidates cannot publish receipts. The sender temporarily adds one raw-size
buffer for grouping. `shuffled_archives` counts sender selections or receiver
validations; `shuffle_bytes_saved` is a sender-only comparison of encoded payloads,
not total network traffic including retries.

Recovery obtains the Frame section layout from its owned checkpoint codec and
uses Features bit 256, which requires bit 128. Reconnect clears both capabilities.
`net.checkpoint_frame_layout` provides the immutable schema/offset borrow;
`sender_publish` uses it when a caller-owned codec is supplied. Recovery Link owns
that codec automatically. Peers advertising only bit 128 retain ordinary block
compression, and peers advertising neither retain original offers. None of these
options changes checkpoint formats, the recovery Point, queue ordering or rollback
policy.


`sender_begin` also accepts an explicit delivery channel (default `Unreliable`).
A reliable sender relies on the transport for chunk delivery and does not enqueue
application-level retransmissions of chunks already accepted by that transport.
It retries its offer until the receiver acknowledges admission. Pass the actual
received channel to `blob_receive`; accepted reliable traffic upgrades replies to
reliable for the lifetime of that admitted scope. Delayed older datagrams cannot
downgrade replies. Timeouts, byte budgets, hashes, typed installation and retention
still apply. Transport disconnection or a broken delivery promise cannot be cured
by this option.

The caller must know the peer/router supports this delivery mode. Recovery Link
negotiates Features bit 512 and chooses reliable checkpoint delivery only for a
peer advertising it. Older peers retain the original unreliable path. This uses
the existing transport channels; no new archive format or RTC channel is created.

# Negotiated snapshot parts

Large snapshots can now travel as bounded unreliable datagrams. The initial
snapshot still establishes a reliable baseline. After that, a capable recipient
can receive full or delta snapshots in pieces without waiting for the previous
large snapshot's acknowledgment. Reliable facts remain the confirmation gate.

The protocol-7 base contract, existing packet schemas, canonical state bytes and
checkpoint format are unchanged. The optional `Features` packet (kind 16) carries
generation, Welcome serial, feature bits and maximum part size. Bit 0 offers
snapshot parts. The sender chooses the smaller advertised/configured limit,
between 512 and 1,024 bytes, including the envelope. Capability and transfer state
are discarded on the next Welcome/recovery scope. Before its first pump a client
may set `snapshot_parts_enabled = false` to use the fallback path.

A server sends `Snapshot_Part` (kind 17) only after a valid capability message from
that exact admitted connection, generation and serial. A frozen pre-extension
Replay runner interoperates in both directions: the older server ignores the
unknown optional advertisement; the newer server keeps the existing snapshot
path for an older client. The compatibility corpus verifies identical base
contract hashes and advancing worlds. This does not change interoperability with
Kit or older Replay protocol versions.

Each part has the ordinary schema envelope plus generation, serial, snapshot ID,
whole-message digest, total byte count, part index and chosen part size. The inner
message is the exact existing full/delta snapshot envelope. A receiver validates
scope, size, offsets and duplicate consistency before copying. Complete reassembly
must match the digest, inner kind/scope/tick/ID, then pass the existing canonical
snapshot/delta decoder, state validation and baseline checks. Partial or corrupt
messages never publish a world or authorize a new baseline.

The sender retains at most one encoded message per recipient. Backpressure resumes
its remaining parts before encoding another world. Reserved IDs are never reused
when a checkpoint or lost baseline abandons a partial send. Cache/acknowledgment
eligibility begins after all data parts have been accepted by the transport,
before final parity parts if those are still clearing backpressure. Facts
are sent first, and existing byte/rate budgets apply to every part and its overhead.

A client retains at most four incomplete assemblies, each bounded by its actual
snapshot wire size and the 64-KiB transport limit. Newer IDs can evict older partial
assemblies; completed/stale assemblies are discarded, and incomplete ones expire
after two seconds. Reordering and identical duplicate parts are allowed. Assembly
metadata supports up to 256 parts, including the smallest negotiated datagrams.
Reset/destroy frees assembly memory. A sender's reusable wire buffer may retain
its peak capacity until server destruction; it holds at most one snapshot per peer.

This improves delivery opportunity, not bandwidth efficiency. At an unchanged
snapshot cadence, more complete worlds can arrive and more correction work can
run. Packet overhead and loss probability also increase with fragmentation. Use
the existing snapshot cadence, egress budgets and recipient projection controls;
measure the actual game. Delivery still depends on transport queues, peer credit,
loss, CPU and available bandwidth. Bootstrap/facts are reliable, and losing a
needed delta baseline still requests the existing full-snapshot recovery path.

`Stats.fragmented_snapshots`, `snapshot_parts_sent`, `snapshot_parts_received` and
`snapshot_parts_expired` expose activity. Application byte counters include part
envelopes; transport framing/retransmission remains outside them. These counters
and capability/assembly buffers are local runtime state, not checkpoint state.

Tests cover advancing dense worlds versus fallback, loss/jitter/duplication,
backpressure, complete-only publication, scope/digest/ID corruption, bounded
assembly eviction/expiry, smaller negotiated packet limits and reconnects. The
[frozen-runner corpus](../../tests/replay_snapshot_compat/README.md) checks the
protocol-7 interoperability claim. Real swarm, browser/RTC and migration results
are recorded separately in the roadmap evidence.

## Negotiated LZ4 deltas

Feature bit 1 adds `Snapshot_Delta_Lz4` (kind 18), using the existing 48-byte
delta prefix followed by an independent LZ4 block of canonical XOR bytes. The
acknowledged base ID/hash and target hash remain mandatory. The block has an exact
decoded size from the snapshot schema, with complete validation before output.
Full and sparse-delta encodings remain available. The sender chooses LZ4 only
when it is strictly smaller than both, and skips attempts that cannot meet a
conservative format-size lower bound. The same message may use ordinary
unreliable delivery or snapshot parts, according to size and negotiated support.

`Client.lz4_snapshots_enabled = false` before first pump advertises parts without
LZ4. `snapshot_parts_enabled = false` retains the base-protocol fallback. A client
refuses an LZ4 message when support was not advertised. Capabilities reset with
the Welcome scope and are absent from checkpoints. `Stats.lz4_snapshots` counts
successful messages. The sender reuses bounded scratch: a 16-KiB match table and
a 65,808-byte output stage, with no retained dictionary. There is no foreign
compression library in the runtime.

The [codec contract](../delta/lz4.md) and [reference corpus](../../tests/replay_lz4/README.md)
cover the format and error behavior. Frozen pre-extension and parts-only runners
are both exercised by the compatibility gate. Canonical state and base contract
hashes are unchanged; this extension reduces encoded payload, not game state or
the history needed to reproduce simulation and historical queries.

Godot sessions expose the local `Session_Options.disable_lz4` preference, copied
through Room reconnect/migration setup. It does not change game state or the
checkpoint contract. Scrapyard's `RSY_LZ4=0` development setting uses that option;
the browser acceptance party keeps one parts-only peer to test both encodings.

## Negotiated two-erasure parity

Feature bit 4 (value 16) enables `Snapshot_Parity` (kind 23). For every group of
up to eight data parts, the sender emits two parity parts, interleaved after that
group's data. They protect the exact existing inner snapshot bytes. Each parity
packet uses the existing part header; its index is `group * 2 + row`, where row
0 is P and row 1 is Q from [the erasure codec](../erasure/README.md). Short data
parts are virtually zero-padded to the longest part in their group.

The receiver can reconstruct any two missing shards among that group's data and
parity. It then performs the same whole-message digest, canonical decoder,
baseline and state checks as ordinary reassembly. Parity carries no authority to
publish incomplete or unvalidated state. Duplicate consistency, generation,
Welcome serial, epoch/content, ID and size checks apply before reconstruction.
An older peer never receives parity unless it offered the feature.

Every parity packet consumes existing sender byte/rate credit and uses the
negotiated packet size. Full eight-part groups add 25% shard overhead; shorter
final groups have a higher proportional cost. This can reduce snapshot cadence
under the same budget, even as it improves completion under loss. More than two
erasures within one group may still prevent recovery; later snapshots and resync
remain available. This is not a guarantee against arbitrary loss or queue overload.

Each of the four client assemblies lazily owns parity storage bounded by
`2 * ceil(data_parts / 8) * payload_bytes`, in addition to its existing data.
The existing wire-size, assembly-count and expiry limits remain. Reset, expiry,
eviction and destruction free parity together with data. The sender needs only
2 KiB of stack scratch per flush and retains no extra snapshot history.

Parity is enabled by default for capable peers. Set
`Client.snapshot_erasure_enabled = false` before its first pump, or
`Session_Options.disable_snapshot_erasure = true`, to opt out. Scrapyard exposes
`RSY_FEC=0` (browser query `fec=0`) for comparison. These are local transport
preferences, not durable gameplay data or changes to the base protocol contract.

`Stats.snapshot_parity_sent`, `snapshot_parity_received`, `snapshot_parity_bytes`
and `snapshot_shards_recovered` report the extra activity. Recovered shards can
include reordered data, so the recovery count is not a direct packet-loss count.

## Schema-derived array shuffle

Feature bit 5 (value 32) offers `Snapshot_Delta_Shuffled` (kind 24), alongside
parts and ordinary LZ4 support. Its existing 48-byte delta prefix is followed by
an eight-byte little-endian `Schema.shuffle_fingerprint` and an LZ4 block of the
shuffled canonical XOR. The receiver requires that signature to match its compiled
transform, then reconstructs canonical bytes and checks the usual base/target
hashes, scope, snapshot ID and state. Fragmentation and parity protect the encoded
message unchanged.

The [schema transform](../schema/README.md#structural-compression-metadata) groups
equal byte positions from fixed-array records. It changes no gameplay values,
query history, canonical fingerprints or checkpoint bytes. The sender retains the
old full/sparse/LZ4 choices and uses this candidate only when it saves bytes after
its extra signature. A size heuristic skips already compact candidates; see the
[codec and scratch contract](../delta/shuffle.md).

Scratch is lazy and reused: twice the canonical snapshot size per server and per
receiving client, freed at destruction. `Stats.shuffled_snapshots` counts accepted
messages, `shuffle_attempts` counts candidate encodes, and `shuffle_bytes_saved`
counts logical payload savings relative to the prior candidate for accepted
messages. These savings exclude changes in part/parity/framing overhead and are
not a measured reduction in total network traffic. `lz4_snapshots` includes both
ordinary and shuffled LZ4 messages.

Set `Client.snapshot_shuffle_enabled = false` before first pump, or
`Session_Options.disable_snapshot_shuffle = true`, to opt out. Scrapyard exposes
`RSY_SHUFFLE=0` (browser query `shuffle=0`) for measurement. A peer that does not
advertise the capability receives its existing formats. The base protocol contract
and content semantics remain unchanged; the transform has a separate versioned
signature so an ordinary schema match cannot authorize a different permutation.

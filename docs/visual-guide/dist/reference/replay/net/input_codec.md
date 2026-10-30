# Compact scheduled-input windows

Protocol 7 adds envelope kind 15, `Inputs_Compact`. It carries the same generation,
checkpoint serial, ordered ticks, controls and view stamps as the full kind-4
packet. The sender keeps the same eight-sample redundancy window and sends at the
same cadence. Every packet contains its own first sample, so dropping or reordering
other packets cannot remove a decoding baseline. Latest-observation timing remains a separate mode. Its optional
[packet-local sparse encoding](observations.md) retains the full kind-14 fallback.

The body begins with `generation:u64`, `serial:u64`, `count:u8`, all little-endian.
Count is 1–8. Each record begins with a flags byte:

| Bit | Meaning |
| --- | --- |
| 0 | Tick equals the previous record's tick plus one; omit its eight bytes |
| 1 | Canonical control bytes equal the previous record's; omit them |
| 2 | View stamp equals the previous record's; omit it |
| 3 | View stamp uses the byte-difference form below |

The first flags byte must be zero. Bits 2 and 3 are mutually exclusive; higher
bits are reserved. Fields not omitted follow in tick, control, view order. Controls
use their ordinary canonical schema. The view is the existing 35-byte canonical
stamp, including both IDs, ticks, fraction and validity flag.

A view difference starts with five bitmap bytes, low bit first. Each set bit
selects one of the 35 view bytes, followed in index order by its nonzero XOR byte.
The five unused high bits must be zero. A difference must change at least one byte.
The sender chooses it only when the bitmap and changes are smaller than a full
view. Control equality uses canonical bytes, preserving distinctions such as the
bit patterns of signed zero. If compact framing would not save space, the sender
uses the full input packet; both forms are accepted by protocol-7 receivers.

Decode is bounded and transactional. Truncation, trailing bytes, reserved flags,
invalid reuse, tick overflow, bitmap overflow and invalid canonical values reject
the packet. The server then performs the same connection/seat, generation/serial,
control-language, order, future-window and view-provenance checks as for full input.
It validates the entire window before admitting any tick. First accepted input
for a tick still wins, and actions retain their separate reliable/deduplicated path.

The extra sender scratch buffer holds one canonical input packet; it is allocated
at client initialization and freed at destruction. Per-packet encoding and decoding
allocate no memory. The full packet's schema fingerprint remains the envelope's
logical schema identity; the protocol version specifies the compact framing.

Tests compare compact/full admission, decode a packet without earlier input
deliveries, check duplicate delivery, preserve view provenance, and reject malformed
headers/records and a late invalid control without partial admission. The broader
network fault suite exercises loss, reordering, duplication and resync.

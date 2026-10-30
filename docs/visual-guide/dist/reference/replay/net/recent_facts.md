# Compact recent facts

Protocol-7 feature **4096** permits envelope kind **27**, `Recent_Facts_Compact`.
It replaces repeated inner packet envelopes and connection scopes with one shared
header. The reliable fact stream, every-other-tick bundle cadence, four-tick
coverage, canonical events, recipient filtering and normal admission remain intact.
No previous packet or decoding baseline is required.

The outer envelope retains the epoch, content and newest tick. Its fingerprint is
the logical Facts schema fingerprint, binding the event schema as well as the
connection header. The body is:

1. Generation `u64`, serial `u64`, entry count `u8`, using the existing canonical
   `Recent_Facts_Header` codec. Entry count is 1–4.
2. Each entry: age `u8`, event count `u16` little-endian, then that many complete
   canonical occurrences. Age is 0–3; the fact tick is outer tick minus age.

Entry ticks must be positive and strictly increasing. Event counts remain bounded
by `WIRE_EVENTS`. Canonical decoding, exact length, occurrence epoch/tick, duplicate
identity and retained-fact conflict checks all run before any entry is admitted.
Validated entries then use the same receiver as reliable facts. History exhaustion
and presentation errors retain their normal explicit handling.

Packets remain bounded by the smaller of the host limit, the recipient’s advertised
`part_bytes`, and `SNAPSHOT_PART_BYTES`.
An entry that does not fit is skipped; its reliable delivery and request-based
repair are unchanged. Smaller headers can let more complete entries fit. Event
payloads are not truncated. Four empty entries occupy 81 bytes rather than 389.

The client offers support after each Welcome through the existing feature exchange.
The server sends compact bundles only for an offered capability and current
generation/serial. No acknowledgment is needed for this downstream-only format:
the offering client already knows how to receive it. Older clients receive kind 19;
older servers ignore the new offer and continue sending kind 19. Restored peer
state resets the server's selection and requires a fresh offer.

`Client.compact_recent_facts_enabled` defaults to true. Disable it before negotiation
to retain kind 19. `Server.compact_recent_facts_disabled` provides a server opt-out.
Godot's `Session_Options.disable_compact_recent_facts` applies both through open and
resume. Changing these flags during an admitted session is not supported.

`Stats.compact_recent_facts` counts successfully sent compact bundles.
`Stats.recent_fact_bytes_saved` counts header savings for those entries relative to
their kind-19 representation; that hypothetical full bundle might exceed the packet
limit when compact headers allow more events to fit. Existing `redundant_facts` and
`redundant_fact_bytes` include either encoding. These statistics do not include
transport framing or retransmissions.

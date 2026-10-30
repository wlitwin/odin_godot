# Compact latest observations

Latest-observation models can negotiate protocol-7 feature value **2048** and
envelope kind **26**, `Observation_Compact`. The logical Observation schema,
model contract, accepted controls, scheduling, view validation and checkpoints
are unchanged. The sender keeps the same observation cadence.

The compact body encodes the complete canonical Observation body independently:

1. `ceil(canonical_size / 8)` bitmap bytes, low bit first.
2. The nonzero canonical bytes selected by those bits, in ascending byte order.

Unused high bitmap bits must be zero. Selected bytes must be nonzero. Truncated,
overlong and noncanonical payloads are rejected before control admission. The
decoded value must also pass ordinary canonical schema and model validation.
Canonical bits—including signed zero—are retained exactly. No packet depends on
an earlier packet, so loss/reordering cannot destroy a decoding baseline.

The sender uses the compact kind only when it is smaller. Dense values use the
existing full kind-14 packet. Compression reuses the client's canonical input
scratch and server transmit scratch; it adds no allocation or retained baseline.
The bitmap bounds expansion to at most eight canonical bytes per encoded byte.

The client advertises support in its existing Features offer and waits for the
server's matching-generation/serial reply. An older peer continues using full
observations. The server rejects compact input without negotiation. Welcome,
reconnect and restored peer state reset negotiation. This extension currently uses
the existing snapshot-feature exchange; disabling that exchange leaves the full
observation format in use.

`Client.compact_observations_enabled` defaults to true. Set it before negotiation
to opt out. `Server.compact_observations_disabled` opts out on the receiver;
set it before admitting peers. Godot `Session_Options.disable_compact_observations`
applies the corresponding setting through open/resume and Room's Session options.
`Stats.compact_observations` and `Stats.observation_bytes_saved` count successful
compact sends and their savings relative to full canonical Observation packets.

This is a wire-cost optimization. It does not suppress idle samples, weaken
ownership checks, infer missing poses, or change reliable action context.

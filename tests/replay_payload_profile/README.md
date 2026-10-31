# Canonical payload profile

```sh
REPLAY_PAYLOAD_OUT=/private/tmp/replay-payload-profile-new \
  nix develop --command bash tests/replay_payload_profile/run.sh
```

This deterministic offline profile runs Scrapyard's actual game steps, ordinary
spawn/action, AI, weapons, damage/death and pickup code. Two stationary bolter users
shoot a replenished population of forty scrapbots for 1,200 ticks after warmup.
The shared offensive fixture uses zero enemy bite damage, magazine 255 and no jams.
Spawn timing and direct live aiming are explicit profile inputs; this is not a
replacement for the paired Godot/network workload.

The exact snapshot-shaped canonical schema supplies each byte's owning state group.
For baseline ages 1, 4, 8, 16 and 32 ticks, the profile attributes nonzero XOR bytes
and four-byte sparse-run headers. A header spanning groups belongs to its first
byte's group. Group contributions plus the two-byte run count must equal the actual
encoded size. The selected payload includes the 48-byte delta header and compares
against full-snapshot size; transport/part overhead is not included.

It also compares a negotiated LZ4 candidate, reconstructs every target byte, and
retains the final world hash and gameplay totals. Encoder timings include their
required preflight passes but exclude model stepping, schema encoding and decoder
verification. These are elapsed encoding times from one process, not process
CPU accounting, network traffic, a matched runtime benchmark, or confidence
intervals.

The selection comparison additionally times the prior network selection order and
`encode_smallest` at a payload budget that must beat a full snapshot. Method order
alternates each tick to avoid always warming the same input cache. Each pair must
choose the identical encoding kind, size and bytes, including sparse ties. The
`SELECTION` rows report elapsed selection time and winner counts; neither timing
is an acceptance threshold. This comparison does not change gameplay or canonical data.

`SHUFFLE` rows describe the optional schema-derived candidate with the exact
network heuristic and its eight-byte transform signature. Every selected payload
must reconstruct the complete original canonical value. `extra_ns` is additional
candidate work measured after the existing encodings, so its inputs are warm;
it is not a full-frame or independent algorithm benchmark. `attempts` and `wins`
show where the size heuristic skips work or keeps the existing encoding.

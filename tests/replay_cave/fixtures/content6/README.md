# Frozen C6 carrier states

`dead.replay` contains a dead carrier at `(220, 150)`, respawn tick 104, and the
relic at `(230, 138)`, carrier 1/version 7. `disconnected.replay` contains the same
position/ownership with a disconnected 65-HP avatar. Both archives are tick 100
and use test identity `cave-carrier-legacy`.

The producer scripts these world conditions and captures/encodes them through
the C6 checkpoint API. They are conversion/advancement fixtures, not recordings
of actual network departure. Live migration scenarios test real membership loss
and rejoin separately. `source.tar.gz` freezes the producer and C6 model;
`SHA256.json` seals the original outputs. Do not regenerate with a newer model.

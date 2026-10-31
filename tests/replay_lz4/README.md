# Portable LZ4 XOR codec acceptance

```sh
nix develop --command bash tests/replay_lz4/run.sh
```

The library implementation is pure Odin. Only this native oracle imports the
reference LZ4 library; the dev shell supplies `LZ4_LIB_DIR`. Other environments need
an installed LZ4 library or that variable pointing to its library directory.

768 cases cover six distributions, eight source alignments, lengths 0–65,535 and
LZ4 length/end boundaries. Native default/optimized and executed WASM builds must
agree on the encoded/mutation fingerprint. Round trips preserve every target byte.
Short outputs, truncations, malformed mutations and disallowed aliases must retain
transactional output on failure. The workspace cannot overlap either input/output.

The native LZ4 reference decoder reads Replay's standard blocks as XOR bytes,
and Replay's codec reads reference-compressed XOR blocks. Selected mutated
blocks accepted by Replay's decoder must also produce the same result in the
reference implementation.
No reference library is linked into production, Godot or the WASM corpus.

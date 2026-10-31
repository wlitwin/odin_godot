# Structurally shuffled LZ4 deltas

`shuffle_lz4_encode` combines the schema's byte permutation with the existing LZ4
block codec. A permutation is linear over XOR, so it transforms `base XOR target`
once. Its output is identical to separately shuffling both values and LZ4-encoding
their XOR. `shuffle_lz4_apply` decodes, reverses the permutation and applies the
canonical base. Callers still validate the reconstructed target digest and state.

The helpers allocate nothing. Callers supply scratch of at least twice the exact
canonical wire size, plus the existing LZ4 workspace for encoding. Scratch may
change on failure; the destination and inputs do not. Buffers/workspace must not
alias. Rejected sizes, aliases and malformed/truncated blocks preserve output.

The network runner negotiates this candidate separately and retains full, sparse
and ordinary LZ4 fallback. It tries the transform only when the existing candidate
is at least `max(2048, canonical_size / 16)` bytes, or no old candidate fits. A
transformed candidate must be strictly smaller including its eight-byte transform
signature. This heuristic avoids repeatedly testing small, already compact deltas.
It does not promise the globally smallest encoding for every possible value.

Scratch is allocated lazily once per server and receiving client, then reused and
freed at destruction. It costs twice the canonical snapshot size per such owner;
there is no new per-snapshot allocation, retained compression dictionary or changed
simulation history. Transforming arrays is lossless: it does not omit old queries,
quantize coordinates or change checkpoint semantics.

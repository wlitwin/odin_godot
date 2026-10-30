# LZ4 over canonical XOR deltas

`lz4_xor_encode(base, target, output, workspace)` emits an independent LZ4 block
whose uncompressed bytes are `base XOR target`. `lz4_xor_apply` restores the target
against the same base. Lengths are equal and bounded to 65,535 bytes. A bounded
4,096-entry hash workspace is reset for each encode; there is no retained dictionary
or cross-message compression dependency beyond the acknowledged base.

The encoder stages one complete pass in its workspace before changing output.
Its workspace contains the 16,384-byte hash table and a 65,808-byte output bound
(82,192 bytes total). Short encoder output returns the required size without
writing the caller's destination. This replaces the previous second match-search
pass with a copy of the completed block. The decoder still preflights before writing. The decoder bounds literal/match lengths, validates
backreferences and the exact decoded length, and checks the LZ4 terminal conditions
before writing. Output may not overlap inputs; the encoder workspace may not overlap
any input/output. A failed operation may change scratch workspace, never output.

The encoder follows the [LZ4 block specification](https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md),
including overlapping matches, terminal literals and match-start limits. The
reference library is a test dependency only. Native/default/optimized and executed
WASM corpora verify byte equality, rejection behavior and reference interoperability.

This codec retains all canonical data, including game-owned history. It does not
change state schemas, validate game rules, authenticate a base or choose a delivery
policy. The network runner negotiates its use separately and verifies the resulting
canonical target hash and state before publication. Compression is selected only
when its payload is smaller than both the existing sparse delta and full state.
Smaller packets can still cost more CPU; measure actual workloads.


The [staging comparison](../../tests/replay_lz4_staging/README.md) retains the earlier
implementation as an exact-byte reference. Explicit decoder word-copy/XOR experiments
were slower in the synthetic corpus and were not adopted; decoder behavior/code
remains unchanged by the staging optimization.

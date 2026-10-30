# Replay canonical schema and message codecs

`replay/schema` builds a bounded scalar-field program from Odin compiler type
information. It encodes logical values independently of struct padding, native
offsets, and endian-qualified scalar storage. This is the initial backend for
future generated schema/codecs; no new scriptgen attributes are required yet.

Initialization also compiles validation indices and contiguous copy spans. The
codec still validates constrained values before writing; adjacent canonical bytes
then copy in bulk. Padding, excluded fields and endian-qualified values split spans
as needed. This local program does not change fingerprints or wire bytes. Schema
options are fixed at initialization; rebuild a schema to change them.

```odin
State :: struct {
    position: [2]f32,
    health: i32,
    director_seed: u64 `replay:"authority"`,
}

schema: sc.Schema
report := sc.init(&schema, State)
defer sc.destroy(&schema) // also required after a failed initialization

// Callers own their buffers. encode/decode do not allocate.
report = sc.encode(&schema, state, bytes[:])
report = sc.decode(&schema, &candidate, bytes[:schema.wire_size])
```

## Contracts

- Scalars have fixed wire widths and little-endian encoding. Packed and padded
  structs with identical logical fields produce identical fingerprints/bytes.
- Fixed-width integers, f16/f32/f64, one-byte booleans, enums, bit sets, fixed
  arrays, enumerated arrays, ordinary nested structs and value-safe tagged unions
  are supported. See the [tagged-union contract](unions.md).
- Pointer-bearing/dynamic types, raw unions, platform-width serialized integers,
  unsupported widths, and unknown `replay` tags are rejected with a field path.
  An enum used only to index an array or bit set does not itself cross the wire,
  so its semantic names/values are recorded without imposing a serialized width.
- Finite floats are required by default; booleans, enum values, and bit-set masks
  are validated. Ordinary integer ranges and cross-field/game rules remain the
  admission layer's responsibility. Unused fixed-storage enum fields must still
  have a legal value; include an explicit zero member when zero initialization is used.
- Decode requires exact payload length and commits only after complete validation.
  Encode preflights values before writing any destination byte.
- Schemas own metadata/path strings and retain compiler-owned enum metadata.
  They must not outlive their compiled module. Do not copy live schema owners.
- Limits bound recursive depth, paths, logical field count, canonical metadata,
  and wire bytes. This is a fixed-value format; large assets need chunking and
  managed dynamic collections need a separate storage/codec contract.

`Schema.canonical` is the readable compatibility description. The fingerprint
includes projection, float policy, field names/order, widths, array/index meaning,
enum definitions, and authority annotations. It excludes native offsets, padding,
type aliases, and the native/endian-qualified representation of equivalent scalars.
Changing gameplay code/assets also requires a content/semantic version; a schema
fingerprint alone cannot detect changes to game rules.

## Public and authority projections

`DEFAULT_OPTIONS` describes a complete authority value. To construct a public
projection, copy those options and set `projection = .Public`. Fields under
`replay:"authority"` are omitted from its payload. Public decode preserves those
excluded fields in the supplied destination value. The entire declared type is
still checked for portable checkpoint compatibility.

The public projection and full authority checkpoint have different fingerprints.
The session uses the public projection for ordinary snapshots and the full
projection for authority checkpoints and authorized recovery holders. A filtered public
value is not sufficient to resume an authority, nor automatically sufficient to
predict gameplay that depends on excluded state.

## Envelopes

`pack` and `unpack` add a 52-byte versioned envelope around one canonical value:

```text
magic[4], version:u16, kind:u16, epoch:u64, tick:u64,
schema:u64, content:u64, body_bytes:u32, checksum:u64, body
```

The wire magic is `RPLY`; version is currently 1. `Envelope_Meta` supplies message
kind, authority epoch, tick, and content contract. `unpack` requires matching
kind/epoch/content and schema, checks exact length and checksum, then decodes
transactionally. Its returned tick still needs the session's timing validation;
`expected.tick` is intentionally unused.

`inspect` only reads untrusted routing metadata. It is not a substitute for
`unpack` or for checking transport sender identity. FNV fingerprints/checksums
detect compatibility changes and accidental corruption; they are not signatures,
authentication, or encryption. Envelopes are not yet a durable-save versioning or
host-migration protocol.

## Verification

```sh
nix develop --command bash tests/replay_schema/run.sh
```

Native tests pin bytes, padding/endian equivalence, projections, enum/bit-set
validation, field diagnostics, transactional failure, allocation ownership, and
envelope mutation/truncation rejection. The gate also type-checks the instantiated
schema/correction/transport/adapter surface for WASM. Actual cross-platform replay
and execution parity remain a later milestone.

## Field differences

`diff(schema, left, right, output)` and `diff_encoded(schema, left_payload,
right_payload, output)` compare canonical fields using the same validation and
projection as the codec. They validate both complete inputs before writing any
output, return a total count independently of display capacity and allocate nothing.
Differences carry borrowed field paths and canonical scalar bits. `diff_value`
returns owned readable text, including enum names and exact integer values.
See [audit captures and diagnostics](../diagnostics.md) for equality rules, metadata
lifetimes and an example that connects a local audit failure to field paths.

## Compiled validation

Flat schemas now compile a compact validation program alongside their copy spans.
The hot loop reads offsets, widths and validation rules directly, without copying
full diagnostic field descriptors. Boolean and finite-float checks retain their
existing rules. Bit sets use their declared mask; small enums use exact bit sets,
ascending ranges use bounds, and sparse/wide enums retain exact membership checks.
Native qualified-endian and packed/unaligned fields still use byte-safe reads.

The program preserves field order and returns the same first invalid field path.
Validation completes before encoding writes output or decoding commits a candidate.
Tagged unions retain the general guard-aware validator. Only local compiled metadata
changes: canonical fields, fingerprints, envelope checksums and bytes do not.
No runtime code generation, platform-specific vector instruction or relaxed float
validation is introduced. `Schema` owns and releases the program with its other
metadata; do not mutate compiled schema metadata after initialization.

[The codec benchmark](../../tests/replay_schema_bench/README.md) compares exact bytes
and timing with an explicitly retained reference implementation. Use game-level
profiles and workload comparisons to assess the practical benefit.

The FNV-1a compatibility digest keeps its exact historical bytes/seed behavior.
Its scan now recognizes bounded eight-byte zero blocks and applies `prime^8`
modulo 2^64; dense blocks and tails retain the ordered byte fold. Loads are explicitly
unaligned, and the zero test is endian-independent. This changes scan cost, not
fingerprints, envelope validation or cryptographic guarantees.

## Sparse validation blocks

For non-union schemas, initialization also groups zero-valid checks within one
existing direct-copy span, up to 32 checks and 128 bytes per block. A wholly zero
block is valid without interpreting each scalar. Booleans, finite floats and bit
sets accept zero; an enum must explicitly contain zero. Nonzero-only enums keep
their normal check. No scan crosses padding, omitted private fields, reversed
scalar storage or guarded union storage.

A bounded per-call probe samples up to eight compiled blocks. Two zero blocks
select grouped validation; otherwise the original scalar loop handles the value.
The decision is not cached and changes no schema state, so dense and sparse values
can alternate safely. Nonzero blocks fall back in original field order, preserving
first-error paths. Encode/decode still validate fully before writing output.

This adds local metadata and retains a small dense-input overhead in the measured
microbenchmark. It changes no canonical bytes, fingerprints, public projection or
wire/save version. [Oracle checks](../../tests/replay_schema_blocks/README.md) and
[measurement evidence](../../docs/replay/results/codec-blocks-2026-09-08/README.md)
record the supported cases and tradeoffs.

## Structural compression metadata

Schema initialization also records disjoint outer array regions in canonical byte
coordinates. Version 1 selects fixed arrays with at least four elements, at least
256 public/authority wire bytes as appropriate, and element width greater than one.
An eligible outer array replaces nested candidates. Variant-specific arrays inside
union payloads are excluded because their storage can overlap; a fixed array of
whole tagged unions can still be transformed as fixed-width records.

`shuffle(schema, canonical, grouped)` places equal byte positions from successive
array elements together. `unshuffle` reverses that permutation exactly. Bytes
outside the selected regions retain their positions. Both require disjoint,
exact-size buffers and leave the destination unchanged on rejected arguments.
They operate on serialized bytes, so padding, private-field projection and native
endianness do not leak into the transform.

`Schema.shuffle_fingerprint` identifies the transform version, canonical schema,
wire size and ordered regions. It is separate from the canonical fingerprint.
Changing the wire transform requires a new transform contract; receivers must not
infer a different permutation from a matching ordinary schema alone. These helpers
are compression primitives: canonical bytes and ordinary encode/decode stay exact.

## Local scalar authoring

`field_index(&schema, "$.path")` resolves a scalar leaf. `scalar_text(&schema,
value, index)` returns owned display text and an `Edit_Error`; free successful
text with `delete`. `edit_scalar(&schema, &value, index, text, validator)` validates
and commits one scalar change transactionally. Pass a typed `proc(State)->bool`
for application invariants, or `nil` when schema checks suffice. The helper requires
an authority projection, rejects inactive leaves and union-tag changes, and
preserves the destination on any failure. Integer parsing checks overflow before
arithmetic; float narrowing rejects overflow and nonfinite values. It supports
packed/endian-qualified values through canonical bytes, without a wire-format
change. See the [Godot preview editor](../godot/scrubber.md#editing-a-preview).

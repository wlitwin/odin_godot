# Complete physics frame diagnostics

`box3d/diagnostics` is a native-free utility for Kit and Replay. It compares
canonical complete-frame bytes supplied by the adapter and retains one bounded
first-divergence artifact. It adds no simulation, correction, or transport loop.
The existing framework decides which authenticated, confirmed frame to inspect.

## Frame contract

Import `bd "godot:box3d/diagnostics"`. A `Frame_View` borrows five ordered parts:

| Part | Required contents |
| --- | --- |
| Solver | Complete normalized future-affecting solver state, including pending end queues |
| Game | Typed deterministic game state, RNG, counters, timers, mappings and prior input state |
| Side | Additional deterministic side state and Kit registered prediction fields; empty when already included in Game |
| Observations | Provider-owned completed same-tick observations, separate from native future pending queues |
| Occurrences | Ordered deterministic event occurrences and stable identities |

The caller encodes these through its explicit schema. Native struct padding,
addresses, process-local type IDs, a motion hash, or a body-pose list do not
satisfy this contract. The utility cannot discover fields that an adapter omits.
An empty Solver is rejected; the other parts may encode an empty admitted type.
Side must not duplicate a second, inconsistently encoded copy of Game.

`Identity` binds solver, recovery, game and observation format versions, a
nonzero profile, and six SHA-256 descriptor identities: exact build/target,
assets, solver schema, game schema, observation schema, and input schema. None
may be zero. The input schema covers the accepted/predicted control and action
history used to reproduce the frame, including authoritative decisions.
The game schema identity includes the whole typed game contract: State, Side,
registered fields, Occurrence(Event), and verified application/model rules and
immutable behavior parameters, rather than State layout alone. Use
`hash_descriptors(domain, []Descriptor)` to combine schema descriptors with
unique, lexicographically sorted stable tags. The helper includes a domain,
count, tag lengths, tags, payload lengths and payloads; ambiguous concatenation
cannot alias a different schema catalog. It permits at most 32 descriptors and
1 MiB of combined descriptor bytes. Domains and tags use ASCII letters,
digits, underscore, hyphen and period, with limits of 128 and 64 bytes.
Descriptors must bind the actual admitted configuration; hashing a caller's
arbitrary label is not a compatibility check. The recovery codec's build/target
identity must include engine pin, patches, private ABI, compiler and FP/SIMD
policy. Compatibility changes require new descriptor identities.

`sign(view)` returns per-part lengths and SHA-256 values plus a complete digest
that also covers identity, epoch and tick. Motion digests remain separate native
diagnostics. `compare` accepts locally signed or successfully decoded signatures
and reports Identity, Frame, or the first differing part in the table's order.
It does not establish that a remote sample is confirmed or authorized.

## Confirmed signature wire format

`signature_encode` writes exactly 480 bytes. `signature_decode` rejects a short
packet, trailing bytes, unsupported version/flags, absent identity, zero epoch,
excessive lengths and a bad complete digest. All integers use little endian;
there is no native padding.

| Bytes | Contents |
| --- | --- |
| 0..15 | Magic `OGB3SIG1`, u32 version 1, u32 reserved zero |
| 16..39 | Four u32 format versions and u64 profile |
| 40..231 | Six 32-byte descriptor digests in Identity field order |
| 232..247 | u64 epoch, u64 tick |
| 248..447 | Five pairs of u64 byte length and 32-byte part digest |
| 448..479 | SHA-256 of bytes 0..447 |

The existing session envelope must supply source ownership, replay protection,
epoch/tick admission and rate limits. SHA-256 here detects corruption and
divergence; it does not authenticate a sender. Never receive a native Signature
struct or trust a recomputed checksum as semantic recovery validation.

## First divergence

`trace_capture` copies the first differing expected/actual frames and a
`Trace_Context`: input window, correction depth, source/sequence, and canonical
accepted and predicted input bytes. It retains the full component bytes and
first differing byte offset, including solver bytes when a game or observation
component differs. Later capture attempts return Already_Captured. Destroying
the source world or timeline does not invalidate the trace.

Allocation failure or an invalid input leaves the destination unchanged. A
caller may retry; a failed diagnostic allocation does not authorize partial
simulation publication. Charge its allocator to the diagnostic/resource budget.
Default caps are 1 MiB per part, 2 MiB per frame, and 64 KiB each for accepted
and predicted input windows. Explicit overrides have hard ceilings of 2 MiB per
part, 4 MiB per frame and 256 KiB per input window. The trace uses one allocation
for the copied payload. The caller owns the encode buffer separately.

`trace_encode` produces a versioned binary artifact and `trace_text` produces a
small readable index containing both identities, epochs/ticks, part digests,
input context and first-byte location. Release the returned text with its
allocator. `trace_destroy` releases the artifact owner; assignment aliases it.
Both encoders support an empty sizing query and preserve a short nonempty
buffer on Capacity.

The trace's 1,040-byte header contains magic `OGB3TRC1`, u32 version/reserved,
four u64 values (from tick, to tick, source, sequence), u32 depth/reserved, three
u64 values (accepted bytes, predicted bytes, total artifact bytes), and two
480-byte signatures. It is followed by all expected parts, all actual parts,
accepted inputs, predicted inputs, then SHA-256 of the preceding artifact bytes.
`trace_decode` bounds every region and verifies both component and artifact
digests before publishing one owned trace. It never imports solver state.
The artifact is a diagnostic format, not a recovery codec.

## Evidence and integration status

Native-free protocol test groups cover every frame component/identity,
truncation at every byte, single-byte corruption, semantically invalid packets
with recomputed checksums, capacity preservation, first-owner lifetime,
allocation failure and input budgets. An independent Python implementation
defines exact LE/SHA-256 vectors; native and import-free WebAssembly execution
must produce identical signature and trace bytes. Run
`bash tests/box3d_protocol/run.sh OUTPUT` in the development shell.
The optional second argument `Native` runs native tests and the Python vector
check without requiring a WebAssembly linker or Node. The full mode requires
both tools; the observed Linux container lacks `wasm-ld`, so its evidence uses
Native mode. macOS executes the import-free WebAssembly vector as well.

The native protocol vectors use synthetic fixed bytes; their agreement does not
establish cross-target physics. The measured macOS/Linux solver streams differ.
Initial physics diagnostics and recovery remain exact-build, same-target
contracts. Kit/Replay runtime consumption and impaired independent-process
evidence are tracked in P3.1/P3.2/P3.5; this standalone utility alone does not
close those gates. Both existing runtimes produce verified current-build
first-conflict artifacts. Kit retains a registered-field conflict with both complete solver
streams and input contexts. Replay retains a solver-only conflict at confirmed
tick nine while all four other components remain identical. Independent Python
checks verify both signature hashes, every component hash and the artifact
hash, and the native-free inspector decodes and re-encodes the exact bytes.
Kit's current four Debug/Release target artifacts and Replay's current Release
artifact pass independent signature/component/artifact checks and exact offline
decode/re-encoding. Replay records planned rewind depth three and the one-step
checked prefix separately. The functional codec/adapter reports retain exact
source/archive fingerprints. Independent-process testing remains P3.5, and the
unmet whole-call correction CPU target remains an explicit Gate B requirement;
these diagnostics results do not establish either acceptance.

`run_native_state.sh ARCHIVE OUTPUT` additionally exercises two actual native
cases against the specified coherent archive, with native and wrapper owners
returning to zero. A gravity change differs in Solver while motion and typed Game
remain equal. A post-step sensor destruction retains the future end queue and
copied completed observations as separate components; restored worlds agree for
60 suffix steps, while dropping the completed cache reports Observations.
Its identity is explicitly test-only; runtime peers must use the codec's verified
native identity plus their actual application schema and rule contracts.

`python3 tests/box3d_protocol/recovery_fuzz.py ARCHIVE OUTPUT` runs independent
public-ABI recovery protocol cases in separate processes. It checks header and
section metadata, truncation, trailing bytes, and seeded payload variations
with recomputed checksums. Legal finite scalar variations may be accepted;
every accepted result must restore and step eight times. Every result must
preserve an independently retained published world and balance native/wrapper
owners. The pilot run covered 460 cases; this limited test is additional
evidence, not exhaustive coverage, the native codec's semantic test suite, or
the integrated network acceptance gate. The report fingerprints its copied
archive and probe sources so evolving pilot builds cannot be conflated.

Build `tests/box3d_protocol/inspect` as a native executable and pass a trace file
to inspect one offline. It validates the bounded artifact and exact re-encoding,
then prints identities, tick/input window, differing component, first-byte
location and retained byte counts. It links no native physics backend.

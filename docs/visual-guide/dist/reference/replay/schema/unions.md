# Tagged value unions

Use ordinary Odin tagged unions or `union #no_nil` when actions, controls,
events or state need typed alternatives. Replay supports them when every possible
variant is a supported owned value:

```odin
Take :: struct {amount: u32}
Put :: struct {amount: u32}
Action :: union {Take, Put}

apply :: proc(action: Action) {
    switch value in action {
    case Take: // value.amount belongs to Take
    case Put:  // value.amount belongs to Put
    case:      // nil: no action
    }
}
```

There is no second handwritten enum or a set of unrelated argument fields to keep
in sync. Reference-bearing variants, raw unions, shared-nil unions, unsupported
scalar types and platform-width wire integers remain rejected. Validation examines
all possible variants, including hidden fields and zero-length arrays. Merely
leaving a forbidden variant inactive does not make its type safe.

## Canonical representation

Each union occupies a fixed-width canonical region:

- A four-byte little-endian tag: 0 means nil, and 1..N follow declaration order.
- A payload area as large as the largest projected variant.
- The active variant's canonical fields at the start of that area.
- Zero bytes in the remaining payload area. A nil value has an all-zero payload.

The fixed representation fits the existing bounded frame/snapshot/delta programs.
It does not transmit native union padding, inactive values or native tag width.
For `#no_nil`, zero is invalid on the wire; the native zero-based discriminator is
mapped to the same one-based canonical tags. Variant names, declaration order,
nullability and field layouts participate in the schema fingerprint. Named variants
include their package/name; compiler pointers and source locations never enter it.

Schema construction builds conditional field metadata. Encoding validates only the
active value, then writes a zeroed canonical region. Decoding checks all active
tags/scalars and every unused tail byte before changing its destination. A malformed
tag, active enum/bool/float or nonzero unused tail fails transactionally. Nested
unions are conditional on their entire enclosing variant chain.

Schemas without unions retain their existing fingerprints, bytes and contiguous
copy program. No global protocol version changes solely to add this type support.
A game changing its declared types still needs its own schema/content compatibility
transition; existing peers cannot silently reinterpret a new union shape.

## Public projections and variant changes

An authority-only union field is entirely excluded from a public projection.
Private fields inside a public union variant are omitted from the payload, while
the variant choice remains visible. Annotate the whole union if its choice is also
private information.

Public decode preserves private local fields when the active variant stays the
same. On a variant change, it zero-initializes the union's native storage before
installing the new tag and public fields. It does not reinterpret old private bytes
as a different variant. Private fields in a newly selected variant therefore need
appropriate application defaults/validation if zero is not meaningful for them.
This is explicit initialization, not reconstruction of hidden authority state.

Nilable unions are a useful default for actions/events and unused fixed storage.
For `#no_nil`, the zero-initialized first variant must be valid wherever the program
uses zero-filled values; an enum without a zero member still needs initialization.

## Replay and diagnostics

Local frame storage recursively admits only value-safe variants. State/input/event
copies and replay restore the selected variant with the rest of the world. Odin's
logical comparison ignores inactive variant storage; canonical encoding also ignores
that storage and makes its wire tail deterministic.

Field diffs expose a `$tag` entry plus conditional variant paths. A switch can report
a field becoming inactive even if both its numeric bit values happen to be zero.
`Difference.left_present/right_present` distinguish absence from a real zero;
`diff_value` prints `<inactive>` for that side. Consumers should retain the schema
while using its borrowed diagnostic metadata.

## Acceptance

`tests/replay_unions/run.sh` executes a union-valued state/input/event corpus,
revises an earlier input and checks identical schema fingerprints, canonical bytes
and final hashes in native default/optimized builds and actual WASM execution.
On the tested ARM64 Mac, an x86-64 binary executed through Rosetta agrees too.

`tests/replay_unions/enet_run.sh` runs separate Godot host/client processes with
union-valued state, controls, actions and events under latency, jitter, loss and
duplication. Both see four accepted transfers, conserve inventory and compare the
same final world. The in-memory network suite additionally covers checkpoint
capture/decode/restore and local audit of that model.

These tests establish the stated type/codec/runner behavior on the recorded targets.
They do not establish every OS, every user union layout, an unbounded dynamic-state
model or full roadmap completion. See the
[recorded union evidence](../../docs/replay/results/tagged-unions-2026-09-07/README.md).

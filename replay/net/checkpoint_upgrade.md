# Explicit checkpoint conversion

`checkpoint_decode` and `server_restore` continue to require the current protocol,
archive layout, schemas, model and application-supplied content ID. A failed load
never guesses a conversion or changes the source bytes.

The first bridge is `checkpoint_upgrade_v6(bytes, model, content, allocator)`.
It accepts gameplay protocol 6 / checkpoint layout 4 and returns owned protocol-7
archive bytes, or an error and no output. Free a successful result with the same
allocator. The input is borrowed, remains unchanged and can be released after
conversion. This routine performs no I/O and opens no session.

```odin
converted, err := net.checkpoint_upgrade_v6(old_bytes, game.model(), game.CONTENT)
defer delete(converted)
if err != .None {return err}
// Decode and apply the application's identity, dependency and recovery policy
// before publishing or restoring the result.
```

Protocol 7 changes scheduled input packet framing. Its logical schemas, archive
layout and model semantics remain compatible with protocol 6. The converter:

1. Validates the original envelope, exact bounded section lengths, layout version,
   model values, roster, pending work and old protocol's complete contract hash.
2. Computes the current contract from the same model and archived configuration.
3. Changes the protocol/contract stamps and canonically re-encodes the archive.

The authority frame, tick, epoch, roster, held/future controls, queued actions,
settled outcomes, bans and opaque admission-policy bytes are preserved. Scheduled
and latest-observation models retain distinct contracts. Passing the wrong control
timing fails. Passing an already-current archive also fails; this is a specific
bridge rather than an idempotent generic loader.

The bridge only applies while the current protocol is 7. It does not convert older
archive layouts, different state schemas, removed fields, changed gameplay content
or application semantics. Those require explicit source-version types and a
separately reviewed game conversion. Protocol-6 live peers still need a software
update; a converted save does not let different protocol versions play together.

## Authority and assets

Conversion grants no authority and does not advance the epoch. Permit requirements
and custom policy IDs remain present. `server_restore` still needs a newer epoch,
a valid permit when required and the application's admission callback. Converting
bytes changes their digest: an existing coordinator-approved checkpoint point or
sealed handoff cannot simply be replaced by these bytes. Coordinated upgrade needs
its own approved transition and publication under the new contract.

For a bundle, validate its old container, convert its root, then call
`assets.bundle_replace_root(original, converted, content)`. This preserves the
asset records and payloads byte for byte and rebuilds the container's lengths and
body digest. Check the root's content/epoch/tick against the container and verify
all application dependencies before publication. A generic converter cannot infer
which external assets a game's pending actions require.

The separate [Scrapyard tool](../../examples/replay_scrapyard/saves.md#converting-a-protocol-6-run)
adds identity, complete current-frame spray dependencies, metadata and offline
recovery checks. Its native regression gate uses genuine saves emitted by a retained
protocol-6 game binary, with source hashes and exact resumed world hashes recorded
in [the conversion evidence](../../docs/replay/results/protocol-upgrade-2026-09-06/README.md).

## Action-schema changes

`checkpoint_convert_actions(bytes, source_model, source_content, target_model,
target_content, convert)` handles an explicit application change to the action
schema while retaining the same state/control types, seat count and control
timing. It requires a current-protocol source archive. For a protocol-6 source,
first use `checkpoint_upgrade_v6` with the **source** model/content.

The converter validates the original archive and contract, maps each pending action,
then computes the target contract and validates/encodes the result. Common world,
roster, control, outcome, ban and policy sections are preserved. The mapper returns
`(new_action, ok)`; a false result or an invalid target accepted action fails the
whole conversion without producing output. Missing required validation callbacks
fail with `Invalid_Model`. Both models must provide an action handler when their
archive contains accepted pending work.

Already refused requests can contain application-invalid values. A mapper should
preserve their representable fields; the archive retains their original refusal
reason and settlement frontier. They are not promoted into accepted requests.
The target still enforces canonical schema validity for every encoded value.

The result is an owned byte buffer and the source is unchanged. This API does not
convert world/control schemas, authorize a leader, advance epochs, reconstruct
custom policy callbacks or infer which external assets the new content requires.
Changing content also requires an explicitly updated bundle envelope; use
`bundle_replace_root(..., target_content=new_content)` after checking application
metadata and dependencies. Scrapyard's content-42 importer retains a frozen original
action type and adds zeroed development payloads to the current action type. Event
types may also differ: their schemas enter the target contract, but there is no
serialized event history to transform. Scrapyard retains the content-42/43 event
shape when importing into content 44.

## World-schema changes

`checkpoint_convert_state(bytes, source_model, source_content, target_model,
target_content, convert)` maps a complete source world into a target world. The
source must use the current protocol; controls, actions, events, seat count and
control timing remain shared. Keep explicit source-version world types instead of
making normal decode guess older layouts.

The mapper returns `(target_world, ok)`. A refused mapping, invalid target world or
insufficient restored egress budget fails without output. Full source validation
precedes the mapper. Target contract/schema validation follows it. The frame tick,
epoch, roster, held and future controls, pending actions, outcomes, bans and policy
bytes remain intact. Output is owned; the borrowed source is unchanged. This
conversion has the same authority and external-asset limitations described above.

[Cavecrawl's explicit importer](../../examples/replay_cavecrawl/authoring.md)
uses this boundary to add two captured floor definitions to an older Replay world.
Its fixture is a real save produced by the earlier game binary, then converted and
resumed by the current game in a fresh process.

## Combined world and action changes

`checkpoint_convert(bytes, source_model, source_content, target_model,
target_content, world_mapper, action_mapper)` changes both world and action schemas
in one explicit conversion. Controls, seat count and control timing stay shared;
event types may differ because the archive contains no event history. Both mappers
return `(value, ok)` and run only after complete source validation. A failed mapper
or invalid target produces no output. The target must fit the restored egress budget.

The converter preserves frame tick, epoch, roster, held/future controls, pending
action identities and refusal reasons, settled outcomes, bans and policy bytes.
Rejected source actions can contain application-invalid fields; map their
representable values without promoting them to accepted work. Source bytes are
borrowed and unchanged; output is owned. The authority/asset limitations above still
apply. Cavecrawl uses this path to add lobby state and commands while importing its
two earlier Replay content versions. It does not attempt to import original Kit saves.

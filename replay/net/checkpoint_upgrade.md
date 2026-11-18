# Explicit checkpoint conversion

Normal checkpoint decoding requires the current protocol and layout, matching
schemas, model policy and application content identity. It does not infer a
conversion. The generic conversion APIs support deliberate application schema
changes within the current protocol; source-specific historical protocol readers
are not shipped.

## Authority and assets

Conversion validates the complete source archive before calling a mapper,
produces owned bytes, and leaves the source unchanged. It grants no authority and
does not advance the epoch. Restore still needs the appropriate identity, newer
epoch, permit and admission callback. A converted digest cannot replace an already
approved coordinator checkpoint or sealed handoff without its publication policy.

Validate every external dependency before publication. For a bundle, validate the
container and converted root, then use
`assets.bundle_replace_root(original, root, source_content, target_content=target_content)`.
That operation preserves asset bytes; it cannot infer which assets new gameplay
requires. Game bundle readers require a bundle envelope. Explicit raw checkpoint
APIs remain available for callers that own their storage/dependency policy.

## Action-schema changes

`checkpoint_convert_actions(bytes, source_model, source_content, target_model,
target_content, action_mapper)` maps pending actions while state, control types,
seat count and control timing remain shared. Event schemas may differ because a
checkpoint has no serialized event history.

The mapper returns `(target_action, ok)`. Accepted pending work must be valid under
the target model. Refused requests can contain application-invalid values: retain
their representable payload, refusal reason and settlement frontier. Conversion
must not re-admit them or rerun action scheduling. Missing validation callbacks,
a rejected mapping or invalid target produces no output.

## World-schema changes

`checkpoint_convert_state(bytes, source_model, source_content, target_model,
target_content, world_mapper)` maps the complete world. Controls, actions, events,
seat count and control timing remain shared. The mapper returns `(target_world, ok)`.
An invalid target or insufficient restored egress budget fails without output.

Frame tick, epoch, roster, held/future controls, pending action identities,
outcomes, bans and policy bytes are preserved. Define reviewed source types and
explicit target defaults for each application conversion. Matching field names or
layout sizes alone do not establish semantic compatibility.

## Combined world and action changes

`checkpoint_convert(bytes, source_model, source_content, target_model,
target_content, world_mapper, action_mapper)` maps both world and action schemas.
Controls, seat count and control timing remain shared; event types may differ.
Both mappers run after complete source validation. The target contract is computed
and validated before owned output is returned.

A control-schema or gameplay-timing change needs an application-owned conversion
that accounts for those semantics. Recordings also retain expected frames and
events: verify them with the target model instead of regenerating expectations to
hide divergence. [Evolution helpers](../evolution/README.md) provide explicit
schema freezing, manifests, additive defaults and unchanged-field checks.

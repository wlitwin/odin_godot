# Authority moderation compatibility

`reference` contains the pre-extension authority package captured before this
change. Only its package declaration is renamed; the manifest records original
and adapted hashes. The fixture runs an old client against the current service
and a current client against the old service using actual transport packets.
Start/Query schemas and MAC domains remain unchanged. An optional removal packet
must be ignored by the old service without a durable mutation.

```sh
REPLAY_AUTHORITY_MODERATION_COMPAT_OUT=/absolute/fresh/output nix develop --command bash tests/replay_authority_moderation_compat/run.sh
```

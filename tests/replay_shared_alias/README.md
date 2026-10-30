# Shared plain-type and runtime-alias acceptance

```sh
REPLAY_SHARED_ALIAS_OUT=/absolute/fresh/output nix develop --command bash tests/replay_shared_alias/run.sh
```

The focused generator matrix accepts plain structs, alias chains, distinct types,
generic/nested-generic wrappers, actual Replay Timeline aliases, ordinary using
embeds and engine/standard-library leaves. Accepted ordinary fixtures also compile
as Odin packages. Cross-package generic cases ensure an argument resolves in the
caller's package, even when the generic library defines a different same-named type.

Negative cases retain refusal for tagged fields and nested/generic aliases to them,
composed methods/ticks, typed signals including aliases/renamed engine imports,
missing declarations, cycles and wrong generic arity. A user package named `gd`
must not be mistaken for an opaque engine import.

The existing scriptgen suite follows, preserving its tagged-bundle and wire ABI
tests. Replay Hello now declares `timeline: game.Timeline` in its real script;
native/WASM builds, input and full history/recording/playback/browser workflows
exercise the alias beyond a synthetic generator result.

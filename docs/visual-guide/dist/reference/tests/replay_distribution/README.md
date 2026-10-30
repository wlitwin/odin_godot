# Replay consumer distribution gate

This gate builds the actual Nix addon recipe from a frozen, bounded source snapshot
and installs its output into a temporary Godot project outside the repository. It
does not modify the shared Git index, create a release branch/tag, or publish an
artifact. The snapshot includes current untracked Replay implementation files that
a normal Git-flake build would otherwise omit.

```sh
REPLAY_DISTRIBUTION_OUT=/tmp/replay-consumer-check \
nix develop --command bash tests/replay_distribution/run.sh
```

Use a fresh output path. `snapshot.py` includes only known addon build inputs and
the documented consumer files, excluding caches, binaries, game projects and result
archives. It writes a source-content manifest before Nix reads the snapshot.

The test copies `template/replay/` into the external project, builds using the
installed addon's helper with `SKIP_CORE=1`, and unsets `ODIN_SCRIPTS_DLL`. The
prebuilt core must discover the consumer's compiled scripts in the split layout.
The starter runs offline and in separate host/client/observer processes, with a
conserved shared coin and a remote accepted action. The same packaged web helper
builds an actual browser export; Chrome executes the offline starter and captures
a screenshot. A WASM type-check is additional evidence, not a replacement for that
browser run.

The gate verifies every packaged Replay source against its snapshot, checks source
directories' `.gdignore` files, and rejects original-checkout paths in consumer Odin
sources. The source repository is used only by the external test driver/reporting,
not by the consumer's collection or build helper. Logs and the temporary consumer
remain available for review.

The separate `#release` package adds cross-built Linux/Windows cores and ZIP/checksum
assembly. Runtime acceptance in this environment covers macOS and Chrome; cross-built
core formats alone do not establish Linux/Windows runtime support. See
[recorded evidence](../../docs/replay/results/distribution-2026-09-07/README.md).

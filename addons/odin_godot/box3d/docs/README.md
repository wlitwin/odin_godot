# Box3D engineering contracts

For game development, use the [Box3D manual](../../docs/box3d/index.md). These
records describe the native boundary and adapter invariants for SDK contributors.
Executable validation fixtures and their reports live under `tests/`.

| Contract | Covers |
| --- | --- |
| [Framework state](framework-contract.md) | Owned images, staged execution, transaction and callback lifetimes |
| [Kit world protocol](kit-world-protocol-v2.md) | Complete-state identity, accepted input, and settled frontiers |
| [Recovery codec](recovery-codec.md) | Canonical solver encoding, validation, and trusted reconstruction |
| [Frame diagnostics](network-diagnostics.md) | Complete signatures, copied bytes, and first-divergence traces |
| [Operational diagnostics](production-diagnostics.md) | Diagnostic bundles and failure inspection |
| [Runtime deployment](runtime-deployment.md) | One native domain, producer/code/data ownership, and reload |
| [Bounds](bounds.md) | Input and resource validation boundaries |
| [Prediction and presentation](prediction-presentation.md) | Copied views and complete-state correction |
| [Dependencies](dependencies.md) | Pins, patches, notices, and attribution |
| [Upgrades](upgrade.md) | Candidate identity, compatibility, and validation |
| [Releases](release.md) | Candidate review and release checks |

Normative API details also live in the native headers and public package source.
Use source identities attached to a validation report when interpreting recorded
measurements; a past run does not qualify a changed backend or target.

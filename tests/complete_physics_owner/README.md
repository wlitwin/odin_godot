# Complete-physics owner acceptance

Run `nix develop --command bash tests/run_all.sh completephysicsowner`.
`BOX3D_NATIVE_LIBRARY` can select an existing coherent test-enabled shared
backend with its adjacent static archive; otherwise the wrapper builds the
default backend. Outputs remain in the printed temporary evidence directories.

The gate runs metered-storage tests, Replay codec refusal/rollback regressions,
Kit provider/codec/Lane/network cleanup regressions, then a real Core SDK build
and Godot runtime. The runtime covers unsupported-role and rejected-initializer
rollback, a non-default Replay epoch, concurrent sources, detached checkpoints
surviving source close, another source opening while an old checkpoint survives,
managed temporary checkpoints, Kit busy-close retry, and script removal during
initialization. Native allocations and all meter categories must return to zero.

Controlled owner callbacks exercise refused retain/drop behavior; real native
catalogs, snapshots and schema allocations are used where appropriate. Separate
normal Host/Client sample runs verify existing network/game behavior after
adoption. This gate does not replace those pair checks or claim new platforms.

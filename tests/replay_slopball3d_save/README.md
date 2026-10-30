# Native slopball3d checkpoint acceptance

```sh
REPLAY_SLOPBALL3D_SAVE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_slopball3d_save/run.sh
```

The runner builds an isolated app and runs its existing UI/profile/WASM checks.
A named host/client pair scores through real gameplay and saves with F5 during
moving play. A blocked staging-file open must preserve the committed archive,
then the runner kills both exact writer processes after the durable receipt.

An independent decoder validates the actual checkpoint and creates valid protected
policy/maximum-epoch negative fixtures. Wrong owner, damaged/missing data and a
configured Room path must also refuse without replacing files. Fresh solo and host
processes restore the exact tick/digest. The first eligible local ball solver seed
must match the saved pose/momentum; a later reseed cannot hide an initial mismatch.

The guest reclaims its seat/name. New kicks and goals, named chat and a common
authoritative world after continued play are required. The host saves the completed
match again, and independent decode verifies its newer epoch/result. Profile bytes
remain unchanged. The 3D fixture requires a spinning, nontrivially rotated source.

`execute.py OUTPUT LABEL` reuses a verified prepared app. `capture.py OUTPUT LABEL`
renders its menu and a solo restore while preserving files. Raw profiles and
checkpoint bytes are private test state; retain decoded observations and hashes
instead when publishing evidence.

The read phase records an observational trajectory once per 60 game ticks. Failure
receipts include the final observation. `replay_saved.py PREPARED_APP SOURCE_SAVE_DIR
FRESH_OUTPUT` reruns only the read phase from a retained checkpoint and its original
fixture profiles. It verifies source hashes before/after and writes only into the
fresh directory. This reproduces solver/bot continuation failures without selecting
a different save. It does not install synthetic world state.

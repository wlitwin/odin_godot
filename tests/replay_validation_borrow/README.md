# Borrowed validation equivalence

This fixture compares the six original Scrapyard validator bodies with their
borrowed implementations in one isolated model package. It preserves the original
public value-taking interfaces. No gameplay rule, schema, content ID or validation
predicate is intentionally changed.

```sh
python3 tests/replay_validation_borrow/prepare.py /absolute/before-model /absolute/fresh/oracle
nix develop --command odin test /absolute/fresh/oracle/shared/game \
  -collection:godot="$PWD" -o:speed -out:/absolute/fresh/validation-test
```

`before-model` contains the six unmodified files (`game.odin`, `combat.odin`,
`abilities.odin`, `run.odin`, `ordnance.odin`, `effects.odin`) archived by the result.
Preparation copies the current shared model, extracts and renames the original
validator bodies, and never edits either input. Their surrounding game helpers
remain the current unchanged helpers.

The test creates a valid populated world with recorded history, then varies every
canonical scalar field twice. It uses normal Boolean/enum values and integer/float
edge cases, including NaNs. Each case compares all six results and verifies that
borrowed validation leaves the supplied world's bytes untouched. This is a
behavioral equivalence check, not permission to omit validation. The ordinary
model suite and WASM check remain required.

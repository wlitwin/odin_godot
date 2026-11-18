# Synthetic evolution fixtures

These small independent schemas exercise contract export, frozen Odin source,
and conversion scaffolding. They have no dependency on a game or retired game
schema. `source` and `target` are frozen from `../schema_fixture/types.odin` using
`e.freeze`/`e.contract`; `conversion.odin` is the unchanged output of `e.scaffold`.
The scaffold intentionally refuses conversion until its new defaults are reviewed.
`contracts_test.odin` compares the exact generated text and contracts and tests
an explicit reviewed conversion separately.

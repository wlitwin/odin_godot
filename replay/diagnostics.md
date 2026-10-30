# Explaining a local replay failure

`audit` reports the first tick whose re-executed state or event batch differs from
recorded history. `audit_capture` performs the same single audit execution and
retains the evidence at that first mismatch:

```odin
capture: r.Audit_Capture(World, Input, Event)
defer r.audit_capture_destroy(&capture)
result := r.audit_capture(&timeline, first_tick, &capture)
if capture.ready {
    // capture.parent: the preceding frame used to execute the failing tick
    // capture.input: the recorded input for that tick
    // capture.expected / capture.actual: independent owned frame values
    // capture.expected_events / actual_events: independent owned arrays
}
```

The capture is populated only for `Diverged_State` or `Diverged_Event`. Successful
audit, missing history, invalid arguments and a step that aborts do not produce a
capture. The returned `Result` still explains those errors. An occupied capture
must be destroyed before reuse. Destroy even when no mismatch was captured; the
operation is safe for an empty owner.

Captures do not alias the timeline, its recorded events or replay scratch. They
remain available after another audit/correction reuses scratch, and modifying a
capture cannot change the original history. All frame/input/event values still
obey the core's no-reference value contract. Only the diagnostic event arrays
allocate, and only after a divergence has actually been found. Ordinary `audit`
retains its existing behavior and does not allocate a capture.

This is evidence from one local replay, not a proof of determinism or a recorder
of illegal external side effects. Callbacks must still obey the simulation contract.
The captured preceding frame and input help reproduce one tick with the same code
and explicitly supplied model configuration; hidden external state is not captured.

## Canonical field differences

The optional `replay/schema` layer locates differing fields in schema-supported
values. It remains separate from the core, whose value rules also permit types
without a portable network schema.

```odin
schema: sc.Schema
sc.init(&schema, World)
defer sc.destroy(&schema)
fields: [32]sc.Difference
report := sc.diff(&schema, capture.expected.state, capture.actual.state, fields[:])
for field in fields[:report.count] {
    expected := sc.diff_value(&schema, field, .Left)
    actual := sc.diff_value(&schema, field, .Right)
    fmt.println(field.path, expected, actual)
    delete(expected); delete(actual)
}
```

`report.total` counts every differing field, while `report.count` is the number
written into the caller's bounded buffer. Paths and enum names borrow the schema's
metadata; keep it alive while using them. Formatted values are owned strings.
Both complete inputs are validated before any output entry is written. Reports
identify which side failed validation. Public projection excludes private fields
from comparison and output. Compare authority fields only in trusted local tooling.

These are canonical scalar-bit differences: padding is ignored, endian-qualified
fields are normalized, and signed zero or permitted NaN payload differences remain
visible. The core audit compares logical Odin values, so its equality rule can differ
from canonical byte equality. `diff_encoded` compares exact canonical payloads;
validate framing/context/authenticity separately before supplying untrusted bytes.

For event failures, compare the captured event counts and use a schema for
`r.Occurrence(Event)` to compare corresponding entries. Event order and semantic IDs
are part of the core's recorded batch, so a different order is itself useful evidence.

The [Scrapyard inspection tool](../examples/replay_scrapyard/tools/inspect_run/README.md)
shows the field-diff API applied to validated real game checkpoints. It emits bounded
JSON without modifying either save or opening a network session.


`audit_window` finds the latest bounded replayable suffix without copying gameplay
values. It stops at an initial/corrected checkpoint or retained-history edge.
`audit_recent` captures a failure from that suffix. This is useful for clients,
whose authority correction did not come from locally recorded generating input.
The [Godot overlay](godot/debug.md) uses these boundaries and the owned plain-text
formatter in `replay/diagnostic` for explicit developer audits.

## Persistent gameplay windows

[Portable local recordings](diagnostic/recording.md) retain a complete replayable
suffix, including input, expected frames and events. They can be exported from
Hello, loaded by the headless verifier and executed in native/WASM independently
of the original process. This complements the failure-only `Audit_Capture` and
transport-interface trace recorder.

[Loaded recording playback](diagnostic/playback.md) adds a transactional recording
owner and expected-frame cursor. Hello's Open recording control verifies files,
shows mismatch details, and explicitly returns to the original game or starts a
new branch. Native and Chrome import workflows preserve pause and effect ownership.

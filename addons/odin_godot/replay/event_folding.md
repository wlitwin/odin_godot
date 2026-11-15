# Folding feedback within a tick

Use `emit_fold` when several operations in one tick should contribute to the
same feedback event, such as damage feedback for one target. It combines their
payloads with a pure caller-provided reducer under one occurrence identity.
Ordinary `emit` rejects duplicate semantic IDs:

```odin
r.emit_fold(ctx, source, key, damage, proc(a, b: u32) -> (u32, bool) {
    if a > max(u32) - b {return 0, false}
    return a + b, true
})
```

The first contribution fixes the occurrence's position in the tick's event list.
Later contributions preserve its identity and replace its value with the fold
result. A rejected fold aborts the complete candidate tick. This is useful for
per-target feedback accumulated by multiple systems or actions; it does not turn
accidental duplicate ordinary emits into accepted events.

Network action rejection restores both the candidate world and its prior event
storage. Thus an action that folds into an earlier simulation event and then
rejects cannot alter the committed event. The native regression demonstrates the
old failure and verifies both rejected and accepted actions. Core tests cover
revised input, stable identity, fold failure and replay audit.

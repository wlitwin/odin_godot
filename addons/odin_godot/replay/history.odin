package replay

// Contiguous retained frames ending at head, including checkpoints whose
// generating input is unknown. This is an inspection window, not audit_window.
// A bounded metadata scan does not copy State or expose Record storage.
history_window :: proc(t: ^Timeline($S, $I, $E)) -> (first, last: u64, error: Error) {
    if t == nil {
        return 0, 0, .Not_Initialized
    }

    if err := available(t); err != .None {
        return 0, 0, err
    }

    if record_at(t, t.head) == nil {
        return 0, 0, .History_Missing
    }

    first, last = t.head, t.head

    for _ in 1 ..< len(t.records) {
        if first == 0 || record_at(t, first - 1) == nil {
            break
        }

        first -= 1
    }

    return
}

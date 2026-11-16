package replay_view_test

import "core:testing"
import "core:mem"
import "core:reflect"
import r "godot:replay"
import v "godot:replay/view"

Authority_Tail :: struct {
    batches:        [4][]r.Occurrence(Event),
    missing:        u64,
    calls:          int,
    invalid_policy: bool,
}

authority_reader :: proc(user: rawptr, tick: u64) -> ([]r.Occurrence(Event), bool) {
    source := cast(^Authority_Tail)user
    return source.batches[tick % 4], tick != source.missing
}

@(test)
authority_rebase_prepares_once_without_publication_and_reconciles_existing_ids :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    assert(v.journal_init(&j, cfg = {4, 3, 16}) == .None)
    defer v.journal_destroy(&j)
    v.journal_set_policy(&j, policy)
    predicted := [2]r.Occurrence(Event){occ(1, 1, .Speculative), occ(1, 2, .Speculative)}
    assert(v.sync_tick(&j, 1, predicted[:]) == .None)
    out: [16]v.Change(Event)
    assert(v.drain(&j, out[:]) == 2)
    retained := [2]r.Occurrence(Event){occ(1, 1, .Speculative, 9), occ(1, 3, .Watched)}
    tail := Authority_Tail{}
    tail.batches[1] = retained[:]
    j.policy_user = &tail
    j.context_policy = proc(user: rawptr, event: Event) -> v.Policy {
        source := cast(^Authority_Tail)user
        source.calls += 1
        return source.invalid_policy ? v.Policy(255) : event.mode
    }
    source := v.Journal_Authority(Event) {
        through = 1,
        user    = &tail,
        read    = authority_reader,
    }
    plan, error := v.journal_rebase_prepare(&j, 10, &source)
    testing.expect_value(t, error, v.Error.None)
    testing.expect(t, j.baseline == 0 && j.confirmed == 0 && j.queue_count == 0)
    testing.expect_value(t, tail.calls, 1) // only the genuinely new ID is classified
    tail.invalid_policy = true // installing the world may change policy context
    testing.expect_value(t, v.journal_rebase_commit(&plan), v.Error.None)
    testing.expect_value(t, tail.calls, 1)
    testing.expect_value(t, v.drain(&j, out[:]), 4)
    testing.expect(t, out[0].kind == .Cancel && out[0].occurrence.id.key == 2)
    testing.expect(t, out[1].kind == .Update && out[1].previous.amount == 1 && out[1].occurrence.value.amount == 9)
    testing.expect(t, out[2].kind == .Confirm && out[2].occurrence.id.key == 1 && out[2].confirmed)
    testing.expect(t, out[3].kind == .Begin && out[3].occurrence.id.key == 3 && out[3].confirmed)
    testing.expect_value(t, v.journal_rebase_commit(&plan), v.Error.Invalid_Config)
    testing.expect_value(t, v.journal_rebase(&j, 12), v.Error.None)
    testing.expect_value(t, v.drain(&j, out[:]), 0)
}

@(test)
authority_rebase_rejects_unknown_batches_malformed_ids_policy_and_queue_pressure_atomically :: proc(t: ^testing.T) {
    for variant in 0 ..< 6 {
        j: v.Journal(Event)
        assert(v.journal_init(&j, cfg = {4, 2, 4}) == .None)
        defer v.journal_destroy(&j)
        v.journal_set_policy(&j, policy)
        events := [2]r.Occurrence(Event){occ(1, 1, .Watched), occ(1, 2, .Confirmed)}
        tail := Authority_Tail{}
        tail.batches[1] = events[:]
        source := v.Journal_Authority(Event) {
            through = 1,
            user    = &tail,
            read    = authority_reader,
        }
        expected := v.Error.Missing_History

        switch variant {
        case 0:
            tail.missing = 1
        case 1:
            events[0].id.epoch = 2
            expected = .Bad_Epoch
        case 2:
            events[0].id.tick = 2
            expected = .Bad_Tick
        case 3:
            events[1].id = events[0].id
            expected = .Duplicate_Event
        case 4:
            events[0].value.mode = v.Policy(255)
            expected = .Invalid_Policy
        case 5:
            prior := [2]r.Occurrence(Event){occ(1, 3, .Speculative), occ(1, 4, .Speculative)}
            assert(v.sync_tick(&j, 1, prior[:]) == .None)
            j.policy_user = &tail
            j.context_policy = proc(user: rawptr, event: Event) -> v.Policy {
                state := cast(^Authority_Tail)user
                state.calls += 1
                return event.mode
            }
            expected = .Output_Full
        }

        storage := make([]u8, len(j.storage) * size_of(j.storage[0]))
        copy(storage, mem.slice_to_bytes(j.storage))
        defer delete(storage)
        _, error := v.journal_rebase_prepare(&j, 10, &source)
        testing.expect_value(t, error, expected)
        testing.expect(t, j.baseline == 0 && j.confirmed == 0 && j.watch_tick == 0)
        testing.expect_value(t, j.queue_count, variant == 5 ? 2 : 0)
        testing.expect(t, reflect.equal(storage, mem.slice_to_bytes(j.storage), true))

        if variant == 5 {
            testing.expect_value(t, tail.calls, 0)
            out: [8]v.Change(Event)
            assert(v.drain(&j, out[:]) == 2)
            plan, retry := v.journal_rebase_prepare(&j, 10, &source)
            testing.expect_value(t, retry, v.Error.None)
            testing.expect_value(t, v.journal_rebase_commit(&plan), v.Error.None)
            testing.expect_value(t, tail.calls, 2)
            testing.expect_value(t, v.drain(&j, out[:]), 4)
        }
    }
}

@(test)
authority_rebase_confirms_only_its_contiguous_known_tail_without_filling_a_gap :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    assert(v.journal_init(&j, cfg = {4, 1, 8}) == .None)
    defer v.journal_destroy(&j)
    v.journal_set_policy(&j, policy)
    known := [1]r.Occurrence(Event){occ(1, 1, .Watched)}
    tail := Authority_Tail{}
    tail.batches[1] = known[:]
    source := v.Journal_Authority(Event) {
        through = 1,
        user    = &tail,
        read    = authority_reader,
    }
    plan, error := v.journal_rebase_prepare(&j, 100, &source)
    testing.expect_value(t, error, v.Error.None)
    testing.expect_value(t, v.journal_rebase_commit(&plan), v.Error.None)
    out: [8]v.Change(Event)
    testing.expect_value(t, v.drain(&j, out[:]), 1)
    testing.expect_value(t, out[0].occurrence.id.tick, u64(1))
    testing.expect(t, j.baseline == 100 && j.confirmed == 100 && j.watch_tick == 100)
}

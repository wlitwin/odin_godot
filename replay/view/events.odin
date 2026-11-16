package replay_view

import "core:mem"
import "core:reflect"
import r "godot:replay"

Policy :: enum u8 {
    Speculative,
    Confirmed,
    Watched,
}

Change_Kind :: enum u8 {
    Begin,
    Update,
    Cancel,
    Confirm,
}

Change :: struct($Event: typeid) {
    kind:       Change_Kind,
    occurrence: r.Occurrence(Event),
    previous:   Event, // Update carries the previous payload
    confirmed:  bool,
}

Error :: enum {
    None,
    Invalid_Config,
    Unsupported_Value,
    Not_Initialized,
    Already_Initialized,
    Bad_Epoch,
    Bad_Tick,
    Expired,
    Capacity,
    Output_Full,
    Duplicate_Event,
    Confirmed_Changed,
    Missing_History,
    Time_Reversed,
    Invalid_Policy,
}

Journal_Config :: struct {
    history_ticks:   int,
    events_per_tick: int,
    queue_capacity:  int,
}

DEFAULT_JOURNAL_CONFIG :: Journal_Config{128, 32, 8192}

@(private)
Tracked :: struct($Event: typeid) {
    occurrence:   r.Occurrence(Event),
    policy:       Policy,
    begun, final: bool,
}

@(private)
Batch :: struct($Event: typeid) {
    valid: bool,
    tick:  u64,
    items: []Tracked(Event),
    count: int,
}

// Single-owner presentation ledger. All payloads are owned values; dead
// simulation entities are never dereferenced to deliver a delayed occurrence.
Journal :: struct($Event: typeid) {
    allocator:                              mem.Allocator,
    epoch, baseline, confirmed, watch_tick: u64,
    policy:                                 proc(event: Event) -> Policy,
    policy_user:                            rawptr,
    context_policy:                         proc(user: rawptr, event: Event) -> Policy,
    batches:                                []Batch(Event),
    storage, scratch:                       []Tracked(Event),
    changes:                                []Change(Event),
    queue:                                  []Change(Event),
    queue_head, queue_count:                int,
}

// Borrowed complete authority batches immediately after the journal's confirmed
// frontier. The reader and returned values must remain immutable until commit;
// no callback or borrowed slice is retained beyond the transaction.
Journal_Authority :: struct($Event: typeid) {
    through: u64,
    user:    rawptr,
    read:    proc(user: rawptr, tick: u64) -> ([]r.Occurrence(Event), bool),
}

// Borrowed, one-use checkpoint transaction. The journal and authority batches
// must remain unchanged between prepare and commit, as for rebase_check. Policy
// callbacks for newly admitted IDs are evaluated only during preparation.
Journal_Rebase :: struct($Event: typeid) {
    journal:                                                   ^Journal(Event),
    authority:                                                 Journal_Authority(Event),
    baseline, epoch, previous_baseline, confirmed, watch_tick: u64,
    queue_head, queue_count:                                   int,
    ready:                                                     bool,
}

journal_init :: proc(
    j: ^Journal($Event),
    epoch: u64 = 1,
    baseline: u64 = 0,
    cfg := DEFAULT_JOURNAL_CONFIG,
    allocator := context.allocator,
) -> Error {
    if len(j.batches) != 0 {
        return .Already_Initialized
    }

    if epoch == 0 ||
       cfg.history_ticks < 2 ||
       cfg.history_ticks > 4096 ||
       cfg.events_per_tick < 1 ||
       cfg.events_per_tick > 4096 ||
       cfg.queue_capacity < 2 * cfg.events_per_tick ||
       cfg.queue_capacity > 1_048_576 {
        return .Invalid_Config
    }

    if !r.value_supported(Event) {
        return .Unsupported_Value
    }

    j.allocator = allocator
    j.epoch, j.baseline, j.confirmed, j.watch_tick = epoch, baseline, baseline, baseline
    j.batches = make([]Batch(Event), cfg.history_ticks, allocator)
    j.storage = make([]Tracked(Event), cfg.history_ticks * cfg.events_per_tick, allocator)
    j.scratch = make([]Tracked(Event), cfg.events_per_tick, allocator)
    j.changes = make([]Change(Event), 2 * cfg.events_per_tick, allocator)
    j.queue = make([]Change(Event), cfg.queue_capacity, allocator)

    for &batch, i in j.batches {
        batch.items = j.storage[i * cfg.events_per_tick:(i + 1) * cfg.events_per_tick]
    }

    return .None
}

// Applies to newly observed IDs; an existing occurrence keeps its chosen policy.
journal_set_policy :: proc(j: ^Journal($Event), policy: proc(event: Event) -> Policy) {
    j.policy = policy
}

journal_destroy :: proc(j: ^Journal($Event)) {
    delete(j.batches, j.allocator)
    delete(j.storage, j.allocator)
    delete(j.scratch, j.allocator)
    delete(j.changes, j.allocator)
    delete(j.queue, j.allocator)
    j^ = {}
}

// End the old epoch's retained effects and seed a fresh presentation baseline.
// Consumers must have drained prior changes; Cancel for an already-finished
// one-shot is harmless. This also closes confirmed continuous effects whose old
// IDs will never receive later updates in the new epoch.
journal_reset :: proc(j: ^Journal($Event), epoch, baseline: u64) -> Error {
    if len(j.batches) == 0 {
        return .Not_Initialized
    }

    if epoch <= j.epoch {
        return .Bad_Epoch
    }

    if j.queue_count != 0 {
        return .Output_Full
    }

    needed := 0

    for batch in j.batches {
        if batch.valid {
            for item in batch.items[:batch.count] {
                if item.begun {
                    needed += 1
                }
            }
        }
    }

    if needed > len(j.queue) {
        return .Capacity
    }

    for &batch in j.batches {
        if batch.valid {
            for item in batch.items[:batch.count] {
                if item.begun {
                    enqueue(j, Change(Event){kind = .Cancel, occurrence = item.occurrence, confirmed = item.final})
                }
            }
        }

        batch.valid, batch.count = false, 0
    }

    j.epoch, j.baseline, j.confirmed, j.watch_tick = epoch, baseline, baseline, baseline
    return .None
}

// Preflight a same-epoch checkpoint jump. No history is invented for the gap:
// only effects already confirmed by complete authority batches may mature.
// Callers coordinating a timeline reset can check output capacity before either
// owner changes. The journal must stay unchanged between check and commit.
journal_rebase_check :: proc(j: ^Journal($Event), baseline: u64) -> Error {
    authority: Journal_Authority(Event)
    _, error := journal_rebase_prepare(j, baseline, &authority)
    return error
}

// Preparation allocates nothing and publishes nothing. The caller may install
// the matching world only after this succeeds, then commit this same plan.
journal_rebase_prepare :: proc(
    j: ^Journal($Event),
    baseline: u64,
    source: ^Journal_Authority(Event),
) -> (
    Journal_Rebase(Event),
    Error,
) {
    if len(j.batches) == 0 {
        return {}, .Not_Initialized
    }

    if baseline < j.confirmed || baseline < j.watch_tick {
        return {}, .Time_Reversed
    }

    authority: Journal_Authority(Event)

    if source != nil {
        authority = source^
    }

    if authority.through != 0 &&
       (authority.read == nil ||
               authority.through < j.confirmed ||
               authority.through > baseline ||
               authority.through - j.confirmed > u64(len(j.batches))) {
        return {}, .Invalid_Config
    }

    needed, error := journal_rebase_walk(j, baseline, authority, false, false)

    if error != .None {
        return {}, error
    }

    if needed > len(j.queue) {
        return {}, .Capacity
    }

    if needed > len(j.queue) - j.queue_count {
        return {}, .Output_Full
    }

    // Output pressure must not consume a stateful classification callback.
    // Every valid policy has the same final result here, so count first and
    // classify new IDs only once the complete transaction fits.
    if authority.through > j.confirmed {
        if _, error := journal_rebase_walk(j, baseline, authority, false, true); error != .None {
            return {}, error
        }
    }

    return {
            journal = j,
            authority = authority,
            baseline = baseline,
            epoch = j.epoch,
            previous_baseline = j.baseline,
            confirmed = j.confirmed,
            watch_tick = j.watch_tick,
            queue_head = j.queue_head,
            queue_count = j.queue_count,
            ready = true,
        },
        .None
}

// Install a later checkpoint in this epoch without discarding output already
// owed to the consumer. Confirmed watched effects now have a visible cause at
// or before the new baseline; speculative effects are explicitly cancelled.
// Already-final effects do not restart. All retained tracking is then retired;
// subsequent batches must be newer than the checkpoint. On error nothing changes.
journal_rebase :: proc(j: ^Journal($Event), baseline: u64) -> Error {
    authority: Journal_Authority(Event)
    plan, error := journal_rebase_prepare(j, baseline, &authority)

    if error != .None {
        return error
    }

    return journal_rebase_commit(&plan)
}

journal_rebase_commit :: proc(plan: ^Journal_Rebase($Event)) -> Error {
    if plan == nil || !plan.ready || plan.journal == nil {
        return .Invalid_Config
    }

    j := plan.journal

    // Sanity checks supplement the immutable-journal caller precondition; these
    // are not a fingerprint of every retained item or policy context.
    if j.epoch != plan.epoch ||
       j.baseline != plan.previous_baseline ||
       j.confirmed != plan.confirmed ||
       j.watch_tick != plan.watch_tick ||
       j.queue_head != plan.queue_head ||
       j.queue_count != plan.queue_count {
        return .Invalid_Config
    }

    if _, error := journal_rebase_walk(j, plan.baseline, plan.authority, true, false); error != .None {
        return error
    }

    for &batch in j.batches {
        batch.valid, batch.count = false, 0
    }

    j.baseline, j.confirmed, j.watch_tick = plan.baseline, plan.baseline, plan.baseline
    plan.ready = false
    return .None
}

@(private)
journal_rebase_walk :: proc(
    j: ^Journal($Event),
    baseline: u64,
    authority: Journal_Authority(Event),
    commit, classify: bool,
) -> (
    needed: int,
    error: Error,
) {

    // A sparse future batch may coexist with the oldest confirmed batch.
    // Cover both bounded windows, not just one ring starting at the oldest tick.
    history := u64(len(j.batches))
    first := j.confirmed >= history ? j.confirmed - history + 1 : 1

    for offset in 0 ..< 2 * len(j.batches) {
        if u64(offset) > max(u64) - first {
            break
        }

        tick := first + u64(offset)
        batch := &j.batches[tick % u64(len(j.batches))]

        if authority.through != 0 && tick > j.confirmed && tick <= authority.through {
            events, found := authority.read(authority.user, tick)

            if !found {
                return needed, .Missing_History
            }

            old: []Tracked(Event)

            if batch.valid && batch.tick == tick {
                old = batch.items[:batch.count]
            }

            count, err := journal_rebase_authority_tick(j, tick, events, old, baseline, classify)

            if err != .None {
                return needed, err
            }

            needed += count

            if commit {
                for change in j.changes[:count] {
                    enqueue(j, change)
                }
            }

            continue
        }

        if !batch.valid || batch.tick != tick {
            continue
        }

        for item in batch.items[:batch.count] {
            if tick <= j.confirmed {
                _, change, produced := mature(item, j.confirmed, baseline)

                if produced {
                    needed += 1

                    if commit {
                        enqueue(j, change)
                    }
                }
            } else if item.begun {
                needed += 1

                if commit {
                    enqueue(j, Change(Event){kind = .Cancel, occurrence = item.occurrence})
                }
            }
        }
    }

    return needed, .None
}

// Plan one authoritative replacement without publishing or changing tracking.
// A checkpoint makes these known effects final in one transaction; speculative
// IDs keep their original policy and reconcile before their final confirmation.
@(private)
journal_rebase_authority_tick :: proc(
    j: ^Journal($Event),
    tick: u64,
    events: []r.Occurrence(Event),
    old: []Tracked(Event),
    baseline: u64,
    classify: bool,
) -> (
    count: int,
    error: Error,
) {
    if len(events) > len(j.scratch) {
        return 0, .Capacity
    }

    for event, i in events {
        if event.id.epoch != j.epoch {
            return 0, .Bad_Epoch
        }

        if event.id.tick != tick {
            return 0, .Bad_Tick
        }

        for prior in events[:i] {
            if prior.id == event.id {
                return 0, .Duplicate_Event
            }
        }
    }

    for entry in old {
        found := false

        for event in events {
            if entry.occurrence.id == event.id {
                found = true
                break
            }
        }

        if !found && entry.begun {
            j.changes[count] = {
                kind       = .Cancel,
                occurrence = entry.occurrence,
            }
            count += 1
        }
    }

    for event in events {
        entry := Tracked(Event) {
            occurrence = event,
        }

        if index := find(old, event.id); index >= 0 {
            entry = old[index]

            if entry.begun && !reflect.equal(entry.occurrence.value, event.value) {
                j.changes[count] = {
                    kind       = .Update,
                    occurrence = event,
                    previous   = entry.occurrence.value,
                }
                count += 1
            }

            entry.occurrence = event
        } else {
            // Every valid policy yields the same final Begin for a new ID at
            // or before the accepted checkpoint. Validate once; never re-enter
            // application policy code after its world has changed.
            entry.policy = .Confirmed

            if classify {
                if j.context_policy != nil {
                    entry.policy = j.context_policy(j.policy_user, event.value)
                } else if j.policy != nil {
                    entry.policy = j.policy(event.value)
                }

                if entry.policy > .Watched {
                    return 0, .Invalid_Policy
                }
            }
        }

        if _, change, produced := mature(entry, tick, baseline); produced {
            j.changes[count] = change
            count += 1
        }
    }

    return count, .None
}

// Replace one COMPLETE tick batch, including an empty tick. Transactional with
// respect to both tracking and output: on error, drain/recover and retry.
sync_tick :: proc(j: ^Journal($Event), tick: u64, events: []r.Occurrence(Event)) -> Error {
    if len(j.batches) == 0 {
        return .Not_Initialized
    }

    if tick <= j.baseline {
        return .Expired
    }

    if tick > j.confirmed && tick - j.confirmed > u64(len(j.batches)) {
        return .Capacity
    }

    if len(events) > len(j.scratch) {
        return .Capacity
    }

    for e, i in events {
        if e.id.epoch != j.epoch {
            return .Bad_Epoch
        }

        if e.id.tick != tick {
            return .Bad_Tick
        }

        for other in events[:i] {
            if other.id == e.id {
                return .Duplicate_Event
            }
        }
    }

    batch := &j.batches[tick % u64(len(j.batches))]
    old: []Tracked(Event)

    if batch.valid {
        if batch.tick > tick {
            return .Expired
        }

        if batch.tick == tick {
            old = batch.items[:batch.count]
        } else {
            if tick <= j.confirmed {
                return .Expired
            }

            if batch.tick > j.confirmed {
                return .Capacity
            }

            for entry in batch.items[:batch.count] {
                if !entry.begun || !entry.final {
                    return .Capacity
                }
            }
        }
    } else if tick <= j.confirmed {
        return .Expired
    }

    // Confirmation is a promise: already settled history cannot be rewritten.
    if tick <= j.confirmed {
        if len(old) != len(events) {
            return .Confirmed_Changed
        }

        for e in events {
            index := find(old, e.id)

            if index < 0 || !reflect.equal(old[index].occurrence.value, e.value) {
                return .Confirmed_Changed
            }
        }

        return .None
    }

    count := 0

    for entry in old {
        found := false

        for e in events {
            if entry.occurrence.id == e.id {
                found = true
                break
            }
        }

        if !found && entry.begun {
            j.changes[count] = {
                kind       = .Cancel,
                occurrence = entry.occurrence,
            }
            count += 1
        }
    }

    for e, i in events {
        entry := Tracked(Event) {
            occurrence = e,
            policy     = .Speculative,
        }

        if index := find(old, e.id); index >= 0 {
            entry = old[index]

            if !reflect.equal(entry.occurrence.value, e.value) && entry.begun {
                j.changes[count] = {
                    kind       = .Update,
                    occurrence = e,
                    previous   = entry.occurrence.value,
                }
                count += 1
            }

            entry.occurrence = e
        } else {
            if j.context_policy != nil {
                entry.policy = j.context_policy(j.policy_user, e.value)
            } else if j.policy != nil {
                entry.policy = j.policy(e.value)
            }

            if entry.policy > .Watched {
                return .Invalid_Policy
            }

            if entry.policy == .Speculative {
                entry.begun = true
                j.changes[count] = {
                    kind       = .Begin,
                    occurrence = e,
                }
                count += 1
            }
        }

        j.scratch[i] = entry
    }

    if count > len(j.queue) - j.queue_count {
        return .Output_Full
    }

    batch.valid, batch.tick, batch.count = true, tick, len(events)
    copy(batch.items, j.scratch[:len(events)])

    for change in j.changes[:count] {
        enqueue(j, change)
    }

    return .None
}

// Confirm only after complete batches have been synchronized through that tick.
// A watched effect additionally waits for the visible cause's presentation tick.
// Time cannot move backwards in an epoch: replaying a committed world is a new
// playback epoch with a fresh journal and explicit view teardown.
advance_time :: proc(j: ^Journal($Event), confirmed, watch_tick: u64) -> Error {
    if len(j.batches) == 0 {
        return .Not_Initialized
    }

    if confirmed < j.confirmed || watch_tick < j.watch_tick {
        return .Time_Reversed
    }

    if confirmed - j.confirmed > u64(len(j.batches)) {
        return .Missing_History
    }

    for offset in u64(0) ..< confirmed - j.confirmed {
        tick := j.confirmed + offset + 1
        batch := &j.batches[tick % u64(len(j.batches))]

        if !batch.valid || batch.tick != tick {
            return .Missing_History
        }
    }

    needed := 0

    for batch in j.batches {
        if !batch.valid {
            continue
        }

        for item in batch.items[:batch.count] {
            _, _, produced := mature(item, confirmed, watch_tick)

            if produced {
                needed += 1
            }
        }
    }

    if needed > len(j.queue) - j.queue_count {
        return .Output_Full
    }

    // Ascending tick order also works when the ring wrapped.
    oldest := max(u64)
    have_batch := false

    for batch in j.batches {
        if batch.valid {
            oldest = min(oldest, batch.tick)
            have_batch = true
        }
    }

    if have_batch {
        for offset in 0 ..< len(j.batches) {
            if u64(offset) > max(u64) - oldest {
                break
            }

            tick := oldest + u64(offset)
            batch := &j.batches[tick % u64(len(j.batches))]

            if !batch.valid || batch.tick != tick {
                continue
            }

            for &item in batch.items[:batch.count] {
                next, change, produced := mature(item, confirmed, watch_tick)
                item = next

                if produced {
                    enqueue(j, change)
                }
            }
        }
    }

    j.confirmed, j.watch_tick = confirmed, watch_tick
    return .None
}

drain :: proc(j: ^Journal($Event), dst: []Change(Event)) -> int {
    n := min(len(dst), j.queue_count)

    for i in 0 ..< n {
        dst[i] = j.queue[j.queue_head]
        j.queue_head = (j.queue_head + 1) % len(j.queue)
    }

    j.queue_count -= n
    return n
}

@(private)
find :: proc(items: []Tracked($Event), id: r.Event_Id) -> int {
    for item, i in items {
        if item.occurrence.id == id {
            return i
        }
    }

    return -1
}

@(private)
enqueue :: proc(j: ^Journal($Event), change: Change(Event)) {
    j.queue[(j.queue_head + j.queue_count) % len(j.queue)] = change
    j.queue_count += 1
}

@(private)
mature :: proc(
    item: Tracked($Event),
    confirmed, watch_tick: u64,
) -> (
    next: Tracked(Event),
    change: Change(Event),
    produced: bool,
) {
    next = item

    if item.occurrence.id.tick > confirmed || item.final {
        return
    }

    if !item.begun {
        if item.policy == .Watched && item.occurrence.id.tick > watch_tick {
            return
        }

        next.begun, next.final = true, true
        return next, {kind = .Begin, occurrence = item.occurrence, confirmed = true}, true
    }

    next.final = true
    return next, {kind = .Confirm, occurrence = item.occurrence, confirmed = true}, true
}

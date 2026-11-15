package replay_authority

import net "godot:replay/net"

Clock_Source :: struct {
    user: rawptr,
    read: proc(user: rawptr) -> (milliseconds: u64, valid: bool),
}

Lease :: struct {
    ready, poisoned, pending, require_owner:                                  bool,
    identity:                                                                 Identity,
    room, content:                                                            u64,
    clock:                                                                    Clock_Source,
    drift_ppm:                                                                u32,
    now, sequence, sent_at, retired_through, highest_epoch, highest_revision: u64,
    deadline:                                                                 u64,
    view:                                                                     View,
}

lease_init :: proc(
    l: ^Lease,
    identity: Identity,
    room, content: u64,
    clock: Clock_Source,
    require_owner: bool,
    drift_ppm: u32 = 1000,
) -> Error {
    if l.ready || !identity_valid(identity) || room == 0 || content == 0 || clock.read == nil || drift_ppm > 10000 {
        return .Invalid
    }

    now, ok := clock.read(clock.user)

    if !ok {
        return .Clock
    }

    l^ = {
        ready         = true,
        identity      = identity,
        room          = room,
        content       = content,
        clock         = clock,
        require_owner = require_owner,
        drift_ppm     = drift_ppm,
        now           = now,
    }
    return .None
}

// One correlated request may be outstanding. Retransmission reuses the original
// sequence/sent_at; starting a retry must not move its lease reference forward.
lease_request :: proc(l: ^Lease) -> (u64, Error) {
    if err := lease_time(l); err != .None {
        return 0, err
    }

    if l.pending {
        return l.sequence, .Busy
    }

    if l.sequence == max(u64) {
        return 0, .Capacity
    }

    l.sequence += 1
    l.sent_at, l.pending = l.now, true
    return l.sequence, .None
}

lease_cancel_request :: proc(l: ^Lease) {
    l.pending = false
}

// The caller authenticates the coordinator and response correlation. Neither
// room numbers nor envelope checksums are signatures. A delayed reply derives
// its deadline from the local request start, never its later arrival time.
lease_accept :: proc(l: ^Lease, request: u64, view: View) -> Error {
    if err := lease_time(l); err != .None {
        return err
    }

    if !l.pending || request != l.sequence {
        return .Stale
    }

    if view.room != l.room ||
       view.content != l.content ||
       !policy_valid(view.policy) ||
       view.remaining_ms > view.policy.lease_ms ||
       view.revision == 0 ||
       view.coordinator_generation == 0 ||
       view.recovery > .Coordinator_Restart ||
       (view.remaining_ms != 0 && (!identity_valid(view.owner) || !endpoint_valid(view.endpoint) || view.epoch == 0)) {
        return .Invalid
    }

    if view.epoch < l.highest_epoch || view.revision < l.highest_revision {
        return .Stale
    }

    if view.recovery != .None &&
       (!point_valid(view.recovered) ||
               view.recovered.scope.epoch >= view.epoch ||
               view.recovered.scope.room != l.room ||
               view.recovered.scope.content != l.content) {
        return .Invalid
    }

    drift := u64(max(l.drift_ppm, view.policy.drift_ppm))
    usable := u64(view.remaining_ms) * (1000000 - drift) / (1000000 + drift)
    usable = usable > u64(view.policy.margin_ms) ? usable - u64(view.policy.margin_ms) : 0

    if usable > max(u64) - l.sent_at {
        l.poisoned, l.deadline = true, 0
        return .Clock
    }

    l.deadline = l.sent_at + usable
    l.view, l.highest_epoch, l.highest_revision, l.pending = view, view.epoch, view.revision, false

    // A retired owner still needs authenticated control replies (for example to
    // learn that the final checkpoint is prepared). They never revive its permit.
    if l.deadline <= l.now || view.epoch <= l.retired_through {
        l.deadline = 0
    }

    return .None
}

lease_live :: proc(l: ^Lease, epoch: u64) -> bool {
    if lease_time(l) != .None {
        return false
    }

    return(
        epoch != 0 &&
        l.view.epoch == epoch &&
        epoch > l.retired_through &&
        l.now < l.deadline &&
        (!l.require_owner || l.view.owner == l.identity) \
    )
}

lease_retire :: proc(l: ^Lease) -> (Retirement, Error) {
    if lease_time(l) != .None {
        return {}, .Clock
    }

    if l.view.owner != l.identity || l.view.epoch == 0 {
        return {}, .Denied
    }

    l.retired_through = max(l.retired_through, l.view.epoch)
    l.deadline, l.pending = 0, false
    return {l.identity, l.room, l.view.epoch, l.view.revision}, .None
}

lease_permit :: proc(l: ^Lease) -> net.Permit {
    return {user = l, allow = lease_allow}
}

@(private)
lease_allow :: proc(user: rawptr, epoch: u64) -> bool {
    return lease_live(cast(^Lease)user, epoch)
}

@(private)
lease_time :: proc(l: ^Lease) -> Error {
    if !l.ready {
        return .Not_Ready
    }

    if l.poisoned {
        return .Clock
    }

    now, ok := l.clock.read(l.clock.user)

    if !ok || now < l.now {
        l.poisoned, l.deadline = true, 0
        return .Clock
    }

    l.now = now
    return .None
}

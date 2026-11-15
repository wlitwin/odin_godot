package replay_owned

// Local producer cursor, kept outside world state. Only authority-observed
// scopes can enable publication. A preparing solver is still speculative.
Role :: enum u8 {
    Observer,
    Owner,
    Preparing,
}

Driver :: struct {
    scope:                                                 Scope,
    role:                                                  Role,
    sequence, produced, epoch, observed_at, discontinuity: u64,
}

Drive :: struct($T: typeid) {
    error:       Error,
    role:        Role,
    reseed, cut: bool,
    baseline:    T,
}

drive :: proc(d: ^Driver, s: State($T), local_owner: u16, epoch, observed_at: u64, live: bool) -> Drive(T) {
    if epoch == 0 || epoch < d.epoch {
        return {error = .Invalid_Epoch}
    }

    if (epoch == d.epoch && observed_at < d.observed_at) || observed_at < s.changed_at {
        return {error = .Invalid_Time}
    }

    if s.key.kind == 0 || s.key.generation == 0 || s.revision == 0 {
        return {error = .Not_Ready}
    }

    role := Role.Observer
    selected := scope(s)
    baseline := s.value

    if live && s.epoch == epoch && local_owner != 0 {
        if s.owner == local_owner {
            role = .Owner
        } else if s.pending.owner == local_owner && s.pending.revision != 0 && observed_at < s.pending.expires {
            role, selected, baseline = .Preparing, offer_scope(s), s.pending.baseline
        }
    }

    changed := d.scope != selected || d.epoch != epoch
    cut := d.discontinuity != s.discontinuity || d.scope.key != selected.key || d.epoch != epoch
    reseed := changed || (d.role == .Observer && role != .Observer)

    if changed {
        d.sequence, d.produced = 0, 0

        if role == .Owner {
            d.sequence, d.produced = s.sequence, s.produced
        }
    } else if role == .Owner {
        d.sequence, d.produced = max(d.sequence, s.sequence), max(d.produced, s.produced)
    }

    d.scope, d.role, d.epoch, d.observed_at = selected, role, epoch, observed_at
    d.discontinuity = s.discontinuity
    return {role = role, reseed = reseed, cut = cut, baseline = baseline}
}

// produced_steps belongs to the producer's own tick lineage, not authority time.
// Rebase from accepted frontiers on fresh ownership/restart; do not use a raw
// process clock that restarts at zero as a persistent sample sequence.
capture :: proc(d: ^Driver, value: $T, produced_steps: u64 = 1) -> (Sample(T), Error) {
    if d.role == .Observer || d.scope.epoch != d.epoch || d.scope.revision == 0 {
        return {}, .Invalid_Owner
    }

    if d.sequence == max(u64) || produced_steps > max(u64) - d.produced {
        return {}, .Exhausted
    }

    d.sequence += 1
    d.produced += produced_steps
    return {d.scope, d.sequence, d.produced, value}, .None
}

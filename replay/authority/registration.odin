package replay_authority

import "core:crypto"
import tr "godot:replay/transport"

@(private)
Registration_Challenge :: struct {
    valid:                                                   bool,
    nonce:                                                   Nonce,
    value:                                                   [32]u8,
    base_incarnation, next_incarnation, generation, expires: u64,
    endpoint:                                                Endpoint,
}

// The member's long-lived control key authenticates registration. Hosting rights
// and game token binding are preserved; the peer cannot grant itself permissions.
// The service allocates a strictly newer incarnation and requires a fresh proof
// before the durable replacement. Replaying Challenge alone changes no identity.
@(private)
service_register :: proc(
    s: ^Service,
    index: int,
    from: tr.Peer_Id,
    packet: Request,
    digest: [32]u8,
    now: u64,
) -> (
    Error,
    [32]u8,
    Identity,
) {
    member := s.coordinator.record.members[index]
    frontier := s.coordinator.record.requests[index]

    if packet.command.verb == .Rebind &&
       packet.command.incarnation == member.identity.incarnation &&
       frontier.sequence == packet.sequence &&
       frontier.hash == digest &&
       frontier.nonce == packet.nonce {
        s.stats.duplicates += 1
        return frontier.result, {}, member.identity
    }

    // A new process never inherits the old lease. A recovery-enabled service may
    // replace an expired owner after quarantine; a separate guarded publication
    // decision must then grant a newer epoch before that process can host.
    if s.coordinator.record.epoch != 0 && s.coordinator.record.owner.member == member.identity.member {
        if !s.allow_expired_owner_rebind ||
           now < s.coordinator.quarantine_until ||
           (s.coordinator.active && now < s.coordinator.expires) {
            return .Busy, {}, {}
        }
    }

    if nonzero(frontier.nonce[:]) &&
       frontier.nonce != packet.nonce &&
       s.active_peer[index] != 0 &&
       tr.peer_connected(&s.wire, s.active_peer[index]) &&
       now - s.active_at[index] < u64(s.coordinator.record.policy.lease_ms) + 100 {
        return .Busy, {}, {}
    }

    endpoint := packet.command.endpoint

    if endpoint == (Endpoint{}) {
        endpoint = member.endpoint
    }

    if !endpoint_valid(endpoint) {
        return .Invalid, {}, {}
    }

    challenge := &s.challenges[index]

    if packet.command.verb == .Challenge {
        if member.identity.incarnation == max(u64) || now > max(u64) - 5000 {
            return .Capacity, {}, {}
        }

        if !challenge.valid ||
           challenge.expires <= now ||
           challenge.nonce != packet.nonce ||
           challenge.base_incarnation != member.identity.incarnation ||
           challenge.endpoint != endpoint ||
           challenge.generation != s.coordinator.record.coordinator_generation {
            value: [32]u8

            when crypto.HAS_RAND_BYTES {
                crypto.rand_bytes(value[:])
            } else {
                return .Invalid, {}, {}
            }

            challenge^ = {
                true,
                packet.nonce,
                value,
                member.identity.incarnation,
                member.identity.incarnation + 1,
                s.coordinator.record.coordinator_generation,
                now + 5000,
                endpoint,
            }
        }

        return .None, challenge.value, {member.identity.member, challenge.next_incarnation}
    }

    if !challenge.valid ||
       challenge.expires <= now ||
       challenge.nonce != packet.nonce ||
       challenge.base_incarnation != member.identity.incarnation ||
       challenge.next_incarnation != packet.command.incarnation ||
       challenge.generation != s.coordinator.record.coordinator_generation ||
       challenge.endpoint != endpoint ||
       challenge.value != packet.command.challenge {
        return .Stale, {}, {}
    }

    candidate := s.coordinator
    candidate.commit, candidate.user = service_stage, nil
    member.identity.incarnation, member.endpoint = challenge.next_incarnation, endpoint

    if err := coordinator_member(&candidate, member, now); err != .None {
        return err, {}, {}
    }

    if candidate.record.epoch == 0 && candidate.record.bootstrap.member == member.identity.member {
        candidate.record.bootstrap = member.identity
    }

    candidate.record.requests[index] = {packet.sequence, digest, .None, packet.nonce}

    if !record_valid(candidate.record) ||
       !s.coordinator.commit(s.coordinator.user, s.coordinator.record.revision, candidate.record) {
        s.coordinator.poisoned, s.coordinator.active = true, false
        return .Storage, {}, {}
    }

    candidate.commit, candidate.user = s.coordinator.commit, s.coordinator.user
    s.coordinator = candidate
    challenge.valid = false
    s.stats.commits += 1
    return .None, {}, member.identity
}

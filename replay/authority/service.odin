package replay_authority

import "core:crypto"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Service :: struct {
    ready:                      bool,
    coordinator:                Coordinator,
    clock:                      Clock_Source,
    wire:                       tr.Transport,
    credentials:                [MAX_MEMBERS]Credential,
    disabled_credentials:       [MAX_MEMBERS]Credential, // optional retained keys for denial-only replies
    codecs:                     Rpc_Codecs,
    stats:                      Rpc_Stats,
    // Authenticated members have separate request token buckets. Ingress itself
    // is bounded to 32 packets/update; a bad MAC never reaches the durable store.
    budget:                     [MAX_MEMBERS]f64,
    budget_at:                  [MAX_MEMBERS]u64,
    active_peer:                [MAX_MEMBERS]tr.Peer_Id,
    active_generation:          [MAX_MEMBERS]u64,
    active_at:                  [MAX_MEMBERS]u64,
    challenges:                 [MAX_MEMBERS]Registration_Challenge,
    allow_expired_owner_rebind: bool, // trusted recovery-service opt-in; never grants a lease
    rxb:                        [tr.MAX_PACKET_BYTES]u8,
    txb:                        [RPC_BYTES]u8,
}

service_init :: proc(
    s: ^Service,
    record: Record,
    commit: Commit,
    user: rawptr,
    clock: Clock_Source,
    wire: tr.Transport,
    credentials: []Credential,
    allocator := context.allocator,
) -> Error {
    if s.ready || clock.read == nil || len(credentials) == 0 || len(credentials) > MAX_MEMBERS {
        return .Invalid
    }

    for credential, i in credentials {
        k := credential.key

        if !identity_valid(credential.identity) || !nonzero(k[:]) {
            return .Invalid
        }

        found := false

        for member in record.members {
            if member.identity.member == credential.identity.member && member.enabled {
                found = true
            }
        }

        if !found {
            return .Denied
        }

        for previous in credentials[:i] {
            if previous.identity.member == credential.identity.member || previous.key == credential.key {
                return .Invalid
            }
        }
    }

    if !rpc_codecs_init(&s.codecs, allocator) {
        return .Invalid
    }

    now, ok := clock.read(clock.user)

    if !ok {
        service_destroy(s)
        return .Clock
    }

    if err := coordinator_init(&s.coordinator, record, commit, user, now); err != .None {
        service_destroy(s)
        return err
    }

    s.clock, s.wire = clock, wire
    copy(s.credentials[:], credentials)

    for &budget in s.budget {
        budget = 32
    }

    for &at in s.budget_at {
        at = now
    }

    s.ready = true
    return .None
}

service_destroy :: proc(s: ^Service) {
    rpc_codecs_destroy(&s.codecs)
    crypto.zero_explicit(&s.credentials, size_of(s.credentials))
    crypto.zero_explicit(&s.disabled_credentials, size_of(s.disabled_credentials))
    s^ = {}
}

service_receive :: proc(s: ^Service, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !s.ready {
        return false
    }

    s.stats.rx_packets += 1

    if from == 0 || len(bytes) != sc.HEADER_BYTES + s.codecs.request.wire_size + 32 {
        s.stats.rejected += 1
        return false
    }

    envelope, _, inspection := sc.inspect(bytes[:len(bytes) - 32])

    if inspection.error != .None || (envelope.kind != RPC_REQUEST && envelope.kind != RPC_REMOVE_REQUEST) {
        s.stats.rejected += 1
        return false
    }

    removal := envelope.kind == RPC_REMOVE_REQUEST
    packet: Request
    meta, report := sc.unpack(
        &s.codecs.request,
        &packet,
        bytes[:len(bytes) - 32],
        {kind = envelope.kind, epoch = u64(RPC_VERSION), content = s.coordinator.record.content},
    )

    if report.error != .None ||
       packet.version != RPC_VERSION ||
       packet.room != s.coordinator.record.room ||
       packet.sequence == 0 ||
       packet.sequence != meta.tick ||
       !nonzero(packet.nonce[:]) {
        s.stats.rejected += 1
        return false
    }

    key: Key
    authenticated := false

    for credential in s.credentials {
        if credential.identity.member == packet.identity.member {
            key, authenticated = credential.key, true
            break
        }
    }

    if !authenticated {
        for credential in s.disabled_credentials {
            if credential.identity.member == packet.identity.member {
                key, authenticated = credential.key, true
                break
            }
        }
    }

    if !authenticated || !rpc_authenticated(key, envelope.kind, bytes) {
        s.stats.rejected += 1
        return false
    }

    index := -1

    for member, i in s.coordinator.record.members {
        if member.identity.member == packet.identity.member {
            index = i
            break
        }
    }

    if index < 0 {
        s.stats.rejected += 1
        return false
    }

    now, ok := s.clock.read(s.clock.user)

    if !ok || now < s.budget_at[index] {
        s.coordinator.poisoned, s.coordinator.active = true, false
        return false
    }

    s.budget[index] = min(s.budget[index] + f64(now - s.budget_at[index]) * 16 / 1000, 32)
    s.budget_at[index] = now

    if s.budget[index] < 1 {
        s.stats.rejected += 1
        return false
    }

    s.budget[index] -= 1

    if !s.coordinator.record.members[index].enabled {
        return service_disabled_reply(s, from, packet, key, envelope.kind, rec.hash(bytes[:len(bytes) - 32]))
    }

    digest := rec.hash(bytes[:len(bytes) - 32])
    frontier := s.coordinator.record.requests[index]
    result := Error.None
    replayed := false
    registration := !removal && (packet.command.verb == .Challenge || packet.command.verb == .Rebind)
    registered :=
        packet.identity == s.coordinator.record.members[index].identity &&
        (!nonzero(frontier.nonce[:]) || frontier.nonce == packet.nonce)
    challenge: [32]u8
    next_identity: Identity

    if s.coordinator.poisoned {
        result = .Storage
    } else if registration {
        result, challenge, next_identity = service_register(s, index, from, packet, digest, now)
        registered = result == .None && packet.command.verb == .Rebind
    } else if !registered {
        result = .Denied
        s.stats.rejected += 1
    } else if packet.sequence < frontier.sequence ||
       (packet.sequence == frontier.sequence && digest != frontier.hash) {
        result = .Stale
        s.stats.rejected += 1
    } else if packet.sequence == frontier.sequence {
        result, replayed = frontier.result, true
        s.stats.duplicates += 1
    } else {
        // Run the decision privately with a staging commit. Only one real CAS
        // publishes the decision AND request outcome/frontier, including Query
        // and rejected commands, so delayed mutations cannot follow a newer read.
        candidate := s.coordinator
        candidate.commit, candidate.user = service_stage, nil

        if removal {
            if !remove_command_valid(packet.command) {
                result = .Invalid
            } else {
                result = coordinator_remove(
                    &candidate,
                    packet.identity,
                    packet.command.epoch,
                    packet.command.successor,
                    now,
                )
            }
        } else {
            result = service_command(&candidate, packet, now)
        }

        if result == .Clock || candidate.record.revision == max(u64) || s.coordinator.record.revision == max(u64) {
            s.coordinator.poisoned, s.coordinator.active = true, false
            result = .Storage
        } else {
            candidate.record.revision = s.coordinator.record.revision + 1
            candidate.record.requests[index] = {packet.sequence, digest, result, packet.nonce}

            if !record_valid(candidate.record) ||
               !s.coordinator.commit(s.coordinator.user, s.coordinator.record.revision, candidate.record) {
                s.coordinator.poisoned, s.coordinator.active = true, false
                result = .Storage
            } else {
                candidate.commit, candidate.user = s.coordinator.commit, s.coordinator.user
                s.coordinator = candidate
                s.stats.commits += 1
            }
        }
    }

    if registered && result != .Storage {
        s.active_peer[index], s.active_at[index] = from, now
        s.active_generation[index] = tr.peer_generation(&s.wire, from)
    }

    view, err := coordinator_view(&s.coordinator, now)

    if err != .None {
        r := s.coordinator.record
        view = {
            room                   = r.room,
            content                = r.content,
            revision               = r.revision,
            epoch                  = r.epoch,
            coordinator_generation = r.coordinator_generation,
            owner                  = r.owner,
            endpoint               = r.authority_endpoint,
            policy                 = r.policy,
            recovery               = r.recovery,
            recovered              = r.recovered,
            last_known_tick        = r.last_tick,
        }
        result = .Storage
    }

    r := s.coordinator.record

    if !registered {
        view.remaining_ms = 0
    }

    reply := Reply {
        version               = RPC_VERSION,
        identity              = packet.identity,
        nonce                 = packet.nonce,
        sequence              = packet.sequence,
        request_hash          = digest,
        result                = result,
        replayed              = replayed,
        view                  = view,
        nominee               = r.nominee,
        binding               = r.source_binding,
        prepared              = r.prepared,
        released              = r.released,
        point                 = r.point,
        sequence_floor        = registered ? r.requests[index].sequence : 0,
        challenge             = challenge,
        registration_identity = next_identity,
        members               = r.members,
    }
    reply_kind := removal ? RPC_REMOVE_REPLY : RPC_REPLY
    count := rpc_pack(&s.codecs.reply, reply, key, reply_kind, r.content, packet.sequence, s.txb[:])

    if count != 0 && tr.send(&s.wire, from, .Reliable, s.txb[:count]) == .Sent {
        s.stats.tx_packets += 1
    } else {
        s.stats.deferred += 1
    }

    return true
}

service_pump :: proc(s: ^Service) -> Error {
    if !s.ready {
        return .Not_Ready
    }

    tr.poll(&s.wire)

    for _ in 0 ..< 32 {
        packet := tr.receive(&s.wire, s.rxb[:])

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            s.stats.rejected += 1
            continue
        }

        service_receive(s, packet.from, s.rxb[:packet.count])
    }

    return s.coordinator.poisoned ? .Storage : .None
}

@(private)
service_stage :: proc(user: rawptr, expected: u64, next: Record) -> bool {
    return next.revision == expected + 1
}

@(private)
service_command :: proc(c: ^Coordinator, r: Request, now: u64) -> Error {
    v := r.command

    switch v.verb {
    case .Query:
        _, err := coordinator_view(c, now)
        return err
    case .Start:
        return coordinator_start(c, r.identity, r.sequence, now)
    case .Renew:
        return coordinator_renew(c, r.identity, v.epoch, r.sequence, v.tick, now)
    case .Nominate:
        return coordinator_nominate(c, r.identity, v.epoch, v.successor, v.binding, now)
    case .Prepare:
        return coordinator_prepare(c, r.identity, v.point, now)
    case .Release:
        return coordinator_release(c, r.identity, v.retired, v.point, now)
    case .Claim:
        return coordinator_claim(c, r.identity, v.epoch, r.sequence, v.point, now)
    case .Recover_Owner:
        return coordinator_recover_owner(c, r.identity, v.epoch, r.sequence, v.point, now)
    case .Challenge, .Rebind:
        return .Invalid
    }

    return .Invalid
}

// A retained revoked key can authenticate only this minimal denial. No roster,
// endpoint, checkpoint or remaining lease is disclosed, and no frontier changes.
@(private)
service_disabled_reply :: proc(
    s: ^Service,
    from: tr.Peer_Id,
    q: Request,
    key: Key,
    kind: u16,
    digest: [32]u8,
) -> bool {
    r := s.coordinator.record
    members: [MAX_MEMBERS]Member
    members[0] = {
        identity = q.identity,
        enabled  = false,
    }
    reply := Reply {
        version = RPC_VERSION,
        identity = q.identity,
        nonce = q.nonce,
        sequence = q.sequence,
        request_hash = digest,
        result = .Denied,
        view = {
            room = r.room,
            content = r.content,
            revision = r.revision,
            epoch = r.epoch,
            coordinator_generation = r.coordinator_generation,
            policy = r.policy,
        },
        members = members,
    }
    reply_kind := kind == RPC_REMOVE_REQUEST ? RPC_REMOVE_REPLY : RPC_REPLY
    count := rpc_pack(&s.codecs.reply, reply, key, reply_kind, r.content, q.sequence, s.txb[:])

    if count != 0 && tr.send(&s.wire, from, .Reliable, s.txb[:count]) == .Sent {
        s.stats.tx_packets += 1
    } else {
        s.stats.deferred += 1
    }

    s.stats.rejected += 1
    return true
}

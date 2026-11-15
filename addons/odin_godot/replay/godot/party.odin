package replay_godot

import "core:crypto"
import "core:fmt"
import "core:strings"
import "core:mem"
import gd "godot:godot"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rec "godot:replay/recovery"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

Party_Action :: enum {
    Create,
    Join,
    Rejoin,
}

Party_Error :: enum {
    None,
    Config,
    Storage,
    Conflict,
    Missing,
    Invite,
    Transport,
    Entropy,
    Enrollment,
    Relay,
}

Party_Storage :: struct {
    user:   rawptr,
    open:   proc(user: rawptr, slot: string) -> (Enrollment_Backing, bool),
    recent: proc(user: rawptr, key: string) -> (room, revision: u64, error: Party_Error),
    select: proc(user: rawptr, key: string, room, expected: u64) -> Party_Error,
}

Party_Config :: struct {
    service, namespace, ice_json: string,
    content:                      u64,
    endpoint:                     auth.Endpoint,
    invite_role:                  p.Role,
    invite_uses:                  u8,
    local_development:            bool,
    relay_credentials:            bool,
    checkpoint_interval_ms:       u64, // opt-in; requires a checkpoint-enabled service
    tls:                          gd.Tls_Options,
    storage:                      Party_Storage,
    entropy:                      p.Entropy, // optional embedding/test source; default uses Godot Crypto
    short_codes:                  bool, // opt-in cooperative Player, five-character code v1; invite_uses 1..8
    browser_seats:                bool, // opt-in exclusive durable browser seat per live tab
}

// Stable-address owner. Storage is borrowed; close Party before its native store.
// No scene/UI/model dependency. A game starts Room only after party_grant succeeds.
Party :: struct {
    initialized, active, failed, recent_loaded, recent_writing, recent_saved, invited, invite_resolved, ready: bool,
    config:                                                                                                    Party_Config,
    scope:                                                                                                     string,
    error:                                                                                                     Party_Error,
    protocol_error:                                                                                            p.Error,
    invite_error:                                                                                              p.Error,
    profile:                                                                                                   Enrollment_Profile,
    connection:                                                                                                Provision_Connection,
    relay:                                                                                                     Relay_Connection,
    recent_op:                                                                                                 storagegd.Browser_Store_Op,
    browser_seat:                                                                                              storagegd.Browser_Seat,
    seat_resolved:                                                                                             bool,
    recent_room, recent_revision, target:                                                                      u64,
    request:                                                                                                   p.Request,
    grant:                                                                                                     p.Grant,
    invite:                                                                                                    p.Ticket,
    code:                                                                                                      [p.INVITE_CODE_BYTES]u8,
    code_count:                                                                                                int,
    allocator:                                                                                                 mem.Allocator,
}

@(private)
party_scope :: proc(service: string) -> string {
    hash := rec.hash(transmute([]u8)service)
    alphabet := "0123456789abcdef"
    bytes: [64]u8

    for b, i in hash {
        bytes[2 * i], bytes[2 * i + 1] = alphabet[b >> 4], alphabet[b & 15]
    }

    return strings.clone(string(bytes[:]))
}

party_open :: proc(o: ^Party, cfg: Party_Config, allocator := context.allocator) -> bool {
    context.allocator = allocator

    if cfg.short_codes && (cfg.invite_role != .Player || cfg.invite_uses > p.SHORT_CODE_MAX_USES) {
        return false
    }

    if cfg.checkpoint_interval_ms != 0 && (cfg.checkpoint_interval_ms < 1000 || cfg.checkpoint_interval_ms > 120000) {
        return false
    }

    if o.initialized ||
       !p.service_url_valid(cfg.service, cfg.local_development) ||
       !storagegd.browser_store_key_valid(cfg.namespace) ||
       cfg.content == 0 ||
       cfg.invite_role > .Trusted_Peer ||
       cfg.invite_uses == 0 ||
       cfg.invite_uses >= auth.MAX_MEMBERS {
        return false
    }

    probe := auth.record_make(1, cfg.content, {1, 1})
    probe.members[0] = {
        identity = {1, 1},
        endpoint = cfg.endpoint,
    }

    if !auth.record_valid(probe) {
        return false
    }

    if transportgd.rtc_ice_validate(cfg.ice_json) != .None {
        return false
    }

    if cfg.relay_credentials && cfg.ice_json != "" {
        return false
    }

    when !gd.IS_WEB {
        if cfg.storage.open == nil || cfg.storage.recent == nil || cfg.storage.select == nil {
            return false
        }
    }

    o.allocator = allocator
    o.config = cfg
    o.config.service = strings.clone(cfg.service)
    o.config.namespace = strings.clone(cfg.namespace)
    o.config.ice_json = strings.clone(cfg.ice_json)

    if cfg.tls != nil {
        gd.ref_counted_reference(cfg.tls)
    }

    o.scope, o.initialized = party_scope(cfg.service), true

    when gd.IS_WEB {
        o.seat_resolved = !cfg.browser_seats
        opened: bool

        if cfg.browser_seats {
            opened = storagegd.browser_seat_open(&o.browser_seat, o.config.namespace, o.scope)
        } else {
            opened = storagegd.browser_store_read(&o.recent_op, o.config.namespace, o.scope, 8)
        }

        if !opened {
            party_fail(o, .Storage)
            return false
        }
    } else {
        o.recent_room, o.recent_revision, o.error = cfg.storage.recent(cfg.storage.user, o.scope)

        if o.error != .None {
            party_fail(o, o.error)
            return false
        }

        if (o.recent_room == 0) != (o.recent_revision == 0) {
            party_fail(o, .Storage)
            return false
        }

        o.recent_loaded = true
    }

    return true
}

party_begin :: proc(o: ^Party, action: Party_Action, ticket: p.Ticket = {}) -> bool {
    if !o.initialized ||
       !o.recent_loaded ||
       o.active ||
       o.recent_writing ||
       action > .Rejoin ||
       (action != .Join && ticket != (p.Ticket{})) {
        return false
    }

    context.allocator = o.allocator
    provision_disconnect(&o.connection)
    relay_close(&o.relay)
    enrollment_profile_close(&o.profile)
    o.active, o.failed, o.invited, o.ready, o.recent_saved, o.error, o.protocol_error =
        false, false, false, false, false, .None, .None
    o.grant, o.invite, o.code, o.request = {}, {}, {}, {}
    o.code_count = 0
    o.invite_resolved, o.invite_error = false, .None
    claim, room, ok := party_random(o.config.entropy)

    if !ok {
        party_fail(o, .Entropy)
        return false
    }

    if action == .Create && o.config.short_codes {
        code, valid := p.short_code(claim, o.config.content)

        if !valid {
            party_fail(o, .Entropy)
            return false
        }

        ticket, valid_ticket := p.short_ticket_parse(string(code[:]), o.config.content)

        if !valid_ticket {
            party_fail(o, .Entropy)
            return false
        }

        room = ticket.room
    }

    if action == .Rejoin {
        room = o.recent_room

        if room == 0 {
            party_fail(o, .Missing)
            return false
        }
    } else if action == .Join {
        _, valid := p.ticket_code(ticket)

        if !valid {
            party_fail(o, .Invite)
            return false
        }

        room = ticket.room
    }

    o.target = room
    o.request = {
        version  = p.PROTOCOL,
        verb     = action == .Create ? .Create : .Join,
        room     = room,
        content  = o.config.content,
        claim    = claim,
        ticket   = ticket.secret,
        endpoint = o.config.endpoint,
    }

    if action == .Rejoin {
        o.request = {}
    }

    slot := fmt.tprintf("%s.%016x", o.scope, room)
    backing: Enrollment_Backing

    when !gd.IS_WEB {
        available: bool
        backing, available = o.config.storage.open(o.config.storage.user, slot)

        if !available {
            party_fail(o, .Storage)
            return false
        }
    }

    if !enrollment_profile_open(
        &o.profile,
        o.config.service,
        o.config.content,
        o.config.namespace,
        slot,
        backing,
        o.config.local_development,
    ) {
        party_fail(o, .Storage)
        return false
    }

    o.active = true
    return true
}

party_frame :: proc(o: ^Party) {
    if !o.initialized || o.failed {
        return
    }

    context.allocator = o.allocator

    if o.ready && o.config.relay_credentials {
        relay_frame(&o.relay)
    }

    party_recent_frame(o)

    if o.failed || !o.active {
        return
    }

    enrollment_profile_frame(&o.profile)
    e := &o.profile.value

    if e.phase == .Loading {
        return
    }

    if e.phase == .Failed {
        party_fail(o, e.error == .Conflict ? .Conflict : .Storage)
        return
    }

    // A code collision must not silently adopt an earlier local creator's
    // enrollment. Rejoin is an explicit action with a different request path.
    if o.config.short_codes &&
       o.request.version != 0 &&
       o.request.verb == .Create &&
       (e.phase == .Pending || e.phase == .Ready) &&
       e.record.request.claim != o.request.claim {
        party_fail(o, .Conflict)
        return
    }

    if e.phase == .Empty {
        if o.request.version == 0 || !enrollment_profile_begin(&o.profile, o.request) {
            party_fail(o, .Missing)
        }

        return
    }

    if e.phase == .Pending || e.phase == .Ready {
        if !o.recent_saved {
            if o.recent_room == o.target {
                o.recent_saved = true
            } else {
                when gd.IS_WEB {
                    if !o.recent_writing {
                        bytes: [8]u8

                        for i in 0 ..< 8 {
                            bytes[i] = u8(o.target >> uint(8 * i))
                        }

                        if !storagegd.browser_store_write(
                            &o.recent_op,
                            o.config.namespace,
                            o.scope,
                            bytes[:],
                            o.recent_revision,
                            8,
                        ) {
                            party_fail(o, .Storage)
                            return
                        }

                        o.recent_writing = true
                    }
                } else {
                    if error := o.config.storage.select(o.config.storage.user, o.scope, o.target, o.recent_revision);
                       error != .None {
                        party_fail(o, error)
                        return
                    }

                    o.recent_room, o.recent_revision, o.recent_saved = o.target, o.recent_revision + 1, true
                }

                return
            }
        }

        // A returning guest with a ready record needs no provisioning socket.
        needs_network := e.phase == .Pending || (e.record.request.verb == .Create && !o.invite_resolved)

        if needs_network && !o.connection.ready {
            if provision_connect(&o.connection, o.config.service, o.config.tls, o.config.local_development) != .None {
                party_fail(o, .Transport)
                return
            }
        }
    }

    if e.phase == .Pending {
        if error := provision_enrollment_frame(&o.connection, &o.profile); error != .None {
            o.protocol_error = error
            party_fail(o, .Enrollment)
            return
        }
    }

    if e.phase != .Ready {
        return
    }

    o.grant, _ = p.enrollment_grant(e)

    if e.record.request.verb == .Create && !o.invite_resolved {
        if !o.connection.client.pending && !o.connection.client.complete {
            q, ok := p.creator_invite(
                e.record,
                o.config.invite_role,
                o.config.invite_uses,
                local_development = o.config.local_development,
            )

            if o.config.short_codes {
                short, valid := p.creator_short_invite(
                    e.record,
                    local_development = o.config.local_development,
                    uses = o.config.invite_uses,
                )

                if valid {
                    q, ok = short, true
                } else if o.request.version != 0 && o.request.verb == .Create {
                    ok = false
                }
            }

            if !ok || provision_request(&o.connection, q) != .None {
                party_fail(o, .Invite)
                return
            }
        }

        if error := provision_frame(&o.connection); error != .None {
            o.protocol_error = error
            party_fail(o, .Transport)
            return
        }

        if !o.connection.client.complete {
            return
        }

        reply := o.connection.client.reply
        o.connection.client.complete = false
        o.invite_resolved, o.invite_error = true, reply.result

        if reply.result == .None {
            o.invite = reply.ticket
            o.code, _ = p.ticket_code(reply.ticket)
            o.code_count = p.INVITE_CODE_BYTES

            if o.config.short_codes {
                code, valid := p.short_code(e.record.request.claim, e.record.request.content)
                expected, parsed := p.short_ticket_parse(string(code[:]), e.record.request.content)

                if valid && parsed && expected == reply.ticket {
                    o.code = {}
                    o.code_count = copy(o.code[:], code[:])
                }
            }

            o.invited = true
        }
    }

    if o.config.relay_credentials {
        if !o.relay.ready &&
           !relay_connect(&o.relay, o.config.service, o.grant, o.config.tls, o.config.local_development) {
            party_fail(o, .Relay)
            return
        }

        relay_frame(&o.relay)

        if _, valid := relay_ice_source(&o.relay); !valid {
            if o.relay.error != .None {
                party_fail(o, .Relay)
            }

            return
        }
    }

    provision_disconnect(&o.connection)
    o.ready, o.active = true, false
}

party_grant :: proc(o: ^Party) -> (p.Grant, bool) {
    if !o.ready || o.failed {
        return {}, false
    }

    return o.grant, true
}

party_room_options :: proc(o: ^Party, session: Session_Options) -> (Room_Options, bool) {
    grant, ready := party_grant(o)

    if !ready {
        return {}, false
    }

    options := Room_Options {
        coordinator            = o.config.service,
        control_backend        = .Websocket,
        control_tls            = o.config.tls,
        automatic_successor    = true,
        session                = session,
        checkpoint_interval_ms = o.config.checkpoint_interval_ms,
    }
    options.checkpoint_local_development = o.config.local_development
    options.restore_published = grant.can_host && grant.trusted_authority && session.role != .Observer
    options.session.replication.accept_checkpoints = grant.can_host && grant.trusted_authority

    when gd.IS_WEB {
        options.session.backend = .Rtc
        options.session.rtc.url = o.config.service
    }

    if o.config.ice_json != "" {
        options.session.rtc.ice_json = o.config.ice_json
    }

    if o.config.relay_credentials {
        options.session.rtc.ice_user, options.session.rtc.ice_source = &o.relay, relay_ice_source
    }

    return room_with_grant(options, grant)
}

party_close :: proc(o: ^Party) {
    if o.allocator.procedure != nil {
        context.allocator = o.allocator
    }

    provision_disconnect(&o.connection)
    relay_close(&o.relay)
    enrollment_profile_close(&o.profile)
    storagegd.browser_store_close(&o.recent_op)
    storagegd.browser_seat_close(&o.browser_seat)

    if o.config.tls != nil {
        gd.release_ref(o.config.tls)
    }

    delete(o.config.service)
    delete(o.config.namespace)
    delete(o.config.ice_json)
    delete(o.scope)
    crypto.zero_explicit(o, size_of(Party))
}

party_message :: proc(o: ^Party) -> string {
    if !o.failed {
        return(
            o.active ? "Connecting to the party…" : o.invite_error != .None ? "The invitation is unavailable. Existing members can still rejoin." : "" \
        )
    }

    switch o.error {
    case .Storage:
        return "Party data could not be saved or loaded. Existing data was kept."
    case .Conflict:
        return "Another window changed the party selection. Reopen the game to reload it."
    case .Missing:
        return "The selected party credentials are missing."
    case .Invite:
        return "The party invite is invalid or unavailable."
    case .Transport:
        return "The party service could not be reached. Rejoin to retry."
    case .Entropy:
        return "A party identity could not be created."
    case .Enrollment:
        return "Enrollment did not finish. The stored request was kept for retry."
    case .Relay:
        return "Relay credentials could not be obtained. Rejoin to retry."
    case .Config:
        return "The party service configuration is invalid."
    case .None:
        return ""
    }

    return "Party setup failed."
}

@(private)
party_fail :: proc(o: ^Party, error: Party_Error) {
    o.failed, o.active, o.ready, o.error = true, false, false, error
}

@(private)
party_random :: proc(entropy: p.Entropy) -> (p.Secret, u64, bool) {
    bytes: [40]u8

    if entropy.read != nil {
        if !entropy.read(entropy.user, bytes[:]) {
            return {}, 0, false
        }
    } else {
        crypto := gd.new_crypto()
        gd.ref_counted_init_ref(crypto)
        defer gd.release_ref(crypto)
        packet := gd.crypto_generate_random_bytes(crypto, 40)
        defer gd.free_packed_byte_array(packet)
        view := gd.packed_byte_array_view(&packet)

        if len(view) != len(bytes) {
            return {}, 0, false
        }

        copy(bytes[:], view)
    }

    secret: p.Secret
    copy(secret[:], bytes[:32])
    room := u64(0)

    for i in 0 ..< 8 {
        room |= u64(bytes[32 + i]) << uint(8 * i)
    }

    return secret, room, secret != (p.Secret{}) && room != 0
}

@(private)
party_recent_frame :: proc(o: ^Party) {
    when gd.IS_WEB {
        if !o.seat_resolved {
            if storagegd.browser_seat_poll(&o.browser_seat) != .Complete {
                return
            }

            if o.browser_seat.failed {
                party_fail(o, .Storage)
                return
            }

            // Seat zero preserves existing saved crews. Additional live seats
            // share the database but never enrollment or Recent selection keys.
            if o.browser_seat.seat > 0 {
                previous := o.scope
                o.scope = strings.clone(fmt.tprintf("%s.seat%d", previous, o.browser_seat.seat))
                delete(previous)
            }

            o.seat_resolved = true

            if !storagegd.browser_store_read(&o.recent_op, o.config.namespace, o.scope, 8) {
                party_fail(o, .Storage)
                return
            }
        }

        if !o.recent_loaded {
            if storagegd.browser_store_poll(&o.recent_op) != .Complete {
                return
            }

            if o.recent_op.error == .None {
                bytes, error := storagegd.browser_store_bytes(&o.recent_op)
                defer delete(bytes)

                if error != .None || len(bytes) != 8 {
                    party_fail(o, .Storage)
                    return
                }

                for i in 0 ..< 8 {
                    o.recent_room |= u64(bytes[i]) << uint(8 * i)
                }

                if o.recent_room == 0 {
                    party_fail(o, .Storage)
                    return
                }

                o.recent_revision = o.recent_op.revision
            } else if o.recent_op.error != .Missing {
                party_fail(o, .Storage)
                return
            }

            storagegd.browser_store_close(&o.recent_op)
            o.recent_loaded = true
        }

        if o.recent_writing && storagegd.browser_store_poll(&o.recent_op) == .Complete {
            if o.recent_op.error != .None {
                party_fail(o, o.recent_op.error == .Conflict ? .Conflict : .Storage)
                return
            }

            o.recent_revision, o.recent_room, o.recent_saved, o.recent_writing =
                o.recent_op.revision, o.target, true, false
            storagegd.browser_store_close(&o.recent_op)
        }
    }
}

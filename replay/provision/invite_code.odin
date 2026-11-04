package replay_provision

import "core:crypto/hmac"
import "core:strings"

INVITE_CODE_BYTES :: 85

// One reproducible capability for a chosen role/use count/index. The creator's
// persisted claim is the key; invite recipients cannot derive that claim or
// other invitation capabilities. Repeating issuance cannot refill a spent or
// revoked ticket. A new index is an explicit new invite, not automatic recovery.
creator_invite :: proc(
    record: Enrollment_Record,
    role: Role,
    uses: u8,
    index: u32 = 0,
    local_development: bool = false,
) -> (
    Request,
    bool,
) {
    if !enrollment_record_valid(record, local_development) ||
       record.state != .Ready ||
       record.request.verb != .Create ||
       role > .Trusted_Peer ||
       uses == 0 ||
       uses >= 16 {
        return {}, false
    }

    key := record.request.claim
    mac: hmac.Context
    hmac.init(&mac, .SHA256, key[:])
    domain := "replay-client-invite-v1"
    hmac.update(&mac, transmute([]u8)domain)
    data: [22]u8

    for i in 0 ..< 8 {
        data[i] = u8(record.request.room >> uint(i * 8))
        data[8 + i] = u8(record.request.content >> uint(i * 8))
    }

    data[16], data[17] = u8(role), uses

    for i in 0 ..< 4 {
        data[18 + i] = u8(index >> uint(i * 8))
    }

    hmac.update(&mac, data[:])
    url := record.service
    hmac.update(&mac, url[:])
    ticket: Secret
    hmac.final(&mac, ticket[:])
    return {
            version = PROTOCOL,
            verb = .Invite,
            room = record.request.room,
            content = record.request.content,
            claim = record.request.claim,
            ticket = ticket,
            role = role,
            uses = uses,
        },
        true
}

ticket_code :: proc(ticket: Ticket) -> ([INVITE_CODE_BYTES]u8, bool) {
    s := ticket.secret

    if ticket.room == 0 || !nonzero(s[:]) {
        return {}, false
    }

    code: [INVITE_CODE_BYTES]u8
    copy(code[:4], transmute([]u8)string("RP1."))
    code[20] = '.'
    alphabet := "0123456789abcdef"

    for i in 0 ..< 16 {
        code[4 + i] = alphabet[(ticket.room >> uint(4 * (15 - i))) & 15]
    }

    for b, i in s {
        code[21 + 2 * i], code[22 + 2 * i] = alphabet[b >> 4], alphabet[b & 15]
    }

    return code, true
}

ticket_parse :: proc(text: string) -> (Ticket, bool) {
    text := strings.trim_space(text)

    if len(text) != INVITE_CODE_BYTES || text[:4] != "RP1." || text[20] != '.' {
        return {}, false
    }

    ticket: Ticket

    for b in text[4:20] {
        n, ok := invite_nibble(b)

        if !ok {
            return {}, false
        }

        ticket.room = (ticket.room << 4) | u64(n)
    }

    for i in 0 ..< 32 {
        a, a_ok := invite_nibble(rune(text[21 + 2 * i]))
        b, b_ok := invite_nibble(rune(text[22 + 2 * i]))

        if !a_ok || !b_ok {
            return {}, false
        }

        ticket.secret[i] = (a << 4) | b
    }

    if ticket.room == 0 || !nonzero(ticket.secret[:]) {
        return {}, false
    }

    return ticket, true
}

@(private)
invite_nibble :: proc(b: rune) -> (u8, bool) {
    if b >= '0' && b <= '9' {
        return u8(b - '0'), true
    }

    if b >= 'a' && b <= 'f' {
        return u8(b - 'a' + 10), true
    }

    return 0, false
}

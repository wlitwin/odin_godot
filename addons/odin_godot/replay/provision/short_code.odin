package replay_provision

import "core:crypto/hmac"
import "core:strings"

// Opt-in, human-entered cooperative room codes (format v1). The code is a
// low-entropy invitation, not an administrator or member credential. Only
// Player invitations are issued through this door: single-use by default, or
// up to SHORT_CODE_MAX_USES uses so one code seats a whole party. The existing
// confidential transport, global/peer request limits, durable invite use count
// and random creator/member secrets remain necessary and unchanged.
SHORT_CODE_BYTES :: 5
SHORT_CODE_MAX_USES :: 8
SHORT_CODE_ALPHABET :: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

short_code :: proc(creator: Secret, content: u64) -> ([SHORT_CODE_BYTES]u8, bool) {
    creator := creator

    if !nonzero(creator[:]) || content == 0 {
        return {}, false
    }

    mac: hmac.Context
    hmac.init(&mac, .SHA256, creator[:])
    domain := "replay-short-room-code-v1"
    hmac.update(&mac, transmute([]u8)domain)
    bytes: [8]u8

    for i in 0 ..< 8 {
        bytes[i] = u8(content >> uint(8 * i))
    }

    hmac.update(&mac, bytes[:])
    digest: [32]u8
    hmac.final(&mac, digest[:])
    code: [SHORT_CODE_BYTES]u8
    alphabet := SHORT_CODE_ALPHABET

    for i in 0 ..< SHORT_CODE_BYTES {
        code[i] = alphabet[digest[i] & 31]
    }

    return code, true
}

// Both explicit UI actions use the same room code, with separately registered
// invitation secrets: index 0 joins the crew, index 1 watches. Neither can mint
// an invitation or derive the creator's independent 256-bit claim.
short_ticket_parse :: proc(text: string, content: u64, index: u32 = 0) -> (Ticket, bool) {
    text := strings.trim_space(text)

    if len(text) != SHORT_CODE_BYTES || content == 0 || index > 1 {
        return {}, false
    }

    code: [SHORT_CODE_BYTES]u8

    for byte, i in text {
        if byte < 0 || byte > 127 {
            return {}, false
        }

        c := u8(byte)

        if c >= 'a' && c <= 'z' {
            c -= 'a' - 'A'
        }

        found := false

        for valid in SHORT_CODE_ALPHABET {
            if rune(c) == valid {
                found = true
                break
            }
        }

        if !found {
            return {}, false
        }

        code[i] = c
    }

    data: [9]u8

    for i in 0 ..< 8 {
        data[i] = u8(content >> uint(8 * i))
    }

    data[8] = u8(index)
    mac: hmac.Context
    hmac.init(&mac, .SHA256, code[:])
    domain := "replay-short-room-id-v1"
    hmac.update(&mac, transmute([]u8)domain)
    hmac.update(&mac, data[:8])
    digest: [32]u8
    hmac.final(&mac, digest[:])
    ticket: Ticket

    for i in 0 ..< 8 {
        ticket.room |= u64(digest[i]) << uint(8 * i)
    }

    if ticket.room == 0 {
        return {}, false
    }

    hmac.init(&mac, .SHA256, code[:])
    domain = "replay-short-room-invite-v1"
    hmac.update(&mac, transmute([]u8)domain)
    hmac.update(&mac, data[:])
    hmac.final(&mac, ticket.secret[:])
    return ticket, nonzero(ticket.secret[:])
}

creator_short_invite :: proc(
    record: Enrollment_Record,
    index: u32 = 0,
    local_development: bool = false,
    uses: u8 = 1,
) -> (
    Request,
    bool,
) {
    if uses == 0 ||
       uses > SHORT_CODE_MAX_USES ||
       !enrollment_record_valid(record, local_development) ||
       record.state != .Ready ||
       record.request.verb != .Create {
        return {}, false
    }

    code, valid := short_code(record.request.claim, record.request.content)

    if !valid {
        return {}, false
    }

    ticket, ok := short_ticket_parse(string(code[:]), record.request.content, index)

    if !ok || ticket.room != record.request.room {
        return {}, false
    }

    return {
            version = PROTOCOL,
            verb = .Invite,
            room = ticket.room,
            content = record.request.content,
            claim = record.request.claim,
            ticket = ticket.secret,
            role = .Player,
            uses = uses,
        },
        true
}

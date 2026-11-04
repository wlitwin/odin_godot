package replay_provision

import "core:crypto"
import "core:mem"
import "core:strings"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"

ENROLLMENT_VERSION :: u16(1)
ENROLLMENT_KIND :: u16(0x5043)
ENROLLMENT_BYTES :: 4096
ENROLLMENT_REVISION_MAX :: u64(9007199254740991)
Service_URL :: [2049]u8

Enrollment_State :: enum u8 {
    Pending,
    Ready,
}

Enrollment_Record :: struct {
    version:  u16,
    revision: u64,
    service:  Service_URL,
    state:    Enrollment_State,
    request:  Request,
    grant:    Grant,
}

Enrollment_Phase :: enum {
    Closed,
    Loading,
    Empty,
    Writing_Request,
    Pending,
    Writing_Grant,
    Ready,
    Refused,
    Failed,
}

Enrollment_Error :: enum {
    None,
    Invalid,
    Store,
    Conflict,
    Corrupt,
    Scope,
    Busy,
    Response,
}

Enrollment_Journal :: struct {
    phase:             Enrollment_Phase,
    error:             Enrollment_Error,
    response_error:    Error,
    record, candidate: Enrollment_Record,
    service:           Service_URL,
    content:           u64,
    revision:          u64,
    codec:             sc.Schema,
    protocol:          Codecs,
    buffer:            [ENROLLMENT_BYTES]u8,
    count:             int,
    local_development: bool,
}

service_url :: proc(text: string, local_development: bool = false) -> (Service_URL, bool) {
    if !service_url_valid(text, local_development) {
        return {}, false
    }

    url: Service_URL
    copy(url[:], transmute([]u8)text)
    return url, true
}

service_url_text :: proc(url: Service_URL) -> string {
    // Returns an owned string. Never borrow a slice of this value parameter.
    u := url
    count := 0

    for b in u {
        if b == 0 {
            break
        }

        count += 1
    }

    return strings.clone(string(u[:count]))
}

enrollment_record_valid :: proc(record: Enrollment_Record, local_development: bool = false) -> bool {
    r := record

    if r.version != ENROLLMENT_VERSION ||
       r.revision == 0 ||
       r.revision > ENROLLMENT_REVISION_MAX ||
       r.state > .Ready ||
       !request_valid(r.request) ||
       (r.request.verb != .Create && r.request.verb != .Join) {
        return false
    }

    count := -1

    for b, i in r.service {
        if b == 0 {
            count = i
            break
        }
    }

    if count < 1 || count > 2048 || !service_url_valid(string(r.service[:count]), local_development) {
        return false
    }

    for b in r.service[count:] {
        if b != 0 {
            return false
        }
    }

    if r.state == .Pending {
        return r.revision == 1 && r.grant == (Grant{})
    }

    return r.revision == 2 && reply_valid({grant = r.grant}, r.request)
}

// A slot is an immutable enrollment: absent -> pending -> ready. Reuse requires
// an explicit higher-level retirement policy, not overwriting another identity.
enrollment_transition :: proc(
    previous: Enrollment_Record,
    found: bool,
    expected: u64,
    next: Enrollment_Record,
    local_development: bool = false,
) -> bool {
    if expected >= ENROLLMENT_REVISION_MAX ||
       next.revision != expected + 1 ||
       !enrollment_record_valid(next, local_development) {
        return false
    }

    if !found {
        return expected == 0 && next.state == .Pending
    }

    return(
        enrollment_record_valid(previous, local_development) &&
        previous.revision == expected &&
        previous.state == .Pending &&
        next.state == .Ready &&
        previous.request == next.request &&
        previous.service == next.service \
    )
}

enrollment_codec_init :: proc(codec: ^sc.Schema, allocator := context.allocator) -> bool {
    if codec.initialized || sc.init(codec, Enrollment_Record, allocator = allocator).error != .None {
        return false
    }

    if codec.wire_size + sc.HEADER_BYTES > ENROLLMENT_BYTES {
        sc.destroy(codec)
        return false
    }

    return true
}

enrollment_encode :: proc(
    codec: ^sc.Schema,
    record: Enrollment_Record,
    dst: []u8,
    local_development: bool = false,
) -> int {
    if !codec.initialized || !enrollment_record_valid(record, local_development) {
        return 0
    }

    count := codec.wire_size + sc.HEADER_BYTES

    if len(dst) < count ||
       sc.pack(codec, record, {kind = ENROLLMENT_KIND, epoch = u64(ENROLLMENT_VERSION), tick = record.revision, content = record.request.content}, dst[:count]).error !=
           .None {
        return 0
    }

    return count
}

enrollment_decode :: proc(
    codec: ^sc.Schema,
    bytes: []u8,
    content: u64,
    local_development: bool = false,
) -> (
    Enrollment_Record,
    bool,
) {
    if !codec.initialized || content == 0 || len(bytes) != codec.wire_size + sc.HEADER_BYTES {
        return {}, false
    }

    r: Enrollment_Record
    meta, report := sc.unpack(
        codec,
        &r,
        bytes,
        {kind = ENROLLMENT_KIND, epoch = u64(ENROLLMENT_VERSION), content = content},
    )

    if report.error != .None ||
       meta.tick != r.revision ||
       r.request.content != content ||
       !enrollment_record_valid(r, local_development) {
        return {}, false
    }

    return r, true
}

// No network or storage side effects. A driver starts the read, then reports its
// result. Never submit enrollment_request before the write receipt publishes it.
enrollment_open :: proc(
    e: ^Enrollment_Journal,
    service: string,
    content: u64,
    local_development: bool = false,
    allocator := context.allocator,
) -> bool {
    if e.phase != .Closed || content == 0 {
        return false
    }

    url, ok := service_url(service, local_development)

    if !ok || !enrollment_codec_init(&e.codec, allocator) || !codecs_init(&e.protocol, allocator) {
        enrollment_close(e)
        return false
    }

    e.service, e.content, e.local_development, e.phase = url, content, local_development, .Loading
    return true
}

enrollment_loaded :: proc(
    e: ^Enrollment_Journal,
    record: Enrollment_Record,
    found: bool,
    revision: u64,
    error: Enrollment_Error = .None,
) -> bool {
    if e.phase != .Loading {
        return false
    }

    if error != .None {
        e.phase, e.error = .Failed, error
        return false
    }

    if !found {
        if revision != 0 || record != (Enrollment_Record{}) {
            e.phase, e.error = .Failed, .Corrupt
            return false
        }

        e.phase = .Empty
        return true
    }

    if !enrollment_record_valid(record, e.local_development) || revision != record.revision {
        e.phase, e.error = .Failed, .Corrupt
        return false
    }

    if record.service != e.service || record.request.content != e.content {
        e.phase, e.error = .Failed, .Scope
        return false
    }

    e.record, e.revision, e.phase = record, revision, record.state == .Ready ? .Ready : .Pending
    return true
}

enrollment_begin :: proc(e: ^Enrollment_Journal, request: Request) -> bool {
    if e.phase != .Empty {
        return false
    }

    candidate := Enrollment_Record {
        version  = ENROLLMENT_VERSION,
        revision = 1,
        service  = e.service,
        state    = .Pending,
        request  = request,
    }

    if request.content != e.content {
        return false
    }

    return enrollment_stage(e, candidate, .Writing_Request)
}

enrollment_request :: proc(e: ^Enrollment_Journal) -> (Request, bool) {
    if e.phase != .Pending {
        return {}, false
    }

    return e.record.request, true
}

enrollment_accept :: proc(e: ^Enrollment_Journal, reply: Reply) -> bool {
    if e.phase != .Pending {
        return false
    }

    request_bytes: [PACKET_BYTES]u8
    defer crypto.zero_explicit(&request_bytes, size_of(request_bytes))
    count := request_pack(&e.protocol, e.record.request, request_bytes[:])

    if count == 0 ||
       reply.version != PROTOCOL ||
       reply.room != e.record.request.room ||
       reply.content != e.content ||
       reply.request_hash != rec.hash(request_bytes[:count]) ||
       !reply_valid(reply, e.record.request) {
        e.error = .Response
        return false
    }

    if reply.result != .None {
        e.phase, e.response_error = .Refused, reply.result
        return false
    }

    if e.revision >= ENROLLMENT_REVISION_MAX {
        e.phase, e.error = .Failed, .Invalid
        return false
    }

    candidate := e.record
    candidate.revision += 1
    candidate.state, candidate.grant = .Ready, reply.grant
    return enrollment_stage(e, candidate, .Writing_Grant)
}

enrollment_retry :: proc(e: ^Enrollment_Journal) -> bool {
    if e.phase != .Refused {
        return false
    }

    e.phase, e.error, e.response_error = .Pending, .None, .None
    return true
}

enrollment_write :: proc(e: ^Enrollment_Journal) -> ([]u8, u64, bool) {
    if e.phase != .Writing_Request && e.phase != .Writing_Grant {
        return nil, 0, false
    }

    return e.buffer[:e.count], e.revision, true
}

enrollment_receipt :: proc(e: ^Enrollment_Journal, revision: u64, error: Enrollment_Error = .None) -> bool {
    if e.phase != .Writing_Request && e.phase != .Writing_Grant {
        return false
    }

    defer {
        crypto.zero_explicit(&e.buffer, size_of(e.buffer))
        crypto.zero_explicit(&e.candidate, size_of(e.candidate))
        e.count = 0
    }

    if error != .None || revision != e.revision + 1 || revision != e.candidate.revision {
        e.phase, e.error = .Failed, error != .None ? error : .Corrupt
        return false
    }

    e.record, e.revision = e.candidate, revision
    e.phase = e.record.state == .Ready ? .Ready : .Pending
    return true
}

enrollment_grant :: proc(e: ^Enrollment_Journal) -> (Grant, bool) {
    if e.phase != .Ready {
        return {}, false
    }

    return e.record.grant, true
}

enrollment_close :: proc(e: ^Enrollment_Journal) {
    sc.destroy(&e.codec)
    codecs_destroy(&e.protocol)
    crypto.zero_explicit(e, size_of(Enrollment_Journal))
}

@(private)
enrollment_stage :: proc(e: ^Enrollment_Journal, candidate: Enrollment_Record, phase: Enrollment_Phase) -> bool {
    count := enrollment_encode(&e.codec, candidate, e.buffer[:], e.local_development)

    if count == 0 {
        e.error = .Invalid
        return false
    }

    e.candidate, e.count, e.phase, e.error = candidate, count, phase, .None
    return true
}

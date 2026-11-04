package replay_relay

import "core:crypto"
import "core:crypto/hmac"
import "core:crypto/legacy/sha1"
import "core:encoding/base64"
import "core:fmt"
import "core:strings"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"

VERSION :: u16(1)
REQUEST_KIND :: u16(0x5451)
REPLY_KIND :: u16(0x5452)
PACKET_BYTES :: 2048
MAX_URLS :: 4
URL :: [256]u8

Error :: enum u8 {
    None,
    Invalid,
    Denied,
    Clock,
    Capacity,
    Expired,
    Rate_Limited,
    Unavailable,
}

Verb :: enum u8 {
    Challenge,
    Acquire,
}

Request :: struct {
    version:                         u16,
    verb:                            Verb,
    room, content, member, sequence: u64,
    nonce:                           [16]u8,
    challenge:                       [32]u8,
}

Grant :: struct {
    issued, expires: u64,
    urls:            [MAX_URLS]URL,
    username:        [96]u8,
    credential:      [64]u8,
    relay_only:      bool,
}

Reply :: struct {
    version:                         u16,
    room, content, member, sequence: u64,
    nonce:                           [16]u8,
    request_hash:                    [32]u8,
    error:                           Error,
    challenge:                       [32]u8,
    grant:                           Grant,
}

Codecs :: struct {
    request, reply: sc.Schema,
}

codecs_init :: proc(c: ^Codecs, allocator := context.allocator) -> bool {
    if c.request.initialized || c.reply.initialized {
        return false
    }

    if sc.init(&c.request, Request, allocator = allocator).error != .None ||
       sc.init(&c.reply, Reply, allocator = allocator).error != .None ||
       max(c.request.wire_size, c.reply.wire_size) + sc.HEADER_BYTES + 32 > PACKET_BYTES {
        codecs_destroy(c)
        return false
    }

    return true
}

codecs_destroy :: proc(c: ^Codecs) {
    sc.destroy(&c.request)
    sc.destroy(&c.reply)
}

request_valid :: proc(q: Request) -> bool {
    return(
        q.version == VERSION &&
        q.verb <= .Acquire &&
        q.room != 0 &&
        q.content != 0 &&
        q.member != 0 &&
        q.sequence != 0 &&
        q.nonce != ([16]u8{}) &&
        (q.verb == .Challenge ? q.challenge == ([32]u8{}) : q.challenge != ([32]u8{})) \
    )
}

url :: proc(text: string) -> (URL, bool) {
    if len(text) < 6 ||
       len(text) >= size_of(URL) ||
       (!strings.has_prefix(text, "turn:") && !strings.has_prefix(text, "turns:")) {
        return {}, false
    }

    for b in text {
        if b <= 32 || b > 126 || b == '@' || b == '#' || b == '\\' {
            return {}, false
        }
    }

    u: URL
    copy(u[:], transmute([]u8)text)
    return u, true
}

grant_valid :: proc(g: Grant) -> bool {
    g := g

    if g.issued == 0 ||
       g.expires <= g.issued ||
       g.expires - g.issued < 5 ||
       g.expires - g.issued > 3600 ||
       !fixed_valid(g.username) ||
       !fixed_valid(g.credential) {
        return false
    }

    count := 0
    ended := false

    for u in g.urls {
        if u == (URL{}) {
            ended = true
            continue
        }

        if ended || !fixed_valid(u) {
            return false
        }

        value := u
        text := string(value[:fixed_count(value)])

        if _, ok := url(text); !ok {
            return false
        }

        count += 1
    }

    return count != 0
}

// Coturn's TURN REST password is base64(HMAC-SHA1(shared secret, username)).
// Only the returned temporary password is sent to a member; never the secret.
credential :: proc(secret: string, username: string) -> [64]u8 {
    inner, outer: [64]u8
    digest: [20]u8
    key := transmute([]u8)secret
    state: sha1.Context

    if len(key) > 64 {
        sha1.init(&state)
        sha1.update(&state, key)
        sha1.final(&state, digest[:])
        key = digest[:]
    }

    copy(inner[:], key)
    copy(outer[:], key)

    for &b in inner {
        b ~= 0x36
    }

    for &b in outer {
        b ~= 0x5c
    }

    sha1.init(&state)
    sha1.update(&state, inner[:])
    sha1.update(&state, transmute([]u8)username)
    sha1.final(&state, digest[:])
    sha1.init(&state)
    sha1.update(&state, outer[:])
    sha1.update(&state, digest[:])
    sha1.final(&state, digest[:])
    encoded := base64.encode(digest[:])
    defer delete(encoded)
    value: [64]u8
    copy(value[:], transmute([]u8)encoded)
    crypto.zero_explicit(&digest, size_of(digest))
    crypto.zero_explicit(&inner, size_of(inner))
    crypto.zero_explicit(&outer, size_of(outer))
    return value
}

grant_make :: proc(
    secret: string,
    urls: [MAX_URLS]URL,
    room, member, incarnation, issued: u64,
    ttl: u32,
    relay_only: bool,
) -> Grant {
    if issued == 0 || ttl < 5 || ttl > 3600 || issued > max(u64) - u64(ttl) {
        return {}
    }

    g := Grant {
        issued     = issued,
        expires    = issued + u64(ttl),
        urls       = urls,
        relay_only = relay_only,
    }
    name := fmt.tprintf("%d:%016x:%016x:%016x", g.expires, room, member, incarnation)
    copy(g.username[:], transmute([]u8)name)
    g.credential = credential(secret, name)
    return g
}

request_pack :: proc(c: ^Codecs, q: Request, key: auth.Key, dst: []u8) -> int {
    if !request_valid(q) {
        return 0
    }

    return pack(&c.request, q, key, REQUEST_KIND, q.content, q.sequence, dst)
}

request_read :: proc(c: ^Codecs, bytes: []u8, content: u64) -> (Request, bool) {
    if len(bytes) != sc.HEADER_BYTES + c.request.wire_size + 32 {
        return {}, false
    }

    q: Request
    meta, result := sc.unpack(
        &c.request,
        &q,
        bytes[:len(bytes) - 32],
        {kind = REQUEST_KIND, epoch = u64(VERSION), content = content},
    )
    return q, result.error == .None && q.content == content && meta.tick == q.sequence && request_valid(q)
}

authenticated :: proc(key: auth.Key, kind: u16, bytes: []u8) -> bool {
    if len(bytes) < sc.HEADER_BYTES + 32 || len(bytes) > PACKET_BYTES {
        return false
    }

    tag := mac(key, kind, bytes[:len(bytes) - 32])
    return crypto.compare_constant_time(tag[:], bytes[len(bytes) - 32:]) == 1
}

request_hash :: proc(bytes: []u8) -> [32]u8 {
    if len(bytes) < 32 {
        return {}
    }

    return rec.hash(bytes[:len(bytes) - 32])
}

fixed_count :: proc(value: [$N]u8) -> int {
    for b, i in value {
        if b == 0 {
            return i
        }
    }

    return N
}

fixed_valid :: proc(value: [$N]u8) -> bool {
    if value[0] == 0 || value[N - 1] != 0 {
        return false
    }

    ended := false

    for b in value {
        if b == 0 {
            ended = true
        } else if ended || b < 32 || b > 126 {
            return false
        }
    }

    return true
}

@(private)
mac :: proc(key: auth.Key, kind: u16, bytes: []u8) -> [32]u8 {
    k := key
    state: hmac.Context
    hmac.init(&state, .SHA256, k[:])
    domain := kind == REQUEST_KIND ? "replay-relay-request-v1" : "replay-relay-reply-v1"
    hmac.update(&state, transmute([]u8)domain)
    hmac.update(&state, bytes)
    tag: [32]u8
    hmac.final(&state, tag[:])
    return tag
}

@(private)
pack :: proc(codec: ^sc.Schema, value: $T, key: auth.Key, kind: u16, content, sequence: u64, dst: []u8) -> int {
    count := codec.wire_size + sc.HEADER_BYTES

    if !codec.initialized ||
       len(dst) < count + 32 ||
       sc.pack(codec, value, {kind = kind, epoch = u64(VERSION), tick = sequence, content = content}, dst[:count]).error !=
           .None {
        return 0
    }

    tag := mac(key, kind, dst[:count])
    copy(dst[count:count + 32], tag[:])
    return count + 32
}

package replay_assets

import "core:mem"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

MAX_WATCHED :: 32
MAX_NEEDS :: MAX_WATCHED + 32
REQUEST_KIND :: u16(0x5301)
ANNOUNCE_KIND :: u16(0x5303)
CONTENT_KIND :: u16(0x5302)

Mesh_Error :: enum {
    None,
    Invalid_Config,
    Not_Ready,
    Invalid_Ref,
    Capacity,
    Invalid_Time,
    Transport,
    Codec,
}

Mesh_Config :: struct {
    peers, packets_per_update, rx_bytes_per_update, bytes_per_update, bytes_per_second, requests_per_update: int,
    request_ms:                                                                                              u64,
    transfer:                                                                                                tf.Config,
}

DEFAULT_MESH_CONFIG :: Mesh_Config{16, 64, 128 * 1024, 16 * 1024, 64 * 1024, 4, 500, tf.DEFAULT_CONFIG}

Mesh_Stats :: struct {
    tx_bytes, rx_bytes, requests, installed, rejected, deferred, starts: u64,
}

// Runtime owner. Cache and Mesh addresses remain stable while bound. Only watched
// references may be served or installed. A binding is supplied after application
// admission; its scope changes when the peer/authority incarnation changes.
Mesh :: struct {
    ready, time_set:                    bool,
    allocator:                          mem.Allocator,
    cache:                              ^Cache,
    wire, budget_wire:                  tr.Transport,
    cfg:                                Mesh_Config,
    peers:                              []Mesh_Peer,
    watched:                            [MAX_WATCHED]Watched,
    published:                          [MAX_WATCHED]Ref,
    published_count:                    int,
    local:                              [MAX_WATCHED]Ref,
    local_count:                        int,
    local_version:                      u64,
    count, send_cursor, request_cursor: int,
    now:                                u64,
    budget:                             f64,
    remaining:                          int,
    request_codec, ref_codec:           sc.Schema,
    validator_user:                     rawptr,
    validator:                          proc(user: rawptr, ref: Ref, bytes: []u8) -> bool,
    policy_user:                        rawptr,
    authorize:                          proc(user: rawptr, peer: tr.Peer_Id, ref: Ref) -> bool,
    stats:                              Mesh_Stats,
    rxb:                                [tr.MAX_PACKET_BYTES]u8,
}

@(private)
Watched :: struct {
    ref:    Ref,
    pinned: bool,
}

@(private)
Request :: struct {
    room, binding: u64,
    ref:           Ref,
}

@(private)
Mesh_Peer :: struct {
    owner:                                      ^Mesh,
    ready:                                      bool,
    peer:                                       tr.Peer_Id,
    scope:                                      tf.Scope,
    sender:                                     tf.Sender,
    receiver:                                   tf.Blob_Receiver,
    queue:                                      [MAX_WATCHED]Ref,
    queue_count:                                int,
    sending:                                    Ref,
    requested:                                  [MAX_NEEDS]Ref,
    request_at:                                 [MAX_NEEDS]u64,
    accept_offers, offer_pinned, announce_sent: bool,
    offer:                                      Ref,
    offer_at, announce_at, announce_version:    u64,
    announce_index:                             int,
    error:                                      Error,
}

handles :: proc(bytes: []u8) -> bool {
    if len(bytes) > tf.CHUNK_BYTES + 128 {
        return false
    }

    if tf.handles(bytes) {
        return true
    }

    meta, _, report := sc.inspect(bytes)
    return report.error == .None && (meta.kind == REQUEST_KIND || meta.kind == ANNOUNCE_KIND)
}

mesh_init :: proc(
    m: ^Mesh,
    cache: ^Cache,
    wire: tr.Transport,
    cfg := DEFAULT_MESH_CONFIG,
    allocator := context.allocator,
    validator: proc(user: rawptr, ref: Ref, bytes: []u8) -> bool = nil,
    validator_user: rawptr = nil,
    authorize: proc(user: rawptr, peer: tr.Peer_Id, ref: Ref) -> bool = nil,
    policy_user: rawptr = nil,
) -> Mesh_Error {
    if m.ready ||
       cache == nil ||
       !cache.ready ||
       cfg.peers < 1 ||
       cfg.peers > 32 ||
       cfg.packets_per_update < 1 ||
       cfg.packets_per_update > 256 ||
       cfg.rx_bytes_per_update < tr.MAX_PACKET_BYTES ||
       cfg.rx_bytes_per_update > 1024 * 1024 ||
       cfg.bytes_per_update < 1200 ||
       cfg.bytes_per_update > 1024 * 1024 ||
       cfg.bytes_per_second < 2048 ||
       cfg.bytes_per_second > 16 * 1024 * 1024 ||
       cfg.requests_per_update < 1 ||
       cfg.requests_per_update > MAX_WATCHED ||
       cfg.request_ms < 50 ||
       cfg.request_ms > 30000 ||
       !tf.config_valid({1, 1, 1, 1}, 1, cfg.transfer) {
        return .Invalid_Config
    }

    m.allocator, m.cache, m.wire, m.cfg = allocator, cache, wire, cfg
    m.validator, m.validator_user = validator, validator_user
    m.authorize, m.policy_user = authorize, policy_user

    if sc.init(&m.request_codec, Request, allocator = allocator).error != .None ||
       sc.init(&m.ref_codec, Ref, allocator = allocator).error != .None {
        mesh_destroy(m)
        return .Codec
    }

    m.peers = make([]Mesh_Peer, cfg.peers, allocator)
    m.budget_wire = {
        user      = m,
        send      = mesh_send,
        receive   = nil,
        connected = mesh_connected,
        status    = mesh_status,
    }
    m.ready = true
    return .None
}

mesh_destroy :: proc(m: ^Mesh) {
    for &peer in m.peers {
        mesh_clear_offer(&peer)
        tf.sender_destroy(&peer.sender)
        tf.blob_destroy(&peer.receiver)
    }

    for watched in m.watched[:m.count] {
        if watched.pinned {
            cache_unpin(m.cache, watched.ref)
        }
    }

    delete(m.peers, m.allocator)
    sc.destroy(&m.request_codec)
    sc.destroy(&m.ref_codec)
    m^ = {}
}

@(private)
watched_index :: proc(m: ^Mesh, ref: Ref) -> int {
    for w, i in m.watched[:m.count] {
        if w.ref == ref {
            return i
        }
    }

    return -1
}

// Replaces the public working set, including local assets awaiting declaration.
// Missing references are requested; cached references are pinned. Repeating an
// unchanged set does not multiply pins. Unwatched cache entries stay local until
// the application explicitly discards them or restores them to the working set.
mesh_watch :: proc(m: ^Mesh, refs: []Ref) -> Mesh_Error {
    if !m.ready {
        return .Not_Ready
    }

    next: [MAX_WATCHED]Watched
    count := 0

    for ref in refs {
        if ref == (Ref{}) {
            continue
        }

        if !ref_valid(ref) || ref.bytes > u32(m.cache.cfg.max_asset_bytes) {
            return .Invalid_Ref
        }

        duplicate := false

        for n in next[:count] {
            if n.ref == ref {
                duplicate = true
                break
            }
        }

        if duplicate {
            continue
        }

        if count == MAX_WATCHED {
            return .Capacity
        }

        index := watched_index(m, ref)
        next[count] = {
            ref    = ref,
            pinned = index >= 0 && m.watched[index].pinned,
        }
        cached := cache_index(m.cache, ref)

        if !next[count].pinned && cached >= 0 && m.cache.items[cached].pins == max(u32) {
            return .Capacity
        }

        count += 1
    }

    for old in m.watched[:m.count] {
        retained := false

        for n in next[:count] {
            if old.ref == n.ref {
                retained = true
                break
            }
        }

        if old.pinned && !retained {
            cache_unpin(m.cache, old.ref)
        }
    }

    for &n in next[:count] {
        if !n.pinned && cache_has(m.cache, n.ref) {
            cache_pin(m.cache, n.ref)
            n.pinned = true
        }
    }

    m.watched, m.count = next, count
    return .None
}

mesh_complete :: proc(m: ^Mesh) -> bool {
    if !m.ready {
        return false
    }

    for w in m.watched[:m.count] {
        if !cache_has(m.cache, w.ref) {
            return false
        }
    }

    return true
}

// Additional public cached content, such as earlier revisions referenced by a
// retained checkpoint. Publishing neither requests missing bytes nor pins them.
mesh_publish :: proc(m: ^Mesh, refs: []Ref) -> Mesh_Error {
    if !m.ready {
        return .Not_Ready
    }

    next: [MAX_WATCHED]Ref
    count := 0

    for ref in refs {
        if ref == (Ref{}) {
            continue
        }

        if !ref_valid(ref) || ref.bytes > u32(m.cache.cfg.max_asset_bytes) {
            return .Invalid_Ref
        }

        duplicate := false

        for prior in next[:count] {
            if prior == ref {
                duplicate = true
                break
            }
        }

        if duplicate {
            continue
        }

        if count == MAX_WATCHED {
            return .Capacity
        }

        next[count] = ref
        count += 1
    }

    m.published, m.published_count = next, count
    return .None
}

mesh_bind :: proc(m: ^Mesh, peer: tr.Peer_Id, scope: tf.Scope, accept_offers: bool = false) -> Mesh_Error {
    if !m.ready {
        return .Not_Ready
    }

    if !tf.config_valid(scope, peer, m.cfg.transfer) {
        return .Invalid_Config
    }

    index := -1

    for p, i in m.peers {
        if p.ready && p.peer == peer {
            if p.scope == scope {
                slot := &m.peers[i]

                if !accept_offers {
                    mesh_clear_offer(slot)
                }

                slot.accept_offers = accept_offers
                return .None
            }

            index = i
            break
        }
    }

    if index < 0 {
        for p, i in m.peers {
            if !p.ready {
                index = i
                break
            }
        }
    }

    if index < 0 {
        return .Capacity
    }

    p := &m.peers[index]
    mesh_clear_offer(p)
    tf.sender_destroy(&p.sender)
    tf.blob_destroy(&p.receiver)
    p^ = {
        owner         = m,
        peer          = peer,
        scope         = scope,
        accept_offers = accept_offers,
    }
    limit := m.cache.cfg.max_asset_bytes + sc.HEADER_BYTES + m.ref_codec.wire_size

    if tf.sender_init(
           &p.sender,
           scope,
           peer,
           m.budget_wire,
           m.cfg.transfer,
           m.allocator,
           CONTENT_KIND,
           max_bytes = limit,
       ) !=
           .None ||
       tf.blob_init(
           &p.receiver,
           scope,
           peer,
           m.budget_wire,
           CONTENT_KIND,
           mesh_accept,
           p,
           m.cfg.transfer,
           m.allocator,
           max_bytes = limit,
       ) !=
           .None {
        tf.sender_destroy(&p.sender)
        tf.blob_destroy(&p.receiver)
        p^ = {}
        return .Invalid_Config
    }

    p.ready = true
    return .None
}

mesh_unbind :: proc(m: ^Mesh, peer: tr.Peer_Id) {
    for &p in m.peers {
        if p.ready && p.peer == peer {
            mesh_clear_offer(&p)
            tf.sender_destroy(&p.sender)
            tf.blob_destroy(&p.receiver)
            p = {}
            return
        }
    }
}

mesh_frame :: proc(m: ^Mesh, now_ms: u64) -> Mesh_Error {
    if !m.ready {
        return .Not_Ready
    }

    if m.time_set && now_ms < m.now {
        return .Invalid_Time
    }

    if !m.time_set {
        m.budget = f64(m.cfg.bytes_per_update)
    } else {
        m.budget = min(
            m.budget + f64(now_ms - m.now) * f64(m.cfg.bytes_per_second) / 1000,
            f64(m.cfg.bytes_per_update) * 2,
        )
    }

    m.time_set, m.now, m.remaining = true, now_ms, m.cfg.bytes_per_update
    received_bytes := 0

    for _ in 0 ..< m.cfg.packets_per_update {
        if received_bytes >= m.cfg.rx_bytes_per_update {
            break
        }

        packet := tr.receive(&m.wire, m.rxb[:])

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            m.stats.rejected += 1
            break
        }

        m.stats.rx_bytes += u64(packet.count)
        received_bytes += packet.count

        if packet.count > tf.CHUNK_BYTES + 128 || packet.channel != .Unreliable {
            m.stats.rejected += 1
            continue
        }

        p: ^Mesh_Peer

        for &candidate in m.peers {
            if candidate.ready && candidate.peer == packet.from {
                p = &candidate
                break
            }
        }

        if p == nil {
            m.stats.rejected += 1
            continue
        }

        bytes := m.rxb[:packet.count]
        meta, _, report := sc.inspect(bytes)

        if report.error != .None {
            m.stats.rejected += 1
            continue
        }

        if meta.kind == REQUEST_KIND {
            mesh_request(m, p, bytes)
        } else if meta.kind == ANNOUNCE_KIND {
            mesh_offer(m, p, bytes)
        } else {
            switch tf.destination(bytes) {
            case .Sender:
                tf.sender_receive(&p.sender, packet.from, bytes, now_ms)
            case .Receiver:
                tf.blob_receive(&p.receiver, packet.from, bytes, now_ms)
            case .None:
                m.stats.rejected += 1
            }
        }
    }

    // Requests share the mesh's aggregate output budget. The cursor prevents a
    // missing first reference or first peer from starving the remaining set.
    needs: [MAX_NEEDS]Ref
    need_count := m.count

    for w, i in m.watched[:m.count] {
        needs[i] = w.ref
    }

    for &p in m.peers {
        if !p.ready {
            continue
        }

        if p.offer != (Ref{}) && now_ms - p.offer_at >= m.cfg.transfer.timeout_ms {
            mesh_clear_offer(&p)
        }

        if p.offer != (Ref{}) {
            duplicate := false

            for ref in needs[:need_count] {
                if ref == p.offer {
                    duplicate = true
                    break
                }
            }

            if !duplicate {
                needs[need_count] = p.offer
                need_count += 1
            }
        }
    }

    attempts := len(m.peers) * max(need_count, 1)
    sent := 0

    for _ in 0 ..< attempts {
        index := m.request_cursor % attempts
        m.request_cursor = (index + 1) % attempts

        if need_count == 0 {
            break
        }

        p := &m.peers[index / need_count]
        ref := needs[index % need_count]

        if !p.ready || cache_has(m.cache, ref) || !tr.peer_connected(&m.wire, p.peer) {
            continue
        }

        at := index % need_count

        if p.requested[at] == ref && now_ms - p.request_at[at] < m.cfg.request_ms {
            continue
        }

        request := Request{p.scope.room, p.scope.binding, ref}
        buffer: [160]u8

        if sc.pack(&m.request_codec, request, {kind = REQUEST_KIND, epoch = p.scope.epoch, content = p.scope.content}, buffer[:]).error !=
           .None {
            return .Codec
        }

        if tr.send(&m.budget_wire, p.peer, .Unreliable, buffer[:sc.HEADER_BYTES + m.request_codec.wire_size]) ==
           .Sent {
            p.requested[at], p.request_at[at] = ref, now_ms
            m.stats.requests += 1
            sent += 1

            if sent >= m.cfg.requests_per_update {
                break
            }
        }
    }

    started := false

    for i in 0 ..< len(m.peers) {
        p := &m.peers[(m.send_cursor + i) % len(m.peers)]

        if !p.ready {
            continue
        }

        tf.blob_update(&p.receiver, now_ms)

        if m.local_count > 0 &&
           (!p.announce_sent || p.announce_version != m.local_version || now_ms - p.announce_at >= m.cfg.request_ms) {
            ref := m.local[p.announce_index % m.local_count]
            message := Request{p.scope.room, p.scope.binding, ref}
            buffer: [160]u8

            if sc.pack(&m.request_codec, message, {kind = ANNOUNCE_KIND, epoch = p.scope.epoch, content = p.scope.content}, buffer[:]).error !=
               .None {
                return .Codec
            }

            if tr.send(&m.budget_wire, p.peer, .Unreliable, buffer[:sc.HEADER_BYTES + m.request_codec.wire_size]) ==
               .Sent {
                p.announce_sent, p.announce_at, p.announce_version = true, now_ms, m.local_version
                p.announce_index = (p.announce_index + 1) % m.local_count
            }
        }

        if p.sender.phase == .Sending && !mesh_may_serve(m, p.peer, p.sending) {
            tf.sender_cancel(&p.sender)
        }

        if !started && p.sender.phase != .Sending && p.queue_count > 0 && tr.peer_connected(&m.wire, p.peer) {
            ref := p.queue[0]
            copy(p.queue[:], p.queue[1:p.queue_count])
            p.queue_count -= 1

            if mesh_may_serve(m, p.peer, ref) && cache_has(m.cache, ref) {
                started = true

                if err := mesh_start(m, p, ref); err != .None {
                    return err
                }
            }
        }

        tf.sender_update(&p.sender, now_ms)
    }

    m.send_cursor = (m.send_cursor + 1) % len(m.peers)
    return .None
}

@(private)
mesh_request :: proc(m: ^Mesh, p: ^Mesh_Peer, bytes: []u8) {
    request: Request
    _, report := sc.unpack(
        &m.request_codec,
        &request,
        bytes,
        {kind = REQUEST_KIND, epoch = p.scope.epoch, content = p.scope.content},
    )

    if report.error != .None ||
       request.room != p.scope.room ||
       request.binding != p.scope.binding ||
       !ref_valid(request.ref) {
        m.stats.rejected += 1
        return
    }

    if !mesh_may_serve(m, p.peer, request.ref) || !cache_has(m.cache, request.ref) {
        return
    }

    if p.sender.phase == .Sending && p.sending == request.ref {
        return
    }

    for ref in p.queue[:p.queue_count] {
        if ref == request.ref {
            return
        }
    }

    if p.queue_count == MAX_WATCHED {
        m.stats.rejected += 1
        return
    }

    p.queue[p.queue_count] = request.ref
    p.queue_count += 1
}

@(private)
mesh_start :: proc(m: ^Mesh, p: ^Mesh_Peer, ref: Ref) -> Mesh_Error {
    if p.sender.next_sequence == max(u64) {
        return .Capacity
    }

    bytes := make([]u8, sc.HEADER_BYTES + m.ref_codec.wire_size + int(ref.bytes), m.allocator)
    defer delete(bytes, m.allocator)
    body := bytes[sc.HEADER_BYTES:]

    if sc.encode(&m.ref_codec, ref, body[:m.ref_codec.wire_size]).error != .None ||
       cache_read(m.cache, ref, body[m.ref_codec.wire_size:]) != .None {
        return .Codec
    }

    if sc.pack_bytes(m.ref_codec.fingerprint, {kind = CONTENT_KIND, epoch = p.scope.epoch, tick = p.sender.next_sequence + 1, content = p.scope.content}, body, bytes).error !=
       .None {
        return .Codec
    }

    if tf.sender_begin(&p.sender, bytes, m.now) != .None {
        return .Transport
    }

    p.sending = ref
    m.stats.starts += 1
    return .None
}

@(private)
mesh_accept :: proc(user: rawptr, archive: tf.Archive, bytes: []u8) -> bool {
    p := cast(^Mesh_Peer)user
    m := p.owner
    _, body, report := sc.unpack_bytes(
        m.ref_codec.fingerprint,
        bytes,
        {kind = CONTENT_KIND, epoch = p.scope.epoch, content = p.scope.content},
    )

    if report.error != .None || len(body) < m.ref_codec.wire_size {
        return false
    }

    ref: Ref

    if sc.decode(&m.ref_codec, &ref, body[:m.ref_codec.wire_size]).error != .None ||
       !ref_valid(ref) ||
       int(ref.bytes) != len(body) - m.ref_codec.wire_size {
        return false
    }

    index := watched_index(m, ref)
    needed := index >= 0

    for peer in m.peers {
        if peer.ready && peer.offer == ref {
            needed = true
        }
    }

    if !needed {
        return false
    }

    payload := body[m.ref_codec.wire_size:]

    if reference(payload) != ref {
        p.error = .Integrity
        m.stats.rejected += 1
        return false
    }

    if m.validator != nil && !m.validator(m.validator_user, ref, payload) {
        p.error = .Invalid_Content
        m.stats.rejected += 1
        return false
    }

    cache_at := cache_index(m.cache, ref)
    pins := u32(0)

    if index >= 0 && !m.watched[index].pinned {
        pins += 1
    }

    for peer in m.peers {
        if peer.ready && peer.offer == ref && !peer.offer_pinned {
            pins += 1
        }
    }

    if cache_at >= 0 && m.cache.items[cache_at].pins > max(u32) - pins {
        return false
    }

    _, err := cache_put(m.cache, payload, ref)
    p.error = err

    if err != .None {
        return false
    }

    if index >= 0 && !m.watched[index].pinned {
        cache_pin(m.cache, ref)
        m.watched[index].pinned = true
    }

    for &peer in m.peers {
        if peer.ready && peer.offer == ref && !peer.offer_pinned {
            cache_pin(m.cache, ref)
            peer.offer_pinned = true
        }
    }

    m.stats.installed += 1
    return true
}

@(private)
mesh_may_serve :: proc(m: ^Mesh, peer: tr.Peer_Id, ref: Ref) -> bool {
    public := watched_index(m, ref) >= 0

    if !public {
        for entry in m.published[:m.published_count] {
            if entry == ref {
                public = true
                break
            }
        }
    }

    if !public {
        for entry in m.local[:m.local_count] {
            if entry == ref {
                public = true
                break
            }
        }
    }

    return public && (m.authorize == nil || m.authorize(m.policy_user, peer, ref))
}

@(private)
mesh_send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
    m := cast(^Mesh)user

    if !m.time_set || len(bytes) > m.remaining || f64(len(bytes)) > m.budget {
        m.stats.deferred += 1
        return .Backpressure
    }

    result := tr.send(&m.wire, to, channel, bytes)

    if result == .Sent {
        m.remaining -= len(bytes)
        m.budget -= f64(len(bytes))
        m.stats.tx_bytes += u64(len(bytes))
    }

    return result
}

@(private)
mesh_connected :: proc(user: rawptr, peer: tr.Peer_Id) -> bool {
    return tr.peer_connected(&(cast(^Mesh)user).wire, peer)
}

@(private)
mesh_status :: proc(user: rawptr) -> tr.Status {
    return tr.status(&(cast(^Mesh)user).wire)
}

// Local public assets offered before their references enter gameplay. A receiver
// opts in per admitted peer and holds at most one pending offer from that peer.
mesh_announce :: proc(m: ^Mesh, refs: []Ref) -> Mesh_Error {
    if !m.ready {
        return .Not_Ready
    }

    next: [MAX_WATCHED]Ref
    count := 0

    for ref in refs {
        if ref == (Ref{}) {
            continue
        }

        if !cache_has(m.cache, ref) {
            return .Invalid_Ref
        }

        duplicate := false

        for prior in next[:count] {
            if prior == ref {
                duplicate = true
                break
            }
        }

        if duplicate {
            continue
        }

        if count == MAX_WATCHED {
            return .Capacity
        }

        next[count] = ref
        count += 1
    }

    same := count == m.local_count

    if same {
        for ref, i in next[:count] {
            if ref != m.local[i] {
                same = false
                break
            }
        }
    }

    if !same {
        if m.local_version == max(u64) {
            return .Capacity
        }

        m.local, m.local_count = next, count
        m.local_version += 1
    }

    return .None
}

@(private)
mesh_clear_offer :: proc(p: ^Mesh_Peer) {
    if p.offer_pinned {
        cache_unpin(p.owner.cache, p.offer)
    }

    p.offer, p.offer_pinned, p.offer_at = {}, false, 0
}

@(private)
mesh_offer :: proc(m: ^Mesh, p: ^Mesh_Peer, bytes: []u8) {
    request: Request
    _, report := sc.unpack(
        &m.request_codec,
        &request,
        bytes,
        {kind = ANNOUNCE_KIND, epoch = p.scope.epoch, content = p.scope.content},
    )

    if !p.accept_offers ||
       report.error != .None ||
       request.room != p.scope.room ||
       request.binding != p.scope.binding ||
       !ref_valid(request.ref) ||
       request.ref.bytes > u32(m.cache.cfg.max_asset_bytes) {
        m.stats.rejected += 1
        return
    }

    if p.offer == request.ref {
        return
    }

    if p.offer != (Ref{}) && !cache_has(m.cache, p.offer) && m.now - p.offer_at < m.cfg.transfer.timeout_ms {
        return
    }

    mesh_clear_offer(p)
    p.offer, p.offer_at = request.ref, m.now

    if cache_has(m.cache, p.offer) && cache_pin(m.cache, p.offer) == .None {
        p.offer_pinned = true
    }
}

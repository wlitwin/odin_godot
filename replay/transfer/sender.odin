package replay_transfer

import compression "godot:replay/compress"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

sender_init :: proc(s: ^Sender, scope: Scope, target: tr.Peer_Id, wire: tr.Transport,
                    cfg := DEFAULT_CONFIG, allocator := context.allocator, archive_kind: u16 = 0, kind_base: u16 = DEFAULT_KIND_BASE, max_bytes: int = MAX_BYTES) -> Error {
	if s.ready || !config_valid(scope, target, cfg, kind_base, max_bytes) || archive_kind == 0 {return .Invalid_Config}
	s.allocator, s.scope, s.target, s.wire, s.cfg = allocator, scope, target, wire, cfg
	s.archive_kind, s.kind_base, s.max_bytes = archive_kind, kind_base, max_bytes
	if !codecs_init(&s.codecs, allocator) {sender_destroy(s); return .Invalid_Config}
	s.ready = true
	return .None
}

sender_destroy :: proc(s: ^Sender) {delete(s.bytes, s.allocator); delete(s.wire_bytes, s.allocator); codecs_destroy(&s.codecs); s^ = {}}

// Makes an owned copy. One archive is in flight at a time; cancel explicitly if
// replacing it. acknowledged continues to name the last fully validated receipt.
sender_begin :: proc(s: ^Sender, bytes: []u8, now_ms: u64, channel: tr.Channel = .Unreliable) -> Error {
	if !s.ready || s.phase == .Sending {return .Wrong_Phase}
 if channel>.Unreliable {return .Invalid_Config}
	if !clock_at(&s.clock, now_ms, s.cfg) {return .Invalid_Time}
	if len(bytes) > s.max_bytes {return .Capacity}
	meta, fingerprint, report := sc.inspect(bytes)
	if report.error != .None || meta.kind != s.archive_kind || meta.epoch != s.scope.epoch ||
	   meta.content != s.scope.content || meta.tick < s.highest_tick {return .Invalid_Archive}
	_, _, checked := sc.unpack_bytes(fingerprint, bytes, expected(s.scope, s.archive_kind))
	if checked.error != .None {return .Invalid_Archive}
	if s.next_sequence == max(u64) {return .Capacity}
	candidate := make([]u8, len(bytes), s.allocator)
	copy(candidate, bytes)
	delete(s.bytes, s.allocator)
	s.bytes = candidate
 delete(s.wire_bytes, s.allocator); s.wire_bytes = nil; s.wire_layout=0
 if s.compress {
  work := new(compression.Workspace, s.allocator); defer free(work, s.allocator)
  encoded := make([]u8, len(bytes), s.allocator)
  n, ok := compression.encode(candidate, encoded, work)
  if ok && n < len(bytes) {s.wire_bytes=make([]u8,n,s.allocator);copy(s.wire_bytes,encoded[:n])}
  if s.shuffle {
   id:=layout_signature(s.layout,len(candidate))
   if id!=0 {
    grouped:=make([]u8,len(candidate),s.allocator);defer delete(grouped,s.allocator)
    copy(grouped,candidate);offset,size:=s.layout.offset,s.layout.schema.wire_size
    if sc.shuffle(s.layout.schema,candidate[offset:offset+size],grouped[offset:offset+size]) {
     prior:=len(s.wire_bytes)>0 ? len(s.wire_bytes) : len(candidate)
     count,valid:=compression.encode(grouped,encoded,work)
     // Compared with an ordinary compressed offer, add the layout
     // signature; compared with a raw offer, add wire size as well.
     overhead:=len(s.wire_bytes)>0 ? 8 : 12
     if valid && count+overhead<prior {
      delete(s.wire_bytes,s.allocator);s.wire_bytes=make([]u8,count,s.allocator);copy(s.wire_bytes,encoded[:count])
      s.wire_layout=id;s.stats.shuffled_archives+=1;s.stats.shuffle_bytes_saved+=u64(prior-count)
     }
    }
   }
  }
  delete(encoded,s.allocator)
 }
	s.channel=channel
	s.next_sequence += 1
	s.archive = {sequence = s.next_sequence, tick = meta.tick, bytes = u32(len(bytes)), hash = hash(candidate)}
	s.highest_tick = meta.tick
	s.phase, s.error, s.remote_failure = .Sending, .None, .None
	s.started, s.offer_ever, s.offer_acked = now_ms, false, false
	s.acked, s.sent, s.sent_at = {}, {}, {}
	return .None
}

sender_cancel :: proc(s: ^Sender) {
	if !s.ready {return}
	delete(s.bytes, s.allocator)
	s.bytes = nil
 delete(s.wire_bytes, s.allocator); s.wire_bytes = nil; s.wire_layout=0
	s.phase, s.error = .Idle, .None
}

sender_update :: proc(s: ^Sender, now_ms: u64, max_output_bytes: u32 = max(u32)) -> Error {
	if !s.ready {return .Wrong_Phase}
	if !clock_at(&s.clock, now_ms, s.cfg) {return .Invalid_Time}
	if s.phase != .Sending {return .None}
	if now_ms - s.started >= s.cfg.timeout_ms {sender_fail(s, .Timeout); return .Timeout}
	if !tr.peer_connected(&s.wire, s.target) {return .Transport}
	remaining := int(min(s.cfg.bytes_per_update,max_output_bytes))
	if !s.offer_ever || ((s.channel==.Unreliable || !s.offer_acked) && now_ms-s.offer_sent>=s.cfg.retry_ms) {
		value := Offer{key = key_for(s.scope), version = PROTOCOL_VERSION, chunk_bytes = CHUNK_BYTES, archive = s.archive,
		               retain_sequence = s.acknowledged.archive.sequence, retain_hash = s.acknowledged.archive.hash}
		sent: bool
  if s.wire_layout!=0 {
   sent=send_value(&s.wire,s.target,&s.codecs.shuffled_offer,Shuffled_Offer{value,u32(len(s.wire_bytes)),s.wire_layout},s.scope,s.kind_base+u16(Kind.Shuffled_Offer),s.archive.tick,s.txb[:],&s.clock,&remaining,&s.stats,s.channel)
  } else if len(s.wire_bytes)>0 {
   sent=send_value(&s.wire,s.target,&s.codecs.compressed_offer,Compressed_Offer{value,u32(len(s.wire_bytes))},s.scope,s.kind_base+u16(Kind.Compressed_Offer),s.archive.tick,s.txb[:],&s.clock,&remaining,&s.stats,s.channel)
  } else {
   sent=send_value(&s.wire,s.target,&s.codecs.offer,value,s.scope,s.kind_base+u16(Kind.Offer),s.archive.tick,s.txb[:],&s.clock,&remaining,&s.stats,s.channel)
  }
  if sent {
			if s.offer_ever {s.stats.retries += 1}
			s.offer_sent, s.offer_ever = now_ms, true
		}
	}
	if !s.offer_acked {return .None}
	first := 0
	count := chunk_count(len(sender_wire_bytes(s)))
	for first < count && s.acked[first] {first += 1}
	for index in first ..< min(count, first + int(s.cfg.window)) {
		if s.acked[index] || (s.sent[index] && (s.channel==.Reliable || now_ms - s.sent_at[index] < s.cfg.retry_ms)) {continue}
		header := Chunk{key_for(s.scope), s.archive.sequence, u16(index)}
		wire_bytes := sender_wire_bytes(s)
		size := min(CHUNK_BYTES, len(wire_bytes) - index * CHUNK_BYTES)
		body := s.txb[sc.HEADER_BYTES:sc.HEADER_BYTES + s.codecs.chunk.wire_size + size]
		if sc.encode(&s.codecs.chunk, header, body[:s.codecs.chunk.wire_size]).error != .None {return .Invalid_Archive}
		copy(body[s.codecs.chunk.wire_size:], wire_bytes[index * CHUNK_BYTES:index * CHUNK_BYTES + size])
		meta := sc.Envelope_Meta{kind = s.kind_base + u16(Kind.Chunk), epoch = s.scope.epoch, tick = s.archive.tick, content = s.scope.content}
		if sc.pack_bytes(s.codecs.chunk.fingerprint, meta, body, s.txb[:]).error != .None {return .Invalid_Archive}
		if !send(&s.wire, s.target, s.txb[:sc.HEADER_BYTES + len(body)], &s.clock, &remaining, &s.stats,s.channel) {break}
		if s.sent[index] {s.stats.retries += 1}
		s.sent[index], s.sent_at[index] = true, now_ms
	}
	return .None
}

sender_receive :: proc(s: ^Sender, from: tr.Peer_Id, bytes: []u8, now_ms: u64) -> Received {
	if !s.ready || !handles(bytes, s.kind_base) {return .Ignored}
	s.stats.rx_packets += 1; s.stats.rx_bytes += u64(len(bytes))
	if len(bytes) > CHUNK_BYTES + 128 || from != s.target || s.phase != .Sending || !clock_at(&s.clock, now_ms, s.cfg) {s.stats.rejected += 1; return .Rejected}
	if now_ms - s.started >= s.cfg.timeout_ms {sender_fail(s, .Timeout); s.stats.rejected += 1; return .Rejected}
	meta, _, _ := sc.inspect(bytes)
	if meta.tick != s.archive.tick {s.stats.rejected += 1; return .Rejected}
	#partial switch Kind(meta.kind - s.kind_base) {
	case .Progress:
		packet: Progress
		_, report := sc.unpack(&s.codecs.progress, &packet, bytes, expected(s.scope, meta.kind))
		if report.error != .None || packet.key != key_for(s.scope) || packet.sequence != s.archive.sequence {break}
		if packet.group == OFFER_GROUP {
			if packet.mask != 0 {break}
			s.offer_acked = true
			return .Accepted
		}
		count := chunk_count(len(sender_wire_bytes(s)))
		if int(packet.group) >= (count + 63) / 64 {break}
		bits := min(64, count - int(packet.group) * 64)
		if bits < 64 && packet.mask >> uint(bits) != 0 {break}
		// An ACK cannot acknowledge a chunk that has never left the sender.
		for bit in 0 ..< bits {if packet.mask & (u64(1) << uint(bit)) != 0 && !s.sent[int(packet.group) * 64 + bit] {s.stats.rejected += 1; return .Rejected}}
		for bit in 0 ..< bits {if packet.mask & (u64(1) << uint(bit)) != 0 {s.acked[int(packet.group) * 64 + bit] = true}}
		return .Accepted
	case .Ready:
		packet: Ready
		_, report := sc.unpack(&s.codecs.ready, &packet, bytes, expected(s.scope, meta.kind))
		if report.error != .None || packet.key != key_for(s.scope) || packet.archive != s.archive {break}
		s.acknowledged = {s.archive, now_ms}
		s.phase = .Complete
		return .Validated
	case .Failed:
		packet: Failed
		_, report := sc.unpack(&s.codecs.failure, &packet, bytes, expected(s.scope, meta.kind))
		if report.error != .None || packet.key != key_for(s.scope) || packet.sequence != s.archive.sequence || packet.reason == .None {break}
		s.remote_failure = packet.reason
		sender_fail(s, .Remote_Rejected)
		return .Accepted
	}
	s.stats.rejected += 1
	return .Rejected
}

@(private)
sender_fail :: proc(s: ^Sender, error: Error) {s.phase, s.error = .Failed, error; s.stats.failures += 1}

@(private)
sender_wire_bytes :: proc(s:^Sender)->[]u8 {return len(s.wire_bytes)>0 ? s.wire_bytes : s.bytes}

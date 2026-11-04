package replay_transfer

import "core:mem"
import replay "godot:replay"
import compression "godot:replay/compress"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

// Bounded canonical blob transport. accept must install a validated candidate
// atomically, borrow bytes only during the call, and return false on failure.
// This owner and its callback user must remain at stable addresses.
Blob_Receiver :: struct {
 ownership:Ownership,
 owner_state:Ownership_State,
	allocator: mem.Allocator,
	budget:Budget_State,
	last_error:Error,
	ready: bool,
	scope: Scope,
	source: tr.Peer_Id,
	wire: tr.Transport,
	cfg: Config,
	archive_kind, kind_base: u16,
	max_bytes: int,
	user: rawptr,
	accept: proc(user: rawptr, archive: Archive, bytes: []u8) -> bool,
	codecs: Codecs,
	clock: Clock,
	latest, previous_receipt: Receipt,
	active: bool,
	offer: Offer,
	highest_sequence, started: u64,
	bytes: []u8,
	decoded, decode_scratch: []u8, // lazy, each bounded by max_bytes
	wire_size, latest_wire_size: int,
	compressed: bool,
	reliable_replies: bool, // upgrade only within an admitted scope
	layout: Layout, // immutable borrowed schema for the receiver lifetime
	offer_layout: u64,
	groups: [GROUPS]u64,
	count: int,
	progress_pending: [GROUPS]bool,
	offer_pending, ready_pending, failure_pending: bool,
	ready_archive: Archive,
	failure_sequence, failure_tick: u64,
	failure: Failure,
	stats: Stats,
	txb: [CHUNK_BYTES + 128]u8,
}

blob_init :: proc(r: ^Blob_Receiver, scope: Scope, source: tr.Peer_Id, wire: tr.Transport, archive_kind: u16,
                  accept: proc(user: rawptr, archive: Archive, bytes: []u8) -> bool, user: rawptr,
                  cfg := DEFAULT_CONFIG, allocator := context.allocator, kind_base: u16 = DEFAULT_KIND_BASE, max_bytes: int = MAX_BYTES,budget:Budget={},ownership:Ownership={}) -> Error {
	if r.owner_state.cleanup || r.ready || !config_valid(scope, source, cfg, kind_base, max_bytes) || archive_kind == 0 || accept == nil {return .Invalid_Config}
 if error:=ownership_entry(ownership,allocator,r,wire.user,user,nil,budget.user);error!=.None{return error}
 r.ownership=ownership
 if error:=ownership_retain(&r.owner_state,ownership);error!=.None{
  retained:=r.owner_state.retains;r^={}
  if replay.owner_retains_drop(&retained)!=.None{r.owner_state={retains=retained,cleanup=true}}
  return error
 }
 committed_owner:=false;defer if !committed_owner{blob_destroy(r)}

	r.allocator, r.scope, r.source, r.wire, r.cfg = allocator, scope, source, wire, cfg
	r.archive_kind, r.accept, r.user = archive_kind, accept, user
	r.kind_base, r.max_bytes = kind_base, max_bytes
	if error:=budget_begin(&r.budget,budget,u64(size_of(Blob_Receiver)));error!=.None{return error}
	schema_allocator,error:=budget_schema_allocator(&r.budget,allocator)
	if error!=.None{return error}
	if !codecs_init(&r.codecs, schema_allocator) { return .Invalid_Config}
	r.bytes,error=budget_alloc(&r.budget,max_bytes,allocator)
	if error!=.None{return error}
 committed_owner=true
	r.ready = true
	return .None
}

blob_destroy :: proc(r: ^Blob_Receiver) -> Error {
 when #config(BOX3D_REQUIRE_DOMAIN,false){
  if !r.ready && replay.owner_is_nil(r.ownership.container.owner) && r.owner_state.retains.count==0 && !r.budget.attached{return .None}
 }
 if error:=blob_owner_entry(r,.Read);error!=.None{return error}
 if r.owner_state.cleanup {
  state:=r.owner_state;r^={}
  if replay.owner_retains_drop(&state.retains)!=.None{r.owner_state=state;return .Invalid_Config}
  return .None
 }
	budget_free(&r.budget,&r.bytes,r.allocator);budget_free(&r.budget,&r.decoded,r.allocator);budget_free(&r.budget,&r.decode_scratch,r.allocator)
	codecs_destroy(&r.codecs);budget_end(&r.budget,r.allocator)
 state:=r.owner_state;r^={}
 if replay.owner_retains_drop(&state.retains)!=.None{state.cleanup=true;r.owner_state=state;return .Invalid_Config}
 return .None
}
// Attach a previously native-free owner before using it in a complete runtime.
blob_budget_attach :: proc(r:^Blob_Receiver,budget:Budget)->Error {
 if error:=blob_owner_entry(r);error!=.None{return error}
 if replay.owned_context_access(r.ownership.budget,budget.user,!replay.owner_is_nil(r.ownership.container.owner),.Execute)!=.None{return .Invalid_Config}
	if !r.ready{return .Wrong_Phase}
	return budget_begin(&r.budget,budget,u64(size_of(Blob_Receiver))+budget_codecs_bytes(&r.codecs)+u64(len(r.bytes)+len(r.decoded)+len(r.decode_scratch)))
}

// Reliable delivery is an explicit caller capability. Valid traffic can upgrade
// replies for this scope; delayed older datagrams cannot downgrade that choice.
blob_receive :: proc(r:^Blob_Receiver,from:tr.Peer_Id,bytes:[]u8,now_ms:u64,channel:tr.Channel=.Unreliable)->Received {
 if error:=blob_owner_entry(r);error!=.None{return .Rejected}
 if channel>.Unreliable {return .Rejected}
 result:=blob_receive_packet(r,from,bytes,now_ms)
 if channel==.Reliable && (result==.Accepted || result==.Validated) {r.reliable_replies=true}
 return result
}

@(private)
blob_receive_packet :: proc(r: ^Blob_Receiver, from: tr.Peer_Id, bytes: []u8, now_ms: u64) -> Received {
 if error:=blob_owner_entry(r);error!=.None{return .Rejected}
	if !r.ready || !handles(bytes, r.kind_base) {return .Ignored}
	r.stats.rx_packets += 1; r.stats.rx_bytes += u64(len(bytes))
	if len(bytes) > CHUNK_BYTES + 128 || from != r.source || !clock_at(&r.clock, now_ms, r.cfg) {r.stats.rejected += 1; return .Rejected}
	if r.active && now_ms - r.started >= r.cfg.timeout_ms {blob_fail(r, .Timeout)}
	meta, _, _ := sc.inspect(bytes)
	#partial switch Kind(meta.kind - r.kind_base) {
	case .Offer, .Compressed_Offer, .Shuffled_Offer:
  packet: Offer
  wire_size: int
  compressed := meta.kind != r.kind_base+u16(Kind.Offer)
  layout_id:=u64(0)
  if meta.kind==r.kind_base+u16(Kind.Shuffled_Offer) {
   encoded: Shuffled_Offer
   _, report:=sc.unpack(&r.codecs.shuffled_offer,&encoded,bytes,expected(r.scope,meta.kind))
   if report.error!=.None {break}
   packet,wire_size,layout_id=encoded.offer,int(encoded.wire_bytes),encoded.layout
   if layout_id==0 || layout_id!=layout_signature(r.layout,int(packet.archive.bytes)) || wire_size<6 || wire_size>=int(packet.archive.bytes) {break}
  } else if compressed {
   encoded: Compressed_Offer
   _, report := sc.unpack(&r.codecs.compressed_offer,&encoded,bytes,expected(r.scope,meta.kind))
   if report.error!=.None {break}
   packet,wire_size=encoded.offer,int(encoded.wire_bytes)
   if wire_size<6 || wire_size>=int(packet.archive.bytes) {break}
  } else {
   _, report := sc.unpack(&r.codecs.offer,&packet,bytes,expected(r.scope,meta.kind))
   if report.error!=.None {break}
   wire_size=int(packet.archive.bytes)
  }
		if packet.key != key_for(r.scope) || packet.version != PROTOCOL_VERSION || packet.chunk_bytes != CHUNK_BYTES || packet.archive.sequence == 0 ||
		   packet.archive.tick != meta.tick || packet.archive.bytes < sc.HEADER_BYTES || packet.archive.bytes > u32(r.max_bytes) {break}
		if packet.archive == r.latest.archive || packet.archive == r.previous_receipt.archive {
			r.ready_archive, r.ready_pending = packet.archive, true
			return .Accepted
		}
		if packet.archive.sequence == r.highest_sequence {
			if packet != r.offer || wire_size!=r.wire_size || compressed!=r.compressed || layout_id!=r.offer_layout {break}
			if r.active {r.offer_pending = true; return .Accepted}
			if r.failure_sequence == packet.archive.sequence {r.failure_pending = true; return .Accepted}
			break
		}
		if packet.archive.sequence < r.highest_sequence || packet.archive.tick < r.latest.archive.tick {break}
		zero_hash: [32]u8
		if packet.retain_sequence == 0 {
			if packet.retain_hash != zero_hash {break}
		} else if packet.retain_sequence >= packet.archive.sequence || !blob_retained(r, packet.retain_sequence, packet.retain_hash) {
			r.failure_sequence, r.failure_tick, r.failure, r.failure_pending = packet.archive.sequence, packet.archive.tick, .Retention, true
			r.stats.rejected += 1
			return .Rejected
		}
		r.offer, r.highest_sequence, r.started, r.active = packet, packet.archive.sequence, now_ms, true
  r.wire_size,r.compressed,r.offer_layout=wire_size,compressed,layout_id
		r.groups, r.progress_pending, r.count = {}, {}, 0
		r.offer_pending, r.ready_pending, r.failure_pending = true, false, false
		return .Accepted
	case .Chunk:
		_, body, report := sc.unpack_bytes(r.codecs.chunk.fingerprint, bytes, expected(r.scope, meta.kind))
		if report.error != .None || len(body) < r.codecs.chunk.wire_size {break}
		header: Chunk
		if sc.decode(&r.codecs.chunk, &header, body[:r.codecs.chunk.wire_size]).error != .None || header.key != key_for(r.scope) {break}
		if r.latest.archive.sequence != 0 && header.sequence == r.latest.archive.sequence && meta.tick == r.latest.archive.tick {
			if int(header.index) >= chunk_count(r.latest_wire_size) || len(body) != r.codecs.chunk.wire_size +
			   min(CHUNK_BYTES, r.latest_wire_size - int(header.index) * CHUNK_BYTES) {break}
			r.ready_archive, r.ready_pending = r.latest.archive, true
			return .Accepted
		}
		if !r.active || header.sequence != r.offer.archive.sequence || meta.tick != r.offer.archive.tick || int(header.index) >= chunk_count(r.wire_size) {break}
		start := int(header.index) * CHUNK_BYTES
		size := min(CHUNK_BYTES, r.wire_size - start)
		payload := body[r.codecs.chunk.wire_size:]
		if len(payload) != size {break}
		group, bit := int(header.index) / 64, uint(header.index % 64)
		if r.groups[group] & (u64(1) << bit) != 0 {
			for value, i in payload {if r.bytes[start + i] != value {blob_fail(r, .Integrity); return .Rejected}}
			r.stats.duplicates += 1
		} else {
			copy(r.bytes[start:start + size], payload)
			r.groups[group] |= u64(1) << bit
			r.count += 1
		}
		r.progress_pending[group] = true
		if r.count != chunk_count(r.wire_size) {return .Accepted}
		archive_bytes := r.bytes[:r.offer.archive.bytes]
  if r.compressed {
   if len(r.decoded)==0 {
    decoded,error:=budget_alloc(&r.budget,r.max_bytes,r.allocator)
    if error!=.None {r.last_error=.Capacity;blob_fail(r,.Archive);return .Rejected}
    scratch,scratch_error:=budget_alloc(&r.budget,r.max_bytes,r.allocator)
    if scratch_error!=.None {budget_free(&r.budget,&decoded,r.allocator);r.last_error=.Capacity;blob_fail(r,.Archive);return .Rejected}
    r.decoded,r.decode_scratch=decoded,scratch
   }
   archive_bytes=r.decoded[:r.offer.archive.bytes]
   if !compression.decode(r.bytes[:r.wire_size],archive_bytes,r.decode_scratch) {blob_fail(r,.Integrity);return .Rejected}
  }
		if r.offer_layout!=0 {
   if r.offer_layout!=layout_signature(r.layout,len(archive_bytes)) {blob_fail(r,.Archive);return .Rejected}
   offset,size:=r.layout.offset,r.layout.schema.wire_size
   if !sc.unshuffle(r.layout.schema,archive_bytes[offset:offset+size],r.decode_scratch[:size]) {blob_fail(r,.Archive);return .Rejected}
   copy(archive_bytes[offset:offset+size],r.decode_scratch[:size])
  }
  if hash(archive_bytes) != r.offer.archive.hash {blob_fail(r, .Integrity); return .Rejected}
		blob_meta, fingerprint, inspected := sc.inspect(archive_bytes)
		if inspected.error != .None || blob_meta.kind != r.archive_kind || blob_meta.epoch != r.scope.epoch || blob_meta.content != r.scope.content || blob_meta.tick != r.offer.archive.tick {
			blob_fail(r, .Archive); return .Rejected
		}
		_, _, decoded := sc.unpack_bytes(fingerprint, archive_bytes, expected(r.scope, r.archive_kind))
		if decoded.error != .None || !r.accept(r.user, r.offer.archive, archive_bytes) {blob_fail(r, .Archive); return .Rejected}
		// The consumer installed this value transactionally. Retain receipts so
		// lost Ready replies and sender retention references remain idempotent.
		if r.offer.retain_sequence == 0 || r.offer.retain_sequence == r.latest.archive.sequence {r.previous_receipt = r.latest}
		r.latest = {r.offer.archive, now_ms}
  r.latest_wire_size=r.wire_size
		r.active, r.offer_pending, r.progress_pending = false, false, {}
		r.ready_archive, r.ready_pending = r.offer.archive, true
		if r.offer_layout!=0 {r.stats.shuffled_archives+=1}
		r.stats.validated += 1; r.stats.validated_bytes += u64(len(archive_bytes))
		return .Validated
	}
	r.stats.rejected += 1
	return .Rejected
}

blob_update :: proc(r: ^Blob_Receiver, now_ms: u64) -> Error {
 if error:=blob_owner_entry(r);error!=.None{return error}
	if !r.ready {return .Wrong_Phase}
	if !clock_at(&r.clock, now_ms, r.cfg) {return .Invalid_Time}
	if r.active && now_ms - r.started >= r.cfg.timeout_ms {blob_fail(r, .Timeout)}
	if !tr.peer_connected(&r.wire, r.source) {return .Transport}
	remaining := int(r.cfg.bytes_per_update)
 channel:=r.reliable_replies ? tr.Channel.Reliable : tr.Channel.Unreliable
	if r.ready_pending {
		packet := Ready{key_for(r.scope), r.ready_archive}
		if send_value(&r.wire, r.source, &r.codecs.ready, packet, r.scope, r.kind_base + u16(Kind.Ready), packet.archive.tick,
		              r.txb[:], &r.clock, &remaining, &r.stats,channel) {r.ready_pending = false}
	}
	if r.failure_pending {
		packet := Failed{key_for(r.scope), r.failure_sequence, r.failure}
		if send_value(&r.wire, r.source, &r.codecs.failure, packet, r.scope, r.kind_base + u16(Kind.Failed), r.failure_tick,
		              r.txb[:], &r.clock, &remaining, &r.stats,channel) {r.failure_pending = false}
	}
	if r.offer_pending {
		packet := Progress{key = key_for(r.scope), sequence = r.offer.archive.sequence, group = OFFER_GROUP}
		if send_value(&r.wire, r.source, &r.codecs.progress, packet, r.scope, r.kind_base + u16(Kind.Progress), r.offer.archive.tick,
		              r.txb[:], &r.clock, &remaining, &r.stats,channel) {r.offer_pending = false}
	}
	for pending, i in r.progress_pending {
		if !pending {continue}
		packet := Progress{key_for(r.scope), r.offer.archive.sequence, u16(i), r.groups[i]}
		if send_value(&r.wire, r.source, &r.codecs.progress, packet, r.scope, r.kind_base + u16(Kind.Progress), r.offer.archive.tick,
		              r.txb[:], &r.clock, &remaining, &r.stats,channel) {r.progress_pending[i] = false}
	}
	return .None
}

@(private)
blob_retained :: proc(r: ^Blob_Receiver, sequence: u64, digest: [32]u8) -> bool {
 if error:=blob_owner_entry(r);error!=.None{return false}
	return (r.latest.archive.sequence == sequence && r.latest.archive.hash == digest) ||
	       (r.previous_receipt.archive.sequence == sequence && r.previous_receipt.archive.hash == digest)
}

@(private)
blob_fail :: proc(r: ^Blob_Receiver, failure: Failure) {
 if error:=blob_owner_entry(r);error!=.None{return}
	r.active, r.offer_pending, r.progress_pending = false, false, {}
	r.failure_sequence, r.failure_tick, r.failure, r.failure_pending = r.offer.archive.sequence, r.offer.archive.tick, failure, true
	r.stats.failures += 1
}

@(private)
blob_owner_entry :: proc(r:^Blob_Receiver,access:replay.Owner_Access=.Execute)->Error {
 if r==nil{return .Invalid_Config}
 if r.owner_state.cleanup{return access==.Read && replay.owner_retains_access(&r.owner_state.retains,.Read)==.None?Error.None:Error.Invalid_Config}
 return ownership_entry(r.ownership,r.allocator,r,r.wire.user,r.user,r.layout.schema,r.budget.hooks.user,access)
}

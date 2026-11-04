package replay_transfer

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

MAX_BYTES :: 1024 * 1024
DEFAULT_KIND_BASE :: u16(0x5200)
CHUNK_BYTES :: 1024
PROTOCOL_VERSION :: u16(1)
MAX_CHUNKS :: (MAX_BYTES + CHUNK_BYTES - 1) / CHUNK_BYTES
GROUPS :: (MAX_CHUNKS + 63) / 64
OFFER_GROUP :: max(u16)

// The application binds this scope to an admitted peer. Binding identifies the
// connection incarnation, not just a reusable transport ID. These fields reject
// mismatched traffic; they do not authenticate a peer or elect an authority.
Scope :: struct {room, epoch, binding, content: u64}
Archive :: struct {sequence, tick: u64, bytes: u32, hash: [32]u8}
Receipt :: struct {archive: Archive, at_ms: u64}
Config :: struct {retry_ms, timeout_ms: u64, bytes_per_second, bytes_per_update, window: u32}
DEFAULT_CONFIG :: Config{150, 30000, 128 * 1024, 8192, 32}
Error :: enum {None, Invalid_Config, Wrong_Phase, Invalid_Archive, Capacity, Invalid_Time, Transport, Timeout, Remote_Rejected}
Phase :: enum u8 {Idle, Sending, Complete, Failed}
Received :: enum {Ignored, Accepted, Rejected, Validated}
Failure :: enum u8 {None, Integrity, Archive, Timeout, Retention}
Stats :: struct {
	tx_packets, tx_bytes, rx_packets, rx_bytes, rejected, duplicates, retries, deferred: u64,
	validated, validated_bytes, failures: u64,
	shuffled_archives, shuffle_bytes_saved: u64,
}

Sender :: struct {
 ownership:Ownership,
 owner_state:Ownership_State,
	allocator: mem.Allocator,
	budget:Budget_State,
	ready: bool,
	scope: Scope,
	target: tr.Peer_Id,
	wire: tr.Transport, // borrowed: destroy does not close it
	channel: tr.Channel, // latched by sender_begin; do not change in flight
	cfg: Config,
	archive_kind, kind_base: u16,
	max_bytes: int,
	codecs: Codecs,
	clock: Clock,
	phase: Phase,
	error: Error,
	remote_failure: Failure,
	next_sequence, highest_tick: u64,
	archive: Archive,
	acknowledged: Receipt,
	bytes: []u8, // owned canonical archive
	compress: bool, // opt in only when the recipient supports compressed offers
	shuffle: bool, // additionally requires peer support for this layout
	layout: Layout, // immutable borrowed schema, used only by sender_begin
	wire_layout: u64, // selected representation for the active archive
	wire_bytes: []u8, // owned compressed representation, nil for ordinary offers
	started, offer_sent: u64,
	offer_ever, offer_acked: bool,
	acked: [MAX_CHUNKS]bool,
	sent: [MAX_CHUNKS]bool,
	sent_at: [MAX_CHUNKS]u64,
	stats: Stats,
	txb: [CHUNK_BYTES + 128]u8,
}

@(private)
Clock :: struct {set: bool, now: u64, budget: f64}
@(private)
Codecs :: struct {offer, compressed_offer, shuffled_offer, chunk, progress, ready, failure: sc.Schema}
@(private)
Key :: struct {room, binding: u64}
@(private)
Offer :: struct {key: Key, version, chunk_bytes: u16, archive: Archive, retain_sequence: u64, retain_hash: [32]u8}
@(private)
Compressed_Offer :: struct {offer: Offer, wire_bytes: u32}
@(private)
Shuffled_Offer :: struct {offer: Offer, wire_bytes: u32, layout: u64}
@(private)
Chunk :: struct {key: Key, sequence: u64, index: u16}
@(private)
Progress :: struct {key: Key, sequence: u64, group: u16, mask: u64}
@(private)
Ready :: struct {key: Key, archive: Archive}
@(private)
Failed :: struct {key: Key, sequence: u64, reason: Failure}

@(private)
Kind :: enum u16 {Offer = 1, Chunk, Progress, Ready, Failed, Compressed_Offer, Shuffled_Offer}

Destination :: enum {None, Sender, Receiver}
// Untrusted routing hint only. The selected consumer validates again.
destination :: proc(bytes: []u8, kind_base: u16 = DEFAULT_KIND_BASE) -> Destination {
	if !handles(bytes, kind_base) {return .None}
	meta, _, _ := sc.inspect(bytes)
	return (meta.kind <= kind_base + u16(Kind.Chunk) || meta.kind == kind_base + u16(Kind.Compressed_Offer) || meta.kind == kind_base + u16(Kind.Shuffled_Offer)) ? .Receiver : .Sender
}

// A demultiplexer can route these packets before the gameplay runner consumes
// its transport. Untrusted inspection is routing only; receive validates again.
handles :: proc(bytes: []u8, kind_base: u16 = DEFAULT_KIND_BASE) -> bool {
	meta, _, report := sc.inspect(bytes)
	return report.error == .None && kind_base > 0 && kind_base <= max(u16) - u16(Kind.Shuffled_Offer) && meta.kind > kind_base && meta.kind <= kind_base + u16(Kind.Shuffled_Offer)
}

config_valid :: proc(scope: Scope, peer: tr.Peer_Id, cfg: Config, kind_base: u16 = DEFAULT_KIND_BASE, max_bytes: int = MAX_BYTES) -> bool {
	return kind_base > 0 && kind_base <= max(u16) - u16(Kind.Shuffled_Offer) && max_bytes >= sc.HEADER_BYTES && max_bytes <= MAX_BYTES && scope.room != 0 && scope.epoch != 0 && scope.binding != 0 && scope.content != 0 && peer != 0 &&
	       cfg.retry_ms >= 10 && cfg.retry_ms <= 10000 && cfg.timeout_ms >= cfg.retry_ms * 4 && cfg.timeout_ms <= 120000 &&
	       cfg.bytes_per_second >= 2048 && cfg.bytes_per_second <= 16 * 1024 * 1024 &&
	       cfg.bytes_per_update >= CHUNK_BYTES + 128 && cfg.bytes_per_update <= 1024 * 1024 && cfg.window >= 1 && cfg.window <= 128
}

@(private)
clock_at :: proc(c: ^Clock, now: u64, cfg: Config) -> bool {
	if c.set && now < c.now {return false}
	if !c.set {c.budget = f64(cfg.bytes_per_update)} else {
		c.budget = min(c.budget + f64(now - c.now) * f64(cfg.bytes_per_second) / 1000, f64(cfg.bytes_per_update) * 2)
	}
	c.set, c.now = true, now
	return true
}

@(private)
key_for :: proc(scope: Scope) -> Key {return {scope.room, scope.binding}}
@(private)
chunk_count :: proc(bytes: int) -> int {return (bytes + CHUNK_BYTES - 1) / CHUNK_BYTES}

// Optional allocation accounting. Hooks never affect wire bytes or pacing.
// Each owner acquires its own lease; callback metadata must remain immutable and
// valid until drop. Nil hooks preserve the ordinary native-free behavior.
Budget :: struct {
	user:rawptr,
	reserve:proc(rawptr,u64)->bool,
	release:proc(rawptr,u64),
	acquire:proc(rawptr)->bool,
	drop:proc(rawptr),
}
Budget_State :: struct {
	hooks:Budget,
	bytes,denied:u64,
	attached,leased:bool,
	schema_memory:[]u8,
	schema_arena:mem.Arena,
}
SCHEMA_ARENA_BYTES :: 512*1024

@(private)
budget_begin :: proc(state:^Budget_State,hooks:Budget,retained:u64)->Error {
	if (hooks.reserve==nil)!=(hooks.release==nil) || (hooks.acquire==nil)!=(hooks.drop==nil){return .Invalid_Config}
	if hooks.reserve==nil {if hooks.acquire!=nil{return .Invalid_Config};return .None}
	if state.attached {return state.hooks.user==hooks.user && state.hooks.reserve==hooks.reserve && state.hooks.release==hooks.release && state.hooks.acquire==hooks.acquire && state.hooks.drop==hooks.drop ? .None:.Invalid_Config}
	if hooks.acquire!=nil && !hooks.acquire(hooks.user){return .Capacity}
	if !hooks.reserve(hooks.user,retained){if hooks.drop!=nil{hooks.drop(hooks.user)};state.denied+=1;return .Capacity}
	state.hooks=hooks;state.bytes=retained;state.attached=true;state.leased=hooks.acquire!=nil
	return .None
}
@(private)
budget_add :: proc(state:^Budget_State,bytes:u64)->bool {
	if !state.attached{return true}
	if bytes>max(u64)-state.bytes || !state.hooks.reserve(state.hooks.user,bytes){state.denied+=1;return false}
	state.bytes+=bytes;return true
}
@(private)
budget_sub :: proc(state:^Budget_State,bytes:u64){
	if !state.attached{return};assert(state.bytes>=bytes);state.bytes-=bytes;state.hooks.release(state.hooks.user,bytes)
}
@(private)
budget_alloc :: proc(state:^Budget_State,n:int,allocator:mem.Allocator)->([]u8,Error){
	if n==0{return nil,.None}
	if n<0 || !budget_add(state,u64(n)){return nil,.Capacity}
	bytes,error:=mem.alloc_bytes(n,allocator=allocator)
	if error!=.None || len(bytes)!=n {if len(bytes)!=0{delete(bytes,allocator)};budget_sub(state,u64(n));return nil,.Capacity}
	return bytes,.None
}
@(private)
budget_free :: proc(state:^Budget_State,bytes:^[]u8,allocator:mem.Allocator){
	n:=len(bytes^);if n==0{bytes^=nil;return};delete(bytes^,allocator);bytes^=nil;budget_sub(state,u64(n))
}
@(private)
budget_end :: proc(state:^Budget_State,allocator:mem.Allocator){
	budget_free(state,&state.schema_memory,allocator)
	if state.attached {state.hooks.release(state.hooks.user,state.bytes);if state.leased {state.hooks.drop(state.hooks.user)}}
	state^={}
}
@(private)
budget_schema_allocator :: proc(state:^Budget_State,allocator:mem.Allocator)->(mem.Allocator,Error){
	if !state.attached{return allocator,.None}
	memory,error:=budget_alloc(state,SCHEMA_ARENA_BYTES,allocator)
	if error!=.None{return {},error}
	state.schema_memory=memory;mem.arena_init(&state.schema_arena,memory)
	return mem.arena_allocator(&state.schema_arena),.None
}
@(private)
budget_array_bytes :: proc(array:[dynamic]$T)->u64{return u64(cap(array))*u64(size_of(T))}
@(private)
budget_schema_bytes :: proc(s:^sc.Schema)->u64 {
	bytes:=budget_array_bytes(s.fields)+budget_array_bytes(s.checks)+budget_array_bytes(s.validation)+budget_array_bytes(s.validation_blocks)+budget_array_bytes(s.spans)+budget_array_bytes(s.arrays)+budget_array_bytes(s.canonical)+budget_array_bytes(s.unions)+budget_array_bytes(s.guards)+u64(len(s.problem.path))
	for field in s.fields {bytes+=u64(len(field.path))}
	for layout in s.unions {bytes+=u64(len(layout.variant_sizes))*8+u64(len(layout.variant_names))*size_of(string);for name in layout.variant_names{bytes+=u64(len(name))}}
	return bytes
}
@(private)
budget_codecs_bytes :: proc(c:^Codecs)->u64 {
	bytes:u64
	for schema in ([?]^sc.Schema{&c.offer,&c.compressed_offer,&c.shuffled_offer,&c.chunk,&c.progress,&c.ready,&c.failure}) {bytes+=budget_schema_bytes(schema)}
	return bytes
}

// Charge a containing owner's retained payload alongside this transfer. The
// containing owner must free it before ending this budget owner. This is for
// immutable schema caches and fixed context owned by recovery adapters.
budget_charge_owner :: proc(state:^Budget_State,bytes:u64)->Error {
	return budget_add(state,bytes)?Error.None:Error.Capacity
}

// Optional process-local whole-owner metadata. Exact aliases are explicit;
// allocator ownership never implies ownership of wire/accept/schema user data.
Ownership :: struct {allocator,container,wire,accept,schema,budget:r.Owned_Context}
@(private)
Ownership_State :: struct {retains:r.Owner_Retains,cleanup:bool}
@(private)
ownership_entry :: proc(owned:Ownership,allocator:mem.Allocator,container,wire,accept,schema,budget:rawptr,access:r.Owner_Access=.Execute)->Error {
 managed:=!r.owner_is_nil(owned.allocator.owner) || !r.owner_is_nil(owned.container.owner)
 when #config(BOX3D_REQUIRE_DOMAIN,false){if !managed{return .Invalid_Config}}
 if managed {
  if r.owner_is_nil(owned.allocator.owner) || r.owner_is_nil(owned.container.owner){return .Invalid_Config}
  if r.owner_contexts_check({owner=owned.allocator.owner,owner_allocator_data=owned.allocator.data},allocator)!=.None{return .Invalid_Config}
 }
 bindings:=[?]r.Owned_Context{owned.allocator,owned.wire,owned.accept,owned.schema,owned.budget,owned.container}
 values:=[?]rawptr{allocator.data,wire,accept,schema,budget,container}
 for binding,index in bindings {if r.owned_context_access(binding,values[index],managed,access)!=.None{return .Invalid_Config}}
 return .None
}
@(private)
ownership_retain :: proc(state:^Ownership_State,owned:Ownership)->Error {
 owners:=[?]r.Owner{owned.allocator.owner,owned.wire.owner,owned.accept.owner,owned.schema.owner,owned.budget.owner,owned.container.owner}
 return r.owner_retains_acquire(&state.retains,owners[:])==.None?Error.None:Error.Invalid_Config
}

// Composition preflight, before a containing recovery adapter allocates any
// schema/container or invokes an application callback.
ownership_validate :: proc(owned:Ownership,allocator:mem.Allocator,container,wire,accept,schema,budget:rawptr)->Error{return ownership_entry(owned,allocator,container,wire,accept,schema,budget)}

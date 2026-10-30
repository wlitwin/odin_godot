package replay_transfer

import "core:mem"
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
	allocator: mem.Allocator,
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

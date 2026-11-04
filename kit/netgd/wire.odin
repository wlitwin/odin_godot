package kit_netgd

// The SESSION transport binding — the ~50 lines every game used to write by
// hand: the Send_Proc adapter (kind byte + channel pick), the packet route,
// the engine's connection signals, and the client's join handshake. Godot
// signals must land on @(gd_method)s of a script, and those four forwards
// are GENERATED now — a kboot.Boot field on the game's struct declares them
// (hand-written same-name methods win, name by name). This file owns
// everything behind them:
//
//     wire: netgd.Session_Wire   // a field on the game's script struct
//
//     // ready():
//     netgd.wire_attach(&self.wire, self.owner, &self.ses, MSG_GAME)
//     netgd.wire_listen(&self.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down")
//
//     // the four forwards (generated; shown for the hand-driven path):
//     on_packet(id, packet)  -> netgd.wire_receive(&self.wire, id, packet)
//     on_peer_left(id)       -> ksess.session_peer_disconnected(&self.ses, ksess.Peer_Id(id))
//     on_net_up()            -> ksess.session_client_join(&self.ses)
//     on_net_down()          -> ksess.session_peer_disconnected(&self.ses, ksess.HOST_PEER)
//
//     // process():
//     netgd.wire_pump(&self.wire, now)
//
// The disconnect signals are NOT optional plumbing: without them an alt-F4'd
// client haunts the roster forever and a failed join hangs on "Joining..." —
// which is exactly why the forwards now exist by construction.

import gd "godot:godot"
import "godot:gdext"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strings"
import "core:mem"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"

WIRE_QUEUE_PACKETS :: 128
WIRE_QUEUE_BYTES :: u64(2*1024*1024)
WIRE_QUEUE_PEERS :: 8
Wire_Error :: enum {Ok,Invalid,Busy,Owner,Unsupported,Allocation_Failed,Capacity,Transport}
Wire_Config :: struct {
	allocator:mem.Allocator,
	owner,allocator_owner:bg.Owner,
	user_data,allocator_data:rawptr,
	max_delayed_packets:int,
	max_delayed_bytes:u64,
	max_peers:int,
	seed:u64,
}
Wire_Status :: struct {
	error:Wire_Error,
	peer:ksess.Peer_Id,
	channel:ksess.Channel,
	queued_packets:int,
	queued_bytes,stream_drops,reliable_refusals,retired_packets,unavailable_recipients:u64,
}
@(private)
Wire_Sender :: struct {used:bool,peer:ksess.Peer_Id,lossy:bool,last_due:f64}

// One session's transport binding. Lives in the game's script struct (no
// package globals); `latency`/`jitter`/`loss` are the built-in acid-test
// shim — see wire_set_latency. `gauge` tallies every framed byte by session
// message kind — see wire_traffic.
Session_Wire :: struct {
	owned:bool,
	config:Wire_Config,
	fault:Wire_Status,
	senders:[WIRE_QUEUE_PEERS]Wire_Sender,
	app_in_acc,app_out_acc,app_in_rate,app_out_rate:[ksess.MAX_APP_TAGS+1]int,
	node:     gd.Node,
	ses:      ^ksess.Session,
	transport: ^Transport, // which control plane opened this wire (nil = the raw path; reads as ENet — see transport_of)
	installed_peer_id: u64, // identity of the peer installed by a synchronous transport door; 0 = borrowed/async
	installed_mp: gd.Multiplayer_Api, // owned reference to that peer's exact MultiplayerAPI
	signals: Wire_Signals,
	kind:     u8, // the game's one message byte for session traffic
	latency:  f64, // injected one-way receive delay, seconds (0 = off)
	jitter:   f64, // extra per-packet delay, uniform [0, jitter) seconds
	loss:     f64, // simulated loss fraction [0,1) — streams drop, reliable pays a retransmit delay
	burst:    f64, // mean lost-run length in packets (<=1 = independent losses; >1 = Gilbert-Elliott clustering at the same AVERAGE loss — real WiFi loses in bursts, and bursts are crueler than the coin flip)
	bandwidth: int, // downlink cap in bytes/s (0 = infinite): ONE shared pipe for all senders; sustained overflow QUEUES behind it, so delay grows under load — bufferbloat, the failure real narrow links actually have
	rng:      u64, // the shim's xorshift state (seeded on first use)
	pipe_free: f64, // when the modeled downlink finishes its current queue
	lossy:    map[ksess.Peer_Id]bool, // Gilbert-Elliott per-sender state (true = inside a loss burst)
	last_due: map[ksess.Peer_Id]f64, // per-peer monotone due clamp: jitter varies delay, never reorders
	delayed:  [dynamic]Wire_Delayed,
	dropping: [dynamic]Wire_Drop, // sockets scheduled to close (kicks)
	gauge:    Wire_Gauge,
}

@(private)
wire_owner_empty :: proc "contextless"(owner:bg.Owner)->bool {return owner==bg.Owner{}}
@(private)
wire_owner_check :: proc "contextless"(owner:bg.Owner,access:u32)->Wire_Error {
	if wire_owner_empty(owner) {return .Ok}
	service:=bg.service_get()
	if owner.realm==0 || owner.realm!=service.realm || owner.reserved!=0 || owner.user==nil || owner.check==nil || owner.retain==nil || owner.drop==nil || owner.context_caps & bg.MANAGED_DATA==0 {return .Owner}
	return owner.check(owner.user,access)==bg.OK?.Ok:.Owner
}
@(private)
wire_access :: proc "contextless"(wire:^Session_Wire,access:u32)->Wire_Error {
	if wire==nil {return .Invalid}
	if !wire.owned {return .Ok}
	if e:=wire_owner_check(wire.config.owner,access);e!=.Ok {return e}
	return wire_owner_check(wire.config.allocator_owner,bg.READ)
}
// Optional bounded/owned mode. Configure BEFORE wire_attach/open/signals. Zero
// legacy wires keep their existing behavior and do not activate a native profile.
wire_configure :: proc(wire:^Session_Wire,options:Wire_Config)->Wire_Error {
	if wire==nil {return .Invalid}
	if wire.owned || wire.ses!=nil || wire.node!=nil || len(wire.delayed)!=0 || len(wire.dropping)!=0 {return .Busy}
	cfg:=options
	if cfg.allocator.procedure==nil {return .Invalid}
	if cfg.max_delayed_packets==0 {cfg.max_delayed_packets=WIRE_QUEUE_PACKETS}
	if cfg.max_delayed_bytes==0 {cfg.max_delayed_bytes=WIRE_QUEUE_BYTES}
	if cfg.max_peers==0 {cfg.max_peers=WIRE_QUEUE_PEERS}
	if cfg.seed==0 {cfg.seed=1}
	if cfg.max_delayed_packets<1 || cfg.max_delayed_packets>WIRE_QUEUE_PACKETS || cfg.max_delayed_bytes<1 || cfg.max_delayed_bytes>WIRE_QUEUE_BYTES || cfg.max_peers<1 || cfg.max_peers>WIRE_QUEUE_PEERS {return .Capacity}
	when #config(BOX3D_REQUIRE_DOMAIN,false) {
		if bg.module_profile()!=0 {
			if wire_owner_empty(cfg.owner) || wire_owner_empty(cfg.allocator_owner) || !bm.is_allocator(cfg.allocator) || cfg.owner.context_caps & bg.WEAK_INSTANCE==0 {return .Unsupported}
		}
	}
	if (!wire_owner_empty(cfg.owner) && cfg.user_data!=rawptr(wire)) || (!wire_owner_empty(cfg.allocator_owner) && cfg.allocator_data!=cfg.allocator.data) {return .Owner}
	if e:=wire_owner_check(cfg.owner,bg.EXECUTE);e!=.Ok {return e}
	if e:=wire_owner_check(cfg.allocator_owner,bg.READ);e!=.Ok {return e}
	if !wire_owner_empty(cfg.owner) && cfg.owner.retain(cfg.owner.user)!=bg.OK {return .Owner}
	retained:=!wire_owner_empty(cfg.owner)
	if !wire_owner_empty(cfg.allocator_owner) && cfg.allocator_owner.retain(cfg.allocator_owner.user)!=bg.OK {if retained {_=cfg.owner.drop(cfg.owner.user)};return .Owner}
	queue,error:=make([dynamic]Wire_Delayed,0,cfg.max_delayed_packets,cfg.allocator)
	if error!=nil {if !wire_owner_empty(cfg.allocator_owner) {_=cfg.allocator_owner.drop(cfg.allocator_owner.user)};if retained {_=cfg.owner.drop(cfg.owner.user)};return .Allocation_Failed}
	drops,drop_error:=make([dynamic]Wire_Drop,0,cfg.max_peers,cfg.allocator)
	if drop_error!=nil {delete(queue);if !wire_owner_empty(cfg.allocator_owner) {_=cfg.allocator_owner.drop(cfg.allocator_owner.user)};if retained {_=cfg.owner.drop(cfg.owner.user)};return .Allocation_Failed}
	wire.config=cfg;wire.delayed=queue;wire.dropping=drops;wire.rng=cfg.seed;wire.owned=true
	return .Ok
}
wire_status :: proc "contextless"(wire:^Session_Wire)->Wire_Status {
	if e:=wire_access(wire,bg.READ);e!=.Ok {return {error=e}}
	result:=wire.fault;result.queued_packets=len(wire.delayed)
	return result
}
@(private)
wire_fail :: proc(wire:^Session_Wire,error:Wire_Error,peer:ksess.Peer_Id,channel:ksess.Channel)->Wire_Error {
	if wire.fault.error==.Ok {wire.fault.error=error;wire.fault.peer=peer;wire.fault.channel=channel}
	if channel==.Reliable {wire.fault.reliable_refusals+=1}
	return error
}

@(private)
Wire_Signals :: struct {
	mp: gd.Multiplayer_Api, // owned reference to the exact emitter used at listen time
	callbacks: [5]gd.Callable,
	owned: [5]bool,
}

@(private = "file")
WIRE_SIGNAL_NAMES :: [5]cstring {
	"peer_packet", "peer_disconnected", "connected_to_server",
	"connection_failed", "server_disconnected",
}

// ---- the wire gauge: bytes by message kind, windowed per second -----------
//
// Every framed byte this wire sends or receives, tallied by the session
// message kind riding it (SES_STATE, SES_STREAM, SES_APP, ...), with SES_APP
// split by its tag byte (the sim lane, comms, and game messages each wear
// one). Rates roll once per second in wire_pump; read them raw, or let
// wire_traffic format the netgraph line. Cost: a few adds per packet.

// This package's wire revision — the FRAME formats only (the leading kind
// byte's stream-channel bit, the succession torch record). Registered into
// the session's fingerprint salt at load; a frame change bumps THIS
// constant, in the same commit.
WIRE_REV :: u64(3) // 1: the framed wire · 2: the frame byte carries the stream-channel bit · 3: the succession torch is a typed rendezvous record

@(init, private = "file")
wire_load_init :: proc "contextless" () {
	ksess.session_register_wire_rev(WIRE_REV, 24)
	// The gauge labels come from the session's own table — id and name live
	// beside each other there; this copy exists because the constants are
	// rightly package-private. "other" is the overflow bucket, ours alone.
	for s, i in ksess.SES_KIND_NAMES {
		WIRE_KIND_NAMES[i] = s
	}
	WIRE_KIND_NAMES[WIRE_KINDS - 1] = "other"
}

// The gauge's table size DERIVES from the session's kind count (the one
// number a new SES_* bumps, beside its constant) + one dedicated overflow
// bucket ("other") — a kind from a future build lands THERE, never aliased
// onto a real kind's row.
WIRE_KINDS :: ksess.SES_KIND_COUNT + 1

Wire_Gauge :: struct {
	in_acc, out_acc:           [WIRE_KINDS]int, // current window, bytes (frame byte included)
	in_rate, out_rate:         [WIRE_KINDS]int, // last completed window, bytes/second
	packets_in_acc, packets_out_acc:   int,
	packets_in_rate, packets_out_rate: int,
	app_in_acc, app_out_acc:   map[u8]int, // SES_APP, split by tag
	app_in_rate, app_out_rate: map[u8]int,
	window:                    f64, // when the current window opened (0 = not yet)
}

@(private = "file")
gauge_count :: proc(g: ^Wire_Gauge, out: bool, ses_kind: u8, app_tag: u8, size: int) {
	k := int(ses_kind)
	if k >= WIRE_KINDS {k = WIRE_KINDS - 1}
	if out {
		g.out_acc[k] += size
		g.packets_out_acc += 1
		if ses_kind == ksess.SES_APP {g.app_out_acc[app_tag] += size}
	} else {
		g.in_acc[k] += size
		g.packets_in_acc += 1
		if ses_kind == ksess.SES_APP {g.app_in_acc[app_tag] += size}
	}
}
@(private)
wire_gauge_count :: proc(wire:^Session_Wire,out:bool,kind,tag:u8,size:int) {
	if !wire.owned {gauge_count(&wire.gauge,out,kind,tag,size);return}
	g:=&wire.gauge;k:=min(int(kind),WIRE_KINDS-1)
	if out {g.out_acc[k]+=size;g.packets_out_acc+=1}else{g.in_acc[k]+=size;g.packets_in_acc+=1}
	if kind==ksess.SES_APP {
		i:=min(int(tag),ksess.MAX_APP_TAGS)
		if out {wire.app_out_acc[i]+=size}else{wire.app_in_acc[i]+=size}
	}
}
@(private)
wire_gauge_roll :: proc(wire:^Session_Wire,now:f64) {
	if wire.owned && wire.gauge.window!=0 && now-wire.gauge.window>=1 {
		dt:=now-wire.gauge.window
		for i in 0..<len(wire.app_in_acc) {
			wire.app_in_rate[i]=int(f64(wire.app_in_acc[i])/dt);wire.app_in_acc[i]=0
			wire.app_out_rate[i]=int(f64(wire.app_out_acc[i])/dt);wire.app_out_acc[i]=0
		}
	}
	gauge_roll(&wire.gauge,now)
}

@(private = "file")
gauge_roll :: proc(g: ^Wire_Gauge, now: f64) {
	if g.window == 0 {
		g.window = now
		return
	}
	dt := now - g.window
	if dt < 1.0 {
		return
	}
	for k in 0 ..< WIRE_KINDS {
		g.in_rate[k] = int(f64(g.in_acc[k]) / dt)
		g.out_rate[k] = int(f64(g.out_acc[k]) / dt)
		g.in_acc[k] = 0
		g.out_acc[k] = 0
	}
	g.packets_in_rate = int(f64(g.packets_in_acc) / dt)
	g.packets_out_rate = int(f64(g.packets_out_acc) / dt)
	g.packets_in_acc = 0
	g.packets_out_acc = 0
	clear(&g.app_in_rate)
	for tag, bytes in g.app_in_acc {g.app_in_rate[tag] = int(f64(bytes) / dt)}
	clear(&g.app_in_acc)
	clear(&g.app_out_rate)
	for tag, bytes in g.app_out_acc {g.app_out_rate[tag] = int(f64(bytes) / dt)}
	clear(&g.app_out_acc)
	g.window = now
}

// Numeric totals for dashboards and production telemetry. `wire_traffic`
// remains the compact bytes-by-kind rendering; this exposes the same completed
// one-second window without forcing callers to parse presentation text.
Wire_Rates :: struct {
	packets_in, packets_out: int,
	bytes_in, bytes_out:     int,
}

wire_rates :: proc(wire: ^Session_Wire) -> Wire_Rates {
	rates := Wire_Rates {
		packets_in  = wire.gauge.packets_in_rate,
		packets_out = wire.gauge.packets_out_rate,
	}
	for k in 0 ..< WIRE_KINDS {
		rates.bytes_in += wire.gauge.in_rate[k]
		rates.bytes_out += wire.gauge.out_rate[k]
	}
	return rates
}

Wire_Delayed :: struct {
	due:     f64,
	from:    ksess.Peer_Id,
	channel: ksess.Channel,
	data:    []u8,
}

Wire_Drop :: struct {
	due:  f64,
	peer: ksess.Peer_Id,
}

// Install the session's Send_Proc (kind byte + reliable/stream channel pick).
// Survives session_host_start / session_client_start / session_host_resume —
// call once in ready().
wire_attach :: proc(wire: ^Session_Wire, node: gd.Node, ses: ^ksess.Session, kind: u8) {
	if wire_access(wire,bg.EXECUTE)!=.Ok {return}
	wire.node = node
	wire.ses = ses
	wire.kind = kind
	ksess.session_set_transport(ses, wire, wire_send)
	ksess.session_set_peer_drop(ses, wire, wire_policy_drop)
	// WEB: core:time is stuck inside the wasm module — every knet pacer and
	// ticker freezes on it. Swap the toolkit clock for the engine's before
	// anything reads it (native keeps the core:time path untouched).
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		knet.set_clock(web_clock)
	}
}

@(private = "file")
wire_policy_drop :: proc(user: rawptr, peer: ksess.Peer_Id) {
	wire_drop(cast(^Session_Wire)user, peer)
}

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	@(private = "file")
	web_clock :: proc "contextless" () -> f64 {
		return f64(gd.time_get_ticks_usec(gd.singleton_time())) / 1e6
	}
}

// The teardown twin of wire_attach — for the ONE flow that keeps a process
// alive across a transport's whole life: a game returning to menu, then
// re-hosting/re-joining in the same run (kboot.boot_detach's wire slice). It
// frees everything the wire OWNS: the gauge's per-tag windows, the bad-link
// shim's per-peer state and its still-queued receive copies, and the pending-
// kick queue; then closes the transport opened through this wire's doors.
// A raw wire_attach borrows its engine peer and does not close it. Safe on a
// half-attached OR already-zeroed wire: deleting nil containers is a no-op.
// It does NOT
// unregister the session's transport — the session pointer is the game's, and
// a re-host re-runs wire_attach (which re-registers) — it just returns the
// wire to its zero value.
wire_detach :: proc(wire: ^Session_Wire)->Wire_Error {
	if e:=wire_access(wire,bg.READ);e!=.Ok {return e}
	context.allocator=wire.owned?wire.config.allocator:context.allocator
	owned,cfg:=wire.owned,wire.config
	if owned && wire.ses!=nil && wire.ses.send_user==rawptr(wire) {
		ksess.session_set_transport(wire.ses,nil,nil)
		ksess.session_set_peer_drop(wire.ses,nil,nil)
	}
	wire_unlisten(wire)
	// The bad-link shim's still-queued receives each own a copied byte slice.
	for d in wire.delayed {
		delete(d.data)
	}
	delete(wire.delayed)
	delete(wire.dropping)
	delete(wire.lossy)
	delete(wire.last_due)
	// The gauge's SES_APP-by-tag windows (the fixed [WIRE_KINDS] arrays are
	// inline — nothing to free there).
	delete(wire.gauge.app_in_acc)
	delete(wire.gauge.app_out_acc)
	delete(wire.gauge.app_in_rate)
	delete(wire.gauge.app_out_rate)
	// An owned ENet close uses retained MultiplayerAPI/peer references. Never
	// dereference a now-expired source Node while retiring the binding.
	if owned {wire.node=nil}
	if wire.transport != nil || wire.installed_mp != nil {
		transport_close(wire)
	}
	wire^ = {owned=owned,config=cfg}
	if !wire_owner_empty(cfg.allocator_owner) {
		if cfg.allocator_owner.drop(cfg.allocator_owner.user)!=bg.OK {return .Owner}
		wire.config.allocator_owner={}
	}
	wire^={}
	// Dropping this final exact block lease may free the Wire itself. Return
	// without another read/write after success. A declining drop keeps its data
	// valid and leaves a cleanup-only owner for an explicit retry.
	if !wire_owner_empty(cfg.owner) && cfg.owner.drop(cfg.owner.user)!=bg.OK {
		wire.owned=owned;wire.config=cfg;wire.config.allocator_owner={};return .Owner
	}
	return .Ok
}

// The frame byte's high bit marks a STREAM-channel packet — the sender is
// the only one who knows the channel, and the receive-side shim needs it to
// be honest (streams drop under loss and never queue behind reliable
// traffic; reliable must arrive, in order). Godot's peer_packet signal
// erases the channel, so the frame carries it. Wire-format change:
// ksess.PROTOCOL_REV covers it (a skewed peer is refused at the door).
@(private = "file")
WIRE_STREAM_BIT :: u8(0x80)

// Kit peer → engine peer, the sentinel boundary: kit's BROADCAST_PEER (-1)
// becomes the engine's broadcast id (0). NEVER cast a ksess.Peer_Id to int
// yourself — a raw -1 reaches the engine as "all except peer 1", which
// silently excludes the SERVER from every broadcast. Hand-rolled Send_Procs
// (the raw-layer path) route through this; ok=false means NO_PEER — a
// disconnected seat's peer reached the transport, drop the send (the old
// 0-aliasing turned exactly that mistake into an accidental broadcast).
wire_engine_peer :: proc(to_peer: ksess.Peer_Id) -> (engine_peer: int, ok: bool) {
	if to_peer == ksess.NO_PEER {
		return 0, false
	}
	return to_peer == ksess.BROADCAST_PEER ? 0 : int(to_peer), true
}

@(private = "file")
wire_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	wire := cast(^Session_Wire)user
	if wire_access(wire,bg.EXECUTE)!=.Ok {return}
	context.allocator=wire.owned?wire.config.allocator:context.allocator
	if wire.owned && wire.fault.error!=.Ok {return}
	assert(to_peer != ksess.NO_PEER, "send to NO_PEER — a disconnected seat's peer reached the transport (check p.connected before sending)")
	engine_peer, peer_ok := wire_engine_peer(to_peer)
	if !peer_ok {
		return
	}
	if len(bytes) > 0 {
		tag := len(bytes) > 1 ? bytes[1] : 0
		wire_gauge_count(wire, true, bytes[0], tag, len(bytes) + 1)
	}
	if wire.owned {
		if len(bytes)>knet.MAX_PACKET_BYTES {_=wire_fail(wire,.Capacity,to_peer,channel);return}
		// SceneMultiplayer can still list a peer during its disconnect signal.
		// Check the actual ENet endpoint, not the server's listening status or
		// that transient Scene roster. Broadcasts expand only to connected peers.
		mp:=gd.node_get_multiplayer(wire.node);defer gd.release_ref(mp)
		if mp==nil {_=wire_fail(wire,.Transport,to_peer,channel);return}
		transport:=gd.multiplayer_api_get_multiplayer_peer(mp);defer gd.release_ref(transport)
		if transport==nil || !gd.object_is_class(cast(gd.Object)transport,gd.e_net_multiplayer_peer_name()) {_=wire_fail(wire,.Unsupported,to_peer,channel);return}
		peers:=gd.multiplayer_api_get_peers(mp);defer gd.free_packed_int32_array(peers)
		count:=int(gd.packed_int32_array_size(&peers))
		if count>wire.config.max_peers {_=wire_fail(wire,.Capacity,to_peer,channel);return}
		recipients:[WIRE_QUEUE_PEERS]int;available:=0
		for i in 0..<count {
			id:=int(gd.packed_int32_array_get(&peers,gd.Int(i)))
			if engine_peer!=0 && id!=engine_peer {continue}
			// ENet clients have only their server as a physical recipient.
			if !gd.multiplayer_api_is_server(mp) && id!=int(ksess.HOST_PEER) {wire.fault.unavailable_recipients+=1;continue}
			endpoint:=gd.e_net_multiplayer_peer_get_peer(cast(gd.E_Net_Multiplayer_Peer)transport,gd.Int(id))
			connected:=endpoint!=nil && gd.e_net_packet_peer_is_active(endpoint) && gd.e_net_packet_peer_get_state(endpoint)==.State_Connected
			gd.release_ref(endpoint)
			if !connected {wire.fault.unavailable_recipients+=1;continue}
			recipients[available]=id;available+=1
		}
		if available==0 {wire.fault.unavailable_recipients+=1;return}
		framed,error:=make([]u8,len(bytes)+1,wire.config.allocator)
		if error!=nil || len(framed)!=len(bytes)+1 {_=wire_fail(wire,.Allocation_Failed,to_peer,channel);return}
		defer delete(framed,wire.config.allocator)
		framed[0]=channel==.Stream?wire.kind|WIRE_STREAM_BIT:wire.kind;copy(framed[1:],bytes)
		for recipient in recipients[:available] {
			status:=channel==.Stream?send_stream(wire.node,recipient,framed):send_reliable(wire.node,recipient,framed)
			if status!=.Ok {_=wire_fail(wire,.Transport,ksess.Peer_Id(recipient),channel);return}
		}
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, channel == .Stream ? wire.kind | WIRE_STREAM_BIT : wire.kind)
	append(&w.buf, ..bytes)
	if channel == .Stream {
		_ = send_stream(wire.node, engine_peer, knet.writer_bytes(&w))
	} else {
		_ = send_reliable(wire.node, engine_peer, knet.writer_bytes(&w))
	}
}

// Connect the engine's transport signals to the game's four forwarding
// @(gd_method)s (see the header). Empty method names skip that signal.
// Call after the node is in the tree (ready() qualifies).
wire_listen :: proc "contextless" (
	wire: ^Session_Wire,
	on_packet: cstring,
	on_peer_left: cstring = "",
	on_net_up: cstring = "",
	on_net_down: cstring = "",
) -> gd.Error {
	if wire_access(wire,bg.EXECUTE)!=.Ok {return .Failed}
	wire_unlisten(wire)
	mp := gd.node_get_multiplayer(wire.node)
	if cast(rawptr)mp == nil {return .Failed}
	wire.signals.mp = mp
	methods := [5]cstring{on_packet, on_peer_left, on_net_up, on_net_down, on_net_down}
	signal_names := WIRE_SIGNAL_NAMES
	for method, i in methods {
		if method == "" {continue}
		callback := gd.callable(cast(gd.Object)wire.node, method)
		signal := gd.sname(signal_names[i])
		if gd.object_is_connected(cast(gd.Object)mp, signal, callback) {
			// A pre-existing connection belongs to its installer.
			gd.free_callable(callback)
			continue
		}
		if err := gd.object_connect(cast(gd.Object)mp, signal, callback, 0); err != .Ok {
			gd.free_callable(callback)
			wire_unlisten(wire)
			return err
		}
		wire.signals.callbacks[i] = callback
		wire.signals.owned[i] = true
	}
	return .Ok
}

@(private = "file")
wire_unlisten :: proc "contextless" (wire: ^Session_Wire) {
	signals := &wire.signals
	if signals.mp == nil {return}
	emitter := cast(gd.Object)signals.mp
	signal_names := WIRE_SIGNAL_NAMES
	for owned, i in signals.owned {
		if !owned {continue}
		signal := gd.sname(signal_names[i])
		callback := signals.callbacks[i]
		if gd.object_is_connected(emitter, signal, callback) {
			gd.object_disconnect(emitter, signal, callback)
		}
		gd.free_callable(callback)
	}
	gd.release_ref(signals.mp)
	signals^ = {}
}

// Route one received packet: strip the kind byte (other kinds are not ours —
// the game routes those itself before calling this) and hand the rest to the
// session; with a latency shim active, buffer instead and wire_pump delivers.
wire_receive :: proc(wire:^Session_Wire,id:gd.Int,packet:gd.Packed_Byte_Array) {
 packet:=packet
 _=wire_receive_bytes(wire,ksess.Peer_Id(id),pba_view(&packet),knet.now_s())
}
// Same framed-byte ingress used by Godot's PackedByteArray signal adapter.
// The bounded mode owns every delayed copy; immediate delivery borrows bytes
// only for the synchronous Session parser. No simulation is executed here.
wire_receive_bytes :: proc(wire:^Session_Wire,from:ksess.Peer_Id,view:[]u8,now:f64)->Wire_Error {
 if e:=wire_access(wire,bg.EXECUTE);e!=.Ok {return e}
 if !wire.owned {wire_receive_legacy(wire,gd.Int(from),view);return .Ok}
 context.allocator=wire.config.allocator
 if wire.fault.error!=.Ok {return wire.fault.error}
 if len(view)==0 || view[0]&~WIRE_STREAM_BIT!=wire.kind {return .Ok}
 channel:=view[0]&WIRE_STREAM_BIT!=0?ksess.Channel.Stream:.Reliable
 if len(view)-1>knet.MAX_PACKET_BYTES {return wire_fail(wire,.Capacity,from,channel)}
 kind:=len(view)>1?view[1]:0;tag:=len(view)>2?view[2]:0
 wire_gauge_count(wire,false,kind,tag,len(view))
 if wire.ses==nil {return wire_fail(wire,.Invalid,from,channel)}
 if wire.latency<=0 && wire.jitter<=0 && wire.loss<=0 && wire.bandwidth<=0 {
  r:=knet.reader_make(view[1:]);ksess.session_handle_packet(wire.ses,from,&r,channel);return .Ok
 }
 sender:^Wire_Sender
 for &candidate in wire.senders[:wire.config.max_peers] {if candidate.used && candidate.peer==from {sender=&candidate;break}}
 if sender==nil {for &candidate in wire.senders[:wire.config.max_peers] {if !candidate.used {sender=&candidate;break}}}
 if sender==nil {if channel==.Stream {wire.fault.stream_drops+=1;return .Ok};return wire_fail(wire,.Capacity,from,channel)}
 delay:=wire.latency+wire.jitter*wire_rand01(wire)
 pipe:=wire.pipe_free
 if wire.bandwidth>0 {pipe=max(now,pipe)+f64(len(view))/f64(wire.bandwidth);delay+=pipe-now}
 lossy:=sender.used && sender.lossy;lost:=false
 if wire.loss>0 {
  if wire.burst>1 {
   if lossy {lost=true;if wire_rand01(wire)<1.0/wire.burst {lossy=false}}
   else if wire_rand01(wire)<(wire.loss/(1-wire.loss))/wire.burst {lossy=true;lost=true}
  }else{lost=wire_rand01(wire)<wire.loss}
 }
 if lost && channel==.Stream {wire.fault.stream_drops+=1;sender^={used=true,peer=from,lossy=lossy,last_due=sender.last_due};wire.pipe_free=pipe;return .Ok}
 if lost {delay+=2*wire.latency}
 due:=now+delay
 if channel==.Reliable && sender.used {due=max(due,sender.last_due)}
 bytes:=u64(len(view)-1)
 if len(wire.delayed)>=wire.config.max_delayed_packets || bytes>wire.config.max_delayed_bytes-wire.fault.queued_bytes {
  if channel==.Stream {wire.fault.stream_drops+=1;return .Ok}
  return wire_fail(wire,.Capacity,from,channel)
 }
 data,error:=make([]u8,int(bytes),wire.config.allocator)
 if error!=nil || len(data)!=int(bytes) {return wire_fail(wire,.Allocation_Failed,from,channel)}
 copy(data,view[1:])
 // Capacity was reserved at configure; append cannot grow while below the cap.
 append(&wire.delayed,Wire_Delayed{due=due,from=from,channel=channel,data=data})
 wire.fault.queued_bytes+=bytes
 sender.used=true;sender.peer=from;sender.lossy=lossy
 if channel==.Reliable {sender.last_due=due}
 wire.pipe_free=pipe
 return .Ok
}

@(private)
wire_receive_legacy :: proc(wire:^Session_Wire,id:gd.Int,view:[]u8) {
	if len(view) == 0 || view[0] & ~WIRE_STREAM_BIT != wire.kind {
		return
	}
	streamed := view[0] & WIRE_STREAM_BIT != 0 // the sender's channel, carried on the frame
	ses_kind := len(view) > 1 ? view[1] : 0
	app_tag := len(view) > 2 ? view[2] : 0
	gauge_count(&wire.gauge, false, ses_kind, app_tag, len(view)) // dropped-below counts too: it crossed the wire
	if wire.latency > 0 || wire.jitter > 0 || wire.loss > 0 || wire.bandwidth > 0 {
		from := ksess.Peer_Id(id)
		delay := wire.latency + wire.jitter * wire_rand01(wire)
		// The narrow pipe: ONE downlink shared by every sender. A packet
		// transmits at the cap; sustained overflow queues behind the pipe and
		// the queue IS the delay — bufferbloat, what a real constrained link
		// does long before it drops anything.
		if wire.bandwidth > 0 {
			now := knet.now_s()
			start := max(now, wire.pipe_free)
			wire.pipe_free = start + f64(len(view)) / f64(wire.bandwidth)
			delay += wire.pipe_free - now
		}
		lost := false
		if wire.loss > 0 {
			if wire.burst > 1 {
				// Gilbert-Elliott: two states per SENDER — long clean runs, then
				// a burst that eats ~`burst` consecutive packets, at the same
				// average rate the uniform roll would give. Transition math:
				// leave the bad state with p=1/burst (mean run = burst packets),
				// enter it so the stationary bad share equals `loss`.
				bad := wire.lossy[from]
				if bad {
					lost = true
					if wire_rand01(wire) < 1.0 / wire.burst {
						bad = false
					}
				} else if wire_rand01(wire) < (wire.loss / (1.0 - wire.loss)) / wire.burst {
					bad = true
					lost = true
				}
				wire.lossy[from] = bad
			} else {
				lost = wire_rand01(wire) < wire.loss
			}
		}
		if lost {
			// Channel-honest loss: an unreliable-channel packet (owner streams,
			// the sim lane's input windows and snapshots) simply VANISHES —
			// redundancy and last-value semantics absorb it, which is the real
			// behavior. Reliable traffic MUST arrive (the whole stack assumes
			// ordered-reliable delivery), so its "loss" is what loss really
			// costs that channel: a retransmit's worth of extra delay — and a
			// BURST on reliable stacks those delays through the FIFO clamp,
			// which is the convoy a real burst builds.
			if streamed {
				return
			}
			delay += 2 * wire.latency
		}
		due := knet.now_s() + delay
		// Jitter varies delay but the RELIABLE channel never reorders: its
		// packets stay FIFO per sender (the shim sits above ENet, whose
		// ordered channel already sequenced them — handing them over shuffled
		// would break contracts no real network can break at this layer).
		// STREAM packets skip the clamp both ways: they neither queue behind
		// a delayed reliable packet (real streams bypass that queue) nor hold
		// reliable traffic back — and if jitter lands two of them out of
		// order, the stamps and acks above already shrug that off, exactly as
		// they do on a real link.
		if !streamed {
			if prev, seen := wire.last_due[from]; seen && due < prev {
				due = prev
			}
			wire.last_due[from] = due
		}
		data := make([]u8, len(view) - 1)
		copy(data, view[1:])
		channel := streamed ? ksess.Channel.Stream : ksess.Channel.Reliable
		append(&wire.delayed, Wire_Delayed{due = due, from = from, channel = channel, data = data})
		return
	}
	r := knet.reader_make(view[1:])
	channel := streamed ? ksess.Channel.Stream : ksess.Channel.Reliable
	ksess.session_handle_packet(wire.ses, ksess.Peer_Id(id), &r, channel)
}

// The shim's own dice — xorshift64*, seeded from the clock on first use. A
// shim wants believable variety, not statistics; this is plenty.
@(private = "file")
wire_rand01 :: proc(wire: ^Session_Wire) -> f64 {
	if wire.rng == 0 {
		wire.rng = u64(knet.now_s() * 1e6) | 1
	}
	x := wire.rng
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	wire.rng = x
	return f64(x >> 11) / f64(1 << 53)
}

// Per-frame: deliver latency-shimmed packets whose time has come, and close
// any sockets a kick scheduled. (Without a shim or a pending kick this is a
// no-op — still call it; the shim is how you acid-test YOUR game's feel
// under real round trips: netgd.wire_set_latency(&wire, 120).)
wire_pump :: proc(wire: ^Session_Wire, now: f64) {
	if wire_access(wire,bg.EXECUTE)!=.Ok {return}
	context.allocator=wire.owned?wire.config.allocator:context.allocator
	if wire.owned && wire.fault.error!=.Ok {return}
	wire_gauge_roll(wire,now)
	// Deliver in ARRIVAL order, not due order: with jitter the dues aren't
	// globally sorted, but each sender's are monotone (the receive clamp), so
	// an in-order scan keeps every peer's packets FIFO.
	for i := 0; i < len(wire.delayed); {
		if wire.delayed[i].due > now {
			i += 1
			continue
		}
		pkt := wire.delayed[i]
		ordered_remove(&wire.delayed, i)
		if wire.owned {wire.fault.queued_bytes-=u64(len(pkt.data))}
		r := knet.reader_make(pkt.data)
		ksess.session_handle_packet(wire.ses, pkt.from, &r, pkt.channel)
		delete(pkt.data)
	}
	for i := 0; i < len(wire.dropping); {
		if wire.dropping[i].due <= now { // one clock rules the pump
			drop_peer(wire.node, wire.dropping[i].peer)
			unordered_remove(&wire.dropping, i)
			continue
		}
		i += 1
	}
}

// Schedule a kicked peer's socket to close shortly — the second half of a
// kick (session_kick unseats and returns the seat; this severs it). DEFERRED
// on purpose: an immediate ENet disconnect races its own outgoing queue and
// the SES_KICKED the session just sent is discarded — the kicked player then
// sees a mystery host-crash instead of the truth. The delay lets the
// reliable queue flush and ack; the session already ignores the unseated
// peer, so nothing it sends in the gap matters.
wire_drop :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id, after := 0.75) {
	if wire_access(wire,bg.EXECUTE)!=.Ok {return}
	context.allocator=wire.owned?wire.config.allocator:context.allocator
	if wire.owned {
		if wire.fault.error!=.Ok {return}
		for &pending in wire.dropping {if pending.peer==peer {pending.due=min(pending.due,knet.now_s()+after);return}}
		if len(wire.dropping)>=wire.config.max_peers {_=wire_fail(wire,.Capacity,peer,.Reliable);return}
	}
	append(&wire.dropping, Wire_Drop{due = knet.now_s() + after, peer = peer})
}
// An actual transport disconnect ends that peer's delivery promise. Retire its
// queued copies explicitly and release its bounded sender slot for reconnect.
wire_peer_left :: proc(wire:^Session_Wire,peer:ksess.Peer_Id)->Wire_Error {
	if e:=wire_access(wire,bg.EXECUTE);e!=.Ok {return e}
	if !wire.owned {return .Ok}
	for i:=0;i<len(wire.delayed); {
		if wire.delayed[i].from!=peer {i+=1;continue}
		data:=wire.delayed[i].data;wire.fault.queued_bytes-=u64(len(data));wire.fault.retired_packets+=1
		delete(data,wire.config.allocator);ordered_remove(&wire.delayed,i)
	}
	for &sender in wire.senders {if sender.used && sender.peer==peer {sender={}}}
	for i:=0;i<len(wire.dropping); {if wire.dropping[i].peer==peer {ordered_remove(&wire.dropping,i)}else{i+=1}}
	return .Ok
}

// Inject one-way receive latency (milliseconds; 0 disables), plus optional
// JITTER (extra uniform [0, jitter_ms) per packet — delays vary, order is
// preserved) and LOSS (percent: stream batches drop outright — last-value
// semantics absorb it — while reliable traffic pays a retransmit's worth of
// extra delay, because this layer may never break ordered-reliable
// delivery). The toolkit's own acid tests run at 120ms so predictions are
// proven to bite instantly while confirms measurably ride the slow wire;
// jitter and loss are how you prove your game FEELS right on a bad link,
// not just a slow one. Test your game the same way — kit/boot reads
// <ENV>_LATENCY / <ENV>_JITTER / <ENV>_LOSS for you.
// `burst` clusters the loss: the mean lost-RUN length in packets, at the same
// average rate — 1 (the default) keeps independent per-packet losses; 4 means
// losses arrive as ~4-packet bursts with long clean stretches between, the
// shape real WiFi and cellular actually produce. Bursts are crueler than the
// coin flip at the same percentage: a redundant-input window survives
// scattered drops and dies whole inside one burst — test against them.
// `bandwidth_bps` caps the modeled downlink in BYTES/s (0 = infinite), one
// shared pipe for all senders; past it, packets queue and delay GROWS
// (bufferbloat), which is what a narrow link really does before it drops.
wire_set_latency :: proc(wire: ^Session_Wire, ms: int, jitter_ms := 0, loss_pct := 0, burst := 1, bandwidth_bps := 0) {
	if wire_access(wire,bg.EXECUTE)!=.Ok {return}
	wire.latency = f64(ms) / 1000.0
	wire.jitter = f64(jitter_ms) / 1000.0
	wire.loss = clamp(f64(loss_pct) / 100.0, 0, 0.95)
	wire.burst = f64(max(burst, 1))
	wire.bandwidth = max(bandwidth_bps, 0)
}

// Short display names per SES kind, for wire_traffic (indexes match the
// SES_* ids; unknown/overflow reads "other").
@(private = "file")
// Filled at load from the session's own SES_KIND_NAMES (id and label live in
// one file over there) + our overflow bucket — see wire_load_init.
WIRE_KIND_NAMES: [WIRE_KINDS]string

// The netgraph's traffic line: total in/out bytes per second with the top
// contributors named — `rx 3.2k state 2.1 stream 0.8 · tx 0.4k cmd 0.3`.
// SES_APP splits by tag (`app16 1.2` = the sim lane's tag riding it). Rates
// are the last completed one-second window; "" until the first window rolls.
wire_traffic :: proc(wire: ^Session_Wire, allocator := context.temp_allocator) -> string {
	g := &wire.gauge
	total_in, total_out := 0, 0
	for k in 0 ..< WIRE_KINDS {
		total_in += g.in_rate[k]
		total_out += g.out_rate[k]
	}
	if total_in == 0 && total_out == 0 {
		return ""
	}
	b := strings.builder_make(allocator)
	dir :: proc(b: ^strings.Builder, label: string, total: int, rates: [WIRE_KINDS]int, app: map[u8]int,fixed:[]int) {
		fmt.sbprintf(b, "%s %.1fk", label, f64(total) / 1024.0)
		// The top three kinds carry the story; the rest is noise.
		shown := 0
		used: [WIRE_KINDS]bool
		for shown < 3 {
			best, best_k := 0, -1
			for k in 0 ..< WIRE_KINDS {
				if !used[k] && rates[k] > best {
					best, best_k = rates[k], k
				}
			}
			if best_k < 0 || best == 0 {break}
			used[best_k] = true
			shown += 1
			if best_k == int(ksess.SES_APP) && (len(app) > 0 || len(fixed)>0) {
				// Name the heaviest tag instead of the opaque bucket.
				bt, bb := u8(0), 0
				for tag, bytes in app {
					if bytes > bb {bt, bb = tag, bytes}
				}
				for bytes,tag in fixed {if bytes>bb {bt,bb=u8(tag),bytes}}
				fmt.sbprintf(b, " app%d %.1f", bt, f64(best) / 1024.0)
			} else {
				fmt.sbprintf(b, " %s %.1f", WIRE_KIND_NAMES[best_k], f64(best) / 1024.0)
			}
		}
	}
	in_fixed,out_fixed:[]int
	if wire.owned {in_fixed=wire.app_in_rate[:];out_fixed=wire.app_out_rate[:]}
	dir(&b, "rx", total_in, g.in_rate, g.app_in_rate,in_fixed)
	strings.write_string(&b, " · ")
	dir(&b, "tx", total_out, g.out_rate, g.app_out_rate,out_fixed)
	return strings.to_string(b)
}

// The LINK's own truth: smoothed round trip, its variance (the honest
// jitter), and packet loss percent — the TRANSPORT's view, independent of
// anything the session measures. Answered by whichever transport opened this
// wire (transport.odin's `link` slot); ok=false when that transport has no
// per-peer statistics story, on an unknown peer, or asked about yourself (a
// host has no link to itself; ask per client peer there, or just fill the
// graph on clients). Today ENet is the one transport that answers.
wire_link_quality :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool) {
	return transport_link(wire, peer)
}

// ENet's answer to it — the record's `link` slot for ENET (the class check is
// what makes the raw path safe: a wire that never named a transport reads as
// ENet, and a non-ENet peer answers ok=false here rather than lying).
@(private)
enet_peer_stats :: proc(node: gd.Node, peer: ksess.Peer_Id) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool) {
	mp := gd.node_get_multiplayer(node)
	defer gd.release_ref(mp)
	if cast(rawptr)mp == nil {return}
	if !active_remote_peer(mp,peer) {return}
	p := gd.multiplayer_api_get_multiplayer_peer(mp)
	defer gd.release_ref(p)
	if cast(rawptr)p == nil {return}
	if !bool(gd.object_is_class(cast(gd.Object)p, gd.sname("ENetMultiplayerPeer"))) {return}
	pkt := gd.e_net_multiplayer_peer_get_peer(cast(gd.E_Net_Multiplayer_Peer)p, gd.Int(peer))
	defer gd.release_ref(pkt)
	if cast(rawptr)pkt == nil {return}
	rtt_ms = gd.e_net_packet_peer_get_statistic(pkt, .Peer_Round_Trip_Time)
	jitter_ms = gd.e_net_packet_peer_get_statistic(pkt, .Peer_Round_Trip_Time_Variance)
	// ENet scales loss by PACKET_LOSS_SCALE (65536 = 100%).
	loss_pct = gd.e_net_packet_peer_get_statistic(pkt, .Peer_Packet_Loss) / 65536.0 * 100.0
	return rtt_ms, jitter_ms, loss_pct, true
}

// A connected peer's remote address as the HOST sees it — the rendezvous
// info for live migration over ENet (session Ev_Backup_Target -> read the
// designated holder's address -> session_set_successor_info). Same-subnet
// truth only: across NAT the address the host sees may not be reachable by
// the other peers (Steam and room-code transports don't have this problem —
// their rendezvous blobs are lobby ids). ok=false off-ENet or unknown peer.
peer_address :: proc(node: gd.Node, peer: ksess.Peer_Id, allocator := context.temp_allocator) -> (addr: string, ok: bool) {
	mp := gd.node_get_multiplayer(node)
	defer gd.release_ref(mp)
	if cast(rawptr)mp == nil {return "", false}
	if !active_remote_peer(mp,peer) {return "",false}
	p := gd.multiplayer_api_get_multiplayer_peer(mp)
	defer gd.release_ref(p)
	if cast(rawptr)p == nil {return "", false}
	if !bool(gd.object_is_class(cast(gd.Object)p, gd.sname("ENetMultiplayerPeer"))) {return "", false}
	pkt := gd.e_net_multiplayer_peer_get_peer(cast(gd.E_Net_Multiplayer_Peer)p, gd.Int(peer))
	defer gd.release_ref(pkt)
	if cast(rawptr)pkt == nil {return "", false}
	gs := gd.e_net_packet_peer_get_remote_address(pkt)
	defer gd.free_string(gs)
	buf: [64]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&gs, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {return "", false}
	out := make([]u8, min(int(n), len(buf) - 1), allocator)
	copy(out, buf[:len(out)])
	return string(out), true
}

// Sever a peer's transport connection — the second half of a kick:
// session_kick unseats the player and returns the seat; this closes its
// socket so the kicked client can't keep talking (the session would ignore
// it, but the wire shouldn't hum). GRACEFUL (force=false) on purpose: the
// SES_KICKED message the session just queued must flush before the socket
// dies, or the kicked player sees a mystery host-crash instead of the truth.
drop_peer :: proc "contextless" (node: gd.Node, peer: ksess.Peer_Id) {
	mp := gd.node_get_multiplayer(node)
	defer gd.release_ref(mp)
	if cast(rawptr)mp == nil {return}
	p := gd.multiplayer_api_get_multiplayer_peer(mp)
	defer gd.release_ref(p)
	if cast(rawptr)p == nil {return}
	gd.multiplayer_peer_disconnect_peer(p, gd.Int(peer), false)
}
// ---- the two buttons, minus the ceremony ---------------------------------------
//
// Every game's Host/Join handlers repeat the same two-step: bring the
// transport up, then start the session over it. The UI around them (status
// lines, menu hiding) stays the game's — or use kit/boot, which wraps these
// with the stock lobby ritual.
//
// These four are SUGAR over transport_host / transport_join with the flavor
// picked for you (transport.odin holds the mechanism and the per-transport
// records). They are the names games already say, and the shortest way to
// spell the common case; reach for the generic pair when the transport is a
// variable — a settings menu, a fallback chain, kit/boot's doors.

// Host on `port`. false = the transport refused (port taken) — the session
// was NOT started; tell the player and let them try again. `token` is the
// host's own reconnect identity (see session_host_start) — pass it so a
// dead host can reclaim its seat from whoever resumes the run. `dedicated`
// makes this authority a SERVER, not a player (see session_host_start).
begin_host :: proc(wire: ^Session_Wire, port: int, name: string, max_peers := 32, token: u64 = 0, dedicated := false) -> bool {
	return transport_host(wire, &ENET, {port = port, max_peers = max_peers}, name, token, dedicated)
}

// Join `addr:port` as `token`/`name`. false = the transport refused outright;
// an unreachable host surfaces later as Ev_Join_Failed (the join timeout).
// `spectate` joins to WATCH (a receive-only seat — see ksess.Player.spectator).
begin_join :: proc(wire: ^Session_Wire, addr: cstring, port: int, token: u64, name: string, spectate := false) -> bool {
	return transport_join(wire, &ENET, {addr = addr, port = port}, name, token, spectate)
}

// ---- the same two buttons, WebRTC flavor -----------------------------------------------
//
// Browser co-op pairs through a ROOM CODE brokered by a signaling relay
// instead of an address the joiner already knows — and the code is ASSIGNED
// by the relay after the host connects, so it arrives async (read it back
// with gd.webrtc_room_code once web_poll has pumped the handshake). The
// session layer neither knows nor cares: once the data channel installs the
// multiplayer peer, everything above these calls is the ENet path verbatim.

// Host a room on the relay at `url` and start the session AT ONCE —
// authoritative from the first tick; peers drop in when their channel comes
// up. `token` is the host's reconnect identity, exactly as in begin_host.
begin_host_web :: proc(wire: ^Session_Wire, url: cstring, name: string, token: u64 = 0, room: cstring = "") -> bool {
	return transport_host(wire, &WEBRTC, {addr = url, room = room}, name, token)
}

// Join `room` (the code the host shared) through the relay at `url`.
begin_join_web :: proc(wire: ^Session_Wire, url: cstring, room: cstring, token: u64, name: string) -> bool {
	return transport_join(wire, &WEBRTC, {addr = url, room = room}, name, token)
}

// Pump the signaling handshake — every frame while a web session lives (the
// data channel itself is engine-polled; this services the relay socket).
// WEBRTC's pump slot, so kit/boot drives it for door games without knowing
// which transport it holds; hand-driven games on the raw path call it (or
// transport_service) from process() themselves.
web_poll :: proc(wire: ^Session_Wire) {
	gd.webrtc_poll(wire.node)
}

// Tear a web session down COMPLETELY so a fresh begin_*_web can start clean
// — the retry after a failed join, or a successor raising a new room.
web_close :: proc(wire: ^Session_Wire) {
	gd.webrtc_close(wire.node)
}

// wire_punch — fire a few tiny UDP packets from this wire's own bound ENet
// socket at a joiner's observed endpoint (kit/netgd code.odin's rendezvous):
// garbage to ENet, gold to the NAT — the joiner's inbound connect then meets
// a warm outbound mapping. ENet-transport hosts only (the code door is an
// ENet feature; begin_host installed the peer this reaches).
wire_punch :: proc(wire: ^Session_Wire, ip: cstring, port: int) {
	mp := gd.node_get_multiplayer(wire.node)
	defer gd.release_ref(mp)
	if cast(rawptr)mp == nil {return}
	peer := gd.multiplayer_api_get_multiplayer_peer(mp)
	defer gd.release_ref(peer)
	if cast(rawptr)peer == nil {return}
	if !gd.object_is_class(cast(gd.Object)peer,gd.sname("ENetMultiplayerPeer")) {return}
	host := gd.e_net_multiplayer_peer_get_host(cast(gd.E_Net_Multiplayer_Peer)peer)
	defer gd.release_ref(host)
	if cast(rawptr)host == nil {return}
	addr := gd.new_string_cstring(ip)
	defer gd.free_string(addr)
	pkt := gd.new_packed_byte_array()
	defer gd.free_packed_byte_array(pkt)
	gd.packed_byte_array_push_back(&pkt, 0)
	for _ in 0 ..< 3 {
		gd.e_net_connection_socket_send(host, addr, gd.Int(port), pkt)
	}
}

@(private)
active_remote_peer :: proc "contextless" (mp:gd.Multiplayer_Api,peer:ksess.Peer_Id)->bool {
	if !gd.multiplayer_api_has_multiplayer_peer(mp) {return false}
	ids:=gd.multiplayer_api_get_peers(mp);defer gd.free_packed_int32_array(ids)
	for i in 0..<gd.packed_int32_array_size(&ids) {if ksess.Peer_Id(gd.packed_int32_array_get(&ids,i))==peer {return true}}
	return false
}

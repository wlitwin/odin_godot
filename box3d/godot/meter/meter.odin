package box3d_godot_meter

// Optional exact HOST allocation observer. Pure protocol only: importing this
// package neither loads native physics nor registers an SDK module profile.
import "base:runtime"
import "core:mem"
import bg "godot:box3d/godot"

MAX_ALLOCATIONS :: u32(4096)
MAX_BLOCK_LEASES :: u32(64)
@(private)
POINTER_BUCKETS :: u32(2048)
Stats :: struct {
	live_bytes, requested_bytes, peak_bytes, allocation_count, references: u64,
}
Category_Stats :: struct {
	live_bytes, requested_bytes, contexts, allocations: u64,
}
@(private)
Entry :: struct {
	pointer:                rawptr,
	size, generation, pins: u64,
	alignment:              int,
	pending_free:           bool,
}
@(private)
Alias :: struct {
	user:                   rawptr,
	entry:                  u32,
	generation, references: u64,
	started, retired:       bool,
}
Context :: struct {
	next:               ^Context,
	service:            bg.Service,
	backing:            mem.Allocator,
	category, capacity: u32,
	values:             Stats,
	entries:            [MAX_ALLOCATIONS]Entry,
	aliases:            [MAX_BLOCK_LEASES]Alias,
	// Links encode stable Entry index+1; zero is the end of a chain. The
	// complete index and free stack are part of this charged allocation.
	pointer_heads:      [POINTER_BUCKETS]u16,
	pointer_next:       [MAX_ALLOCATIONS]u16,
	free_slots:         [MAX_ALLOCATIONS]u16,
	free_count:         u32,
}
@(private)
Category :: struct {
	realm:           u64,
	live, requested: u64,
}
// Categories belong to this producer image. Stable Core sums their one producer
// aggregate with every other image; nothing here is global simulation state.
@(private)
categories: [6]Category
@(private)
head: ^Context

// Web has one permanently linked Odin image. Stable Core installs its actual
// stateless engine allocator after Service installation and before indexing any
// user classes. This direct AOT handoff crosses no C protocol/DSO boundary.
@(private)
web_backing: mem.Allocator
@(private)
web_backing_installed: bool
install_web_backing :: proc "contextless" (backing: mem.Allocator) -> bg.Status {
 when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
  if bg.service_get().realm==0 || web_backing_installed || backing.data!=nil || backing.procedure==nil {return bg.INCOMPATIBLE}
  web_backing=backing;web_backing_installed=true;return bg.OK
 } else {return bg.UNSUPPORTED}
}

@(private)
pointer_bucket :: proc "contextless" (pointer: rawptr) -> u32 {
	value := u64(uintptr(pointer))
	value ~= value >> 33
	value *= 0xff51afd7ed558ccd
	value ~= value >> 33
	value *= 0xc4ceb9fe1a85ec53
	value ~= value >> 33
	return u32(value) & (POINTER_BUCKETS - 1)
}
@(private)
entry_lookup :: proc "contextless" (ctx: ^Context, pointer: rawptr) -> (u32, bool) {
	context = runtime.default_context()
	link := ctx.pointer_heads[pointer_bucket(pointer)]
	for _ in 0..<ctx.capacity {
		if link == 0 {return 0, false}
		index := u32(link - 1)
		assert(index < ctx.capacity, "invalid meter pointer index")
		if ctx.entries[index].pointer == pointer {return index, true}
		link = ctx.pointer_next[index]
	}
	assert(link == 0, "cyclic meter pointer index")
	return 0, false
}
@(private)
entry_link :: proc "contextless" (ctx: ^Context, index: u32) {
	context = runtime.default_context()
	assert(index < ctx.capacity && ctx.entries[index].pointer != nil)
	assert(ctx.pointer_next[index] == 0)
	bucket := pointer_bucket(ctx.entries[index].pointer)
	ctx.pointer_next[index] = ctx.pointer_heads[bucket]
	ctx.pointer_heads[bucket] = u16(index + 1)
}
@(private)
entry_unlink :: proc "contextless" (ctx: ^Context, index: u32) {
	context = runtime.default_context()
	assert(index < ctx.capacity && ctx.entries[index].pointer != nil)
	bucket := pointer_bucket(ctx.entries[index].pointer)
	previous: u16
	link := ctx.pointer_heads[bucket]
	for _ in 0..<ctx.capacity {
		if link == 0 {break}
		current := u32(link - 1)
		assert(current < ctx.capacity, "invalid meter pointer index")
		if current == index {
			if previous == 0 {
				ctx.pointer_heads[bucket] = ctx.pointer_next[index]
			} else {
				ctx.pointer_next[u32(previous - 1)] = ctx.pointer_next[index]
			}
			ctx.pointer_next[index] = 0
			return
		}
		previous = link
		link = ctx.pointer_next[current]
	}
	assert(false, "live meter allocation absent from pointer index")
}
@(private)
entry_retire :: proc "contextless" (ctx: ^Context, index: u32) {
	context = runtime.default_context()
	// Called only after an actual backing free, including the last pinned drop.
	entry_unlink(ctx, index)
	generation := ctx.entries[index].generation
	ctx.entries[index] = {generation = generation}
	assert(ctx.free_count < ctx.capacity)
	ctx.free_slots[ctx.free_count] = u16(index)
	ctx.free_count += 1
	ctx.values.allocation_count -= 1
}

@(private)
find :: proc "contextless" (pointer: rawptr) -> ^Context {
	node := head
	for node != nil {if rawptr(node) == pointer {return node}; node = node.next}
	return nil
}
@(private)
guard :: proc "contextless" (ctx: ^Context) -> bg.Status {
	if ctx == nil || find(ctx) == nil {return bg.INVALID_HANDLE}
	totals: bg.Request_Totals
	return ctx.service.request_totals(ctx.service.user, &totals)
}
@(private)
publish :: proc "contextless" (ctx: ^Context) -> bg.Status {
	c := &categories[ctx.category - 1]
	return ctx.service.account(ctx.service.user, ctx.category, c.live, c.requested)
}
@(private)
change :: proc "contextless" (ctx: ^Context, add, subtract, requested: u64) -> bg.Status {
	c := &categories[ctx.category - 1]
	if subtract > ctx.values.live_bytes ||
	   subtract > c.live ||
	   add > max(u64) - (ctx.values.live_bytes - subtract) ||
	   add > max(u64) - (c.live - subtract) ||
	   requested > max(u64) - c.requested ||
	   requested > max(u64) - ctx.values.requested_bytes {return bg.CAPACITY}
	ctx.values.live_bytes = ctx.values.live_bytes - subtract + add
	ctx.values.requested_bytes += requested
	ctx.values.peak_bytes = max(ctx.values.peak_bytes, ctx.values.live_bytes)
	c.live = c.live - subtract + add; c.requested += requested
	return publish(ctx)
}
// Creates one source-owned reference. Metadata is a fixed, charged live table;
// capacity limits usable entries, not its physical allocation size. A backing
// allocator with borrowed data rejects rather than inventing its data lifetime.
create :: proc(
	service: bg.Service,
	category: u32,
	backing_allocator := mem.Allocator{},
	capacity: u32 = MAX_ALLOCATIONS,
) -> (
	^Context,
	bg.Status,
) {
	if service.realm == 0 ||
	   service.user == nil ||
	   service.account == nil ||
	   service.request_totals == nil ||
	   service.legacy_extra == nil ||
	   category == 0 ||
	   category > u32(len(categories)) ||
	   capacity == 0 ||
	   capacity > MAX_ALLOCATIONS {return nil, bg.INVALID_ARGUMENT}
	backing := backing_allocator
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		if !web_backing_installed {return nil, bg.UNSUPPORTED}
		if backing.procedure == nil && backing.data == nil {backing=web_backing}
		if backing.data!=nil || backing.procedure!=web_backing.procedure {return nil,bg.UNSUPPORTED}
	} else {
		if backing.procedure == nil && backing.data == nil {backing = runtime.heap_allocator()}
		if backing.data != nil ||
		   backing.procedure != runtime.heap_allocator().procedure {return nil, bg.UNSUPPORTED}
	}
	c := &categories[category - 1]
	if c.realm != 0 && c.realm != service.realm {return nil, bg.INCOMPATIBLE}
	totals: bg.Request_Totals
	if status := service.request_totals(service.user, &totals);
	   status != bg.OK {return nil, status}
	extra: u64
	if status := service.legacy_extra(service.user, 0, 0, u64(size_of(Context)), &extra);
	   status != bg.OK {return nil, status}
	ctx, error := new(Context, backing)
	if error != nil || ctx == nil {return nil, bg.OUT_OF_MEMORY}
	ctx.service =
		service; ctx.backing = backing; ctx.category = category; ctx.capacity = capacity; ctx.values.references = 1
	ctx.free_count = capacity
	for i in 0..<capacity {ctx.free_slots[i] = u16(capacity - 1 - i)}
	ctx.next = head; head = ctx; c.realm = service.realm
	status := change(ctx, u64(size_of(Context)), 0, u64(size_of(Context)))
	if status != bg.OK {
		_ = change(ctx, 0, u64(size_of(Context)), 0)
		head = ctx.next; free(ctx, backing); return nil, status
	}
	return ctx, bg.OK
}
allocator :: proc "contextless" (ctx: ^Context) -> mem.Allocator {
	if ctx == nil || find(ctx) == nil {return {}}
	return {data = ctx, procedure = allocation_proc}
}
context_for :: proc "contextless" (a: mem.Allocator) -> (^Context, bg.Status) {
	if a.procedure != allocation_proc || a.data == nil {return nil, bg.UNSUPPORTED}
	ctx := find(a.data); if ctx == nil {return nil, bg.INVALID_HANDLE}
	return ctx, bg.OK
}
is_allocator :: proc "contextless" (a: mem.Allocator) -> bool {_, status := context_for(a); return(
		status ==
		bg.OK \
	)}
owns :: proc "contextless" (ctx: ^Context, pointer: rawptr, size: u64) -> bool {
	if ctx == nil || find(ctx) == nil || pointer == nil {return false}
	address := u64(uintptr(pointer))
	for e in ctx.entries[:ctx.capacity] {
		base := u64(uintptr(e.pointer))
		if e.pointer != nil &&
		   address >= base &&
		   address - base <= e.size &&
		   size <= e.size - (address - base) {return true}
	}
	return false
}
stats :: proc "contextless" (ctx: ^Context) -> (Stats, bg.Status) {
	if status := guard(ctx); status != bg.OK {return {}, status}
	return ctx.values, bg.OK
}
// Cached producer-local diagnostics only. Core remains the authoritative
// process-wide ledger; this getter never publishes or creates a host profile.
category_stats :: proc "contextless" (category: u32) -> (Category_Stats, bg.Status) {
	if category == 0 || category > u32(len(categories)) {return {}, bg.INVALID_ARGUMENT}
	result := Category_Stats {
		live_bytes      = categories[category - 1].live,
		requested_bytes = categories[category - 1].requested,
	}
	node := head
	for node !=
	    nil {if node.category == category {result.contexts += 1; result.allocations += node.values.allocation_count}; node = node.next}
	return result, bg.OK
}
retain :: proc "contextless" (ctx: ^Context) -> bg.Status {
	if status := guard(ctx); status != bg.OK {return status}
	if ctx.values.references == max(u64) {return bg.CAPACITY}
	ctx.values.references += 1; return bg.OK
}
@(private)
drop :: proc(ctx: ^Context) -> bg.Status {
	if status := guard(ctx); status != bg.OK {return status}
	if ctx.values.references > 1 {ctx.values.references -= 1; return bg.OK}
	if ctx.values.allocation_count != 0 {return bg.INVALID_HANDLE}
	// Cleanup can observe an already exhausted operation. Core still commits
	// the nonincreasing live update; do not retain a duplicate retry reference.
	status := change(ctx, 0, u64(size_of(Context)), 0)
	if status != bg.OK &&
	   status != bg.CAPACITY {_ = change(ctx, u64(size_of(Context)), 0, 0); return status}
	previous: ^Context; node := head
	for node != ctx {previous = node; node = node.next; assert(node != nil)}
	if previous == nil {head = ctx.next} else {previous.next = ctx.next}
	backing := ctx.backing; free(ctx, backing); return bg.OK
}
destroy :: proc(owner: ^^Context) -> bg.Status {
	if owner == nil || owner^ == nil {return bg.OK}
	if status := drop(owner^); status != bg.OK {return status}
	owner^ = nil; return bg.OK
}
@(private)
lease_retain :: proc "c" (user: rawptr) -> bg.Status {return retain(cast(^Context)user)}
@(private)
lease_drop :: proc "c" (user: rawptr) -> bg.Status {context = runtime.default_context()
	return drop(cast(^Context)user)}
data_lease :: proc "contextless" (ctx: ^Context) -> bg.Data_Lease {
	if ctx == nil || find(ctx) == nil {return {}}
	return {user = ctx, retain = lease_retain, drop = lease_drop}
}

// A distinct data owner for one EXPLICIT known allocation and declared user
// alias. Membership alone is never treated as ownership. The returned lease's
// user is exactly the requested callback user, including a checked subfield.
// Lease definitions are borrowed until retained; after the last drop they are
// retired, not reusable handles. Core's Owner adds generational token safety.
block_lease :: proc "contextless" (
	ctx: ^Context,
	allocation_base: rawptr,
	allocation_size: u64,
	user: rawptr,
	user_size: u64,
) -> (
	bg.Data_Lease,
	bg.Status,
) {
	if status := guard(ctx); status != bg.OK {return {}, status}
	if allocation_base == nil ||
	   user == nil ||
	   allocation_size == 0 ||
	   user_size == 0 {return {}, bg.INVALID_ARGUMENT}
	index, found := entry_lookup(ctx, allocation_base)
	if !found ||
	   ctx.entries[index].size != allocation_size ||
	   ctx.entries[index].pending_free {return {}, bg.INVALID_HANDLE}
	base, address := u64(uintptr(allocation_base)), u64(uintptr(user))
	if address < base ||
	   address - base > allocation_size ||
	   user_size > allocation_size - (address - base) {return {}, bg.INVALID_ARGUMENT}
	// Never rebind a retired user address while its meter context remains live.
	node := head
	for node !=
	    nil {for alias in node.aliases {if alias.user == user {return {}, bg.INVALID_HANDLE}}; node = node.next}
	for &alias in ctx.aliases {if alias.user == nil {
			alias = {
				user       = user,
				entry      = u32(index),
				generation = ctx.entries[index].generation,
			}
			return {user = user, retain = block_retain, drop = block_drop}, bg.OK
		}}
	return {}, bg.CAPACITY
}
@(private)
find_alias :: proc "contextless" (user: rawptr) -> (^Context, ^Alias) {
	node := head
	for node !=
	    nil {for &alias in node.aliases {if alias.user == user && !alias.retired {return node, &alias}}; node = node.next}
	return nil, nil
}
@(private)
block_retain :: proc "c" (user: rawptr) -> bg.Status {
	ctx, alias := find_alias(user)
	if ctx == nil {return bg.INVALID_HANDLE}
	if status := guard(ctx); status != bg.OK {return status}
	entry := &ctx.entries[alias.entry]
	if entry.pointer == nil ||
	   entry.generation != alias.generation ||
	   (entry.pending_free && alias.references == 0) ||
	   alias.references == max(u64) ||
	   entry.pins == max(u64) ||
	   ctx.values.references == max(u64) {return bg.INVALID_HANDLE}
	alias.started = true; alias.references += 1; entry.pins += 1; ctx.values.references += 1
	return bg.OK
}
@(private)
block_drop :: proc "c" (user: rawptr) -> bg.Status {
	context = runtime.default_context()
	ctx, alias := find_alias(user)
	if ctx == nil {return bg.INVALID_HANDLE}
	if status := guard(ctx); status != bg.OK {return status}
	entry := &ctx.entries[alias.entry]
	if !alias.started ||
	   alias.references == 0 ||
	   entry.pointer == nil ||
	   entry.generation != alias.generation ||
	   entry.pins == 0 {return bg.INVALID_HANDLE}
	alias.references -= 1; entry.pins -= 1
	if alias.references == 0 {alias.retired = true}
	if entry.pins == 0 && entry.pending_free {
		_, error := ctx.backing.procedure(
			ctx.backing.data,
			.Free,
			0,
			entry.alignment,
			entry.pointer,
			int(entry.size),
			#location(),
		)
		assert(error == nil, "known heap final block free failed")
		bytes := entry.size
		entry_retire(ctx, alias.entry)
		status := change(ctx, 0, bytes, 0); assert(status == bg.OK || status == bg.CAPACITY)
	}
	return drop(ctx)
}

@(private)
allocation_proc :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	location: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	ctx := find(data)
	if ctx == nil {return nil, .Invalid_Pointer}
	if status := guard(ctx); status != bg.OK {return nil, .Invalid_Argument}
	if size < 0 {return nil, .Invalid_Argument}
	if mode == .Free_All {return nil, .Mode_Not_Implemented}
	if mode == .Query_Features || mode == .Query_Info {return nil, .Mode_Not_Implemented}
	entry: ^Entry
	index: u32
	if old !=
	   nil {
		found: bool
		index, found = entry_lookup(ctx, old)
		if !found {return nil, .Invalid_Pointer}
		entry = &ctx.entries[index]
	}
	if mode == .Free || ((mode == .Resize || mode == .Resize_Non_Zeroed) && size == 0) {
		if entry == nil {return nil, .None}
		if entry.pending_free {return nil, .Invalid_Pointer}
		if entry.pins != 0 {entry.pending_free = true; return nil, .None}
		bytes := entry.size
		_, error := ctx.backing.procedure(
			ctx.backing.data,
			.Free,
			0,
			entry.alignment,
			old,
			int(bytes),
			location,
		)
		if error != nil {return nil, error}
		entry_retire(ctx, index)
		status := change(ctx, 0, bytes, 0)
		assert(
			status == bg.OK || status == bg.CAPACITY,
			"nonincreasing host release could not be recorded",
		)
		return nil, .None
	}
	if mode != .Alloc &&
	   mode != .Alloc_Non_Zeroed &&
	   mode != .Resize &&
	   mode != .Resize_Non_Zeroed {return nil, .Mode_Not_Implemented}
	if (mode == .Alloc || mode == .Alloc_Non_Zeroed) && old != nil {return nil, .Invalid_Argument}
	if entry != nil && (entry.pins != 0 || entry.pending_free) {return nil, .Invalid_Argument}
	if size == 0 {return nil, .None}
	if entry == nil {
		if ctx.free_count == 0 {return nil, .Out_Of_Memory}
		index = u32(ctx.free_slots[ctx.free_count - 1])
		assert(index < ctx.capacity && ctx.entries[index].pointer == nil)
		entry = &ctx.entries[index]
	}
	if entry.generation == max(u64) {return nil, .Out_Of_Memory}
	extra: u64
	if ctx.service.legacy_extra(ctx.service.user, 0, 0, u64(size), &extra) !=
	   bg.OK {return nil, .Out_Of_Memory}
	// Never destructively resize old memory before all fallible admission. Both
	// old+new are charged at peak; a rejected update frees only the new block.
	alloc_mode :=
		mode == .Alloc_Non_Zeroed || mode == .Resize_Non_Zeroed ? mem.Allocator_Mode.Alloc_Non_Zeroed : .Alloc
	fresh, error := ctx.backing.procedure(
		ctx.backing.data,
		alloc_mode,
		size,
		alignment,
		nil,
		0,
		location,
	)
	if error != nil ||
	   len(fresh) !=
		   size {if error == nil && raw_data(fresh) != nil {_, _ = ctx.backing.procedure(ctx.backing.data, .Free, 0, alignment, raw_data(fresh), len(fresh), location)}; return nil, error == nil ? .Out_Of_Memory : error}
	status := change(ctx, u64(len(fresh)), 0, u64(len(fresh)))
	if status != bg.OK {
		_, _ = ctx.backing.procedure(
			ctx.backing.data,
			.Free,
			0,
			alignment,
			raw_data(fresh),
			len(fresh),
			location,
		)
		cleanup := change(
			ctx,
			0,
			u64(len(fresh)),
			0,
		); assert(cleanup == bg.OK || cleanup == bg.CAPACITY)
		return nil, .Out_Of_Memory
	}
	if old != nil {
		previous := entry^; copy(fresh[:min(len(fresh), int(previous.size))], (cast([^]u8)old)[:min(len(fresh), int(previous.size))])
		_, free_error := ctx.backing.procedure(
			ctx.backing.data,
			.Free,
			0,
			previous.alignment,
			old,
			int(previous.size),
			location,
		)
		assert(free_error == nil, "accepted builtin backing free failed")
		cleanup := change(
			ctx,
			0,
			previous.size,
			0,
		); assert(cleanup == bg.OK || cleanup == bg.CAPACITY)
		entry_unlink(ctx, index)
	} else {
		ctx.free_count -= 1
		ctx.values.allocation_count += 1
	}
	generation := entry.generation + 1
	entry^ = {
		pointer    = raw_data(fresh),
		size       = u64(len(fresh)),
		generation = generation,
		alignment  = alignment,
	}
	entry_link(ctx, index)
	return fresh, .None
}

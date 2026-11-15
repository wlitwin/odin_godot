This optional package observes successful HOST allocation requests and actual
live heap bytes through the pure `box3d/godot` Service. It imports no native
library and does not register a physics profile. Install its allocator before
constructing a managed Lane/Session/Timeline/schema; wrapping an existing
container silently cannot recover its allocation history or data ownership.

Producer-local APIs (these are not cross-module C arguments):

- `create(service, category, backing_allocator={}, capacity=4096)` returns an
  owned `^Context` reference plus Status. Zero backing selects the known runtime
  heap allocator. Borrowed allocator data and custom procedures reject. Capacity
  is at most 4096; the entire fixed table and 64 lease records are charged.
- `allocator(ctx)`, `is_allocator(a)`, `context_for(a)`, `stats(ctx)`, and
  `category_stats(category)` expose the allocator and observations. `owns` checks
  current membership only. It does not retain an allocation.
- `data_lease(ctx)` returns a borrowed C Data_Lease definition for the allocator
  context. Core's Owner construction retains it. `retain(ctx)` / `destroy(&ctx)`
  manage explicit source references; a successful destroy clears only that
  caller's reference. A last context reference with live blocks cannot disappear.
- `block_lease(ctx, allocation_base, allocation_size, user, user_size)` returns
  a separate borrowed Data_Lease definition for one explicit known allocation
  and declared callback-user alias. Base and size must exactly match a tracked
  allocation; the complete user range must fit inside it. The lease's `user`
  equals the declared callback user exactly. Core may still reject source Scene
  userdata: a meter does not turn a borrowed Scene instance into managed heap.

Context/Stats internals must not be mutated. All allocating operations require
the installed protected origin through Service. Each successful allocation
(including later rolled-back or freed work) increases requested totals. Resize
allocates a new block, charges old plus new, validates admission, copies, and
only then frees old memory. Rejection preserves the old buffer and keeps the
successful temporary request in cumulative totals. Pinned resize rejects.

Exact allocation-base lookup uses a fixed pointer index: 2048 bucket heads and
4096 next links, each storing an Entry index plus one. A fixed 4096-slot free
stack locates unused Entries. These arrays and their counter are included in
the actual charged `sizeof(Context)`, even for a smaller configured capacity.
There are no index allocations, tombstones, or rehashes. Hash collisions compare
the full pointer and follow a chain bounded by 4096 Entries; constant-time
lookup is not guaranteed. Interior-range `owns` keeps its range scan.

Live Entries never move, and resize keeps the Entry index while advancing its
generation only after successful commit. Index/free-stack changes follow the
existing allocation admission and successful backing free. Denied resize keeps
the old pointer, payload, Entry and index intact. A pending pinned free remains
indexed, live and unavailable for reuse until the final block lease drops.
Free-stack reuse is internal LIFO; it does not permit reusing retired aliases.
The index does not batch or remove Service guard/accounting calls.

Retained block leases pin the real allocation and context. Free of a pinned
block marks pending-free and keeps its live charge; the last lease drop frees
it. Copies of a live lease must retain before use. After its last drop the lease
is retired, and stale/double drop rejects; alias slots are never reused within
a live context. Raw Data_Lease definitions are not durable generational handles
after their owned lifetime. The Core Owner tokens provide the outer generation
and code-lifetime boundary. No pointer, Context or allocator is canonical wire.

One producer category receives the aggregate of all its meter contexts. Do not
also publish manual Core/provider/codec byte estimates for these same allocations.
Logical resource counters may remain diagnostics. Core alone combines category
LIVE with the producer's remaining reservation and the other producer/native
contributions. Its allocation/request budget is observational admission, not a
hard cap on the native allocator. A failed operation must still end its exact
unique budget mark once. Cleanup can reduce LIVE while an exhausted operation
continues to return Capacity.

Run pure tests with `odin test box3d/godot/meter/tests -collection:godot=.
-define:ODIN_TEST_THREADS=1`. Tests live in a separate subpackage so a default or
WASM consumer imports neither core:testing nor any native physics linkage.

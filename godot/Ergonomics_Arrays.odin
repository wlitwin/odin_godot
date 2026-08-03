package godot

// Ergonomic helpers for Godot Array iteration — hand-written and owned here (binding
// regeneration only rewrites *.gen.odin).
//
// Engine methods that return collections hand back a refcounted Godot `Array` whose
// elements only come out one Variant at a time (`array_get` + `variant_to_*`) — a dance
// every consumer re-spells. These collapse it to "give me an Odin slice".
//
// ALLOCATION: unlike most of the ergonomics layer this is NOT `contextless` — it
// allocates the returned slice, in `context.temp_allocator` by default (call-local: the
// core resets the temp arena each frame, so iterate the result now and don't stash it;
// pass a real allocator to keep it). Script procs always run with the script context
// set, so calling from any lifecycle/@(gd_method)/signal body is fine.

// array_unpack unpacks a typed Godot array into an Odin slice, each element converted via
// `variant_to`. Faithful: one entry per array element, in order — an Object element whose
// node has been freed comes out nil (see `nodes_in_group` for the filtered group form).
// The slice's values are their own (converted) copies, but for Object/Ref_Counted
// element types the HANDLES borrow lifetime from whatever owns the objects, so keep the
// source array alive until you're done when it is the only owner:
//
//     children := gd.node_get_children(self.owner, false)
//     defer gd.free_array(children.untyped)
//     for child in gd.array_unpack(&children) {
//         // child is gd.Node — passes to any helper with no cast
//     }
array_unpack :: proc(arr: ^Typed_Array($T), allocator := context.temp_allocator) -> []T {
	n := int(array_size(&arr.untyped))
	out := make([]T, n, allocator)
	for i in 0 ..< n {
		v := array_get(&arr.untyped, Int(i))
		out[i] = variant_to(&v, T)
		variant_destroy(&v)
	}
	return out
}

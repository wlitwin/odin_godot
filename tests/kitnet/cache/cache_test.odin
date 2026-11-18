package kitnet_cache_test

import "core:mem"
import "core:testing"
import knet "godot:kit/net"

@(test)
host_cache_storage_survives_callers_and_releases_at_shutdown :: proc(t: ^testing.T) {
    tracked: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracked, context.allocator)
    defer mem.tracking_allocator_destroy(&tracked)
    tracked.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
    persistent := mem.tracking_allocator(&tracked)
    fields := [?]knet.Field_Desc{{name = "position", size = 4, flags = {.Owner_Stream}}, {name = "score", size = 4}}
    desc := knet.Entity_Desc {
        fields = fields[:],
    }
    for _ in 0 ..< 2 {
        testing.expect(t, knet.subset_cache_init(persistent))
        view: ^knet.Subset_View
        {
            // A callback's allocation policy cannot take ownership of this cache.
            context.allocator = mem.nil_allocator()
            view = knet.subset_view(&desc, .Full)
        }
        testing.expect_value(t, view.struct_bytes, 8)
        testing.expect_value(t, len(view.entries), 2)
        testing.expect(t, knet.subset_view(&desc, .Full) == view)
        testing.expect(t, len(tracked.allocation_map) > 0)
        testing.expect(t, !knet.subset_cache_init(context.allocator))
        knet.subset_cache_destroy()
        testing.expect_value(t, len(tracked.allocation_map), 0)
        testing.expect_value(t, len(tracked.bad_free_array), 0)
        knet.subset_cache_destroy() // idempotent shutdown
    }
}

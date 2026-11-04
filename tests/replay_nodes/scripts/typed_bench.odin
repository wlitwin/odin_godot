package nodes_probe
import "core:fmt"
import gd "godot:godot"
import v "godot:replay/view"
import scenegd "godot:replay/godot/scene"

when !LEGACY {
    typed_bench :: proc(self: ^ReplayNodesProbe) {
        count := int(gd.env_int("REPLAY_NODES_COUNT", 512))
        capacity := int(gd.env_int("REPLAY_NODES_CAPACITY", count))
        assert(count > 0 && capacity >= count && capacity <= 2048)
        views: scenegd.View_Pool2(u32, u32, gd.Node2d)
        binding := scenegd.View_Binding(u32, gd.Node2d) {
            attach = proc(_: rawptr, node: gd.Node2d) -> (gd.Node2d, bool) {
                return node, true
            },
            paint = proc(_: rawptr, node: ^gd.Node2d, value: u32) {},
        }
        assert(scenegd.view_pool_load(&views, self.owner, "res://view.tscn", capacity, binding))
        defer scenegd.view_pool_destroy(&views)
        items := make([]v.View_Item(u32, u32), count)
        defer delete(items)

        for &item, i in items {
            item = {
                handle = {u32(i), 1},
                view = {pose = {position = {f32(i), 2}, angle = .25}, scale = {2, 3}, color = {1, .5, .25, 1}},
            }
        }

        assert(scenegd.view_pool_present(&views, {1, 0}, items) == .None)

        for sample in 0 ..< 6 {
            before := gd.time_get_ticks_usec(gd.singleton_time())

            for frame in 0 ..< 120 {
                for &item, i in items {
                    item.view.pose.position[0] = f32(i) + f32(frame % 16)
                }

                assert(scenegd.view_pool_present(&views, {1, 0}, items) == .None)
            }

            elapsed := gd.time_get_ticks_usec(gd.singleton_time()) - before

            if sample > 0 {
                gd.print_str(fmt.tprintf("REPLAY_NODES_BENCH typed=true count=%d frames=120 us=%d", count, elapsed))
            }
        }

        gd.print_str(
            fmt.tprintf(
                "REPLAY_NODES_OPS writes=%d skips=%d probes=%d",
                views.nodes.stats.property_writes,
                views.nodes.stats.property_skips,
                views.nodes.index.probes + views.nodes.desired.probes,
            ),
        )
        gd.print_str(fmt.tprintf("REPLAY_TYPED_OPS paints=%d skips=%d", views.paints, views.skipped_paints))
    }
}

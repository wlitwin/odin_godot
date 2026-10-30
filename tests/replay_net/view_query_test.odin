package replay_net_test

import "core:testing"
import h "godot:replay/history"
import net "godot:replay/net"

@(test)
view_query_resolves_only_available_valid_history :: proc(t: ^testing.T) {
	history: h.History(i32, 4)
	h.record(&history, 2, i32(10)); h.record(&history, 3, i32(20))
	blend := proc(a, b: i32, fraction: u16) -> i32 {return fraction == 0 ? a : b}
	query := net.query_view(&history, net.View_Time{2, 3, 1, .Historical}, i32(99), 5, blend)
	testing.expect(t, query.available); testing.expect_value(t, query.value, i32(20)); testing.expect_value(t, query.tick, u64(2))
	query = net.query_view(&history, net.View_Time{status = .Live}, i32(99), 5, blend)
	testing.expect(t, query.available); testing.expect_value(t, query.value, i32(99))
	for view in ([5]net.View_Time{{1, 2, 0, .Historical}, {3, 2, 0, .Historical}, {2, 9, 0, .Historical}, {status = .Expired}, {status = .Unavailable}}) {
		query = net.query_view(&history, view, i32(99), 5, blend)
		testing.expect(t, !query.available); testing.expect_value(t, query.value, i32(0))
	}
	h.record(&history, 6, i32(30)) // overwrite the old tick-2 slot
	query = net.query_view(&history, net.View_Time{2, 3, 0, .Historical}, i32(99), 6, blend)
	testing.expect(t, !query.available); testing.expect_value(t, query.status, net.View_Status.Unavailable)
}

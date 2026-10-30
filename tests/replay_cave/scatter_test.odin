package replay_cave_test
import "core:testing"
import cave "../../examples/replay_cavecrawl/shared/cave"
@(test)
scatter_zero_seed_and_recorded_original_checksums :: proc(t:^testing.T) {
	zero:=cave.scatter(0,1);testing.expect_value(t,zero.count,u8(0));testing.expect_value(t,zero.checksum,u32(0))
	first,second:=cave.scatter(1337,1),cave.scatter(1337,2)
	testing.expect_value(t,first.count,u8(10));testing.expect_value(t,first.checksum,u32(976669602));testing.expect_value(t,second.checksum,u32(4288723372))
}

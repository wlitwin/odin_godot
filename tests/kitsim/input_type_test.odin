package kit_sim_test

import "core:testing"
import ksim "godot:kit/sim"

@(test)
typed_input_requires_a_registered_type :: proc(t: ^testing.T) {
    lane: ksim.Lane
    lane.inputs = make([dynamic]ksim.Input_Class, 1, 1, context.temp_allocator)
    lane.inputs[0] = {id = 0, size = size_of(i8)}
    testing.expect_assert(t, "lane_input_of: input type is not registered; call lane_class_set_type or use lane_input with an explicit class ID")
    ksim.lane_input_of(&lane, 1, i8)
}

@(test)
typed_input_rejects_an_unregistered_type_with_the_same_size :: proc(t: ^testing.T) {
    lane: ksim.Lane
    lane.inputs = make([dynamic]ksim.Input_Class, 1, 1, context.temp_allocator)
    lane.inputs[0] = {id = 0, size = size_of(i8), type = typeid_of(i8)}
    testing.expect_assert(t, "lane_input_of: input type is not registered; call lane_class_set_type or use lane_input with an explicit class ID")
    ksim.lane_input_of(&lane, 1, u8)
}

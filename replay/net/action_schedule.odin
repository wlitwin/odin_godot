package replay_net

// A pure payload classifier. Change id whenever its semantics change. The
// authority records the chosen execution tick; replay never calls this policy.
Action_Schedule :: struct($Action: typeid) {
    id:     u64,
    timing: proc(action: Action) -> Action_Timing,
}

@(private)
action_schedule_valid :: proc(schedule: Action_Schedule($Action)) -> bool {
    return (schedule.id == 0) == (schedule.timing == nil)
}

@(private)
action_timing_for :: proc(model: Model($S, $C, $A, $E, $N), action: A) -> Action_Timing {
    if model.action_schedule.timing != nil {
        return model.action_schedule.timing(action)
    }

    return model.action_timing
}

package replay_net

import r "godot:replay"

// Recorded simulation metadata supplied by the authority runner. Clients do not
// predict this observation; they receive its consequences in replicated state.
// Seat zero represents a dedicated authority with no local player.
Authority_Observation :: struct {
    known: bool,
    seat:  u16,
}

// Apply is pure simulation code, called every authority tick after fresh-player
// resets and before ordinary gameplay. Keep previous authority identity in State
// if the game needs a transition. Changing policy semantics requires a new id.
Authority_Policy :: struct($State, $Event: typeid) {
    id:    u64,
    apply: proc(state: ^State, authority: Authority_Observation, ctx: ^r.Step(Event)),
}

@(private)
authority_policy_valid :: proc(policy: Authority_Policy($S, $E)) -> bool {
    return (policy.id == 0) == (policy.apply == nil)
}

@(private)
authority_observation_valid :: proc(
    policy: Authority_Policy($S, $E),
    observation: Authority_Observation,
    seats: int,
) -> bool {
    return(
        authority_policy_valid(policy) &&
        (observation.known ? policy.id != 0 && int(observation.seat) <= seats : observation.seat == 0) \
    )
}

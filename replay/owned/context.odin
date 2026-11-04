package replay_owned

import r "godot:replay"

// A reliable action's claimed context is independent of the coalesced pose
// stream. It names an ownership/lifetime scope, not a stream sequence or an
// authority history timestamp. The outer action supplies ordering/deduplication.
Action_Context :: struct($T: typeid) {
    scope: Scope,
    value: T,
}

context_valid :: proc(claim: Action_Context($T), rules: Rules(T)) -> bool {
    return(
        r.value_supported(T) &&
        claim.scope.key.kind != 0 &&
        claim.scope.key.generation != 0 &&
        claim.scope.epoch != 0 &&
        claim.scope.revision != 0 &&
        rules.valid != nil &&
        rules.valid(rules.user, claim.value) \
    )
}

capture_context :: proc(d: ^Driver, value: $T) -> (Action_Context(T), Error) {
    if d == nil || d.role != .Owner || d.scope.epoch != d.epoch || d.scope.revision == 0 {
        return {}, .Invalid_Owner
    }

    return {d.scope, value}, .None
}

// Read without applying a sample, advancing a frontier, or committing an offer.
// A later pose sample does not invalidate the claim; a scope/owner change does.
// Rules.valid checks the context's values. Rules.transition is a stream-update
// policy and is deliberately not applied here. The game separately chooses
// range/leash/age rules; this does not certify an honest or historical engine pose.
read_context :: proc(s: ^State($T), sender: u16, claim: Action_Context(T), tick: u64, rules: Rules(T)) -> (T, Error) {
    if s == nil {
        return {}, .Not_Ready
    }

    if error := at_time(s, tick); error != .None {
        return {}, error
    }

    if claim.scope != scope(s^) {
        return {}, .Stale_Scope
    }

    if sender == 0 || sender != s.owner {
        return {}, .Invalid_Owner
    }

    if !context_valid(claim, rules) {
        return {}, .Invalid_Value
    }

    return claim.value, .None
}

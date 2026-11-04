package replay_authority

// Optional RPC extension using the unchanged canonical Request/Reply layouts.
// A Query-shaped command carries only the current epoch and exact target identity.
// The distinct envelope/MAC domain prevents an old Query from becoming removal.
RPC_REMOVE_REQUEST :: u16(0x5203)
RPC_REMOVE_REPLY :: u16(0x5204)

rpc_remove :: proc(c: ^Rpc_Client, epoch: u64, target: Identity) -> Error {
    if epoch == 0 || !identity_valid(target) {
        return .Invalid
    }

    return rpc_begin_kind(c, {verb = .Query, epoch = epoch, successor = target}, RPC_REMOVE_REQUEST)
}

// Only a current, unretired authority may exclude another exact incarnation.
// Exclusion persists for the room; it is not undone by a new game process or a
// restored gameplay checkpoint. Trusted administration is needed to re-enable it.
coordinator_remove :: proc(c: ^Coordinator, actor: Identity, epoch: u64, target: Identity, now: u64) -> Error {
    if error := coordinator_time(c, now); error != .None {
        return error
    }

    if !coordinator_owner(c, actor, epoch) || c.record.released || target.member == actor.member {
        return .Denied
    }

    if !identity_valid(target) {
        return .Invalid
    }

    for member in c.record.members {
        if member.identity.member == target.member {
            if member.identity != target {
                return .Stale
            }

            if !member.enabled {
                return .None
            }

            member := member
            member.enabled = false
            return coordinator_member(c, member, now)
        }
    }

    return .Denied
}

@(private)
remove_command_valid :: proc(command: Command) -> bool {
    return(
        command.epoch != 0 &&
        identity_valid(command.successor) &&
        command == (Command{verb = .Query, epoch = command.epoch, successor = command.successor}) \
    )
}

package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"

PHYSICS_RECEIPT_BYTES :: 52

@(private)
receipt_put64 :: proc(bytes: []u8, value: u64) {
    for i in 0 ..< 8 {
        bytes[i] = u8(value >> uint(i * 8))
    }
}

@(private)
receipt_get64 :: proc(bytes: []u8) -> u64 {
    value: u64

    for i in 0 ..< 8 {
        value |= u64(bytes[i]) << uint(i * 8)
    }

    return value
}

@(private)
physics_receipts_encode :: proc(s: ^Server($S, $C, $A, $E, $N), allocator: mem.Allocator) -> (Complete_Data, Error) {
    inputs, actions := 0, 0

    for peer, index in s.peers {
        if peer.phase == .Vacant {
            continue
        }

        for receipt in s.physics.input_receipts[index] {
            if receipt.generation == peer.generation &&
               receipt.tick > s.timeline.head &&
               receipt.tick - s.timeline.head <= u64(s.cfg.max_future) {
                inputs += 1
            }
        }

        for receipt in s.physics.action_receipts[index] {
            if receipt.sequence != 0 &&
               receipt.sequence <= peer.action_received &&
               peer.action_received - receipt.sequence < ACTION_CAPACITY {
                actions += 1
            }
        }
    }

    n := 24 + (inputs + actions) * PHYSICS_RECEIPT_BYTES

    if n > 65536 {
        return {}, .Capacity
    }

    if error := s.model.complete_codec.reserve(s.model.complete_codec.catalog, u64(n)); error != .None {
        return {}, error
    }

    bytes, allocation_error := mem.alloc_bytes(n, allocator = allocator)

    if allocation_error != .None {
        s.model.complete_codec.release(s.model.complete_codec.catalog, u64(n))
        return {}, .Capacity
    }

    copy(bytes[:8], "RPLRCPT1")
    complete_put32(bytes[8:12], 1)
    complete_put32(bytes[12:16], u32(inputs))
    complete_put32(bytes[16:20], u32(actions))
    complete_put32(bytes[20:24], 0)
    at := 24

    for peer, index in s.peers {
        if peer.phase == .Vacant {
            continue
        }

        for receipt in s.physics.input_receipts[index] {
            if receipt.generation != peer.generation ||
               receipt.tick <= s.timeline.head ||
               receipt.tick - s.timeline.head > u64(s.cfg.max_future) {
                continue
            }

            complete_put32(bytes[at:at + 4], u32(index))
            receipt_put64(bytes[at + 4:at + 12], receipt.tick)
            receipt_put64(bytes[at + 12:at + 20], receipt.generation)
            digest := receipt.digest
            copy(bytes[at + 20:at + 52], digest[:])
            at += 52
        }
    }

    for peer, index in s.peers {
        if peer.phase == .Vacant {
            continue
        }

        for receipt in s.physics.action_receipts[index] {
            if receipt.sequence == 0 ||
               receipt.sequence > peer.action_received ||
               peer.action_received - receipt.sequence >= ACTION_CAPACITY {
                continue
            }

            complete_put32(bytes[at:at + 4], u32(index))
            receipt_put64(bytes[at + 4:at + 12], receipt.sequence)
            receipt_put64(bytes[at + 12:at + 20], receipt.tick)
            digest := receipt.digest
            copy(bytes[at + 20:at + 52], digest[:])
            at += 52
        }
    }

    owned, error := complete_data_adopt(bytes, allocator, s.model.complete_codec)

    if error != .None {
        delete(bytes, allocator)
        s.model.complete_codec.release(s.model.complete_codec.catalog, u64(n))
        return {}, error
    }

    return owned, .None
}

// No allocation, native decode or publication. Validation accepts only retained
// receipt slots associated with a durable peer and pending future control row.
@(private)
physics_receipts_valid :: proc(cp: ^Checkpoint($S, $C, $A, $N), bytes: []u8) -> bool {
    if len(bytes) < 24 ||
       len(bytes) > 65536 ||
       string(bytes[:8]) != "RPLRCPT1" ||
       complete_get32(bytes[8:12]) != 1 ||
       complete_get32(bytes[20:24]) != 0 {
        return false
    }

    inputs, actions := int(complete_get32(bytes[12:16])), int(complete_get32(bytes[16:20]))

    if inputs > MAX_PEERS * 8 || actions > MAX_PEERS * ACTION_CAPACITY || len(bytes) != 24 + (inputs + actions) * 52 {
        return false
    }

    peers: [MAX_PEERS]Checkpoint_Peer
    used: [MAX_PEERS]bool

    for peer in cp.peers {
        if peer.index >= MAX_PEERS {
            return false
        }

        peers[peer.index] = peer
        used[peer.index] = true
    }

    input_slots: [MAX_PEERS][8]bool
    action_slots: [MAX_PEERS][ACTION_CAPACITY]bool

    for i in 0 ..< inputs + actions {
        at := 24 + i * 52
        index := int(complete_get32(bytes[at:at + 4]))
        key := receipt_get64(bytes[at + 4:at + 12])
        aux := receipt_get64(bytes[at + 12:at + 20])
        digest: bd.Digest
        copy(digest[:], bytes[at + 20:at + 52])

        if index >= MAX_PEERS || !used[index] || peers[index].spectator || digest == (bd.Digest{}) {
            return false
        }

        peer := peers[index]

        if i < inputs {
            if peer.local ||
               key <= cp.frame.tick ||
               key - cp.frame.tick > u64(cp.settings.max_future) ||
               aux != peer.generation ||
               input_slots[index][key % 8] {
                return false
            }

            found := false

            for input in cp.inputs {
                if input.peer == u16(index) && input.tick == key {
                    found = true
                    break
                }
            }

            if !found {
                return false
            }

            input_slots[index][key % 8] = true
        } else {
            if key == 0 ||
               key > peer.action_received ||
               peer.action_received - key >= ACTION_CAPACITY ||
               aux == 0 ||
               action_slots[index][key % ACTION_CAPACITY] {
                return false
            }

            action_slots[index][key % ACTION_CAPACITY] = true
        }
    }

    return true
}

@(private)
physics_receipts_restore :: proc(s: ^Server($S, $C, $A, $E, $N), bytes: []u8) {
    inputs, actions := int(complete_get32(bytes[12:16])), int(complete_get32(bytes[16:20]))

    for i in 0 ..< inputs + actions {
        at := 24 + i * 52
        index := int(complete_get32(bytes[at:at + 4]))
        key := receipt_get64(bytes[at + 4:at + 12])
        aux := receipt_get64(bytes[at + 12:at + 20])
        digest: bd.Digest
        copy(digest[:], bytes[at + 20:at + 52])

        if i < inputs {
            s.physics.input_receipts[index][key % PHYSICS_HISTORY] = {key, aux, digest}
        } else {
            s.physics.action_receipts[index][key % ACTION_CAPACITY] = {key, aux, digest}
        }
    }
}

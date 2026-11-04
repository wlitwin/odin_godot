package main

import "core:fmt"
import "core:reflect"
import r "godot:replay"
import loot "game"

main :: proc() {
    local: loot.Timeline
    assert(r.init(&local, r.Frame(loot.World){state = loot.initial()}, loot.step) == .None)
    defer r.destroy(&local)

    inputs: [8]loot.Input
    inputs[0].players[0] = {
        take = true,
        fire = true,
        seq  = 1,
    }
    inputs[1].players[1] = {
        fire = true,
        seq  = 2,
    }

    for input in inputs {
        assert(r.advance(&local, input).error == .None)
    }

    predicted, _ := r.current(&local)
    assert(predicted.state.players[0].bag == 5)

    // A corrected input says the other player took the chest at tick 1.
    // Inventory, chest lifetime, projectiles, RNG, and event history replay together.
    inputs[0].players[0].take = false
    inputs[0].players[1] = {
        take = true,
        seq  = 1,
    }
    revision := r.revise_input(&local, 1, inputs[0])
    assert(revision.error == .None && revision.steps == 8)
    corrected, _ := r.current(&local)
    assert(corrected.state.players[0].bag == 0 && corrected.state.players[1].bag == 5)
    assert(r.audit(&local, 1).error == .None)

    // A fresh reference run receives correct inputs from the beginning.
    reference: loot.Timeline
    assert(r.init(&reference, r.Frame(loot.World){state = loot.initial()}, loot.step) == .None)
    defer r.destroy(&reference)

    for input in inputs {
        assert(r.advance(&reference, input).error == .None)
    }

    expected, _ := r.current(&reference)
    assert(reflect.equal(corrected, expected))

    // In-process checkpoint continuation, not a network migration implementation.
    checkpoint, _ := r.read(&local, 4)
    resumed: loot.Timeline
    assert(r.init(&resumed, checkpoint, loot.step, epoch = 2) == .None)
    defer r.destroy(&resumed)

    for input in inputs[4:] {
        assert(r.advance(&resumed, input).error == .None)
    }

    continued, _ := r.current(&resumed)
    assert(reflect.equal(continued, expected))

    when ODIN_OS != .Freestanding {
        fmt.printfln(
            "REPLAY_LOOT predicted=%d,%d corrected=%d,%d replayed=%d checkpoint_tick=%d",
            predicted.state.players[0].bag,
            predicted.state.players[1].bag,
            corrected.state.players[0].bag,
            corrected.state.players[1].bag,
            revision.steps,
            checkpoint.tick,
        )
        fmt.println("REPLAY_LOOT_OK")
    }
}

package external_fixture

import "core:mem"
import r "godot:replay"

IDENTITY :: u64(0x4558544553543031)
CONTRACT :: u64(17)

Operation :: enum {
    Clone,
    Open,
    Capture,
    Admit,
    Equal,
}

Stats :: struct {
    images, executions, domains, peak_images: int,
    captures, opens:                          u64,
    last_capability:                          r.Execution,
}

Game :: struct {
    sum:   i64,
    ticks: u64,
}

Input :: struct {
    delta: i64,
    abort: bool,
    event: bool,
}

Owner :: struct {
    _domain: ^Domain,
}

Domain :: struct {
    refs:           int,
    allocator:      mem.Allocator,
    stats:          ^Stats,
    fail_at, calls: [Operation]u64,
    bias:           i64,
}

Image :: struct {
    domain: ^Domain,
    value:  i64,
}

Execution :: struct {
    domain: ^Domain,
    value:  i64,
}

retain :: proc(d: ^Domain) {
    d.refs += 1
}

drop :: proc(d: ^Domain) {
    d.refs -= 1

    if d.refs == 0 {
        if d.stats != nil {
            d.stats.domains -= 1
        }

        free(d, d.allocator)
    }
}

failing :: proc(d: ^Domain, operation: Operation) -> bool {
    d.calls[operation] += 1
    return d.fail_at[operation] != 0 && d.calls[operation] == d.fail_at[operation]
}

image_make :: proc(d: ^Domain, value: i64) -> rawptr {
    image := new(Image, d.allocator)
    image^ = {d, value}
    retain(d)

    if d.stats != nil {
        d.stats.images += 1
        d.stats.peak_images = max(d.stats.peak_images, d.stats.images)
    }

    return image
}

clone :: proc(pointer: rawptr) -> (rawptr, r.Error) {
    image := cast(^Image)pointer

    if failing(image.domain, .Clone) {
        return nil, .External_State
    }

    return image_make(image.domain, image.value), .None
}

release :: proc(pointer: rawptr) {
    image := cast(^Image)pointer
    d := image.domain

    if d.stats != nil {
        d.stats.images -= 1
    }

    free(image, d.allocator)
    drop(d)
}

open :: proc(pointer: rawptr) -> (rawptr, r.Error) {
    image := cast(^Image)pointer
    d := image.domain

    if failing(d, .Open) {
        return nil, .External_State
    }

    execution := new(Execution, d.allocator)
    execution^ = {d, image.value}
    retain(d)

    if d.stats != nil {
        d.stats.executions += 1
        d.stats.opens += 1
    }

    return execution, .None
}

close :: proc(pointer: rawptr) {
    execution := cast(^Execution)pointer
    d := execution.domain

    if d.stats != nil {
        d.stats.executions -= 1
    }

    free(execution, d.allocator)
    drop(d)
}

capture :: proc(pointer: rawptr) -> (rawptr, u64, r.Error) {
    execution := cast(^Execution)pointer
    d := execution.domain

    if failing(d, .Capture) {
        return nil, 0, .External_State
    }

    if d.stats != nil {
        d.stats.captures += 1
    }

    return image_make(d, execution.value), u64(size_of(Image)), .None
}

equal :: proc(a, b: rawptr) -> (bool, r.Error) {
    left, right := cast(^Image)a, cast(^Image)b

    if failing(left.domain, .Equal) {
        return false, .External_State
    }

    return left.value == right.value, .None
}

admit :: proc(pointer: rawptr, phase: r.External_Phase, usage: r.External_Usage) -> r.Error {
    execution := cast(^Execution)pointer

    if failing(execution.domain, .Admit) {
        return .Resource_Limit
    }

    return .None
}

checkpoint :: proc(
    $E: typeid,
    stats: ^Stats,
    value: i64 = 0,
    frame: r.Frame(Game) = {},
    history: int = 8,
    prediction: u64 = 0,
    repair: u64 = 0,
    max_bytes: u64 = 0,
) -> (
    r.Complete_Checkpoint(Game, E),
    Owner,
) {
    d := new(Domain)
    d^ = {
        refs      = 1,
        allocator = context.allocator,
        stats     = stats,
    }

    if stats != nil {
        stats.domains += 1
    }

    external := r.External {
        identity = IDENTITY,
        contract = CONTRACT,
        clone = clone,
        release = release,
        open = open,
        close = close,
        capture = capture,
        equal = equal,
        admit = admit,
        limits = {
            history_frames = history,
            max_prediction_ticks = prediction,
            max_repair_ticks = repair,
            max_bytes = max_bytes,
        },
    }
    image := image_make(d, value)
    result, err := r.complete_checkpoint_adopt(frame, E, external, image, size_of(Image))
    assert(err == .None)
    return result, Owner{d}
}

owner_destroy :: proc(owner: ^Owner) {
    if owner._domain != nil {
        drop(owner._domain)
        owner^ = {}
    }
}

fail :: proc(owner: ^Owner, operation: Operation, after: u64 = 1) {
    d := owner._domain
    d.fail_at[operation] = d.calls[operation] + after
}

bias :: proc(owner: ^Owner, amount: i64) {
    owner._domain.bias = amount
}

value :: proc(checkpoint: ^r.Complete_Checkpoint($S, $E)) -> i64 {
    pointer, err := r.complete_checkpoint_image(checkpoint, IDENTITY)
    assert(err == .None)
    return (cast(^Image)pointer).value
}

add :: proc(capability: r.Execution, delta: i64) {
    pointer, err := r.execution_pointer(capability, IDENTITY)
    assert(err == .None)
    execution := cast(^Execution)pointer
    execution.value += delta + execution.domain.bias

    if execution.domain.stats != nil {
        execution.domain.stats.last_capability = capability
    }
}

step :: proc(game: ^Game, input: Input, ctx: ^r.Step(i64)) {
    add(ctx.execution, input.delta)
    game.sum += input.delta
    game.ticks += 1

    if input.event {
        r.emit(ctx, 1, ctx.tick, game.sum)
    }

    if input.abort {
        r.abort(ctx)
    }
}

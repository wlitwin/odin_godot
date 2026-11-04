package scrapyard_upgrade

import net "godot:replay/net"
import r "godot:replay"
import a "godot:replay/assets"
import game "../game"

Action_46_Kind :: enum u8 {
    Profile,
    Ready,
    Start,
    Cast,
    Buy,
    Workshop,
    Set_Spray,
    Stamp,
    Dev_Spawn,
    Dev_Edit,
}

Action_46 :: struct {
    kind: Action_46_Kind,
    profile: game.Profile,
    ready: bool,
    slot: u8,
    aim: [2]f32,
    aim_is_point: bool,
    item: u8,
    image: a.Ref,
    development: game.Development,
}

map_action_46 :: proc(old: Action_46) -> (game.Action, bool) {
    if old.kind > .Dev_Edit {
        return {}, false
    }

    return {
            kind = game.Action_Kind(old.kind),
            profile = old.profile,
            ready = old.ready,
            slot = old.slot,
            aim = old.aim,
            aim_is_point = old.aim_is_point,
            item = old.item,
            image = old.image,
            development = old.development,
        },
        true
}

action_46_valid :: proc(old: Action_46) -> bool {
    mapped, ok := map_action_46(old)
    return ok && game.action_valid(mapped)
}

CONTENT_42 :: u64(0x5253435241503042)

// Frozen canonical action shape from content 42. World, controls and events
// did not change in content 43; only explicit development edits were added.
Action_42_Kind :: enum u8 {
    Profile,
    Ready,
    Start,
    Cast,
    Buy,
    Workshop,
    Set_Spray,
    Stamp,
    Dev_Spawn,
}

Action_42 :: struct {
    kind: Action_42_Kind,
    profile: game.Profile,
    ready: bool,
    slot: u8,
    aim: [2]f32,
    aim_is_point: bool,
    item: u8,
    image: a.Ref,
}

map_action :: proc(old: Action_42) -> (game.Action, bool) {
    if old.kind > .Dev_Spawn {
        return {}, false
    }

    value := game.Action {
        kind = game.Action_Kind(old.kind),
        profile = old.profile,
        ready = old.ready,
        slot = old.slot,
        aim = old.aim,
        aim_is_point = old.aim_is_point,
        item = old.item,
        image = old.image,
    }
    return value, true
}

// Frozen event shape used by both content 42 and 43. Event histories are not
// archived, but the source event schema participates in the validated contract.
Event_43_Kind :: enum u8 {
    Started,
    Entered,
    Dash,
    Shot,
    Jam,
    Hit,
    Killed,
    Hurt,
    Pickup,
    Healed,
    Blast,
}

Event_43 :: struct {
    kind: Event_43_Kind,
    seat: u16,
    generation, serial: u32,
    position: [2]f32,
}

CONTENT_43 :: u64(0x5253435241503043)

model_42 :: proc() -> net.Model(World_45, game.Control, Action_42, Event_43, game.SEATS) {
    return {
        control_valid = game.control_valid,
        state_valid = state_45_valid,
        action_valid = proc(value: Action_42) -> bool {
            mapped, ok := map_action(value)
            return ok && game.action_valid(mapped)
        },
        action = proc(_: ^World_45, _: u16, _: Action_42, _: ^r.Step(Event_43)) -> bool {
            panic("archive-only source model cannot execute")
        },
    }
}

model_43 :: proc() -> net.Model(World_45, game.Control, Action_46, Event_43, game.SEATS) {
    return {
        control_valid = game.control_valid,
        state_valid = state_45_valid,
        action_valid = action_46_valid,
        action = proc(_: ^World_45, _: u16, _: Action_46, _: ^r.Step(Event_43)) -> bool {
            panic("archive-only source model cannot execute")
        },
    }
}

// Explicit import only. Source models are validation descriptors, never runners.
root_42_unseeded :: proc(bytes: []u8) -> ([]u8, net.Error) {
    model := model_42()
    protocol7: []u8
    defer delete(protocol7)
    cp: net.Checkpoint(World_45, game.Control, Action_42, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    input := bytes

    if net.checkpoint_decode(&cp, bytes, model, CONTENT_42) != .None {
        converted, err := net.checkpoint_upgrade_v6(bytes, model, CONTENT_42)

        if err != .None {
            return nil, err
        }

        protocol7, input = converted, converted
    }

    return net.checkpoint_convert(input, model, CONTENT_42, game.model(), game.CONTENT, map_world, map_action)
}

root_43_unseeded :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(bytes, model_43(), CONTENT_43, game.model(), game.CONTENT, map_world, map_action_46)
}

// Content 44 added audio detail; content 45 adds the Wall enum member only.
CONTENT_44 :: u64(0x5253435241503044)

Event_44 :: struct {
    kind: Event_43_Kind,
    seat: u16,
    generation, serial: u32,
    position: [2]f32,
    detail: u8,
}

model_44 :: proc() -> net.Model(World_45, game.Control, Action_46, Event_44, game.SEATS) {
    return {
        control_valid = game.control_valid,
        state_valid = state_45_valid,
        action_valid = action_46_valid,
        action = proc(_: ^World_45, _: u16, _: Action_46, _: ^r.Step(Event_44)) -> bool {
            panic("archive-only source model cannot execute")
        },
    }
}

root_44_unseeded :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(bytes, model_44(), CONTENT_44, game.model(), game.CONTENT, map_world, map_action_46)
}

CONTENT_45 :: u64(0x5253435241503045)

Event_45_Kind :: enum u8 {
    Started,
    Entered,
    Dash,
    Shot,
    Jam,
    Hit,
    Killed,
    Hurt,
    Pickup,
    Healed,
    Blast,
    Wall,
}

Event_45 :: struct {
    kind: Event_45_Kind,
    seat: u16,
    generation, serial: u32,
    position: [2]f32,
    detail: u8,
}

model_45 :: proc() -> net.Model(World_45, game.Control, Action_46, Event_45, game.SEATS) {
    return {
        control_valid = game.control_valid,
        state_valid = state_45_valid,
        action_valid = action_46_valid,
        action = proc(_: ^World_45, _: u16, _: Action_46, _: ^r.Step(Event_45)) -> bool {
            panic("archive-only source model cannot execute")
        },
    }
}

root_45_unseeded :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(bytes, model_45(), CONTENT_45, game.model(), game.CONTENT, map_world, map_action_46)
}

CONTENT_46 :: u64(0x5253435241503046)

model_46 :: proc() -> net.Model(World_47, game.Control, Action_46, game.Event, game.SEATS) {
    return {
        control_valid = game.control_valid,
        state_valid = state_47_valid,
        action_valid = action_46_valid,
        action = proc(_: ^World_47, _: u16, _: Action_46, _: ^r.Step(game.Event)) -> bool {
            panic("archive-only source model cannot execute")
        },
    }
}

root_46_unseeded :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(
        bytes,
        model_46(),
        CONTENT_46,
        game.model(),
        game.CONTENT,
        map_world_47,
        map_action_46,
    )
}

CONTENT_47 :: u64(0x5253435241503047)

model_47 :: proc() -> net.Model(World_47, game.Control, Action_50, game.Event, game.SEATS) {
    return {
        control_valid = game.control_valid,
        state_valid = state_47_valid,
        action_valid = action_50_valid,
        action_schedule = schedule_50(),
        action = proc(_: ^World_47, _: u16, _: Action_50, _: ^r.Step(game.Event)) -> bool {
            panic("archive-only source model cannot execute")
        },
    }
}

root_47_unseeded :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(
        bytes,
        model_47(),
        CONTENT_47,
        game.model(),
        game.CONTENT,
        map_world_47,
        map_action_50,
    )
}

root_42 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := root_42_unseeded(bytes)
    return seed_epoch(converted, error)
}

root_43 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := root_43_unseeded(bytes)
    return seed_epoch(converted, error)
}

root_44 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := root_44_unseeded(bytes)
    return seed_epoch(converted, error)
}

root_45 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := root_45_unseeded(bytes)
    return seed_epoch(converted, error)
}

root_46 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := root_46_unseeded(bytes)
    return seed_epoch(converted, error)
}

root_47 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := root_47_unseeded(bytes)
    return seed_epoch(converted, error)
}

// Conversion preserves the old frame's timers. The first committed recovery
// tick applies succession; an offline converter never grants an authority epoch.
seed_epoch :: proc(converted: []u8, error: net.Error) -> ([]u8, net.Error) {
    defer delete(converted)

    if error != .None {
        return nil, error
    }

    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)

    if err := net.checkpoint_decode(&cp, converted, game.model(), game.CONTENT); err != .None {
        return nil, err
    }

    cp.frame.state.authority_epoch = cp.header.epoch
    return net.checkpoint_encode(&cp, game.model())
}

CONTENT_48 :: u64(0x5253435241503048)

root_48 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    converted, error := net.checkpoint_convert(
        bytes,
        model_48(),
        CONTENT_48,
        game.model(),
        game.CONTENT,
        map_world_48,
        map_action_50,
    )
    return seed_epoch(converted, error)
}

CONTENT_49 :: u64(0x5253435241503049)

root_49 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(
        bytes,
        model_49(),
        CONTENT_49,
        game.model(),
        game.CONTENT,
        map_world_49,
        map_action_50,
    )
}

CONTENT_50 :: u64(0x525343524150304a)

root_50 :: proc(bytes: []u8) -> ([]u8, net.Error) {
    return net.checkpoint_convert(
        bytes,
        model_50(),
        CONTENT_50,
        game.model(),
        game.CONTENT,
        map_world_50,
        map_action_50,
    )
}

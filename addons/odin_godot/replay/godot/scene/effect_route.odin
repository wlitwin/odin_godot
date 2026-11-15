package replay_godot_scene

import "core:mem"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"

Effect_State :: struct($Value: typeid) {
    value:        Value,
    age, seconds: f64,
    confirmed:    bool,
}

Effect_Binding :: struct($Event, $Value, $Rig: typeid) {
    project: proc(_: Event) -> (v.Entity_View(Value), bool),
    animate: proc(_: v.Entity_View(Value), _: f64, _: f64) -> v.Entity_View(Value),
    view:    View_Binding(Effect_State(Value), Rig),
}

@(private)
Effect_Identity :: struct {}

Effect_Route2 :: struct($Event, $Value, $Rig: typeid) {
    route:       v.Cue_Route(Event, v.Entity_View(Value)),
    views:       View_Pool2(Effect_Identity, Effect_State(Value), Rig),
    binding:     Effect_Binding(Event, Value, Rig),
    items:       []v.View_Item(Effect_Identity, Effect_State(Value)),
    keys:        []u64,
    generations: []u32,
    allocator:   mem.Allocator,
}

effect_route_load :: proc(
    p: ^Effect_Route2($Event, $Value, $Rig),
    parent: gd.Node,
    path: cstring,
    epoch: u64,
    seconds: f64,
    binding: Effect_Binding(Event, Value, Rig),
    policy: v.Route_Policy = .Journal,
    capacity: int = 128,
    baseline: u64 = 0,
    history: int = 512,
    per_tick: int = 40,
    allocator := context.allocator,
) -> bool {
    if len(p.items) != 0 {
        return false
    }

    p.allocator, p.binding = allocator, binding

    if !v.cue_route_init(
        &p.route,
        epoch,
        seconds,
        binding.project,
        policy,
        baseline,
        capacity,
        history,
        per_tick,
        allocator,
    ) {
        return false
    }

    if !view_pool_load(&p.views, parent, path, capacity, binding.view, allocator) {
        effect_route_destroy(p)
        return false
    }

    p.items = make([]v.View_Item(Effect_Identity, Effect_State(Value)), capacity, allocator)
    p.keys = make([]u64, capacity, allocator)
    p.generations = make([]u32, capacity, allocator)
    return true
}

effect_route_destroy :: proc(p: ^Effect_Route2($Event, $Value, $Rig)) {
    view_pool_destroy(&p.views)
    v.cue_route_destroy(&p.route)
    delete(p.items, p.allocator)
    delete(p.keys, p.allocator)
    delete(p.generations, p.allocator)
    p^ = {}
}

effect_route_change :: proc(p: ^Effect_Route2($Event, $Value, $Rig), change: v.Change(Event)) -> bool {
    return v.cue_route_change(&p.route, change)
}

effect_route_clear :: proc(p: ^Effect_Route2($Event, $Value, $Rig)) {
    v.cues_clear(&p.route.cues)
    view_pool_clear(&p.views)
}

effect_route_epoch :: proc(p: ^Effect_Route2($Event, $Value, $Rig), epoch, baseline: u64) -> bool {
    if !v.cues_epoch(&p.route.cues, epoch, baseline) {
        return false
    }

    view_pool_clear(&p.views)

    for &key in p.keys {
        key = 0
    }

    for &generation in p.generations {
        generation = 0
    }

    return true
}

effect_route_retire :: proc(p: ^Effect_Route2($Event, $Value, $Rig), through: u64) -> bool {
    return v.one_shots_retire(&p.route.cues.ledger, through)
}

// Every visual gets a new generation when a bounded cue slot is reused. Paint
// receives age/confirmation without restarting the scene or looking up children.
effect_route_frame :: proc(p: ^Effect_Route2($Event, $Value, $Rig), dt: f64) -> View_Pool_Error {
    if len(p.items) == 0 || !v.cues_advance(&p.route.cues, dt) {
        return .Invalid
    }

    count := 0

    for cue, i in p.route.cues.slots {
        if !cue.active {
            continue
        }

        if p.keys[i] != cue.key {
            if p.generations[i] == max(u32) {
                return .Capacity
            }

            p.generations[i] += 1
            p.keys[i] = cue.key
        }

        value := cue.value

        if p.binding.animate != nil {
            value = p.binding.animate(value, cue.age, cue.seconds)
        }

        p.items[count] = {
            handle = r.Handle(Effect_Identity){u32(i), p.generations[i]},
            tick = cue.id.tick,
            source = .Observed,
            view = {
                pose = value.pose,
                scale = value.scale,
                color = value.color,
                value = {value.value, cue.age, cue.seconds, cue.confirmed},
            },
        }
        count += 1
    }

    return view_pool_present(&p.views, {p.route.cues.ledger.epoch, 0}, p.items[:count])
}

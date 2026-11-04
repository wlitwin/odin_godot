package route_corpus
import v "godot:replay/view"

run :: proc() -> u32 {
    route: v.Cue_Route(i32, i32)

    if !v.cue_route_init(&route, 1, .5, proc(e: i32) -> (i32, bool) {
            return e, e > 0
        }, capacity = 1, history = 4, per_tick = 2) {
        return 1
    }

    defer v.cue_route_destroy(&route)
    change := v.Change(i32) {
        kind = .Begin,
        occurrence = {id = {1, 1, 1, 1}, value = 7},
    }

    if !v.cue_route_change(&route, change) {
        return 2
    }

    v.cues_advance(&route.cues, .25)
    key := route.cues.slots[0].key
    change.kind = .Update
    change.occurrence.value = 9
    v.cue_route_change(&route, change)
    change.kind = .Confirm
    v.cue_route_change(&route, change)

    if route.cues.slots[0].key != key ||
       route.cues.slots[0].age != .25 ||
       !route.cues.slots[0].confirmed ||
       route.cues.slots[0].value != 9 {
        return 3
    }

    change.kind = .Begin
    change.occurrence.id.key = 2

    if v.cue_route_change(&route, change) || route.cues.stats.dropped != 1 {
        return 4
    }

    v.cues_clear(&route.cues)

    if v.cue_route_change(&route, change) {
        return 5
    } // dropped ID stays consumed

    change.occurrence.id.tick = 2

    if !v.cue_route_change(&route, change) || route.cues.slots[0].key == key {
        return 6
    }

    change.kind = .Cancel
    v.cue_route_change(&route, change)
    change.kind = .Begin

    if v.cue_route_change(&route, change) {
        return 7
    }

    if !v.cues_epoch(&route.cues, 2, 2) || v.cue_route_change(&route, change) {
        return 8
    }

    change.occurrence.id.epoch = 2
    change.occurrence.id.tick = 3

    if !v.cue_route_change(&route, change) {
        return 9
    }

    v.cues_advance(&route.cues, 1)

    if v.cue_route_change(&route, change) {
        return 10
    }

    return 0
}

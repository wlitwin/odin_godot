package replay_godot

import r "godot:replay"
import net "godot:replay/net"

// One clock for the items that can collide. Predicted is an explicit alternative
// for a whole interaction group or for independent local input feedback.
Render_Clock :: enum {
    Observed,
    Predicted,
}
Render_Sample :: struct($State: typeid) {
    from, to: r.Frame(State),
    alpha:    f32,
    tick:     u64, // discrete state through this tick
    fraction: f32, // progress from tick toward tick+1
    scope:    Presentation_Context,
    clock:    Render_Clock,
}
Render_Cursor :: struct {
    ready: bool,
    scope: Presentation_Context,
    tick:  u64,
}

// Only committed occurrence batches can provide motion keys for a shared view.
// The returned internal borrow never escapes the public readers.
@(private)
render_fact :: proc(s: ^Session($S, $C, $A, $E, $N), tick: u64) -> ([]r.Occurrence(net.Net_Event(E)), bool) {
    if tick == 0 {return nil, false}
    facts := s.server.facts
    if s.authority {
        if tick > s.server.timeline.confirmed {return nil, false}
    } else {
        if tick <= s.client.baseline || tick > s.client.journal.confirmed {return nil, false}
        facts = s.client.facts
    }
    if len(facts) == 0 {return nil, false}
    f := &facts[tick % u64(len(facts))]
    if f.tick != tick {return nil, false}
    return f.events[:f.count], true
}

// Sample once per draw. Use the same bracket for all interacting players,
// projectiles and obstacles. Observed samples also bind the game's aiming
// stamp. A cursor plus a predicate lets an important contact occupy a render
// frame even if the watched clock stepped over it. Catch-up is bounded by the
// configured maximum view span; admission/reset never plays an old backlog.
session_render_sample :: proc {
    render_current,
    render_contact_frame,
    render_embedded_contacts,
    render_with_events,
}

@(private)
render_current :: proc(s: ^Session($S, $C, $A, $E, $N), clock := Render_Clock.Observed) -> (Render_Sample(S), bool) {
    filter: proc(_: E) -> bool
    return render_with_events(s, clock, nil, filter)
}

@(private)
render_with_events :: proc(
    s: ^Session($S, $C, $A, $E, $N),
    clock: Render_Clock,
    cursor: ^Render_Cursor,
    must_show: proc(_: E) -> bool,
) -> (
    sample: Render_Sample(S),
    ok: bool,
) {
    filter := must_show
    selected :: proc(fn: ^proc(_: E) -> bool, e: E) -> bool {return fn^(e)}
    test: proc(_: ^proc(_: E) -> bool, _: E) -> bool
    if filter != nil {test = selected}
    return render_filtered(s, clock, cursor, &filter, test)
}

@(private)
render_filtered :: proc(
    s: ^Session($S, $C, $A, $E, $N),
    clock: Render_Clock,
    cursor: ^Render_Cursor,
    policy: ^$T,
    selected: proc(_: ^T, _: E) -> bool,
) -> (
    sample: Render_Sample(S),
    ok: bool,
) {
    scope, ready := session_presentation(s)
    if !ready || clock > Render_Clock.Predicted {return}
    sample.scope, sample.clock = scope, clock
    if !s.authority && s.client.phase != .Running {return}
    if clock == .Predicted && s.client.spectator && !s.authority {return}
    pin := max(u64)
    if cursor != nil &&
       selected != nil &&
       clock == .Observed &&
       cursor.ready &&
       presentation_same_scope(cursor.scope, scope) {
        latest: u64
        span: u64
        if s.authority {
            latest, span = s.server.timeline.head, u64(s.server.cfg.max_view_span)
        } else {
            latest, span = u64(s.client.watch_clock), u64(s.client.cfg.max_view_span)
        }
        if latest > cursor.tick {
            first := max(cursor.tick + 1, latest - min(latest, span))
            for t := first; t <= latest; t += 1 {
                batch, found := render_fact(s, t)
                if found {
                    for occurrence in batch {
                        if occurrence.value.kind == .Gameplay &&
                           selected(policy, occurrence.value.value) {pin = t; break}
                    }
                }
                if pin != max(u64) || t == max(u64) {break}
            }
        }
    }
    if s.authority || clock == .Predicted {
        if s.authority && pin != max(u64) {
            sample.from, ok = r.read_values(&s.server.timeline, pin)
        } else {
            sample.from, ok = session_values(s)
        }
        if !ok {return}
        sample.to = sample.from
        sample.tick = sample.from.tick
    } else {
        sample.from, sample.to, sample.alpha, ok = net.client_present(&s.client, pin)
        if !ok {return}
        offset := f64(sample.to.tick - sample.from.tick) * f64(sample.alpha)
        whole := u64(offset)
        sample.tick = sample.from.tick + whole
        sample.fraction = f32(offset - f64(whole))
        if pin >= sample.from.tick && pin <= sample.to.tick {
            // The aiming stamp stays quantized; motion keys use the exact
            // integer contact selected above (at most one fraction unit away).
            sample.tick, sample.fraction = pin, 0
        }
    }
    if cursor != nil {cursor^ = {clock == .Observed, scope, sample.tick}}
    return
}

// Copy confirmed gameplay events for a tick of this exact render bracket.
// Baselines and gaps have no batch. Refuse a short output without a partial copy.
session_render_events :: proc {
    render_events_at,
    render_each_event,
}

@(private)
render_events_at :: proc(
    s: ^Session($S, $C, $A, $E, $N),
    sample: ^Render_Sample(S),
    tick: u64,
    dst: []E,
) -> (
    int,
    bool,
) {
    if sample == nil || sample.clock != .Observed || tick < sample.from.tick || tick > sample.to.tick {return 0, false}
    scope, ready := session_presentation(s)
    if !ready || !presentation_same_scope(sample.scope, scope) {return 0, false}
    batch, found := render_fact(s, tick)
    if !found {return 0, false}
    count := 0
    for occurrence in batch {if occurrence.value.kind == .Gameplay {count += 1}}
    if count > len(dst) {return count, false}
    i := 0
    for occurrence in batch {
        if occurrence.value.kind == .Gameplay {dst[i] = occurrence.value.value; i += 1}
    }
    return count, true
}

// Visit confirmed gameplay motion keys in tick order. Endpoint-only snapshots
// still work when a baseline has no batch. The callback receives copied values.
@(private)
render_each_event :: proc(
    s: ^Session($S, $C, $A, $E, $N),
    sample: ^Render_Sample(S),
    dst: ^$T,
    apply: proc(_: ^T, _: u64, _: E),
) {
    if sample == nil || sample.clock != .Observed || dst == nil || apply == nil || s == nil {return}
    history := s.authority ? len(s.server.facts) : len(s.client.facts)
    if history == 0 {return}
    first := max(sample.from.tick, sample.to.tick - min(sample.to.tick, u64(history - 1)))
    events: [net.WIRE_EVENTS]E
    for tick := first; tick <= sample.to.tick; tick += 1 {
        count, found := render_events_at(s, sample, tick, events[:])
        if found {for e in events[:count] {apply(dst, tick, e)}}
        if tick == sample.to.tick {break}
    }
}

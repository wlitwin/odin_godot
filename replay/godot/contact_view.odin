package replay_godot

import "base:intrinsics"
import v "godot:replay/view"

// Retain one per world view, and zero it on close/reopen. Slots are zero-based.
// Every body is sampled at the same render time. No allocations or simulation writes.
Contact_View :: struct($D, $N: int) {
    clock:         Render_Clock, // zero selects the shared observed timeline
    poses:         [N]v.Motion_Key(D),
    changed_scope: bool,
    cursor:        Render_Cursor,
    initialized:   bool,
}

@(private)
render_contact_frame :: proc(
    session: ^Session($S, $C, $A, $E, $Seats),
    display: ^Contact_View($D, $N),
    model: v.Contact_Model(S, E, D, N),
) -> (
    sample: Render_Sample(S),
    ok: bool,
) {
    if display == nil || model.bodies == nil || model.contact == nil {return}
    old := display.cursor.scope
    Adapter :: proc(_: E) -> v.Contact(D)
    describe: Adapter = model.contact
    must_show :: proc(fn: ^Adapter, e: E) -> bool {return fn^(e).kind == .Hit}
    sample, ok = render_filtered(session, display.clock, &display.cursor, &describe, must_show)
    if !ok {return}

    a, b: v.Contact_Bodies(D, N)
    model.bodies(&sample.from.state, &a)
    if sample.from.tick == sample.to.tick {b = a} else {model.bodies(&sample.to.state, &b)}
    paths := v.contact_paths(&a, &b, sample.from.tick, sample.to.tick, sample.tick, sample.fraction)
    Visitor :: struct {
        paths:    ^v.Contact_Paths(D, N),
        describe: Adapter,
    }
    apply :: proc(visitor: ^Visitor, tick: u64, e: E) {v.contact_apply(visitor.paths, tick, visitor.describe(e))}
    visitor := Visitor{&paths, describe}
    session_render_events(session, &sample, &visitor, apply)
    for path, i in paths.paths {display.poses[i] = v.motion_sample(path)}
    display.changed_scope = display.initialized && !presentation_same_scope(old, sample.scope)
    display.initialized = true
    return
}


// New games can emit Contact directly or embed it with using alongside their
// gameplay payload. Existing event schemas only need a value-to-contact adapter.
@(private)
render_embedded_contacts :: proc(
    session: ^Session($S, $C, $A, $E, $Seats),
    display: ^Contact_View($D, $N),
    bodies: proc(_: ^S, _: ^v.Contact_Bodies(D, N)),
) -> (
    Render_Sample(S),
    bool,
) where E == v.Contact(D) ||
    intrinsics.type_is_subtype_of(E, v.Contact(D)) {
    read :: proc(e: E) -> v.Contact(D) {return e}
    return render_contact_frame(session, display, v.Contact_Model(S, E, D, N){bodies, read})
}

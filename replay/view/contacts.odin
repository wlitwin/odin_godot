package replay_view

// A detached snapshot of the bodies that can touch. Change group at a round or
// map cut, and life when a body's slot is reused. A retained terminal position
// can supply its last_visible_tick even when the entity despawned between sends.
Contact_Body :: struct($D: int) {
    position:          [D]f32,
    life:              u64,
    visible:           bool,
    last_visible_tick: u64,
}
Contact_Bodies :: struct($D, $N: int) {
    group:  u64,
    bodies: [N]Contact_Body(D),
}
Contact_Point :: struct($D: int) {
    slot:     i32,
    life:     u64,
    position: [D]f32,
}
Contact :: struct($D: int) {
    kind:    enum u8 {
        None,
        Motion,
        Hit,
    },
    group:   u64,
    subject: Contact_Point(D),
    other:   Maybe(Contact_Point(D)),
    retires: bool, // subject is visible at contact, hidden on the following tick
}
// Map an existing game schema once. Games emitting Contact directly only need
// the bodies callback.
Contact_Model :: struct($State, $Event: typeid, $D, $N: int) {
    bodies:  proc(_: ^State, _: ^Contact_Bodies(D, N)),
    contact: proc(_: Event) -> Contact(D),
}
Contact_Paths :: struct($D, $N: int) {
    group:    u64,
    from, to: u64,
    paths:    [N]Motion_Path(D),
}

@(private)
body_key :: proc(body: Contact_Body($D), tick: u64) -> Motion_Key(D) {
    return {tick, body.position, body.life, body.visible || (tick != 0 && body.last_visible_tick == tick)}
}

// Engine-free counterpart for replaying a known bracket in a clip or preview.
contact_paths :: proc(
    a, b: ^Contact_Bodies($D, $N),
    from, to, tick: u64,
    fraction: f32,
) -> (
    out: Contact_Paths(D, N),
) {
    first, last := a, b
    start, end := from, to
    if a.group != b.group || to < from {
        if to >= from && tick >= to {first, start = b, to}
        last, end = first, start
    }
    out.group, out.from, out.to = first.group, start, end
    for &path, i in out.paths {
        final := last.bodies[i]
        path = motion_path(body_key(first.bodies[i], start), body_key(final, end), tick, fraction)
        at := final.last_visible_tick
        if !final.visible && at != 0 && at >= start && at <= end {
            motion_key(&path, Motion_Key(D){at, final.position, final.life, true})
            if at < end {motion_key(&path, Motion_Key(D){at + 1, final.position, final.life, false})}
        }
    }
    return
}

contact_apply :: proc(paths: ^Contact_Paths($D, $N), tick: u64, event: Contact(D)) {
    p := event.subject
    if event.kind == .None ||
       event.group != paths.group ||
       tick < paths.from ||
       tick > paths.to ||
       p.slot < 0 ||
       int(p.slot) >= N {return}
    motion_key(&paths.paths[p.slot], Motion_Key(D){tick, p.position, p.life, true})
    if event.retires && tick < paths.to {
        motion_key(&paths.paths[p.slot], Motion_Key(D){tick + 1, p.position, p.life, false})
    }
    if q, ok := event.other.?; ok && q.slot >= 0 && int(q.slot) < N {
        motion_key(&paths.paths[q.slot], Motion_Key(D){tick, q.position, q.life, true})
    }
}

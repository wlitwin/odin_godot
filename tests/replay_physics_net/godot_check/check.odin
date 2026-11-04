package replay_physics_godot_check

import g "godot:replay/godot"
import a "godot:replay/authority"
import n "godot:replay/net"
import r "godot:replay"
import f "../fixture"

// Compile the concrete Session glue without calling engine singletons. Actual
// solver/transfer/handoff transactions are exercised in ../native.
Session :: g.Session(f.Game, f.Control, f.Action, f.Event, 2)

rejoin :: proc(session: ^Session, lease: ^a.Lease) -> n.Error {
    return g.session_rejoin(session, lease)
}

open :: proc(
    session: ^Session,
    checkpoint: ^r.Complete_Checkpoint(f.Game, n.Net_Event(f.Event)),
    model: n.Model(f.Game, f.Control, f.Action, f.Event, 2),
    options: g.Session_Options,
) -> n.Error {
    return g.session_open_complete(session, checkpoint, model, options)
}

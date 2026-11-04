package dockyard_online_compile

import game "godot:examples/replay_dockyard/modules/dockyard"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"

// Compile the actual generic complete/owner/close path before UI integration.
// This function is never executed as a substitute for a real SDK runtime test.
@(export)
n1_room_complete_typecheck :: proc(room:^rgd.Room(game.Game,game.Control,game.Action,game.Event,2),
 cp:^r.Complete_Checkpoint(game.Game,net.Net_Event(game.Event)),codec:^game.Codec,
 options:rgd.Room_Options,ownership:rgd.Room_Ownership)->net.Error{
 error:=rgd.room_open_complete(room,cp,game.model(codec),options,ownership=ownership)
 if error!=.None{return error}
 return rgd.room_try_close(room)
}

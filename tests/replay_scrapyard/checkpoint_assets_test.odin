package replay_scrapyard_test

import "core:testing"
import a "godot:replay/assets"
import net "godot:replay/net"
import r "godot:replay"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
checkpoint_dependencies_include_executable_pending_spray_declarations :: proc(t:^testing.T) {
	first:=a.reference(transmute([]u8)string("first image"));second:=a.reference(transmute([]u8)string("second image"))
	world:=yard();world.players[0].spray.image=first
	server:=new(net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS));defer free(server);defer net.server_destroy(server)
	cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT
	assert(net.server_init(server,r.Frame(game.World){state=world},game.model(),{},cfg,local_seat=1)==.None)
	assert(net.server_set_local_token(server,net.Token{0=7})==.None)
	_,issued:=net.server_issue(server,game.Action{kind=.Set_Spray,image=second});assert(issued==.None)
	cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
	assert(net.checkpoint_capture(server,&cp)==.None && len(cp.actions)==1 && cp.actions[0].reason==.None)
	root,encoded:=net.checkpoint_encode(&cp,game.model());assert(encoded==.None);defer delete(root)
	refs:[a.BUNDLE_ASSETS]a.Ref;count,valid:=game.checkpoint_assets(nil,root,refs[:])
	testing.expect(t,valid && count==2 && refs[0]==first && refs[1]==second)
	cp.actions[0].reason=.Disconnected
	rejected,error:=net.checkpoint_encode(&cp,game.model());assert(error==.None);defer delete(rejected)
	count,valid=game.checkpoint_assets(nil,rejected,refs[:])
	testing.expect(t,valid && count==1 && refs[0]==first)
}

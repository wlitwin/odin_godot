package browser_checkpoint_test
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "godot:examples/replay_cavecrawl/shared/cave"
import storagegd "godot:replay/godot/storage"

@(test)
local_slot_requires_owning_profile_and_rejects_coordinated_policy :: proc(t:^testing.T) {
	server:net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS)
	cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT
	token:=net.Token{0=9}
	testing.expect_value(t,net.server_init(&server,r.Frame(game.World){state=game.initial()},game.model(),{},cfg,local_seat=1),net.Error.None);defer net.server_destroy(&server)
	net.server_set_local_token(&server,token)
	cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
	testing.expect_value(t,net.checkpoint_capture(&server,&cp),net.Error.None)
	slot:rgd.Browser_Checkpoint(game.World,game.Control,game.Action,game.Event,game.SEATS)
	slot.token={0=8};testing.expect_value(t,rgd.browser_checkpoint_validate(&slot,&cp),rgd.Browser_Save_Error.Identity)
	slot.token=token;testing.expect_value(t,rgd.browser_checkpoint_validate(&slot,&cp),rgd.Browser_Save_Error.None)
	cp.header.policy_id=7;testing.expect_value(t,rgd.browser_checkpoint_validate(&slot,&cp),rgd.Browser_Save_Error.Policy)
	cp.header.policy_id=0;cp.settings.require_permit=true;testing.expect_value(t,rgd.browser_checkpoint_validate(&slot,&cp),rgd.Browser_Save_Error.Policy)
}
@(test)
identity_is_not_exposed_before_storage_completion :: proc(t:^testing.T) {
	identity:=storagegd.Browser_Identity{phase=.Creating,token={0=1}}
	token,ok:=storagegd.browser_identity_token(&identity);testing.expect(t,!ok && token==(net.Token{}))
	identity.phase=.Ready;token,ok=storagegd.browser_identity_token(&identity);testing.expect(t,ok && token[0]==1)
	testing.expect(t,!storagegd.browser_identity_valid(net.Token{}))
}

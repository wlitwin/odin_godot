package binding_test

import knet "godot:kit/net"
import ksess "godot:kit/session"
import kboot "godot:kit/boot"

Binding_Game :: struct {
    boot: ^kboot.Boot,
    nested: ^BindingActor,
    defaults, bound, hooks: int,
    nested_ok: bool,
    retire: bool,
    last_hook: knet.Net_Id,
}

bound_add :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env, scale: i32) -> bool {
    actor := cast(^BindingActor)entity
    amount := knet.read_i32(r)
    if r.err {return false}
    actor.value += amount * scale
    if amount < 0 {return false}
    if env.authority {
        game := cast(^Binding_Game)env.user
        game.bound += 1
        if game.nested != nil && amount == 1 {
            result := binding_actor_add_cmd(game.boot, game.nested, 2)
            game.nested_ok = result.state == .Applied
            // A consequence can retire/reassign a body. The outer command's
            // hook must still identify the entity it originally addressed.
            actor.net_id = 99
        }
        if game.retire {
            knet.registry_remove(&game.boot.ses.reg, actor.net_id)
            free(actor)
        }
    }
    return true
}

bound_ten :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
    return bound_add(entity, r, env, 10)
}
bound_twenty :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {
    return bound_add(entity, r, env, 20)
}

binding_hook :: proc(raw: rawptr, _: knet.Player_Id, id: knet.Net_Id, _: u16, _: bool) {
    game := cast(^Binding_Game)raw
    game.hooks += 1
    game.last_hook = id
}

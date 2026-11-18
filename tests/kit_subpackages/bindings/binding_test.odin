#+build !freestanding
package binding_test

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kboot "godot:kit/boot"

@(test)
generated_commands_select_session_binding :: proc(t: ^testing.T) {
    sessions: [2]ksess.Session
    boots: [2]kboot.Boot
    games: [2]Binding_Game
    actors: [2]BindingActor
    sets: [2]knet.Command_Set
    commands: [2][1]knet.Command_Desc
    for &s, i in sessions {
        s.reg = knet.registry_make()
        s.ctx = knet.command_ctx_make()
        s.is_host, s.joined, s.ran = true, true, true
        s.me = 1
        s.ctx.is_authority, s.ctx.me = true, 1
        s.ctx.game_user = &games[i]
        s.ctx.hook, s.ctx.hook_user = binding_hook, &games[i]
        boots[i].ses = &s
        games[i].boot = &boots[i]
        commands[i][0] = knet.command_find(&binding_actor_command_set, u16(BINDING_ACTOR_CMD_ADD))^
        commands[i][0].invoke = i == 0 ? bound_ten : bound_twenty
        sets[i] = binding_actor_command_set
        sets[i].commands = commands[i][:]
        knet.registry_insert(&s.reg, 1, &actors[i], &sets[i], 1)
    }
    defer {
        for &s in sessions {
            knet.registry_destroy(&s.reg)
            knet.command_ctx_destroy(&s.ctx)
        }
    }
    for &actor, i in actors {
        result := binding_actor_add_cmd(&boots[i], &actor, 3)
        testing.expect(t, result.state == .Applied)
        testing.expect_value(t, actor.value, i32(30 * (i + 1)))
        testing.expect_value(t, games[i].bound, 1)
        testing.expect_value(t, games[i].defaults, 0)
        testing.expect_value(t, games[i].hooks, 1)
        result = binding_actor_add_cmd(&boots[i], &actor, -1)
        testing.expect_value(t, result.reason, knet.Action_Reject_Reason.Predicate)
        testing.expect_value(t, actor.value, i32(30 * (i + 1))) // rejected writes roll back
    }
    stale := BindingActor{net_id = 1}
    testing.expect_value(t, binding_actor_add_cmd(&boots[0], &stale, 1).reason, knet.Action_Reject_Reason.Stale)

    nested: BindingActor
    knet.registry_insert(&sessions[0].reg, 2, &nested, &sets[0], 1)
    games[0].nested = &nested
    result := binding_actor_add_cmd(&boots[0], &actors[0], 1)
    testing.expect(t, result.state == .Applied)
    testing.expect(t, games[0].nested_ok)
    testing.expect_value(t, actors[0].value, i32(40))
    testing.expect_value(t, nested.value, i32(20))
    testing.expect_value(t, games[0].last_hook, knet.Net_Id(1))

    // Prediction must use the bound descriptor too, with consequences quiet.
    s := &sessions[1]
    s.is_host, s.ctx.is_authority = false, false
    result = binding_actor_add_cmd(&boots[1], &actors[1], 1)
    testing.expect(t, result.state == .Predicted)
    testing.expect_value(t, actors[1].value, i32(80))
    testing.expect_value(t, games[1].bound, 1)
    testing.expect_value(t, games[1].defaults, 0)
}

@(test)
module_local_block_composes :: proc(t: ^testing.T) {
    session: ksess.Session
    session.ctx = knet.command_ctx_make()
    defer knet.command_ctx_destroy(&session.ctx)
    session.is_host, session.ctx.is_authority = true, true
    boot := kboot.Boot{ses = &session}
    actor: BindingActor
    outcome := binding_actor_counter_add_cmd(&boot, &actor, 7)
    testing.expect(t, outcome.state == .Applied)
    testing.expect_value(t, actor.counter.score, i32(7))
}

@(test)
generated_authority_can_retire_target :: proc(t: ^testing.T) {
    session: ksess.Session
    session.reg = knet.registry_make()
    session.ctx = knet.command_ctx_make()
    defer knet.registry_destroy(&session.reg)
    defer knet.command_ctx_destroy(&session.ctx)
    session.is_host, session.joined, session.ran = true, true, true
    session.ctx.is_authority = true
    boot := kboot.Boot{ses = &session}
    game := Binding_Game{boot = &boot, retire = true}
    session.ctx.game_user = &game
    session.ctx.hook, session.ctx.hook_user = binding_hook, &game
    commands := [1]knet.Command_Desc{knet.command_find(&binding_actor_command_set, u16(BINDING_ACTOR_CMD_ADD))^}
    commands[0].invoke = bound_ten
    set := binding_actor_command_set
    set.commands = commands[:]
    actor := new(BindingActor)
    knet.registry_insert(&session.reg, 3, actor, &set)
    outcome := binding_actor_add_cmd(&boot, actor, 1)
    testing.expect(t, outcome.state == .Applied)
    testing.expect_value(t, knet.registry_count(&session.reg), 0)
    testing.expect_value(t, game.bound, 1)
    testing.expect_value(t, game.hooks, 1)
    testing.expect_value(t, game.last_hook, knet.Net_Id(3))
}

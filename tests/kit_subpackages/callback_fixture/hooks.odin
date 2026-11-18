package callback_game

import knet "godot:kit/net"
import units "actors"
Score :: i32

@(gd_half)
game_a_actor_add_then :: proc(game: ^GameA, self: ^units.Actor, by: knet.Player_Id, amount, payload: i32) { game.points += payload }
@(gd_half)
game_b_actor_add_then :: proc(game: ^GameB, self: ^units.Actor, by: knet.Player_Id, amount, payload: i32) { game.points += 10 * payload }
@(gd_half)
game_a_actor_counter_gain_then :: proc(game: ^GameA, self: ^units.Actor, by: knet.Player_Id, amount: i32, payload: $P) { game.points += i32(payload.value) }
@(gd_half)
game_b_actor_counter_gain_then :: proc(game: ^GameB, self: ^units.Actor, by: knet.Player_Id, amount: i32, payload: $P) { game.points += 10 * i32(payload.value) }
@(gd_half)
game_a_actor_value_edge :: proc(game: ^GameA, self: ^units.Actor, old, new: Score) { game.edges += 1 }
@(gd_half)
game_b_actor_value_edge :: proc(game: ^GameB, self: ^units.Actor, old, new: i32) { game.edges += 10 }
@(gd_half)
game_a_walker_tick_then :: proc(game: ^GameA, self: ^units.Walker, by: knet.Player_Id, fired: bool, value: i32) { game.tick_points += value }
@(gd_half)
game_b_walker_tick_then :: proc(game: ^GameB, self: ^units.Walker, by: knet.Player_Id, fired: bool, value: i32) { game.tick_points += 10 * value }
@(gd_half)
game_a_walker_tick_fx :: proc(game: ^GameA, self: ^units.Walker, mine: bool, fired: bool, value: i32) { game.effects += 1; game.last_mine = mine }
@(gd_half)
game_b_walker_tick_fx :: proc(game: ^GameB, self: ^units.Walker, mine: bool, fired: bool, value: i32) { game.effects += 10; game.last_mine = mine }
@(gd_half)
game_a_walker_push_then :: proc(game: ^GameA, self: ^units.Walker, by: knet.Player_Id, amount, payload: i32) { game.points += payload }
@(gd_half)
game_b_walker_push_then :: proc(game: ^GameB, self: ^units.Walker, by: knet.Player_Id, amount, payload: i32) { game.points += 10 * payload }
@(gd_half)
game_c_walker_tick_fx :: proc(game: ^GameC, self: ^units.Walker, fired: bool, value: i32) { game.effects += 1 }

//gd:extends Node
package generic_game

import gd "godot:godot"
import containers "containers"
import values "values"

Game :: struct { owner: gd.Node }

@(gd_sample)
game_sample :: proc(self: ^Game, tick: u64, input: ^containers.Envelope(values.Local_Type, 0x2)) {}

@(gd_sample)
game_sample_numeric :: proc(self: ^Game, tick: u64, input: ^containers.Numeric_Input(i16, 2, values.Mode)) {}

@(gd_sample)
game_sample_vector :: proc(self: ^Game, tick: u64, input: ^values.Vector_Input) {}

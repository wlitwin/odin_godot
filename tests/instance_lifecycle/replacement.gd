extends Node
var hits := 0
func on_ping(value: int): hits += value
func noop(): hits += 1

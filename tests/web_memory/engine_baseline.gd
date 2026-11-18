extends Node

# Minimal no-Odin comparison for the pinned engine's Web exit diagnostic.
# Place beside the starter's pickup.wav and attach to the project's main Node.
var played:=false
var audio:AudioStreamPlayer

func _ready():
	audio=AudioStreamPlayer.new()
	add_child(audio)
	audio.stream=load("res://pickup.wav")
	print("AUDIO_BASELINE_READY")

func _input(event:InputEvent):
	if event is InputEventMouseButton and event.pressed and not played:
		played=true
		audio.play()
		await get_tree().create_timer(0.3).timeout
		print("AUDIO_BASELINE_DONE")
		get_tree().quit()

func _notification(what:int):
	if what==NOTIFICATION_PREDELETE and is_instance_valid(audio):
		audio.stop()
		audio.stream=null

extends Node3D

const BOOST := preload("res://audio/boost.wav")
const LATCH := preload("res://audio/latch_score.wav")
var volume := 0.65
var reduced_motion := false
var last_sequence := 0
var cues_consumed := 0
var boost_cues := 0
var latch_cues := 0
var unavailable_cues := 0
var voices: Array[AudioStreamPlayer] = []
var bursts: Array[Dictionary] = []
var next_voice := 0
var next_burst := 0
var preparing_visuals := false
var closing := false
var drain_finished := false
var drain_active_at_request := 0
var retiring_playbacks: Array[WeakRef] = []

func _ready() -> void:
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		if OS.has_feature("web"):
			# Use the engine mixer through page suspend/resume. The Web sample
			# pause path can retain a node after its AudioContext has gone away.
			voice.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		voice.name="ConfirmedCueVoice%d" % i
		add_child(voice)
		voices.append(voice)
		var mesh := BoxMesh.new()
		mesh.size=Vector3(.10,.10,.10)
		var material := StandardMaterial3D.new()
		# Match the dock's opaque material family. Per-burst tint is a uniform;
		# shrinking pieces avoids separate alpha/unshaded/color shader variants.
		material.roughness=.8
		mesh.material=material
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=mesh
		multimesh.instance_count=16
		var node := MultiMeshInstance3D.new()
		node.multimesh=multimesh
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible=false
		add_child(node)
		bursts.append({"node":node,"age":1.0,"color":Color.WHITE,"material":material})

func prepare_visuals() -> void:
	preparing_visuals=true
	for burst in bursts:
		burst.node.position=Vector3(0,1,0)
		burst.node.visible=true
		burst.material.albedo_color=Color(1,.8,.4)
		var mesh: MultiMesh=burst.node.multimesh
		for i in range(16):
			mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(float(i%4)*.12,float(i/4)*.12,0)))

func visuals_prepared() -> void:
	for burst in bursts:
		burst.node.visible=false
		burst.age=1.0
	preparing_visuals=false

func consume(value: Dictionary, proxies: Dictionary) -> void:
	if closing:
		return
	var entries: Array=value.get("confirmed_cues",[])
	if not entries.is_empty() and int(entries[0].get("sequence",0))>last_sequence+1:
		unavailable_cues+=int(entries[0].sequence)-last_sequence-1
	for cue in entries:
		var serial:=int(cue.get("sequence",0))
		if serial<=last_sequence:
			continue
		last_sequence=serial
		cues_consumed+=1
		var kind:=int(cue.get("kind",0))
		var index:=int(cue.get("index",0))
		var key: String
		var color: Color
		if kind==1 and index>=1 and index<=2:
			boost_cues+=1
			key="robot_a" if index==1 else "robot_b"
			color=Color("aaf6e7") if index==1 else Color("ffc4ac")
			play(BOOST)
		elif kind==2 and index>=1 and index<=3:
			latch_cues+=1
			key=["cargo_a","cargo_b","cargo_long"][index-1]
			color=Color("ffe4a2")
			play(LATCH)
		else:
			continue
		if not reduced_motion and proxies.has(key):
			var burst: Dictionary=bursts[next_burst]
			next_burst=(next_burst+1)%bursts.size()
			burst.age=0.0
			burst.color=color
			burst.material.albedo_color=color
			burst.node.global_position=proxies[key].global_position+Vector3(0,.45,0)
			burst.node.visible=true

func play(stream: AudioStream) -> void:
	if closing:
		return
	var voice:=voices[next_voice]
	next_voice=(next_voice+1)%voices.size()
	voice.stream=stream
	voice.volume_db=linear_to_db(maxf(volume,0.0001))
	if volume>0:
		voice.play()

func begin_shutdown() -> void:
	if closing:
		return
	closing=true
	set_process(false)
	# This helper must return before the caller awaits. Keep only WeakRefs;
	# a strong playback local across await would prevent its own release.
	for voice in voices:
		if not is_instance_valid(voice):
			continue
		if voice.playing:
			drain_active_at_request+=1
		if voice.has_stream_playback():
			retiring_playbacks.append(weakref(voice.get_stream_playback()))
		voice.stop()
		voice.stream=null

func pending_playbacks() -> int:
	var pending := 0
	for observer in retiring_playbacks:
		if observer.get_ref()!=null:
			pending+=1
	return pending

func finish_shutdown(frames: int, elapsed_ms: int, timed_out: bool) -> void:
	if drain_finished:
		return
	drain_finished=true
	var observation := {"active_at_request":drain_active_at_request,"monitored":retiring_playbacks.size(),"pending":pending_playbacks(),"frames":frames,"elapsed_ms":elapsed_ms,"timed_out":timed_out}
	retiring_playbacks.clear()
	if timed_out:
		push_error("DOCKYARD_AUDIO_DRAIN_TIMEOUT "+JSON.stringify(observation))
	else:
		print("DOCKYARD_AUDIO_DRAINED ",JSON.stringify(observation))

func _exit_tree() -> void:
	# Forced scene removal still stops voices; graceful transitions drain them
	# while the mixer and main-thread cleanup are both alive.
	begin_shutdown()

func _process(dt: float) -> void:
	if preparing_visuals:
		return
	for burst in bursts:
		burst.age+=dt
		if burst.age>=.65 or reduced_motion:
			burst.node.visible=false
			continue
		var t: float=burst.age
		var multimesh: MultiMesh=burst.node.multimesh
		for i in range(16):
			var angle:=float(i)*2.399963
			var velocity:=Vector3(cos(angle)*1.9,1.2+float(i%4)*.45,sin(angle)*1.9)
			var position:=velocity*t+Vector3(0,-3*t*t,0)
			var scale:=maxf(0,1-t/.65)
			var transform:=Transform3D(Basis.from_euler(Vector3(angle,t*4,angle*.5)).scaled(Vector3.ONE*scale),position)
			multimesh.set_instance_transform(i,transform)

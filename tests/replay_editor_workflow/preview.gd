extends SceneTree
var enemy:Node
var ability:Node
func _initialize():run.call_deferred()
func run():
	enemy=load("res://dev/stormcaller_view.tscn").instantiate();root.add_child(enemy)
	await process_frame;await process_frame
	var authored:Resource=enemy.preview_state.definition.pulse
	var original:float=authored.radius
	authored.radius=190
	assert(enemy.preview_refresh())
	assert(enemy.preview_radius()==190)
	enemy.preview_apply(2,.5,0)
	var before:float=enemy.get_node("Charge").rotation
	await create_timer(.15).timeout
	assert(enemy.get_node("Charge").rotation==before,"paused child animation")
	enemy.preview_apply(4,.5,1);await process_frame;await process_frame
	assert(enemy.get_node("Body").frame_coords.y==3,"death pose")
	enemy.preview_apply(3,.5,1);await process_frame;await process_frame
	authored.radius=-1
	assert(not enemy.preview_refresh() and enemy.preview_radius()==190,"invalid refresh must preserve prior preview")
	authored.radius=original;enemy.preview_refresh()
	var original_frames:int=enemy.appearance.idle_frames
	enemy.appearance.idle_frames=0
	assert(not enemy.preview_refresh(),"invalid appearance rejected")
	enemy.preview_apply(0,.5,1);await create_timer(.1).timeout
	enemy.appearance.idle_frames=original_frames;assert(enemy.preview_refresh())
	enemy.queue_free();enemy=null;authored=null;await process_frame;await process_frame
	ability=load("res://dev/ability_preview.tscn").instantiate();root.add_child(ability)
	await process_frame;await process_frame
	var source:Resource=ability.definition
	var radius:float=source.radius;var status:Resource=source.status
	source.radius=123;source.status=load("res://data/status/shock.tres")
	assert(ability.preview_refresh() and ability.preview_radius()==123)
	source.radius=-2
	assert(not ability.preview_refresh() and ability.preview_radius()==123)
	source.radius=radius;source.status=status
	ability.queue_free();ability=null;source=null;status=null
	await process_frame;await process_frame
	print("REPLAY_WORKFLOW_PREVIEW_OK refresh=true pause=true death=true invalid_atomic=true ability_picker=true")
	quit()

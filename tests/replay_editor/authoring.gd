extends "res://workbench_test.gd"
func run():
	bench=load("res://dev/workbench.tscn").instantiate();bench.open_shop=true
	root.add_child(bench);game=bench.game_node()
	if not await until(func():return bench.is_staged() and p("stage")==2):await finish(1,"authoring staging");return
	assert(game.editor_binding_check("res://entities/mob.tscn",true),"script ready/present/retire")
	assert(game.editor_binding_check("res://entities/scrap.tscn",false),"wrong script rejection")
	assert(game.editor_binding_check("res://dev/invalid_enemy.tscn",false),"invalid component rejection")
	var before:int=game.editor_catalog_hash();assert(before!=-1)
	var definition:Resource=load("res://data/mobs/scrapbot.tres")
	var hp:int=definition.hp
	definition.hp=hp+1
	var changed:int=game.editor_catalog_hash();assert(changed!=-1 and changed!=before,"edited Resource bakes new value")
	definition.hp=0
	assert(game.editor_catalog_hash()==-1,"invalid range rejected")
	definition.hp=hp
	assert(game.editor_catalog_hash()==before,"restored Resource identity")
	var duplicate:=definition.duplicate(true)
	var duplicate_path:="res://data/mobs/editor_duplicate.tres"
	assert(ResourceSaver.save(duplicate,duplicate_path)==OK)
	assert(game.editor_catalog_hash()==-1,"duplicate definition ID rejected")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(duplicate_path))==OK)
	duplicate=null;definition=null
	assert(game.editor_catalog_hash()==before)
	print("REPLAY_EDITOR_AUTHORING_OK scripted_binding=true invalid_scene=true bake_edit=true invalid_range=true duplicate=true world_unchanged=true")
	await finish(0)

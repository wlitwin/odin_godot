extends "res://workbench_test.gd"
func run():
	bench=load("res://dev/workbench.tscn").instantiate();root.add_child(bench);game=bench.game_node()
	if not await until(func():return bench.is_staged()):await finish(1,"registry staging");return
	assert(game.editor_registry_count()==7)
	var registration:Resource=load("res://archetypes/enemies/stormcaller.tres")
	var scene:Resource=registration.scene
	registration.scene=load("res://visuals/enemies/stormcaller.tres")
	assert(game.editor_registry_count()==-1,"wrong scene class rejected")
	registration.scene=scene
	var style:Resource=registration.appearance
	registration.appearance=load("res://data/mobs/stormcaller.tres")
	assert(game.editor_registry_count()==-1,"wrong appearance script rejected")
	registration.appearance=style
	var duplicate_path:="res://archetypes/enemies/duplicate.tres"
	assert(ResourceSaver.save(registration.duplicate(),duplicate_path)==OK)
	assert(game.editor_registry_count()==-1,"duplicate ID rejected")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(duplicate_path))==OK)
	var missing_path:="res://archetypes/enemies/stormcaller.tres"
	assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(missing_path),ProjectSettings.globalize_path(missing_path+".hidden"))==OK)
	assert(game.editor_registry_count()==-1,"missing required ID rejected")
	assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(missing_path+".hidden"),ProjectSettings.globalize_path(missing_path))==OK)
	# An eighth entry needs no renderer field, array size, or kind switch edit.
	var definition:Resource=registration.definition.duplicate(true);definition.id=7;definition.name="test variant"
	var definition_path:="res://data/mobs/test_variant.tres"
	assert(ResourceSaver.save(definition,definition_path)==OK)
	definition.take_over_path(definition_path)
	var variant:Resource=registration.duplicate();variant.definition=definition
	var variant_path:="res://archetypes/enemies/test_variant.tres"
	assert(ResourceSaver.save(variant,variant_path)==OK)
	assert(game.editor_registry_count()==8,"new registration and scene bind")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(variant_path))==OK)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(definition_path))==OK)
	variant=null;definition=null;registration=null;scene=null;style=null
	assert(game.editor_registry_count()==7)
	await process_frame;await process_frame
	print("REPLAY_EDITOR_REGISTRY_OK duplicate=true missing=true scene=true appearance=true retained=true added_id=true world_unchanged=true")
	await finish(0)

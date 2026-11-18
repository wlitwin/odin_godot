extends SceneTree

func _initialize(): run.call_deferred()

func run():
	# Exercise catalog admission without starting a game or transport.
	var game:=Node2D.new()
	game.set_script(load("res://scripts/scrapyard.odin"))
	assert(game.catalog_reload())
	var admitted:int=game.catalog_digest()
	var width:int=game.catalog_width()
	var gun:Resource=load("res://data/guns/bolter.tres")
	var damage:int=gun.dmg
	gun.dmg=-1
	assert(ResourceSaver.save(gun,gun.resource_path)==OK)
	assert(not game.catalog_reload())
	assert(game.catalog_digest()==admitted,"failed narrowing must retain all admitted categories")
	gun.dmg=damage
	assert(ResourceSaver.save(gun,gun.resource_path)==OK)
	assert(game.catalog_reload() and game.catalog_digest()==admitted)

	var ability:Resource=load("res://data/abilities/slime.tres")
	var status:int=ability.status
	ability.status=254
	assert(ResourceSaver.save(ability,ability.resource_path)==OK)
	assert(not game.catalog_reload())
	assert(game.catalog_digest()==admitted,"late cross-reference failure must preserve earlier categories")
	ability.status=status
	assert(ResourceSaver.save(ability,ability.resource_path)==OK)
	var duplicate:Resource=ability.duplicate()
	var duplicate_path:="res://data/abilities/zz_duplicate.tres"
	assert(ResourceSaver.save(duplicate,duplicate_path)==OK)
	assert(not game.catalog_reload())
	assert(game.catalog_digest()==admitted,"late duplicate failure must preserve the admitted catalog")
	duplicate=null
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(duplicate_path))==OK)

	var extra:Resource=gun.duplicate()
	extra.id=20
	var extra_path:="res://data/guns/zz_extra.tres"
	assert(ResourceSaver.save(extra,extra_path)==OK)
	assert(game.catalog_reload())
	assert(game.catalog_width()==21,"sparse width is max(id)+1, not loaded row count")
	extra=null
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(extra_path))==OK)
	assert(game.catalog_reload() and game.catalog_digest()==admitted and game.catalog_width()==width)
	game.catalog_clear()
	game.free()
	gun=null
	ability=null
	await process_frame
	print("KIT_CATALOG_ADMISSION_OK")
	quit()

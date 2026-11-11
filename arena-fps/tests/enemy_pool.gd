extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	var built: int = game.enemies_built
	var reserve: int = game.enemy_pool.size()
	var ids: Array[int] = []
	for enemy in game.enemy_pool:
		ids.append(enemy.get_instance_id())
		assert(not enemy.visible and enemy.collision_layer == 0)
		assert(enemy.head_pivot.get_node("HeadHitbox").collision_layer == 0)
	for i in range(reserve): game.spawn_enemy()
	assert(game.enemy_pool.is_empty() and game.enemies.size() == reserve)
	assert(game.enemies_built == built, "No construction during spawning")
	for enemy in game.enemies.duplicate(): game.enemy_killed(enemy)
	assert(game.enemy_pool.size() == reserve)
	game.spawn_enemy()
	var reused = game.enemies[0]
	assert(ids.has(reused.get_instance_id()), "Reuses an existing character")
	assert(reused.health == 100 and reused.visible and reused.collision_layer == 16)
	assert(reused.head_pivot.get_node("HeadHitbox").collision_layer == 8)
	assert(game.enemies_built == built)
	print("PASS: %d enemies spawned without construction; recycling restores health and hitboxes" % reserve)
	quit()

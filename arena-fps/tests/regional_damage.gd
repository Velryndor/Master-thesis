extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_enemy()
	var enemy = game.enemies[0]
	enemy.set_physics_process(false)
	enemy.position = Vector3(0,0,-3)
	game.showing_controls = false
	game.paused = false
	var roots: Array = [enemy,enemy.head_pivot] + enemy.arms + enemy.legs
	for region in roots:
		var area: Area3D
		for candidate in enemy.damage_areas:
			if enemy.region_root(candidate) == region:
				area = candidate
				break
		assert(area != null)
		var expected := 68 if region == enemy.head_pivot else (34 if region == enemy else 17)
		assert(area.get_meta("damage_amount") == expected)
		enemy.health = 100
		enemy.hurt(expected,area)
		assert(enemy.health == 100-expected)
		assert(not enemy.flashing_meshes.is_empty())
		for mesh in enemy.flashing_meshes:
			assert(enemy.region_root(mesh) == region and mesh.material_overlay != null)
		enemy._physics_process(0.13)
		assert(enemy.flashing_meshes.is_empty(), "Flash expires")
	# End-to-end shot on the outside of an upper arm.
	enemy.position = Vector3(0,0,-3)
	enemy.health = 100
	var arm: Node3D = enemy.arms[1]
	var arm_area: Area3D
	for candidate in enemy.damage_areas:
		if candidate.get_parent() == arm: arm_area = candidate; break
	game.camera.global_position = arm_area.global_position+Vector3(2,0,0)
	game.camera.look_at(arm_area.global_position)
	await physics_frame
	await physics_frame
	game.shot_clock = 0
	game.shoot()
	assert(enemy.health == 83 and not game.last_headshot, "Arm shot deals 17")
	assert(game.damage_numbers.back().node.text == "17")
	game.enemy_killed(enemy)
	assert(enemy.flashing_meshes.is_empty(), "Pool clears hit overlay")
	print("PASS: six body regions, flash expiry, arm hitscan damage and floating amount, pooled reset")
	quit()

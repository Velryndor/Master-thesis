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
	var checked := 0
	for pose in [0.0,0.6,1.15]:
		for arm in enemy.arms: arm.rotation.x = pose
		for i in range(enemy.legs.size()): enemy.legs[i].rotation.x = pose*0.3*(1 if i == 0 else -1)
		await physics_frame
		await physics_frame
		for area in enemy.damage_areas:
			var shape: CollisionShape3D = area.get_child(0)
			var target := shape.global_position
			var query := PhysicsRayQueryParameters3D.create(target+Vector3(0,0,-1.2),target,13)
			query.collide_with_areas = true
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			assert(not hit.is_empty(), "Visible limb must register")
			assert(hit.collider.get_meta("damage_target",null) == enemy, "Ray resolves to correct zombie")
			checked += 1
	# Above the former spherical head hitbox: visible upper forehead must count.
	var forehead: Vector3 = enemy.head_pivot.to_global(Vector3(0,0.335,0))
	var query := PhysicsRayQueryParameters3D.create(forehead+Vector3(0,0,-1),forehead,13)
	query.collide_with_areas = true
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and hit.collider.get_meta("headshot",false), "Upper head is a headshot")
	for count in [0,1,2]:
		game.kills = count
		game._process(0)
		assert(game.score_label.text == ("%d kill" % count if count < 2 else "2 kills"))
	assert(game.score_label.get_theme_font_size("font_size") == 30)
	assert(game.ammo_label.get_theme_font_size("font_size") == 38)
	print("PASS: %d animated body/head ray checks, upper forehead, kill plural and HUD sizes" % checked)
	quit()

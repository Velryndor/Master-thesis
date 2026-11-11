extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.upgrade_points = 1
	assert(not game.purchase_upgrade(0), "No purchases in startup popup")
	game.controls_ok.pressed.emit()
	game.upgrade_points = 0
	assert(not game.purchase_upgrade(0), "No free upgrades")
	game.wave = 1
	game.pending = 0
	game.intermission = 5
	game._physics_process(0.01)
	assert(game.upgrade_points == 1)
	game._physics_process(0.01)
	assert(game.upgrade_points == 1, "Only one reward per wave")
	game.upgrade_points = 20
	assert(game.purchase_upgrade(0))
	assert(game.upgrade_points == 19 and game.upgrade_levels[0] == 1)
	assert(game.purchase_upgrade(1))
	game.health = 60
	assert(game.purchase_upgrade(2))
	assert(game.max_health == 120 and game.health == 80)
	game._process(0)
	assert(game.health_bar.max_value == 120 and game.health_label.text == "80 / 120")
	for i in range(4): assert(game.purchase_upgrade(0))
	var points: int = game.upgrade_points
	assert(not game.purchase_upgrade(0) and game.upgrade_points == points, "Level cap costs nothing")
	game.set_paused(true)
	assert(not game.purchase_upgrade(1))
	game.set_paused(false)
	game.spawn_enemy()
	var enemy = game.enemies[0]
	enemy.set_physics_process(false)
	enemy.position = Vector3(0,0,-3)
	game.camera.look_at(enemy.global_position+Vector3(0,1.3,0))
	await physics_frame
	await physics_frame
	game.shoot()
	assert(enemy.health == 32, "Five damage upgrades double body damage to 68")
	assert(is_equal_approx(game.shot_clock,0.34/1.15), "Cadence shortens shot delay")
	assert(game.damage_numbers.back().node.modulate == Color("f0f5fa"), "Upgraded torso damage stays white")
	print("PASS: reward once per wave, purchases, caps, pause, health, weapon damage and cadence")
	quit()

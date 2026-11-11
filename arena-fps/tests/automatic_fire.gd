extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.controls_ok.pressed.emit()
	game.handle_automatic_fire(true)
	assert(game.ammo == 11, "Automatic fire available without upgrades")
	assert(is_equal_approx(game.shot_clock,0.34), "Slower base cadence")
	game.ammo = 12
	game.shot_clock = 0
	game.upgrade_points = 1
	assert(game.purchase_upgrade(1))
	game.handle_automatic_fire(true)
	assert(game.ammo == 11)
	game.handle_automatic_fire(true)
	assert(game.ammo == 11, "Automatic fire respects cooldown")
	game.shot_clock = 0
	game.handle_automatic_fire(false)
	assert(game.ammo == 11, "Release stops firing")
	game.handle_automatic_fire(true)
	assert(game.ammo == 10)
	game.shot_clock = 0
	game.set_paused(true)
	game.handle_automatic_fire(true)
	assert(game.ammo == 10, "No shots in pause")
	game.set_paused(false)
	game.reload_gun()
	game.handle_automatic_fire(true)
	assert(game.ammo == 10, "No shots during reload")
	game.reload_clock = 0
	game.ammo = 0
	game.handle_automatic_fire(true)
	assert(game.ammo == 0 and game.reload_clock > 0, "Empty magazine starts reload")
	game.reload_clock = 0
	game.ammo = 12
	game.dead = true
	game.handle_automatic_fire(true)
	assert(game.ammo == 12)
	print("PASS: automatic fire from start, cooldown, release, pause, reload and death")
	quit()

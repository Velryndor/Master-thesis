extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.controls_ok.pressed.emit()
	var previous: Dictionary = game.wave_settings(1)
	for wave in range(2,101):
		var stats: Dictionary = game.wave_settings(wave)
		assert(stats.count >= previous.count and stats.health >= previous.health)
		assert(stats.damage >= previous.damage and stats.speed >= previous.speed)
		assert(stats.count <= 60 and stats.damage <= 36 and stats.speed <= 4.3)
		assert(stats.interval >= 0.25 and stats.interval <= previous.interval)
		previous = stats
	game.wave = 20
	game.pending = 30
	var built: int = game.enemies_built
	for i in range(25):
		game.spawn_clock = 0
		game._physics_process(0.001)
	assert(game.enemies.size() == 14 and game.pending == 16, "Active limit preserves pending enemies")
	assert(game.enemies_built == built, "No new construction in combat")
	assert(game.enemies[0].health == game.wave_settings(20).health)
	assert(game.enemies[0].contact_damage == game.wave_settings(20).damage)
	game._process(0)
	assert(game.crosshair.position == game.get_viewport().get_visible_rect().size/2, "Reticle centered on shot ray")
	assert(game.wave_settings(5).count == 19 and game.wave_settings(5).health == 130)
	game.upgrade_points = 1
	game.upgrade_levels[0] = 5
	game._process(0)
	assert(game.upgrade_rows[0].text == "MAX")
	assert(game.upgrade_rows[1].text == "0/5")
	assert(not game.upgrade_icons[0].available and game.upgrade_icons[1].available)
	assert(not game.upgrade_keys[0].visible and game.upgrade_keys[1].visible)
	assert(game.upgrade_keys[1].caption == "2")
	game.upgrade_points = 0
	game._process(0)
	for key in game.upgrade_keys: assert(not key.visible)
	print("PASS: wave progression and caps, pending enemies, pooled stats, icon-only HUD and MAX state")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	assert(game.showing_controls and game.paused and game.controls_panel.visible, "Controls popup at startup")
	game._physics_process(10.0)
	assert(game.wave == 0 and game.time_alive == 0, "Popup prevents wave countdown")
	game.controls_ok.pressed.emit()
	assert(not game.paused and not game.controls_panel.visible, "OK starts game")
	game._physics_process(4.1)
	assert(game.wave == 1 and game.enemies.size() == 1 and game.pending == 5, "Wave 1 spawn")
	var enemy = game.enemies[0]
	enemy.set_physics_process(false)
	enemy.position = Vector3(0,0,-3)
	await physics_frame
	game.camera.look_at(enemy.global_position+Vector3(0,1.3,0))
	await physics_frame
	for i in range(3):
		game.shot_clock = 0
		game.shoot()
	assert(game.kills == 1 and game.ammo == 9, "Three ray hits kill")
	game.reload_gun()
	game._physics_process(1.3)
	assert(game.ammo == 12, "Reload completes")
	game.pending = 0
	for remaining in game.enemies.duplicate(): game.enemy_killed(remaining)
	game._physics_process(5.1)
	assert(game.wave == 2 and game.pending == 8, "Wave 2 increases enemy count")
	var attacker = game.enemies[0]
	attacker.set_physics_process(false)
	attacker.position = game.player.position + Vector3(0,0,-1)
	attacker._physics_process(0.016)
	assert(game.health == 88, "Enemy contact attack")
	attacker._physics_process(0.016)
	assert(game.health == 88, "Attack cooldown")
	game.take_damage(12)
	assert(game.health == 76, "Damage")
	game._process(0)
	assert(game.health_bar.value == 76, "Health bar follows damage")
	assert(game.health_label.position == game.health_bar.position, "Health text inside bar")
	assert(game.health_label.get_theme_font("font") == game.display_font, "Health font matches HUD")
	assert(game.gun.get_node("Flashlight") is SpotLight3D, "Player flashlight")
	assert(game.score_label.text.begins_with(str(game.kills) + " "), "Unpadded elimination counter")
	attacker.position = Vector3(0,0,-3)
	await physics_frame
	var head_target: Vector3 = attacker.head_pivot.to_global(Vector3(0,0.08,0))
	game.camera.look_at(head_target)
	await physics_frame
	game.shot_clock = 0
	game.shoot()
	assert(attacker.health == 32 and game.last_headshot, "Headshot deals 68 damage")
	assert(game.damage_numbers.back().node.text == "68", "Headshot floating amount")
	assert(game.flash.visible and game.muzzle_light.light_energy > 0, "Muzzle flash on shot")
	assert(not game.tracers.is_empty(), "Hitscan tracer created")
	assert(game.tracers.back().start.distance_to(game.gun.to_global(Vector3(0,0,-0.245))) < 0.001, "Tracer starts at barrel")
	assert(game.damage_numbers.back().node.no_depth_test, "Damage must remain visible through 3D geometry")
	assert(game.damage_numbers.back().node.modulate == Color("ff9b35"), "Headshot orange")
	assert(game.hit_clock > 0, "Confirmed-hit marker")
	game.camera.look_at(game.camera.global_position+Vector3(0,10,-1))
	game.shot_clock = 0
	game.hit_clock = 0
	var count_before: int = game.damage_numbers.size()
	var built_before: int = game.enemies_built
	game.shoot()
	assert(game.hit_clock == 0 and game.damage_numbers.size() == count_before, "Miss has no hit feedback")
	assert(game.tracers.size() == 1 and game.tracers[0].node.get_child_count() == 1, "Only one single-layer tracer")
	assert(game.enemies_built == built_before, "Shooting does not construct enemies")
	game.update_shot_effects(0.1)
	assert(game.tracers.is_empty() and not game.flash.visible and game.muzzle_light.light_energy == 0, "Shot effects expire")
	game.update_damage_numbers(1.0)
	assert(game.damage_numbers.is_empty(), "Floating damage expires")
	game.set_paused(true)
	var timer: float = game.time_alive
	game._physics_process(2.0)
	assert(game.time_alive == timer, "Pause freezes game")
	game.set_paused(false)
	game.take_damage(100)
	assert(game.dead and game.health == 0 and game.pause_panel.visible, "Death screen")
	game.queue_free()
	await process_frame
	var restarted = load("res://main.tscn").instantiate()
	root.add_child(restarted)
	await physics_frame
	assert(restarted.health == 100 and restarted.wave == 0, "New game resets state")
	print("PASS: waves, raycast shooting, reload, damage, pause, death")
	quit()

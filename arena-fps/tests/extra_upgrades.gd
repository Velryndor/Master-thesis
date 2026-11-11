extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.controls_ok.pressed.emit()
	assert(game.upgrade_icons.size() == 5 and game.upgrade_keys[4].caption == "5")
	game.upgrade_points = 10
	for i in range(5):
		assert(game.purchase_upgrade(3))
		assert(game.purchase_upgrade(4))
	assert(is_equal_approx(game.movement_speed(false),7.8))
	assert(is_equal_approx(game.movement_speed(true),12.0))
	assert(game.magazine_capacity() == 27 and game.ammo == 27)
	assert(not game.purchase_upgrade(3) and not game.purchase_upgrade(4))
	game.ammo = 1
	game.reload_gun()
	game._physics_process(1.3)
	assert(game.ammo == 27)
	game._process(0)
	assert(game.ammo_label.text == "27 / 27")
	assert(game.upgrade_rows[3].text == "MAX" and game.upgrade_rows[4].text == "MAX")
	assert(not game.upgrade_keys[4].visible)
	print("PASS: five icons, movement/sprint bonus, magazine purchase/reload, caps and HUD")
	quit()

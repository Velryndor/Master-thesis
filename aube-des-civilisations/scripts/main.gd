extends Node2D

const Catalog = preload("res://scripts/catalog.gd")
const Simulation = preload("res://scripts/sim.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Hud = preload("res://scripts/hud.gd")

const SAVE_FILE := "user://vallee.json"
const TICK_DURATION := 2.4
const CAMERA_SPEED := 475.0
const ZOOM_LEVELS := [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
const SCREEN_MARGIN_TOP_LEFT := Vector2(28, 68)
const SCREEN_MARGIN_BOTTOM_RIGHT := Vector2(280, 158)
const INVALID_CELL := Vector2i(-1, -1)
const GOOD := Color("#f2e5ac")

var sim: Simulation
var world: WorldView
var camera: Camera2D
var hud: Hud
var mode := "gather"
var selected_building := ""

var _paused := false
var _speed := 1
var _production_time := 0.0
var _zoom_index := 2
var _camera_position := Vector2.ZERO
var _dragging := false
var _cursor_cell := INVALID_CELL
var _cursor_valid := false
var _cursor_mode := ""
var _dirty := false
var _new_producers: Dictionary = {}


func _ready() -> void:
	get_window().min_size = Vector2i(960, 580)
	sim = Simulation.new()
	sim.new_game()
	var had_save := FileAccess.file_exists(SAVE_FILE)
	var loaded := had_save and _read_save()

	world = WorldView.new()
	world.name = "Vallee"
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	world.bind(sim)
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	_center_camera()
	get_viewport().size_changed.connect(_apply_camera)

	hud = Hud.new()
	hud.name = "Interface"
	add_child(hud)
	hud.build(sim)
	hud.gather_requested.connect(func(): _set_mode("gather"))
	hud.craft_requested.connect(_craft)
	hud.demolish_requested.connect(_demolish)
	hud.building_requested.connect(_choose_building)
	hud.advance_requested.connect(_advance)
	hud.pause_requested.connect(_toggle_pause)
	hud.speed_requested.connect(_change_speed)
	hud.center_requested.connect(_center_camera)
	hud.save_requested.connect(_manual_save)
	hud.load_requested.connect(_manual_load)
	hud.restart_requested.connect(_restart)
	hud.fullscreen_requested.connect(_toggle_fullscreen)
	hud.quit_requested.connect(_quit)
	hud.set_time(_paused, _speed)
	if loaded:
		hud.notify("Votre vallée a été rechargée.")
	elif had_save:
		hud.notify("La sauvegarde est illisible. Une nouvelle vallée a été ouverte.", false)


func _process(delta: float) -> void:
	if hud == null:
		return
	if hud.modal_open():
		world.set_worker_paused(true)
		_hide_world_cursor()
		hud.set_yield_preview("", 0)
		return
	world.set_worker_paused(_paused)

	var direction := Vector2(
		float(_movement_key(KEY_D)) - float(_movement_key(KEY_A) or Input.is_key_pressed(KEY_Q)),
		float(_movement_key(KEY_S)) - float(_movement_key(KEY_W) or Input.is_key_pressed(KEY_Z))
	)
	if direction != Vector2.ZERO:
		_move_camera(direction.normalized() * CAMERA_SPEED * delta / camera.zoom.x)

	if not _paused:
		var simulation_delta := delta * _speed
		_update_villager(simulation_delta)
		_production_time += simulation_delta
		while _production_time >= TICK_DURATION:
			_production_time -= TICK_DURATION
			_run_production_cycle()
			_dirty = true
			hud.refresh(sim)
			if sim.ticks % 12 == 0 and (sim.buildings.size() > 1 or not sim.gather_orders.is_empty()):
				_write_save()

	if get_viewport().gui_get_hovered_control() or _dragging:
		_hide_world_cursor()
		_describe_action(INVALID_CELL)
	else:
		var cell := _pointer_cell(world.get_local_mouse_position())
		_describe_action(cell)
		_update_world_cursor(cell)


func _input(event: InputEvent) -> void:
	if hud == null:
		return
	if event is InputEventMouseMotion and _dragging:
		_move_camera(-event.relative / camera.zoom.x)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_dragging = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not hud.modal_open():
		_set_mode("gather")
		hud.clear_selection()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if hud.modal_open():
				hud.close_modal()
			else:
				_set_mode("gather")
				hud.clear_selection()
			get_viewport().set_input_as_handled()
		elif not hud.modal_open():
			match event.keycode:
				KEY_C:
					_center_camera()
				KEY_G:
					_set_mode("gather")
				KEY_SPACE:
					_toggle_pause()
				_:
					return
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if hud == null or hud.modal_open():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var local: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
				_use_tool(_pointer_cell(local))
			MOUSE_BUTTON_MIDDLE:
				_dragging = true
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(-1, event.position)
			_:
				return
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty and sim != null:
		_write_save()


func _choose_building(id: String) -> void:
	if mode == "build" and selected_building == id:
		_set_mode("gather")
	else:
		_set_mode("build", id)


func _set_mode(next: String, id := "") -> void:
	mode = next
	selected_building = id
	if mode != "gather":
		hud.clear_selection()
	var target: String = Catalog.BUILDINGS[id].deposit if mode == "build" else ""
	world.set_build_target(target)
	_hide_world_cursor()
	hud.set_mode(mode, selected_building)
	_describe_action(INVALID_CELL)


func _craft() -> void:
	var reason := sim.craft_reason()
	if not reason.is_empty():
		hud.notify(reason, false)
		return
	if sim.craft():
		hud.notify("Bâton de fouille fabriqué. Le villageois rapporte désormais %d vivres par buisson." % Catalog.FOOD_TOOL_YIELD)
		world.flash(sim.camp, Catalog.TOOL_NAME, GOOD)
		_after_action()


func _use_tool(cell: Vector2i) -> void:
	if not _in_map(cell):
		return
	match mode:
		"build":
			if not sim.place(selected_building, cell):
				hud.notify(sim.place_reason(selected_building, cell), false)
				return
			if not Catalog.BUILDINGS[selected_building].output.is_empty():
				_new_producers[cell] = true
		_:
			if sim.buildings.has(cell):
				hud.select_cell(cell)
				return
			var deposit: String = sim.deposits.get(cell, "")
			if deposit.is_empty():
				hud.clear_selection()
				return
			if not sim.gather(cell):
				hud.notify(sim.gather_reason(cell), false)
				return
			hud.clear_selection()
	_after_action()


func _demolish(cell: Vector2i) -> void:
	if not sim.demolish(cell):
		hud.notify(sim.demolish_reason(cell), false)
		return
	_new_producers.erase(cell)
	hud.clear_selection()
	_after_action()


func _run_production_cycle() -> void:
	var inspected := hud.inspected_cell()
	for event in sim.tick():
		var first_output: bool = event.started and _new_producers.erase(event.cell)
		if first_output or event.cell == inspected:
			for resource in event.output:
				world.flash_resource(event.cell, resource, event.output[resource])


func _update_villager(delta: float) -> void:
	if sim.gather_orders.is_empty():
		return
	_dirty = true
	var events := sim.update_harvest(delta)
	for event in events:
		if event.type == "deposited":
			world.flash_resource(sim.camp, event.resource, event.amount)
	if not events.is_empty():
		_after_action()


func _advance() -> void:
	if not sim.advance():
		hud.notify(sim.advance_reason(), false)
		return
	_set_mode("gather")
	if sim.won:
		_watch_launch()
	else:
		hud.notify("Nouvel âge · " + str(Catalog.AGES[sim.age].name))
		world.flash(sim.camp, Catalog.AGES[sim.age].name, GOOD)
	_after_action()


func _watch_launch() -> void:
	var pad: Vector2i = sim.buildings.find_key("launchpad")
	_zoom_index = 2
	camera.zoom = Vector2.ONE * ZOOM_LEVELS[_zoom_index]
	_camera_position = world.cell_center(pad) + Vector2(46, -40)
	_apply_camera()
	hud.notify("Décollage de la première mission orbitale.")
	get_tree().create_timer(4.0).timeout.connect(func():
		if sim.won and not hud.modal_open():
			hud.show_victory()
	)


func _after_action() -> void:
	_dirty = true
	hud.refresh(sim)
	world.queue_redraw()
	_write_save()


func _toggle_pause() -> void:
	_paused = not _paused
	hud.set_time(_paused, _speed)


func _change_speed() -> void:
	_speed = 1 if _speed >= 4 else _speed * 2
	hud.set_time(_paused, _speed)


func _toggle_fullscreen() -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _quit() -> void:
	if _dirty:
		_write_save()
	get_tree().quit()


func _in_map(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, sim.map_size).has_point(cell)


func _movement_key(key: Key) -> bool:
	return Input.is_key_pressed(key) or Input.is_physical_key_pressed(key)


func _pointer_cell(local_position: Vector2) -> Vector2i:
	if mode == "build":
		var tile := Vector2i((local_position / WorldView.TILE_SIZE).floor())
		var deposit: String = Catalog.BUILDINGS[selected_building].deposit
		if deposit.is_empty() or sim.sites.get(tile, "") == deposit:
			return tile
	return world.cell_at(local_position)


func _update_world_cursor(cell: Vector2i) -> void:
	if not _in_map(cell):
		_hide_world_cursor()
		return
	var display_mode := mode
	var valid: bool
	match mode:
		"build":
			valid = sim.place_reason(selected_building, cell).is_empty()
		_:
			if sim.buildings.has(cell):
				display_mode = "inspect"
				valid = true
			elif sim.deposits.has(cell):
				valid = sim.gather_amount(cell) > 0
			else:
				_hide_world_cursor()
				return
	if cell != _cursor_cell or valid != _cursor_valid or display_mode != _cursor_mode:
		_cursor_cell = cell
		_cursor_valid = valid
		_cursor_mode = display_mode
		world.set_cursor(cell, valid, display_mode, selected_building)


func _hide_world_cursor() -> void:
	if _cursor_cell != INVALID_CELL:
		_cursor_cell = INVALID_CELL
		world.clear_cursor()


func _describe_action(cell: Vector2i) -> void:
	if mode == "build":
		hud.set_yield_preview("", 0)
		var definition: Dictionary = Catalog.BUILDINGS[selected_building]
		var hint := "Cliquez sur un terrain libre."
		if not definition.deposit.is_empty():
			hint = "Cliquez sur un site marqué."
		var reason := sim.place_reason(selected_building, cell) if _in_map(cell) else ""
		hud.set_context(definition.name, hint if reason.is_empty() else reason, reason.is_empty())
		return
	hud.set_context("", "")
	var resource: String = sim.deposits.get(cell, "")
	hud.set_yield_preview(resource, 0 if resource.is_empty() else sim.gather_amount(cell))


func _center_camera() -> void:
	_zoom_index = 2
	camera.zoom = Vector2.ONE * ZOOM_LEVELS[_zoom_index]
	_camera_position = world.cell_center(sim.camp) + Vector2(55, 11)
	_apply_camera()


func _move_camera(change: Vector2) -> void:
	_camera_position += change
	_apply_camera()


func _zoom(step: int, screen_position: Vector2) -> void:
	var next := clampi(_zoom_index + step, 0, ZOOM_LEVELS.size() - 1)
	if next == _zoom_index:
		return
	var distance := screen_position - get_viewport_rect().size / 2.0
	var old_zoom := camera.zoom.x
	_zoom_index = next
	camera.zoom = Vector2.ONE * ZOOM_LEVELS[next]
	_camera_position += distance * (1.0 / old_zoom - 1.0 / camera.zoom.x)
	_apply_camera()


func _apply_camera() -> void:
	var dimensions := Vector2(sim.map_size) * WorldView.TILE_SIZE
	var half_screen := get_viewport_rect().size / (2.0 * camera.zoom)
	# Leave room to bring the map edges out from underneath the HUD.
	var minimum := half_screen - SCREEN_MARGIN_TOP_LEFT / camera.zoom
	var maximum := dimensions - half_screen + SCREEN_MARGIN_BOTTOM_RIGHT / camera.zoom
	var midpoint := (minimum + maximum) * 0.5
	_camera_position = _camera_position.clamp(minimum.min(midpoint), maximum.max(midpoint))
	camera.position = _camera_position.round()
	camera.force_update_scroll()


func _manual_save() -> void:
	var saved := _write_save()
	hud.notify("Partie sauvegardée." if saved else "Impossible d’écrire la sauvegarde.", saved)


func _manual_load() -> void:
	if _read_save():
		_reset_interface()
		hud.notify("Sauvegarde rechargée.")
	else:
		hud.notify("Aucune sauvegarde valide à recharger.", false)


func _restart() -> void:
	sim.new_game()
	_reset_interface()
	_write_save()
	hud.notify("Une nouvelle vallée vous attend.")


func _reset_interface() -> void:
	_dirty = false
	_production_time = 0.0
	_paused = false
	_speed = 1
	_dragging = false
	_new_producers.clear()
	world.bind(sim)
	_set_mode("gather")
	hud.clear_selection()
	hud.set_time(_paused, _speed)
	hud.refresh(sim)
	_center_camera()
	world.queue_redraw()


func _write_save() -> bool:
	var temporary := SAVE_FILE + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(sim.export_state(), "", true, true))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary, SAVE_FILE) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	_dirty = false
	return true


func _read_save() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	return data is Dictionary and sim.import_state(data)

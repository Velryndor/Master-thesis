extends Node2D

const TILE_SIZE := 24
const SPRITE_SIZE := 40
const SPRITE_ANCHOR := Vector2(20, 29)
const ATLAS_COLUMNS := 8
const WORLD_TEXTURE := preload("res://assets/vallee.png")
const SPRITE_TEXTURE := preload("res://assets/sprites.png")
const SLOTS := preload("res://scripts/world_atlas.gd").SLOTS
const Simulation := preload("res://scripts/sim.gd")
const WorldLayout := preload("res://scripts/world_layout.gd")
const ICON_ALIASES := {"ceramic": "bricks"}
const WALK_FRAMES := ["worker_0", "worker_1", "worker_0", "worker_2"]
const CHIMNEYS := {
	"clay_kiln": Vector2(0, -19),
	"bronze_foundry": Vector2(5, -21),
	"forge": Vector2(8, -24),
	"power_plant": Vector2(-1, -25),
	"factory": Vector2(7, -23),
}
const WORK_YARDS := {
	"lumber_camp": Vector2(1, 1),
	"quarry": Vector2(3, -2),
	"copper_mine": Vector2(-4, 0),
	"tin_mine": Vector2(-4, 0),
	"iron_mine": Vector2(-4, 0),
	"coal_mine": Vector2(-4, 0),
	"silica_mine": Vector2(-4, 0),
	"titanium_mine": Vector2(-4, 0),
}
const FLASH_DURATION := 1.25

static var _icons: Dictionary = {}

var _sim: Simulation
var _effects: Node2D
var _atlas_pixels: Image
var _cursor := Vector2i(-1, -1)
var _cursor_valid := false
var _cursor_mode := ""
var _ghost_id := ""
var _build_target := ""
var _building_count := -1
var _deposit_count := -1
var _worker_position := Vector2.ZERO
var _worker_facing := 1.0
var _worker_animation := 0.0
var _worker_paused := false
var _time := 0.0
var _effect_timer := 0.0
var _flashes: Array[Dictionary] = []
var _was_victorious := false
var _launch_time := -10.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_effects = Node2D.new()
	_effects.draw.connect(_draw_effects)
	add_child(_effects)
	_atlas_pixels = SPRITE_TEXTURE.get_image()


func bind(simulation: Simulation) -> void:
	_sim = simulation
	_building_count = _sim.buildings.size()
	_deposit_count = _sim.deposits.size()
	_worker_position = _sim.worker_position
	_worker_facing = 1.0
	_worker_animation = 0.0
	_was_victorious = _sim.won
	_launch_time = -10.0
	_flashes.clear()
	clear_cursor()
	queue_redraw()


static func building_icon(id: String) -> Texture2D:
	return _icon(id if SLOTS.has(id) else "shelter", Rect2(1, 2, 38, 36))


static func resource_icon(id: String) -> Texture2D:
	var key := "icon_" + String(ICON_ALIASES.get(id, id))
	if not SLOTS.has(key):
		key = "icon_stone"
	return _icon(key, Rect2(6, 12, 29, 25))


static func _icon(key: String, crop: Rect2) -> Texture2D:
	if _icons.has(key):
		return _icons[key]
	var texture := AtlasTexture.new()
	texture.atlas = SPRITE_TEXTURE
	var origin := _source(key).position
	texture.region = Rect2(origin + crop.position, crop.size)
	texture.filter_clip = true
	_icons[key] = texture
	return texture


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)


func cell_at(local_position: Vector2) -> Vector2i:
	var tile := Vector2i(floori(local_position.x / TILE_SIZE), floori(local_position.y / TILE_SIZE))
	if _sim == null or _atlas_pixels == null:
		return tile
	if not _build_target.is_empty() and _sim.sites.get(tile) == _build_target and not _sim.deposits.has(tile):
		return tile
	# Match the back-to-front rendering order when a sprite overhangs its tile.
	for y in range(tile.y + 1, tile.y - 1, -1):
		for x in range(tile.x + 1, tile.x - 2, -1):
			var cell := Vector2i(x, y)
			var key := _entity_at(cell)
			if key.is_empty():
				continue
			var pixel := Vector2i((local_position - cell_center(cell) + SPRITE_ANCHOR).floor())
			if not Rect2i(0, 0, SPRITE_SIZE, SPRITE_SIZE).has_point(pixel):
				continue
			var source_pixel := Vector2i(_source(key).position) + pixel
			if _atlas_pixels.get_pixelv(source_pixel).a > 0.6:
				return cell
	return tile


func set_cursor(cell: Vector2i, valid: bool, mode := "inspect", building_id := "") -> void:
	if _cursor == cell and _cursor_valid == valid and _cursor_mode == mode and _ghost_id == building_id:
		return
	_cursor = cell
	_cursor_valid = valid
	_cursor_mode = mode
	_ghost_id = building_id
	queue_redraw()


func clear_cursor() -> void:
	set_cursor(Vector2i(-1, -1), false)


func set_build_target(deposit: String) -> void:
	if _build_target == deposit:
		return
	_build_target = deposit
	queue_redraw()


func set_worker_paused(paused: bool) -> void:
	_worker_paused = paused


func flash(cell: Vector2i, label: String, color: Color) -> void:
	_add_flash(cell, label, color, "")


func flash_resource(cell: Vector2i, resource: String, amount: int) -> void:
	if amount > 0:
		_add_flash(cell, "+%d" % amount, Color("f2e4b6"), resource)


func _add_flash(cell: Vector2i, label: String, color: Color, resource: String) -> void:
	var lift := 0.0
	for previous in _flashes:
		if previous.cell == cell and _time - previous.started < 0.22:
			lift = maxf(lift, float(previous.lift) + 10.0)
	_flashes.append({
		"cell": cell, "label": label, "color": color, "resource": resource,
		"started": _time, "lift": minf(lift, 24.0),
	})
	if _flashes.size() > 40:
		_flashes.pop_front()


func _process(delta: float) -> void:
	if _sim == null:
		return
	_time += delta
	_effect_timer += delta
	if _sim.buildings.size() != _building_count or _sim.deposits.size() != _deposit_count:
		_building_count = _sim.buildings.size()
		_deposit_count = _sim.deposits.size()
		queue_redraw()
	var travel := _sim.worker_position - _worker_position
	_worker_position = _sim.worker_position
	if absf(travel.x) > 0.001:
		_worker_facing = signf(travel.x)
	if not _worker_paused:
		_worker_animation += delta
	if _sim.won and not _was_victorious:
		_launch_time = _time
		queue_redraw()
	_was_victorious = _sim.won
	while not _flashes.is_empty() and _time - float(_flashes[0].started) > FLASH_DURATION:
		_flashes.pop_front()
	if _effects != null and _effect_timer >= 1.0 / 30.0:
		_effect_timer = 0.0
		_effects.queue_redraw()


func _draw() -> void:
	draw_texture(WORLD_TEXTURE, Vector2.ZERO)
	if _sim == null:
		return

	_draw_bridge()
	var has_cursor := Rect2i(Vector2i.ZERO, _sim.map_size).has_point(_cursor)
	var selection := Rect2(Vector2(_cursor) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
	var outline := _cursor_color()
	if has_cursor:
		draw_rect(selection, Color(outline, 0.24))

	for y in range(_sim.map_size.y):
		for x in range(_sim.map_size.x):
			var cell := Vector2i(x, y)
			var key := _entity_at(cell)
			if not key.is_empty():
				_draw_sprite(self, key, cell_center(cell))

	_draw_build_targets()
	if has_cursor:
		if _cursor_mode == "build" and _cursor_valid and SLOTS.has(_ghost_id):
			_draw_sprite(self, _ghost_id, cell_center(_cursor), Color(1.0, 1.0, 1.0, 0.62))
		_draw_selection(selection, outline)


func _draw_bridge() -> void:
	var start := cell_center(WorldLayout.BRIDGE_FIRST)
	var finish := cell_center(WorldLayout.BRIDGE_LAST)
	var left := int(start.x) - 22
	var right := int(finish.x) + 20
	var y := int(start.y)
	draw_colored_polygon(PackedVector2Array([
		Vector2(right - 2, y - 4), Vector2(right + 8, y - 5),
		Vector2(right + 18, y - 14), Vector2(right + 26, y - 16),
		Vector2(right + 27, y - 9), Vector2(right + 18, y - 7),
		Vector2(right + 10, y + 2), Vector2(right - 2, y + 5),
	]), Color("a58d61"))
	draw_rect(Rect2(left - 3, y + 7, right - left + 7, 7), Color("253f40a0"))
	draw_rect(Rect2(left, y - 6, right - left, 17), Color("564636"))
	draw_rect(Rect2(left + 1, y - 4, right - left - 2, 12), Color("a37950"))
	for x in range(left + 2, right - 1, 5):
		var plank_width := mini(4, right - x - 1)
		var plank_color := Color("c6a172") if x % 2 == 0 else Color("b99264")
		draw_rect(Rect2(x, y - 4, plank_width, 11), plank_color)
		draw_rect(Rect2(x, y - 4, plank_width, 1), Color("d4ae7b"))
	draw_rect(Rect2(left + 1, y + 7, right - left - 2, 1), Color("dda773"))
	draw_rect(Rect2(left + 1, y + 8, right - left - 2, 2), Color("8b6041"))
	draw_rect(Rect2(left, y - 8, right - left, 2), Color("715037"))
	draw_rect(Rect2(left, y - 8, right - left, 1), Color("caa071"))
	for x in [left + 1, left + 24, right - 26, right - 4]:
		draw_rect(Rect2(x, y - 10, 3, 6), Color("594738"))
		draw_rect(Rect2(x, y - 10, 2, 5), Color("a77a50"))
		draw_rect(Rect2(x, y - 10, 3, 1), Color("d0a172"))
		draw_rect(Rect2(x, y + 6, 3, 7), Color("594738"))
		draw_rect(Rect2(x, y + 6, 2, 5), Color("a77a50"))
		draw_rect(Rect2(x, y + 6, 3, 1), Color("d0a172"))


func _entity_at(cell: Vector2i) -> String:
	var building: String = _sim.buildings.get(cell, "")
	if not building.is_empty():
		if building == "launchpad" and _sim.won:
			return "launchpad_empty"
		return building if SLOTS.has(building) else "shelter"
	var resource: String = _sim.deposits.get(cell, "")
	var variant := posmod(cell.x * 31 + cell.y * 17, 4)
	match resource:
		"wood":
			return "tree_%d" % variant
		"stone":
			return "rock_%d" % (variant % 2)
		"food":
			return "berries_%d" % (variant % 2)
		"":
			return ""
		_:
			return "deposit_" + resource


static func _source(key: String) -> Rect2:
	var index: int = SLOTS[key]
	var column := index % ATLAS_COLUMNS
	@warning_ignore("integer_division")
	var row := index / ATLAS_COLUMNS
	return Rect2(column * SPRITE_SIZE, row * SPRITE_SIZE, SPRITE_SIZE, SPRITE_SIZE)


static func _draw_sprite(canvas: CanvasItem, key: String, center: Vector2, modulation := Color.WHITE) -> void:
	if SLOTS.has(key):
		canvas.draw_texture_rect_region(
			SPRITE_TEXTURE, Rect2(center.round() - SPRITE_ANCHOR, Vector2.ONE * SPRITE_SIZE),
			_source(key), modulation
		)


func _cursor_color() -> Color:
	if _cursor_mode == "inspect":
		return Color("f0dcab")
	if not _cursor_valid:
		return Color("e99178")
	if _cursor_mode == "demolish":
		return Color("efba7e")
	return Color("d6eb9c")


func _draw_selection(selection: Rect2, color: Color) -> void:
	draw_rect(selection.grow(-0.5), Color(color, 0.55), false, 1.0)
	_draw_corners(selection.position, color, 5)


func _draw_build_targets() -> void:
	if _build_target.is_empty():
		return
	var color := Color("edcd88d9")
	for cell in _sim.sites:
		if _sim.sites[cell] == _build_target and not _sim.buildings.has(cell) and cell != _cursor:
			_draw_corners(Vector2(cell) * TILE_SIZE, color, 3)


func _draw_corners(origin: Vector2, color: Color, length: int) -> void:
	for dy in [0, 1]:
		for dx in [0, 1]:
			var corner := origin + Vector2(dx, dy) * (TILE_SIZE - 1)
			draw_rect(Rect2(corner - Vector2(dx * (length - 1), 0), Vector2(length, 1)), color)
			draw_rect(Rect2(corner - Vector2(0, dy * (length - 1)), Vector2(1, length)), color)


func _draw_effects() -> void:
	if _sim == null:
		return
	_draw_water_shimmers()
	_draw_camp_life()
	_draw_building_activity()
	_draw_gather_orders()
	_draw_worker()
	_draw_launch()
	_draw_flashes()


func _draw_flashes() -> void:
	var font := ThemeDB.fallback_font
	for entry in _flashes:
		var age := _time - float(entry.started)
		var opacity := clampf((FLASH_DURATION - age) * 3.4, 0.0, 1.0)
		var label: String = entry.label
		var resource: String = entry.resource
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var row_width := label_width if resource.is_empty() else label_width + 12.0
		var offset := Vector2(-row_width / 2.0, -16 - 15 * age - float(entry.lift))
		var baseline := (cell_center(entry.cell) + offset).round()
		_effects.draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.10, 0.17, 0.16, opacity))
		_effects.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(entry.color, opacity))
		if not resource.is_empty():
			var icon_origin := baseline + Vector2(ceilf(label_width) + 1.0, -8.0)
			_effects.draw_texture_rect(resource_icon(resource), Rect2(icon_origin, Vector2(11, 9)), false, Color(1.0, 1.0, 1.0, opacity))


func _draw_building_activity() -> void:
	for cell in _sim.buildings:
		var id: String = _sim.buildings[cell]
		if not CHIMNEYS.has(id) and not WORK_YARDS.has(id):
			continue
		if _sim.production_state(cell) != "working":
			continue
		var phase_offset: float = cell.x * 0.173 + cell.y * 0.327
		var center := cell_center(cell)
		if CHIMNEYS.has(id):
			_draw_chimney_smoke(center + Vector2(CHIMNEYS[id]), phase_offset)
		else:
			_draw_yard_dust(center + Vector2(WORK_YARDS[id]), phase_offset)


func _draw_chimney_smoke(origin: Vector2, phase_offset: float) -> void:
	for index in range(2):
		var phase := fposmod(_worker_animation * 0.72 + phase_offset + index * 0.5, 1.0)
		var point := (origin + Vector2(phase * 4.0, -1.0 - phase * 7.0)).round()
		var shade := Color(0.81, 0.80, 0.69, 0.32 * (1.0 - phase))
		_effects.draw_rect(Rect2(point, Vector2(2 + int(phase > 0.55), 1)), shade)


func _draw_yard_dust(origin: Vector2, phase_offset: float) -> void:
	var phase := fposmod(_worker_animation + phase_offset, 2.6)
	if phase > 0.48:
		return
	var point := (origin + Vector2(phase * 5.0, -phase * 7.0)).round()
	var shade := Color(0.86, 0.77, 0.53, 0.38 * (1.0 - phase / 0.48))
	_effects.draw_rect(Rect2(point, Vector2(2, 1)), shade)
	_effects.draw_rect(Rect2(point + Vector2(-2, -1), Vector2.ONE), shade)


func _draw_water_shimmers() -> void:
	var crossing_y := cell_center(WorldLayout.BRIDGE_FIRST).y
	for i in range(40):
		var y := fposmod(i * 47.0 + _time * (3.0 + float(i % 3)), 908.0)
		if absf(y - crossing_y) < 12.0:
			continue
		var x := 380.0 + 61.0 * sin(y / 102.0 - 0.7) + 60.0 * sin(y / 250.0 - 1.25)
		x += sin(float(i) * 9.6 + _time * 0.16) * 18.0
		var alpha := (sin(_time * 1.25 + float(i) * 4.3) * 0.5 + 0.5) * 0.30
		_effects.draw_rect(Rect2(floorf(x), floorf(y), 3 + i % 8, 1), Color(0.58, 0.77, 0.74, alpha))


func _draw_camp_life() -> void:
	var camp := cell_center(_sim.camp)
	var fire := camp + Vector2(2, 1)
	var flare := 0.35 + 0.16 * sin(_time * 8.0)
	_effects.draw_rect(Rect2(fire - Vector2(2, 2), Vector2(5, 3)), Color(0.98, 0.72, 0.35, flare))
	for i in range(4):
		var drift := fposmod(_time * 5.5 + float(i) * 3.1, 15.0)
		var start := (fire + Vector2(1.5 + drift * 0.25, -drift - 2.0)).floor()
		var shade := Color(0.81, 0.82, 0.70, 0.38 - drift * 0.021)
		_effects.draw_rect(Rect2(start, Vector2(2, 1)), shade)


func _draw_gather_orders() -> void:
	var font := ThemeDB.fallback_font
	for index in range(_sim.gather_orders.size()):
		var cell: Vector2i = _sim.gather_orders[index]
		if not _sim.deposits.has(cell) or (index == 0 and _sim.worker_state == "working"):
			continue
		var center := cell_center(cell) + Vector2(9, -10)
		var border := Color("f0cd84") if index == 0 else Color("b6a778")
		_effects.draw_rect(Rect2(center - Vector2(5, 5), Vector2(11, 11)), Color("3d483a"))
		_effects.draw_rect(Rect2(center - Vector2(4.5, 4.5), Vector2(10, 10)), border, false)
		var label := str(index + 1)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		_effects.draw_string(font, center + Vector2(-width / 2.0, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, border)


func _draw_worker() -> void:
	var state := _sim.worker_state
	var center := cell_center(Vector2i.ZERO) + _worker_position * TILE_SIZE
	var camp_distance := _worker_position.distance_to(Vector2(_sim.camp))
	center += Vector2(14, 7) * clampf(1.0 - camp_distance * 2.0, 0.0, 1.0)
	var frame := "worker_0"
	var swing := floori(_worker_animation * 5.0) % 2
	if state == "outbound" or state == "returning":
		frame = WALK_FRAMES[floori(_worker_animation * 9.0) % WALK_FRAMES.size()]
	elif state == "working":
		center += Vector2(-7.0 * _worker_facing, 6.0)
		frame = "worker_work_%d" % swing

	_effects.draw_set_transform(center.round(), 0.0, Vector2(_worker_facing, 1.0))
	if state == "returning":
		_draw_haul(_sim.worker_resource)
	if state == "working" and _sim.worker_uses_tool:
		var grip := Vector2(6, -10) if swing == 0 else Vector2(7, -5)
		var tip := Vector2(10, -16) if swing == 0 else Vector2(13, 1)
		_effects.draw_line(grip + Vector2.DOWN, tip + Vector2.DOWN, Color("654f3a"), 1.0)
		_effects.draw_line(grip, tip, Color("dfb574"), 1.0)
	_draw_sprite(_effects, frame, Vector2.ZERO)
	if state == "working":
		_draw_work_particles()
	_effects.draw_set_transform(Vector2.ZERO)
	if state == "working":
		_draw_work_progress(center)


func _draw_haul(resource: String) -> void:
	if resource == "wood":
		_effects.draw_line(Vector2(-9, -9), Vector2(-2, -13), Color("5d4635"), 4.0)
		_effects.draw_line(Vector2(-10, -6), Vector2(-2, -11), Color("6a4d38"), 4.0)
		_effects.draw_line(Vector2(-9, -8), Vector2(-3, -12), Color("ce9f69"), 2.0)
		_effects.draw_line(Vector2(-9, -5), Vector2(-3, -10), Color("a87d50"), 2.0)
		_effects.draw_rect(Rect2(-7, -10, 1, 4), Color("e3bd85"))
		return
	_effects.draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10), Vector2(-7, -12), Vector2(-3, -11), Vector2(-2, -6),
		Vector2(-6, -3), Vector2(-11, -5),
	]), Color("5e4837"))
	_effects.draw_rect(Rect2(-10, -9, 7, 4), Color("bd9561"))
	_effects.draw_rect(Rect2(-9, -5, 5, 1), Color("916846"))
	if resource == "food":
		_effects.draw_rect(Rect2(-9, -10, 2, 2), Color("d98562"))
		_effects.draw_rect(Rect2(-6, -11, 2, 2), Color("e5ad6f"))
		_effects.draw_rect(Rect2(-7, -10, 1, 1), Color("95a46b"))
	else:
		var key := "icon_" + resource
		if SLOTS.has(key):
			var source := Rect2(_source(key).position + Vector2(9, 16), Vector2(22, 16))
			_effects.draw_texture_rect_region(SPRITE_TEXTURE, Rect2(-11, -13, 8, 7), source)


func _draw_work_particles() -> void:
	var phase := fposmod(_worker_animation * 2.5, 1.0)
	var shade := Color("e9cb8a")
	if _sim.worker_resource == "food":
		shade = Color("d2d492")
	for i in range(4):
		var offset := Vector2(8 + i * phase * 2.1, -3 - i - phase * 6.0).round()
		_effects.draw_rect(Rect2(offset, Vector2(2 - i % 2, 1)), Color(shade, 0.84 * (1.0 - phase)))


func _draw_work_progress(center: Vector2) -> void:
	var origin := (center + Vector2(-11, -23)).round()
	_effects.draw_rect(Rect2(origin, Vector2(22, 5)), Color("514a36"))
	_effects.draw_rect(Rect2(origin + Vector2.ONE, Vector2(20, 3)), Color("8d7651"))
	var filled := floori(_sim.worker_work_progress * 20.0)
	if filled > 0:
		_effects.draw_rect(Rect2(origin + Vector2.ONE, Vector2(filled, 3)), Color("e7c47e"))
		_effects.draw_rect(Rect2(origin + Vector2.ONE, Vector2(filled, 1)), Color("f3d99e"))


func _draw_launch() -> void:
	var elapsed := _time - _launch_time
	if elapsed < 0.0 or elapsed > 5.0:
		return
	for cell in _sim.buildings:
		if _sim.buildings[cell] != "launchpad":
			continue
		var rocket := cell_center(cell) - Vector2(0, 4 + elapsed * elapsed * 7.0)
		for i in range(6):
			var offset := Vector2(float((i % 3) - 1) * (2 + elapsed * 3), 8.0 + float(i) * 2.0 + elapsed * 8.0)
			var color := Color(0.96, 0.75 - float(i) * 0.025, 0.47, 0.80 - float(i) * 0.09)
			_effects.draw_rect(Rect2((rocket + offset).floor(), Vector2(3 + i % 3, 4 + i % 2)), color)
		_draw_sprite(_effects, "vehicle", rocket)
		return

extends Node3D

const ENEMY_SCRIPT = preload("res://enemy.gd")
const MAGAZINE := 12
var player: CharacterBody3D
var camera: Camera3D
var slide: Node3D
var gun: Node3D
var flash: Node3D
var muzzle_light: OmniLight3D
var muzzle_clock := 0.0
var tracers: Array[Dictionary] = []
var enemies: Array[CharacterBody3D] = []
var enemy_pool: Array[CharacterBody3D] = []
var enemies_built := 0
var health := 100
var max_health := 100
var upgrade_points := 0
var upgrade_levels: Array[int] = [0,0,0,0,0]
var rewarded_wave := 0
const MAX_UPGRADE_LEVEL := 5
var upgrade_icons: Array[Control] = []
var upgrade_keys: Array[Control] = []
var upgrade_rows: Array[Label] = []
var ammo := MAGAZINE
var wave := 0
var kills := 0
var pending := 0
var intermission := 4.0
var spawn_clock := 0.0
var shot_clock := 0.0
var reload_clock := 0.0
var recoil := 0.0
var damage_clock := 0.0
var hit_clock := 0.0
var last_headshot := false
var damage_numbers: Array[Dictionary] = []
var hit_marker: Control
var paused := false
var dead := false
var hud: Control
var wave_label: Label
var info_label: Label
var health_label: Label
var health_bar: ProgressBar
var health_fill: StyleBoxFlat
var controls_panel: PanelContainer
var controls_ok: Button
var showing_controls := true
var ammo_label: Label
var score_label: Label
var crosshair: Control
var shade: ColorRect
var pause_panel: VBoxContainer
var pause_title: Label
var resume_button: Button
var time_alive := 0.0
var rng := RandomNumberGenerator.new()
var display_font: Font

func material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false, glow := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color, glow)
	parent.add_child(mesh)
	mesh.position = pos
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		collider.shape = collision
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

func _ready() -> void:
	rng.randomize()
	setup_inputs()
	setup_world()
	setup_player()
	display_font = load("res://fonts/BlackOpsOne-Regular.ttf")
	setup_hud()
	for i in range(16): prepare_enemy()
	upper_screen()
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	controls_ok.grab_focus()

func setup_inputs() -> void:
	var bindings := {"forward": [KEY_W, KEY_Z], "back": [KEY_S], "left": [KEY_A, KEY_Q], "right": [KEY_D], "sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "reload": [KEY_R]}
	for action in bindings:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.keycode = code
			InputMap.action_add_event(action, event)

func setup_world() -> void:
	var city := Node3D.new()
	city.set_script(preload("res://ruined_city.gd"))
	city.set("game", self)
	add_child(city)

func setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.position = Vector3(0,0.1,7)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	player.add_child(col)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 78
	camera.near = 0.08
	camera.far = 160.0
	player.add_child(camera)
	camera.current = true
	gun = Node3D.new()
	gun.name = "Pistol"
	camera.add_child(gun)
	gun.position = Vector3(0.28,-0.24,-0.48)
	var steel := Color("65737e")
	var polymer := Color("232d35")
	slide = Node3D.new()
	slide.name = "Slide"
	gun.add_child(slide)
	# Chamfered slide and frame catch light across distinct machined faces.
	weapon_part(slide, Vector3(0,0.005,-0.015), Vector3(0.118,0.108,0.37), 0.018, steel, 0.75)
	weapon_part(gun, Vector3(0,-0.064,0.015), Vector3(0.108,0.044,0.34), 0.009, polymer, 0.15)
	var grip := weapon_part(gun, Vector3(0,-0.17,0.105), Vector3(0.098,0.22,0.12), 0.018, polymer, 0.0)
	grip.rotation.x = -0.18
	weapon_part(gun,Vector3(0,-0.285,0.125),Vector3(0.112,0.028,0.14),0.008,steel.darkened(0.4),0.5)
	# Open trigger guard, curved trigger and rear beavertail.
	weapon_part(gun,Vector3(0,-0.175,-0.015),Vector3(0.075,0.018,0.14),0.006,polymer,0.2)
	var guard := weapon_part(gun,Vector3(0,-0.12,-0.075),Vector3(0.075,0.115,0.02),0.007,polymer,0.2)
	guard.rotation.x = -0.18
	var trigger := weapon_part(gun,Vector3(0,-0.113,0.015),Vector3(0.018,0.055,0.022),0.005,steel,0.8)
	trigger.rotation.x = -0.3
	weapon_part(gun,Vector3(0,-0.055,0.195),Vector3(0.085,0.028,0.065),0.008,polymer,0.1)
	for side in [-1,1]:
		# Rear and front slide serrations, recessed grip panels and tactile ribs.
		for i in range(8):
			box(slide,Vector3(side*0.0595,0.0,0.075+i*0.011),Vector3(0.002,0.063,0.004),Color("202a32"))
		for i in range(4):
			box(slide,Vector3(side*0.0595,0.0,-0.145+i*0.013),Vector3(0.002,0.06,0.004),Color("303c46"))
		weapon_part(gun,Vector3(side*0.05,-0.18,0.108),Vector3(0.007,0.14,0.082),0.002,Color("121c24"),0.0)
		for i in range(9):
			box(gun,Vector3(side*0.054,-0.122-i*0.014,0.108),Vector3(0.003,0.003,0.068),Color("39454d"))
		weapon_part(gun,Vector3(side*0.057,-0.052,0.065),Vector3(0.012,0.018,0.055),0.004,steel.darkened(0.3),0.65)
	# Ejection port with exposed chamber on the top/right of the slide.
	box(slide,Vector3(0.023,0.059,-0.005),Vector3(0.055,0.002,0.077),Color("10171e"))
	weapon_part(slide,Vector3(0.025,0.06,-0.005),Vector3(0.039,0.004,0.06),0.001,Color("9aa3aa"),0.85)
	box(slide,Vector3(0.06,0.022,-0.005),Vector3(0.002,0.034,0.077),Color("10171e"))
	# Dark sight bodies with small luminous aiming dots.
	weapon_part(slide,Vector3(0,0.07,-0.155),Vector3(0.019,0.026,0.032),0.004,Color("111920"),0.4)
	box(slide,Vector3(0,0.074,-0.137),Vector3(0.007,0.008,0.002),Color("b6dac7"),false,true)
	for side in [-1,1]:
		weapon_part(slide,Vector3(side*0.032,0.071,0.14),Vector3(0.023,0.028,0.033),0.004,Color("111920"),0.4)
		box(slide,Vector3(side*0.032,0.074,0.158),Vector3(0.007,0.007,0.002),Color("b6dac7"),false,true)
	gun_cylinder(Vector3(0,0,-0.212),0.034,0.045,Color("75818a"))
	gun_cylinder(Vector3(0,0,-0.237),0.024,0.008,Color("10161c"))
	gun_cylinder(Vector3(0,-0.035,-0.205),0.009,0.02,Color("8b959b"))
	# Flashlight housing beneath the barrel; its light moves with recoil.
	box(gun,Vector3(0,-0.09,-0.13),Vector3(0.07,0.04,0.15),polymer)
	gun_cylinder(Vector3(0,-0.13,-0.14),0.042,0.16,Color("28333a"))
	gun_cylinder(Vector3(0,-0.13,-0.225),0.032,0.012,Color("cadbd6"))
	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(0,-0.13,-0.24)
	flashlight.light_color = Color("d9e6df")
	flashlight.light_energy = 2.2
	flashlight.spot_range = 22
	flashlight.spot_angle = 32
	flashlight.spot_angle_attenuation = 1.3
	flashlight.shadow_enabled = false
	gun.add_child(flashlight)
	setup_muzzle_flash()
	stabilize_viewmodel(gun)

# An eight-sided cross section gives bevels real geometry rather than painted edges.
func weapon_part(parent: Node3D, pos: Vector3, size: Vector3, bevel: float, color: Color, metal: float) -> MeshInstance3D:
	var x := size.x * 0.5
	var y := size.y * 0.5
	var z := size.z * 0.5
	var rim: Array[Vector2] = [Vector2(-x+bevel,-y),Vector2(x-bevel,-y),Vector2(x,-y+bevel),Vector2(x,y-bevel),Vector2(x-bevel,y),Vector2(-x+bevel,y),Vector2(-x,y-bevel),Vector2(-x,-y+bevel)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a := rim[i]
		var b := rim[(i+1)%8]
		var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
		for v in [Vector3(a.x,a.y,-z),Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(a.x,a.y,-z),Vector3(b.x,b.y,z),Vector3(b.x,b.y,-z)]:
			surface.set_normal(normal)
			surface.add_vertex(v)
		for v in [Vector3(0,0,-z),Vector3(a.x,a.y,-z),Vector3(b.x,b.y,-z)]:
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(v)
		for v in [Vector3(0,0,z),Vector3(b.x,b.y,z),Vector3(a.x,a.y,z)]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(v)
	var part := MeshInstance3D.new()
	part.mesh = surface.commit()
	var finish := material(color)
	finish.metallic = metal
	finish.roughness = 0.38 if metal > 0.4 else 0.82
	part.material_override = finish
	parent.add_child(part)
	part.position = pos
	return part

func gun_cylinder(pos: Vector3, radius: float, length: float, color: Color) -> void:
	var part := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 24
	part.mesh = cylinder
	part.material_override = material(color)
	part.material_override.metallic = 0.5
	part.material_override.roughness = 0.45
	gun.add_child(part)
	part.position = pos
	part.rotation.x = PI/2

func stabilize_viewmodel(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if child.material_override is StandardMaterial3D:
				child.material_override.disable_receive_shadows = true
		stabilize_viewmodel(child)

func label_at(text: String, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("dcebe9"))
	hud.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.65))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color(0.03,0.04,0.04,0.8))
	label.add_theme_constant_override("outline_size", 3)
	return label

func setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	wave_label = label_at("",Vector2.ZERO,Vector2(400,48),30)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label = label_at("",Vector2.ZERO,Vector2(400,32),16)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = health
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.size = Vector2(300,28)
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("17232e")
	health_background.set_corner_radius_all(6)
	health_background.set_border_width_all(2)
	health_background.border_color = Color("61717c")
	health_bar.add_theme_stylebox_override("background", health_background)
	health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color("41d6a0")
	health_fill.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	hud.add_child(health_bar)
	health_label = label_at("",Vector2.ZERO,Vector2(300,28),16)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_label = label_at("",Vector2.ZERO,Vector2(300,60),38)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label = label_at("",Vector2(28,26),Vector2(280,60),30)
	crosshair = Control.new()
	crosshair.set_script(preload("res://reticle.gd"))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	hit_marker = Control.new()
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker.draw.connect(draw_hit_marker)
	hud.add_child(hit_marker)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(shade)
	pause_panel = VBoxContainer.new()
	pause_panel.add_theme_constant_override("separation",18)
	hud.add_child(pause_panel)
	pause_title = Label.new()
	pause_title.add_theme_font_size_override("font_size",32)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel.add_child(pause_title)
	resume_button = Button.new()
	resume_button.text = "Reprendre"
	resume_button.custom_minimum_size = Vector2(380,48)
	resume_button.pressed.connect(func(): set_paused(false))
	pause_panel.add_child(resume_button)
	var restart := Button.new()
	restart.text = "Nouvelle partie"
	restart.custom_minimum_size.y = 48
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	pause_panel.add_child(restart)
	var quit := Button.new()
	quit.text = "Quitter"
	quit.custom_minimum_size.y = 48
	quit.pressed.connect(func(): get_tree().quit())
	pause_panel.add_child(quit)
	pause_panel.hide()
	for label in [wave_label, ammo_label, score_label, pause_title, health_label]:
		label.add_theme_font_override("font", display_font)
	setup_upgrades_hud()
	setup_controls_popup()

func ui_style(background: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func setup_controls_popup() -> void:
	controls_panel = PanelContainer.new()
	var panel_style := ui_style(Color("172022"), Color("59605b"), 16)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 20
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 26
	panel_style.content_margin_bottom = 26
	controls_panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(controls_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	controls_panel.add_child(content)
	var eyebrow := Label.new()
	eyebrow.text = "AVANT DE JOUER"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color("d9b57b"))
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "Prenez les commandes"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_font_override("font", display_font)
	title.add_theme_color_override("font_color", Color("f0f5fa"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Une vague terminée = 1 point. Icônes dorées : amélioration disponible.\n1 : dégâts · 2 : cadence · 3 : santé\n4 : déplacement · 5 : chargeur. Cinq niveaux par amélioration."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.x = 420
	subtitle.add_theme_color_override("font_color", Color("a8b1aa"))
	content.add_child(subtitle)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	content.add_child(grid)
	var commands := [
		["WASD", "Se déplacer"],
		["Clic gauche", "Tirer (maintenir)"], ["R", "Recharger"],
		["Maj", "Courir"], ["Espace", "Sauter"],
		["Échap", "Pause"], ["F11", "Plein écran / fenêtre"]
	]
	for command in commands:
		var keys := VBoxContainer.new()
		keys.add_theme_constant_override("separation", 2)
		grid.add_child(keys)
		if command[0] == "WASD":
			var top_row := HBoxContainer.new()
			top_row.add_theme_constant_override("separation", 3)
			keys.add_child(top_row)
			var spacer := Control.new()
			spacer.custom_minimum_size.x = 42
			top_row.add_child(spacer)
			top_row.add_child(make_keycap("W", 42))
			var bottom_row := HBoxContainer.new()
			bottom_row.add_theme_constant_override("separation", 3)
			keys.add_child(bottom_row)
			for letter in ["A", "S", "D"]:
				bottom_row.add_child(make_keycap(letter, 42))
		elif command[0] == "Clic gauche":
			var mouse_row := HBoxContainer.new()
			keys.add_child(mouse_row)
			var mouse_icon := Control.new()
			mouse_icon.set_script(preload("res://mouse_icon.gd"))
			mouse_icon.custom_minimum_size = Vector2(42, 52)
			mouse_icon.tooltip_text = "Maintenir le clic gauche : tir automatique"
			mouse_row.add_child(mouse_icon)
		else:
			var row := HBoxContainer.new()
			keys.add_child(row)
			row.add_child(make_keycap(command[0], 42 if command[0] == "R" else (108 if command[0] in ["Espace", "Échap"] else 70)))
		var action_label := Label.new()
		action_label.text = command[1]
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.add_theme_font_size_override("font_size", 17)
		action_label.add_theme_color_override("font_color", Color("d5dfe8"))
		grid.add_child(action_label)
	controls_ok = Button.new()
	controls_ok.text = "OK"
	controls_ok.custom_minimum_size.y = 46
	controls_ok.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	controls_ok.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		var color := Color("d9b57b") if state == "normal" else (Color("efc995") if state == "hover" else Color("b59461"))
		controls_ok.add_theme_stylebox_override(state, ui_style(color, color, 8))
		controls_ok.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("23251e"))
	var focus_style := ui_style(Color.TRANSPARENT, Color("ffdfad"), 8)
	focus_style.set_border_width_all(2)
	controls_ok.add_theme_stylebox_override("focus", focus_style)
	controls_ok.pressed.connect(close_controls_popup)
	content.add_child(controls_ok)

func make_keycap(caption: String, width: float) -> Control:
	var key := Control.new()
	key.set_script(preload("res://keycap.gd"))
	key.set("caption", caption)
	key.custom_minimum_size = Vector2(width, 42)
	return key

func close_controls_popup() -> void:
	showing_controls = false
	controls_panel.hide()
	set_paused(false)

func upper_screen() -> void:
	if DisplayServer.get_name() == "headless": return
	var selected := 0
	for i in range(DisplayServer.get_screen_count()):
		var a := DisplayServer.screen_get_position(i)
		var b := DisplayServer.screen_get_position(selected)
		var sa := DisplayServer.screen_get_size(i)
		var sb := DisplayServer.screen_get_size(selected)
		if a.y < b.y or (a.y == b.y and sa.x*sa.y < sb.x*sb.y): selected = i
	DisplayServer.window_set_current_screen(selected)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(selected)+Vector2i(30,30))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not dead and not showing_controls: set_paused(not paused)
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if paused or dead: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		for i in range(upgrade_levels.size()):
			if key == KEY_1+i or event.keycode == KEY_KP_1+i:
				purchase_upgrade(i)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x*0.002)
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*0.002,-1.4,1.4)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot()
	if event.is_action_pressed("reload"): reload_gun()

func set_paused(value: bool) -> void:
	if showing_controls: return
	paused = value
	pause_panel.visible = value
	pause_title.text = "PAUSE"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func reload_gun() -> void:
	if ammo < magazine_capacity() and reload_clock <= 0: reload_clock = 1.25

func shoot() -> void:
	if shot_clock > 0 or reload_clock > 0: return
	if ammo == 0:
		reload_gun()
		return
	ammo -= 1
	shot_clock = 0.34/(1.0+0.15*upgrade_levels[1])
	recoil = 1.0
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from,from-camera.global_basis.z*80,13)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var endpoint: Vector3 = result.position if not result.is_empty() else from-camera.global_basis.z*80
	show_shot_effect(endpoint)
	if result.is_empty(): return
	var collider: Object = result.collider
	var headshot: bool = collider.get_meta("headshot",false)
	var target: Object = collider.get_meta("damage_target") if collider.has_meta("damage_target") else collider
	if is_instance_valid(target) and target.has_method("hurt") and target.health > 0:
		var base_amount: int = collider.get_meta("damage_amount",68 if headshot else 34)
		var limb_hit := base_amount == 17
		var body_damage := roundi(34*(1.0+0.2*upgrade_levels[0]))
		var amount := body_damage*2 if headshot else (roundi(body_damage*0.5) if limb_hit else body_damage)
		target.hurt(amount,collider as Area3D)
		last_headshot = headshot
		hit_clock = 0.22
		show_damage(amount, result.position, headshot, limb_hit)

func show_damage(amount: int, impact: Vector3, headshot: bool, limb_hit := false) -> void:
	var number := Label3D.new()
	number.text = str(amount)
	number.font = display_font
	number.font_size = 48
	number.outline_size = 10
	number.pixel_size = 0.006
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.modulate = Color("ff9b35") if headshot else (Color("626870") if limb_hit else Color("f0f5fa"))
	number.no_depth_test = true
	number.render_priority = 127
	number.outline_render_priority = 126
	add_child(number)
	number.global_position = impact+Vector3(rng.randf_range(-0.12,0.12),0.2,0)
	damage_numbers.append({"node": number, "age": 0.0})

func update_damage_numbers(delta: float) -> void:
	for i in range(damage_numbers.size()-1,-1,-1):
		var entry := damage_numbers[i]
		entry.age += delta
		var number: Label3D = entry.node
		number.position.y += delta*0.65
		number.modulate.a = clampf((0.85-float(entry.age))/0.35,0,1)
		if entry.age >= 0.85:
			number.queue_free()
			damage_numbers.remove_at(i)

func draw_hit_marker() -> void:
	if hit_clock <= 0 or paused or dead: return
	var color := Color("ff9b35") if last_headshot else Color("f0f5fa")
	color.a = minf(1,hit_clock/0.08)
	for x in [-1,1]:
		for y in [-1,1]:
			hit_marker.draw_line(Vector2(x*7,y*7),Vector2(x*14,y*14),color,2.5,true)

func take_damage(amount: int) -> void:
	if dead: return
	health = maxi(0,health-amount)
	damage_clock = 0.35
	if health == 0:
		dead = true
		pause_panel.show()
		resume_button.hide()
		pause_title.text = "FIN DE PARTIE\nVague %02d  ·  %d éliminations" % [wave,kills]
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func enemy_killed(enemy: CharacterBody3D) -> void:
	enemies.erase(enemy)
	kills += 1
	enemy.deactivate()
	enemy_pool.append(enemy)

func prepare_enemy() -> void:
	var enemy := CharacterBody3D.new()
	enemy.set_script(ENEMY_SCRIPT)
	enemy.set("arena",self)
	add_child(enemy)
	enemy.deactivate()
	enemy_pool.append(enemy)
	enemies_built += 1

func spawn_enemy() -> void:
	var choices := [Vector3(-16,0.1,-16),Vector3(16,0.1,-16),Vector3(-16,0.1,16),Vector3(16,0.1,16)]
	var pos: Vector3 = choices[rng.randi_range(0,3)]
	for candidate in choices:
		if candidate.distance_to(player.position) > pos.distance_to(player.position): pos = candidate
	pos += Vector3(rng.randf_range(-1.5,1.5),0,rng.randf_range(-1.5,1.5))
	if enemy_pool.is_empty(): return
	var enemy: CharacterBody3D = enemy_pool.pop_back()
	var stats := wave_settings(wave)
	enemy.activate(pos,stats.speed,stats.health,stats.damage)
	enemies.append(enemy)

func _physics_process(delta: float) -> void:
	update_shot_effects(delta)
	if paused or dead: return
	update_damage_numbers(delta)
	time_alive += delta
	shot_clock = maxf(0,shot_clock-delta)
	damage_clock = maxf(0,damage_clock-delta)
	hit_clock = maxf(0,hit_clock-delta)
	recoil = move_toward(recoil,0,delta*9)
	if reload_clock > 0:
		reload_clock = maxf(0,reload_clock-delta)
		if reload_clock == 0: ammo = magazine_capacity()
	handle_automatic_fire(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var move := Input.get_vector("left","right","forward","back")
	var direction := player.basis*Vector3(move.x,0,move.y)
	var speed := movement_speed(Input.is_action_pressed("sprint"))
	player.velocity.x = direction.x*speed
	player.velocity.z = direction.z*speed
	if not player.is_on_floor(): player.velocity.y -= 22*delta
	elif Input.is_action_just_pressed("jump"): player.velocity.y = 7
	else: player.velocity.y = -0.1
	player.move_and_slide()
	gun.position.z = -0.48+recoil*0.09
	slide.position.z = recoil * 0.055
	gun.rotation.x = recoil*0.15+(-0.6 if reload_clock > 0 else 0.0)
	if pending == 0 and enemies.is_empty():
		if wave > rewarded_wave:
			upgrade_points += 1
			rewarded_wave = wave
		intermission -= delta
		if intermission <= 0:
			wave += 1
			pending = wave_settings(wave).count
			spawn_clock = 0
			health = mini(max_health,health+20)
			ammo = magazine_capacity()
			intermission = 5
	if pending > 0:
		spawn_clock -= delta
		if spawn_clock <= 0 and not enemy_pool.is_empty() and enemies.size() < wave_settings(wave).active_limit:
			spawn_enemy()
			pending -= 1
			spawn_clock = wave_settings(wave).interval

func _process(_delta: float) -> void:
	# Build at most one reserve enemy per frame during downtime, never on spawn.
	if not dead and pending == 0 and enemies.is_empty() and enemy_pool.size() < 16:
		prepare_enemy()
	var screen := get_viewport().get_visible_rect().size
	wave_label.position = Vector2(screen.x/2-200,22)
	wave_label.text = "VAGUE  %d" % wave
	info_label.position = Vector2(screen.x/2-200,64)
	info_label.text = "PROCHAINE VAGUE DANS %d s" % ceili(intermission) if enemies.is_empty() and pending == 0 else "%d HOSTILES RESTANTS" % (enemies.size()+pending)
	health_bar.position = Vector2((screen.x-health_bar.size.x)/2,screen.y-52)
	health_bar.max_value = max_health
	health_bar.value = health
	health_fill.bg_color = Color("f16565") if health <= max_health*0.25 else (Color("efba58") if health <= max_health*0.5 else Color("41d6a0"))
	health_label.position = health_bar.position
	health_label.text = "%d / %d" % [health,max_health]
	ammo_label.position = Vector2(screen.x-330,screen.y-74)
	ammo_label.text = "%02d / %02d" % [ammo,magazine_capacity()]
	score_label.text = "%d %s" % [kills, "kill" if kills <= 1 else "kills"]
	crosshair.position = screen/2
	hit_marker.position = screen/2
	hit_marker.queue_redraw()
	crosshair.set_headshot(hit_clock > 0 and last_headshot)
	shade.color = Color(0.02,0.035,0.05,0.9) if paused or dead else Color(0.8,0.07,0.04,damage_clock*0.8)
	pause_panel.position = screen/2-Vector2(190,140)
	controls_panel.size = Vector2(minf(520,screen.x-32),controls_panel.get_combined_minimum_size().y)
	controls_panel.position = (screen-controls_panel.size)/2
	crosshair.visible = not paused and not dead
	update_upgrades_hud(screen)

func effect_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.disable_receive_shadows = true
	return mat

func setup_muzzle_flash() -> void:
	flash = Node3D.new()
	flash.name = "MuzzleFlash"
	gun.add_child(flash)
	flash.position = Vector3(0,0,-0.245)
	# Soft, irregular flame profile on crossed planes, with no opaque cube edges.
	var pixels := Image.create(64,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		var v := float(y)/127.0
		var width := 0.12 + 0.45*sin(v*PI) * (0.8+0.2*sin(v*29.0))
		for x in range(64):
			var u := absf(float(x)/63.0*2.0-1.0)
			var intensity := pow(maxf(0.0,1.0-u/width),2.0)*pow(sin(v*PI),0.7)
			var color := Color("ff8e28").lerp(Color("fff4c9"),intensity)
			color.a = intensity
			pixels.set_pixel(x,y,color)
	pixels.generate_mipmaps()
	var mat := effect_material(Color.WHITE)
	mat.albedo_texture = ImageTexture.create_from_image(pixels)
	for angle in [0.0,PI/2]:
		var pivot := Node3D.new()
		flash.add_child(pivot)
		pivot.rotation.z = angle
		var flame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22,0.38)
		flame.mesh = quad
		flame.material_override = mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(flame)
		flame.position.z = -0.16
		flame.rotation.x = PI/2
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color("ffc27b")
	muzzle_light.omni_range = 3.0
	muzzle_light.light_energy = 0.0
	muzzle_light.shadow_enabled = false
	flash.add_child(muzzle_light)
	flash.visible = false

func show_shot_effect(endpoint: Vector3) -> void:
	muzzle_clock = 0.055
	flash.visible = true
	flash.rotation.z = rng.randf()*TAU
	flash.scale = Vector3.ONE*rng.randf_range(0.85,1.15)
	muzzle_light.light_energy = 1.2
	var start := gun.to_global(Vector3(0,0,-0.245))
	# The tracer is only visual; the existing camera ray applies damage immediately.
	# Stop its muzzle-to-target path at intervening scenery as well.
	var obstruction := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,endpoint,1))
	if not obstruction.is_empty(): endpoint = obstruction.position
	var direction := endpoint-start
	if direction.length_squared() < 0.0001: return
	var across := direction.normalized().cross(camera.global_position-(start+endpoint)*0.5).normalized()
	if across.length_squared() < 0.01: across = camera.global_basis.x
	# A single streak per shot; remove any previous visual before replacement.
	for previous in tracers:
		previous.node.hide()
		previous.node.queue_free()
	tracers.clear()
	var trail := Node3D.new()
	trail.name = "HitscanTracer"
	add_child(trail)
	var materials: Array[StandardMaterial3D] = []
	for width in [0.008]:
		var mat := effect_material(Color(1.0,0.88,0.6,0.7))
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [start-across*width,start+across*width,endpoint+across*width*0.3,start-across*width,endpoint+across*width*0.3,endpoint-across*width*0.3]:
			surface.add_vertex(point)
		var ribbon := MeshInstance3D.new()
		ribbon.mesh = surface.commit()
		ribbon.material_override = mat
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.add_child(ribbon)
		materials.append(mat)
	tracers.append({"node":trail,"age":0.0,"materials":materials,"start":start,"end":endpoint})

func update_shot_effects(delta: float) -> void:
	muzzle_clock = maxf(0.0,muzzle_clock-delta)
	flash.visible = muzzle_clock > 0.0
	muzzle_light.light_energy = 1.2*muzzle_clock/0.055
	for i in range(tracers.size()-1,-1,-1):
		var trace := tracers[i]
		trace.age += delta
		var fade := clampf(1.0-float(trace.age)/0.035,0.0,1.0)
		for j in range(trace.materials.size()):
			trace.materials[j].albedo_color.a = fade*0.7
		if trace.age >= 0.035:
			trace.node.queue_free()
			tracers.remove_at(i)

func setup_upgrades_hud() -> void:
	for i in range(upgrade_levels.size()):
		var icon := Control.new()
		icon.set_script(preload("res://upgrade_icon.gd"))
		icon.set("kind",i)
		icon.size = Vector2(64,54)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(icon)
		upgrade_icons.append(icon)
		var key := make_keycap(str(i+1),42)
		key.size = Vector2(42,42)
		key.scale = Vector2(0.75,0.75)
		key.position = Vector2(16.25,-35)
		key.visible = false
		icon.add_child(key)
		upgrade_keys.append(key)
		var row := label_at("",Vector2.ZERO,Vector2(64,26),18)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_override("font",display_font)
		upgrade_rows.append(row)

func purchase_upgrade(index: int) -> bool:
	if paused or dead or showing_controls or index < 0 or index >= upgrade_levels.size(): return false
	if upgrade_points <= 0 or upgrade_levels[index] >= MAX_UPGRADE_LEVEL: return false
	upgrade_points -= 1
	upgrade_levels[index] += 1
	if index == 2:
		max_health += 20
		health = mini(max_health,health+20)
	elif index == 4:
		ammo = mini(magazine_capacity(),ammo+3)
	return true

func update_upgrades_hud(screen: Vector2) -> void:
	var columns := clampi(floori((screen.x*0.5-180)/78.0),1,upgrade_levels.size())
	var rows := ceili(float(upgrade_levels.size())/columns)
	var origin := Vector2(28,screen.y-118-(rows-1)*98)
	var visible_hud := not showing_controls and not paused and not dead
	for i in range(upgrade_levels.size()):
		var completed := upgrade_levels[i] == MAX_UPGRADE_LEVEL
		var can_buy := upgrade_points > 0 and not completed
		var icon := upgrade_icons[i]
		icon.visible = visible_hud
		icon.position = origin+Vector2((i%columns)*78,floori(float(i)/columns)*98)
		icon.set_state(can_buy,completed)
		upgrade_keys[i].visible = visible_hud and can_buy
		var row := upgrade_rows[i]
		row.visible = visible_hud
		row.position = icon.position+Vector2(0,56)
		row.text = "MAX" if completed else "%d/5" % upgrade_levels[i]
		row.modulate = Color("f0ce83") if can_buy else (Color("82b79e") if completed else Color("c5cbd0"))

func wave_settings(number: int) -> Dictionary:
	var n := maxi(number,1)
	return {
		"count": mini(60,6+3*(n-1)+floori(n/4.0)),
		"health": 100+10*maxi(0,n-2),
		"damage": mini(36,12+3*floori((n-1)/2.0)),
		"speed": minf(4.3,2.6+n*0.14),
		"interval": maxf(0.25,0.65-(n-1)*0.025),
		"active_limit": 14
	}

func handle_automatic_fire(trigger_held: bool) -> void:
	if trigger_held and not paused and not dead and not showing_controls:
		shoot()

func magazine_capacity() -> int:
	return MAGAZINE+3*upgrade_levels[4]

func movement_speed(sprinting: bool) -> float:
	return (8.0 if sprinting else 5.2)*(1.0+0.10*upgrade_levels[3])

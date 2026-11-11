extends Node2D

signal gaze_updated(position_local: Vector2, confidence: int)

var udp := PacketPeerUDP.new()
var point := Vector2.ZERO
var valid := false
var last_packet_ms := -10000
var status: Label
var received := 0

func _ready() -> void:
	_move_to_upper_screen()
	status = Label.new()
	status.position = Vector2(24, 24)
	status.add_theme_font_size_override("font_size", 22)
	add_child(status)
	var error := udp.bind(4243, "127.0.0.1")
	if error != OK:
		status.text = "Port 4243 indisponible : ferme l'autre démo Godot."
		set_process(false)
		return
	status.text = "En attente de Beam… | Échap : quitter | F11 : plein écran"
	print("BEAM_UDP_READY 127.0.0.1:4243")

func _move_to_upper_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var selected := 0
	for index in range(DisplayServer.get_screen_count()):
		var candidate_pos := DisplayServer.screen_get_position(index)
		var selected_pos := DisplayServer.screen_get_position(selected)
		var candidate_size := DisplayServer.screen_get_size(index)
		var selected_size := DisplayServer.screen_get_size(selected)
		if candidate_pos.y < selected_pos.y or (candidate_pos.y == selected_pos.y and candidate_size.x * candidate_size.y < selected_size.x * selected_size.y):
			selected = index
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(selected)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(selected) + Vector2i(40, 40))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("BEAM_SCREEN ", selected, " position=", DisplayServer.screen_get_position(selected), " taille=", DisplayServer.screen_get_size(selected))

func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var data = JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if not data is Dictionary:
			continue
		last_packet_ms = Time.get_ticks_msec()
		received += 1
		valid = bool(data.get("valid", false)) and data.has("x") and data.has("y")
		if not valid:
			status.text = "Suivi absent ou confiance faible | Échap : quitter"
			continue
		var screen := DisplayServer.window_get_current_screen()
		var origin := Vector2(DisplayServer.screen_get_position(screen))
		var screen_size := Vector2(DisplayServer.screen_get_size(screen))
		var desktop_point := Vector2(float(data.x), float(data.y))
		var normalized := (desktop_point - origin) / screen_size
		# Démo en plein écran sur l'écran calibré ; pas dans le jeu intégré à l'éditeur.
		point = normalized * get_viewport_rect().size
		valid = Rect2(Vector2.ZERO, Vector2.ONE).has_point(normalized)
		var confidence := int(data.get("confidence", 0))
		status.text = "Beam : x=%d, y=%d | confiance %d/3 | Échap : quitter" % [desktop_point.x, desktop_point.y, confidence]
		if valid:
			gaze_updated.emit(point, confidence)
		if received == 1:
			print("BEAM_PACKET_RECEIVED ", desktop_point)
	if Time.get_ticks_msec() - last_packet_ms > 500:
		valid = false
		status.text = "En attente de la passerelle Python… | Échap : quitter"
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	for y in [0.2, 0.5, 0.8]:
		for x in [0.2, 0.5, 0.8]:
			var target := size * Vector2(x, y)
			draw_circle(target, 18, Color(0.25, 0.35, 0.45), false, 2)
			draw_string(font, target + Vector2(-25, 40), "Regarde ici", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if valid:
		draw_circle(point, 12, Color(0.2, 1.0, 0.7))
		draw_circle(point, 24, Color(0.2, 1.0, 0.7, 0.5), false, 2)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _exit_tree() -> void:
	udp.close()

extends CanvasLayer

signal gather_requested
signal craft_requested
signal demolish_requested(cell: Vector2i)
signal building_requested(id: String)
signal advance_requested
signal pause_requested
signal speed_requested
signal center_requested
signal save_requested
signal load_requested
signal restart_requested
signal fullscreen_requested
signal quit_requested

const Catalog = preload("res://scripts/catalog.gd")
const Simulation = preload("res://scripts/sim.gd")
const WorldView = preload("res://scripts/world_view.gd")
const DISPLAY_FONT = preload("res://assets/ui/NotoSerifDisplay-Regular.ttf")
const ICON_PATH := "res://assets/ui/"
const GOLD := Color("#efbb76")
const LIGHT := Color("#f4e6cb")
const MUTED := Color("#b6b99e")
const GREEN := Color("#b7ce8e")
const RED := Color("#e59e88")
const PANEL := Color("#202920")
const BORDER := Color("#54604b")
const INSET := Color("#2d392c")
const ACTIVE := Color("#49432e")

var root: Control
var _resources: HBoxContainer
var _resource_values: Dictionary = {}

var _age_title: Label
var _age_goal: Label
var _goal_icon: TextureRect
var _advance: Button
var _build_list: HBoxContainer
var _earlier: Button
var _build_buttons: Dictionary = {}
var _stick: Button
var _pause: Button
var _speed_value := 1
var _context: PanelContainer
var _context_title: Label
var _context_body: Label
var _yield_badge: PanelContainer
var _yield_icon: TextureRect
var _yield_count: Label


var _toast: PanelContainer
var _toast_text: Label
var _toast_tween: Tween
var _inspection: PanelContainer
var _inspection_title: Label
var _inspection_body: Label
var _inspection_recipe: HBoxContainer
var _inspection_building := ""
var _remove_building: Button
var _overlay: Control
var _modal_content: VBoxContainer
var _modal_title: Label
var _modal_kind := ""
var _inventory_values: Dictionary = {}
var _current_age := -1
var _sim: Simulation
var _mode := "gather"
var _building_id := ""
var _inspection_cell := Vector2i(-1, -1)
var _icons: Dictionary = {}


func build(sim: Simulation) -> void:
	_sim = sim
	root = Control.new()
	root.name = "HUD"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	_build_header()
	_build_journal()
	_build_deck()
	_build_world_overlays()
	_build_modal()
	refresh(sim)


func refresh(sim: Simulation) -> void:
	_sim = sim
	if _current_age != sim.age:
		_current_age = sim.age
		_rebuild_resources()
		_rebuild_buildings()
		if _modal_kind == "inventory":
			_show_inventory()
		elif _modal_kind == "ages":
			_show_ages()
	for id in _resource_values:
		_resource_values[id].text = str(sim.resources.get(id, 0))
	for id in _inventory_values:
		_inventory_values[id].text = str(sim.resources.get(id, 0))
	_refresh_journal()
	set_mode(_mode, _building_id)
	if _inspection.visible:
		_refresh_inspection()



func set_mode(mode: String, building_id: String) -> void:
	_mode = mode
	_building_id = building_id
	_stick.visible = not _sim.tool
	for id in _build_buttons:
		_build_buttons[id].set_pressed_no_signal(mode == "build" and id == building_id)


func set_time(paused: bool, speed: int) -> void:
	_pause.icon = _icon("play" if paused else "pause")
	_pause.tooltip_text = "Reprendre (Espace)" if paused else "Mettre en pause (Espace)"
	_speed_value = speed


func set_context(title: String, body: String, good: bool = true) -> void:
	_context.visible = not title.is_empty()
	_context_title.text = title
	_context_body.text = body
	_context_body.add_theme_color_override("font_color", MUTED if good else RED)


func set_yield_preview(resource: String, amount: int) -> void:
	_yield_badge.visible = amount > 0
	if amount <= 0:
		return
	_yield_icon.texture = WorldView.resource_icon(resource)
	_yield_count.text = "+%d" % amount
	var pointer := get_viewport().get_mouse_position() + Vector2(16, 13)
	_yield_badge.position = pointer.clamp(Vector2.ZERO, (root.size - _yield_badge.size).max(Vector2.ZERO))


func inspected_cell() -> Vector2i:
	return _inspection_cell if _inspection.visible else Vector2i(-1, -1)


func select_cell(cell: Vector2i) -> void:
	_inspection_cell = cell
	_refresh_inspection()


func clear_selection() -> void:
	_inspection_cell = Vector2i(-1, -1)
	_inspection.hide()


func notify(message: String, good: bool = true) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast_text.text = message
	_toast_text.add_theme_color_override("font_color", LIGHT if good else RED)
	_toast.modulate.a = 1.0
	_toast.show()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.30)
	_toast_tween.tween_callback(_toast.hide)


func modal_open() -> bool:
	return _overlay.visible


func close_modal() -> void:
	_overlay.hide()
	_modal_kind = ""
	_inventory_values.clear()


func show_victory() -> void:
	_open_modal("victory", "L’horizon s’agrandit")
	_modal_content.add_child(_label(
		"La première mission a atteint l’orbite. Votre civilisation peut continuer à se développer dans la vallée.",
		17, MUTED, true
	))
	var button := _button("Retour à la vallée")
	button.custom_minimum_size.y = 42
	button.pressed.connect(close_modal)
	_modal_content.add_child(button)



func _build_header() -> void:
	var bar := _shell("TopBar", Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 56), PANEL, BORDER, 0)
	var row := _box(_pad(bar, 13, 4, 13, 4), false, 9)
	var identity := _box(row, false, 6)
	identity.add_child(_picture(_icon("crest"), Vector2(35, 35)))
	var brand := _display("Aube des civilisations", 19)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(brand)
	row.add_child(_separator(true))
	_resources = _box(row, false, 5)
	_resources.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	var inventory := _icon_button("bag", "Tous les stocks", "Inventory")
	inventory.pressed.connect(_show_inventory)
	row.add_child(inventory)
	_pause = _icon_button("pause", "Mettre en pause (Espace)", "Pause")
	_pause.pressed.connect(func(): pause_requested.emit())
	row.add_child(_pause)
	var menu := _icon_button("gear", "Menu de la partie", "Menu")
	menu.pressed.connect(_show_menu)
	row.add_child(menu)


func _build_journal() -> void:
	var panel := _shell("Journal", Vector4(1, 0, 1, 0), Vector4(-264, 69, -14, 69), PANEL, BORDER, 7)
	var column := _box(_pad(panel, 9, 6, 9, 7), true, 5)
	var headline := _box(column, false, 6)
	_age_title = _display("", 20)
	_age_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_age_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	headline.add_child(_age_title)
	var details := _icon_button("book", "Détails de l’objectif", "GoalDetails")
	details.custom_minimum_size = Vector2(31, 29)
	details.pressed.connect(_show_goal)
	headline.add_child(details)

	var goal_row := _box(column, false, 6)
	_goal_icon = _picture(null, Vector2(19, 19))
	_goal_icon.hide()
	goal_row.add_child(_goal_icon)
	_age_goal = _label("", 13, MUTED, true)
	_age_goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_row.add_child(_age_goal)
	_advance = _button("")
	_advance.name = "AdvanceAge"
	_advance.custom_minimum_size.y = 34
	_advance.icon = _icon("arrow")
	_advance.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_advance.add_theme_stylebox_override("normal", _style(Color("#665132"), Color("#a38352"), 5))
	_advance.add_theme_stylebox_override("hover", _style(Color("#7c623b"), GOLD, 5))
	_advance.pressed.connect(func(): advance_requested.emit())
	column.add_child(_advance)


func _build_deck() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_place(center, Vector4(0, 1, 1, 1), Vector4(14, -89, -14, -13))
	var deck := PanelContainer.new()
	deck.name = "Deck"
	deck.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 7))
	center.add_child(deck)
	var row := _box(_pad(deck, 3, 3, 3, 3), false, 6)
	_build_list = _box(row, false, 6)
	_build_list.name = "BuildingList"
	_stick = _icon_button("stick", "", "CraftStick")
	_stick.custom_minimum_size = Vector2(42, 42)
	_stick.tooltip_text = "Bâton de fouille · %d bois\nBuissons récoltés plus vite · %d → %d vivres" % [
		Catalog.TOOL_COST.wood, Catalog.FOOD_HAND_YIELD, Catalog.FOOD_TOOL_YIELD,
	]
	_stick.pressed.connect(func(): craft_requested.emit())
	row.add_child(_stick)
	_earlier = _button("Âges précédents")
	_earlier.name = "EarlierBuildings"
	_earlier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_earlier.custom_minimum_size.y = 42
	_earlier.pressed.connect(_show_earlier_buildings)
	row.add_child(_earlier)


func _build_world_overlays() -> void:
	_inspection = _shell("Inspection", Vector4(0, 0, 0, 0), Vector4(14, 69, 310, 69), PANEL, BORDER, 6)
	var detail := _box(_pad(_inspection, 8, 6, 8, 8), true, 6)
	var caption := _box(detail, false, 4)
	_inspection_title = _display("", 18)
	_inspection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.add_child(_inspection_title)
	_remove_building = _icon_button("hammer", "Démolir ce bâtiment", "Demolish")
	_remove_building.custom_minimum_size = Vector2(30, 27)
	_remove_building.pressed.connect(func(): demolish_requested.emit(_inspection_cell))
	caption.add_child(_remove_building)
	var dismiss := _button("×")
	dismiss.custom_minimum_size = Vector2(29, 27)
	dismiss.pressed.connect(clear_selection)
	caption.add_child(dismiss)
	_inspection_recipe = _box(detail, false, 4)
	_inspection_recipe.name = "ProductionRecipe"
	_inspection_body = _label("", 13, MUTED, true)
	detail.add_child(_inspection_body)
	_inspection.hide()

	_context = _shell("Placement", Vector4(0.5, 1, 0.5, 1), Vector4(-236, -147, 236, -93), PANEL, BORDER, 5)
	_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var placement := _box(_pad(_context, 7, 2, 4, 2), false, 6)
	var hint := _box(placement, true, 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context_title = _label("", 13, LIGHT)
	hint.add_child(_context_title)
	_context_body = _label("", 12, MUTED)
	_context_body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.add_child(_context_body)
	var cancel := _button("×")
	cancel.custom_minimum_size = Vector2(30, 28)
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.tooltip_text = "Annuler le placement"
	cancel.pressed.connect(func(): gather_requested.emit())
	placement.add_child(cancel)
	_context.hide()

	_yield_badge = _shell("HarvestYield", Vector4.ZERO, Vector4(0, 0, 60, 32), PANEL, BORDER, 5)
	_yield_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var yield_row := _box(_yield_badge, false, 3)
	yield_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_yield_count = _label("", 14, LIGHT)
	_yield_count.name = "YieldAmount"
	yield_row.add_child(_yield_count)
	_yield_icon = _picture(null, Vector2(19, 19))
	_yield_icon.name = "YieldIcon"
	yield_row.add_child(_yield_icon)
	_yield_badge.hide()

	_toast = _shell("Toast", Vector4(0.5, 0, 0.5, 0), Vector4(-201, 70, 201, 70), Color("#303c2e"), BORDER, 5)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_text = _label("", 14, LIGHT, true)
	_toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad(_toast, 10, 5, 10, 5).add_child(_toast_text)
	_toast.hide()


func _build_modal() -> void:
	_overlay = Control.new()
	_overlay.name = "Modal"
	root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("#101810b8")
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_modal()
	)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 490
	panel.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 7))
	center.add_child(panel)
	var column := _box(_pad(panel, 19, 16, 19, 18), true, 12)
	var row := _box(column, false, 12)
	_modal_title = _display("", 27)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_modal_title)
	var close := _button("×")
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(close_modal)
	row.add_child(close)
	column.add_child(_separator())
	_modal_content = _box(column, true, 8)
	_overlay.hide()


func _open_modal(kind: String, title: String) -> void:
	_modal_kind = kind
	_inventory_values.clear()
	_clear(_modal_content)
	_modal_title.text = title
	_overlay.show()



func _show_menu() -> void:
	_open_modal("menu", "Partie")
	var actions := _box(_modal_content, false, 7)
	_menu_action(actions, "Vitesse · %d×" % _speed_value, func():
		speed_requested.emit()
		_show_menu()
	)
	_menu_action(actions, "Centrer le camp", func():
		close_modal()
		center_requested.emit()
	).name = "CenterCamera"
	var fullscreen := get_window().mode == Window.MODE_FULLSCREEN
	_menu_action(actions, "Mode fenêtré" if fullscreen else "Plein écran", func():
		fullscreen_requested.emit()
		_show_menu()
	)
	_menu_button("Sauvegarder", func():
		close_modal()
		save_requested.emit()
	)
	_menu_button("Recharger la sauvegarde", func():
		close_modal()
		load_requested.emit()
	)
	_menu_button("Chronologie des âges", _show_ages).name = "Timeline"
	_menu_button("Nouvelle partie", _confirm_restart)
	_menu_button("Quitter", func(): quit_requested.emit())
	_modal_content.add_child(_separator())
	_modal_content.add_child(_label("WASD / ZQSD · Déplacer    |    Molette · Zoom\nClic droit / Échap · Annuler    |    Espace · Pause    |    F11 · Plein écran", 12, MUTED))


func _confirm_restart() -> void:
	_open_modal("restart", "Repartir de l’aube ?")
	_modal_content.add_child(_label("La nouvelle partie remplacera la sauvegarde actuelle.", 15, MUTED, true))
	_menu_button("Revenir au menu", _show_menu)
	_menu_button("Commencer une nouvelle partie", func():
		close_modal()
		restart_requested.emit()
	)



func _menu_button(title: String, action: Callable) -> Button:
	return _menu_action(_modal_content, title, action)


func _menu_action(parent: Control, title: String, action: Callable) -> Button:
	var button := _button(title)
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _show_goal() -> void:
	var age: Dictionary = Catalog.AGES[_sim.age]
	_open_modal("goal", age.name)
	_modal_content.add_child(_label(age.goal, 15, MUTED, true))
	for id in age.buildings:
		_goal_detail(WorldView.building_icon(id), Catalog.BUILDINGS[id].name, _sim.count_buildings(id), age.buildings[id])
	for id in age.cost:
		_goal_detail(WorldView.resource_icon(id), Catalog.RESOURCES[id].name, _sim.resources[id], age.cost[id])
	if not _sim.won:
		_modal_content.add_child(_label("Les stocks sont utilisés au changement d’âge.", 12, MUTED))


func _goal_detail(icon: Texture2D, title: String, amount: int, needed: int) -> void:
	var row := _box(_modal_content, false, 8)
	row.add_child(_picture(icon, Vector2(24, 24)))
	var name_label := _label(title, 14, LIGHT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var complete := amount >= needed or _sim.won
	row.add_child(_label("%d / %d" % [needed if complete else amount, needed], 14, GREEN if complete else MUTED))


func _show_earlier_buildings() -> void:
	_open_modal("buildings", "Bâtiments des âges précédents")
	var scroll := _scroll(_modal_content, false)
	scroll.custom_minimum_size.y = 338
	var list := _box(scroll, true, 5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for age in range(_sim.age - 1, -1, -1):
		list.add_child(_label(Catalog.AGES[age].name, 13, GOLD))
		for id in Catalog.BUILDINGS:
			var item: Dictionary = Catalog.BUILDINGS[id]
			if id == "camp" or item.age != age:
				continue
			var button := _menu_action(list, item.name, func():
				close_modal()
				building_requested.emit(id)
			)
			button.name = "Earlier_" + id
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon = WorldView.building_icon(id)
			button.tooltip_text = _building_tooltip(item)


func _show_inventory() -> void:
	_open_modal("inventory", "Stocks de la vallée")
	var scroll := _scroll(_modal_content, false)
	scroll.custom_minimum_size.y = 310
	var inventory := GridContainer.new()
	inventory.columns = 2
	inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory.add_theme_constant_override("h_separation", 10)
	inventory.add_theme_constant_override("v_separation", 6)
	scroll.add_child(inventory)
	for id in Catalog.RESOURCES:
		var data: Dictionary = Catalog.RESOURCES[id]
		if data.age > _sim.age:
			continue
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", _style(INSET, Color("#485542"), 4))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory.add_child(tile)
		var row := _box(_pad(tile, 7, 5, 9, 5), false, 6)
		row.add_child(_picture(WorldView.resource_icon(id), Vector2(22, 22)))
		var title := _label(data.name, 13, MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var amount := _label(str(_sim.resources.get(id, 0)), 15, LIGHT)
		row.add_child(amount)
		_inventory_values[id] = amount


func _show_ages() -> void:
	_open_modal("ages", "Chronologie")
	for index in Catalog.AGES.size():
		var age: Dictionary = Catalog.AGES[index]
		var panel := PanelContainer.new()
		var active: bool = index == _sim.age
		panel.add_theme_stylebox_override("panel", _style(ACTIVE if active else INSET, GOLD if active else BORDER, 4))
		_modal_content.add_child(panel)
		var row := _box(_pad(panel, 8, 4, 12, 4), false, 7)
		var marker := _picture(_icon("check" if index < _sim.age or _sim.won else "pending"), Vector2(22, 22))
		row.add_child(marker)
		var title := _label(age.name, 15, LIGHT if index <= _sim.age else MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		if active:
			row.add_child(_label("Âge actuel", 12, GOLD))



func _rebuild_resources() -> void:
	_clear(_resources)
	_resource_values.clear()
	for id in Catalog.RESOURCES:
		var data: Dictionary = Catalog.RESOURCES[id]
		if data.age != 0 and data.age != _current_age:
			continue
		var chip := PanelContainer.new()
		chip.tooltip_text = data.name
		chip.custom_minimum_size = Vector2(56, 34)
		chip.add_theme_stylebox_override("panel", _style(INSET, Color("#485442"), 5))
		_resources.add_child(chip)
		var row := _box(chip, false, 3)
		row.add_child(_picture(WorldView.resource_icon(id), Vector2(20, 20)))
		var count := _label("0", 14, LIGHT)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
		_resource_values[id] = count


func _rebuild_buildings() -> void:
	_clear(_build_list)
	_build_buttons.clear()
	_earlier.visible = _current_age > 0
	for id in Catalog.BUILDINGS:
		var item: Dictionary = Catalog.BUILDINGS[id]
		if id != "camp" and item.age == _current_age:
			_building_card(id, item)


func _building_card(id: String, item: Dictionary) -> void:
	var card := _button("")
	card.name = "Build_" + id
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(151, 57)
	card.tooltip_text = _building_tooltip(item)
	card.pressed.connect(func(): building_requested.emit(id))
	_build_buttons[id] = card
	_build_list.add_child(card)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	_place(content, Vector4(0, 0, 1, 1), Vector4(4, 4, -4, -4))
	content.add_child(_picture(WorldView.building_icon(id), Vector2(34, 36)))
	var info := _box(content, true, 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := _label(item.name, 11, LIGHT, true)
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title)
	var output := _box(info, false, 2)
	if item.output.is_empty():
		var purpose := "Passage d’âge" if id == "shelter" else "Mission orbitale"
		output.add_child(_label(purpose, 10, MUTED))
	else:
		_add_quantities(output, item.output, true, 13)
		output.add_child(_label("/ cycle", 10, MUTED))


func _building_tooltip(item: Dictionary) -> String:
	var lines := PackedStringArray([item.name, item.description])
	if not item.cost.is_empty():
		lines.append("Coût · " + _stock_text(item.cost))
	if not item.deposit.is_empty():
		lines.append("À poser sur un site marqué · " + str(Catalog.RESOURCES[item.deposit].name))
	if not item.output.is_empty():
		var recipe := _stock_text(item.output)
		if not item.input.is_empty():
			recipe = _stock_text(item.input) + " → " + recipe
		lines.append("Par cycle · " + recipe)
	return "\n".join(lines)



func _refresh_journal() -> void:
	var age: Dictionary = Catalog.AGES[_current_age]
	_age_title.text = age.name
	_goal_icon.hide()
	var ready := _sim.advance_reason().is_empty()
	_advance.visible = ready
	_advance.text = "Passer à l’âge suivant" if _current_age < Catalog.AGES.size() - 1 else "Lancer la mission orbitale"
	_age_goal.visible = not ready
	if _sim.won:
		_age_goal.text = "Mission accomplie"
		return
	if ready:
		return
	for id in age.buildings:
		if _sim.count_buildings(id) >= age.buildings[id]:
			continue
		if _current_age == 0 and not _sim.can_afford(Catalog.BUILDINGS[id].cost):
			_age_goal.text = "Cliquez sur les arbres et les rochers pour récolter."
		else:
			_goal_icon.texture = WorldView.building_icon(id)
			_goal_icon.show()
			_age_goal.text = "À construire · " + str(Catalog.BUILDINGS[id].name)
		return
	for id in age.cost:
		var missing: int = age.cost[id] - _sim.resources[id]
		if missing > 0:
			_goal_icon.texture = WorldView.resource_icon(id)
			_goal_icon.show()
			_age_goal.text = "Encore %d · %s" % [missing, Catalog.RESOURCES[id].name]
			return


func _refresh_inspection() -> void:
	var id: String = _sim.buildings.get(_inspection_cell, "")
	if id.is_empty():
		clear_selection()
		return
	var building: Dictionary = Catalog.BUILDINGS[id]
	_inspection_title.text = building.name
	_remove_building.visible = _inspection_cell != _sim.camp
	if id != _inspection_building:
		_inspection_building = id
		_clear(_inspection_recipe)
		_inspection_recipe.visible = not building.output.is_empty()
		if not building.output.is_empty():
			if not building.input.is_empty():
				_add_quantities(_inspection_recipe, building.input, false, 17)
				_inspection_recipe.add_child(_label("→", 14, MUTED))
			_add_quantities(_inspection_recipe, building.output, true, 17)
			_inspection_recipe.add_child(_label("/ cycle", 12, MUTED))
	var status := _sim.production_status(_inspection_cell)
	if building.output.is_empty():
		status = building.description
		if id == "shelter":
			status = "Permet de passer au Néolithique."
		elif id == "camp":
			status = "Le villageois rapporte ses récoltes ici."
	var color := GREEN if _sim.production_state(_inspection_cell) == "working" else MUTED
	_inspection_body.add_theme_color_override("font_color", color)
	_inspection_body.text = status
	_inspection.show()


func _add_quantities(row: HBoxContainer, resources: Dictionary, show_gain: bool, icon_size: int) -> void:
	for resource in resources:
		var amount := "+%d" % resources[resource] if show_gain else str(resources[resource])
		row.add_child(_label(amount, 11 if icon_size < 15 else 13, GREEN if show_gain else LIGHT))
		row.add_child(_picture(WorldView.resource_icon(resource), Vector2.ONE * icon_size))


func _stock_text(stock: Dictionary) -> String:
	var values := PackedStringArray()
	for id in stock:
		values.append("%s ×%d" % [Catalog.RESOURCES[id].name, stock[id]])
	return ", ".join(values)





func _shell(node_name: String, anchors: Vector4, offsets: Vector4, fill: Color, border: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _style(fill, border, radius))
	root.add_child(panel)
	_place(panel, anchors, offsets)
	return panel


func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _button(title: String) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _icon_button(id: String, tooltip: String, node_name: String) -> Button:
	var button := _button("")
	button.name = node_name
	button.icon = _icon(id)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.custom_minimum_size = Vector2(38, 38)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tooltip
	return button


func _label(title: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _display(title: String, font_size: int) -> Label:
	var label := _label(title, font_size, LIGHT)
	label.add_theme_font_override("font", DISPLAY_FONT)
	return label


func _box(parent: Control, vertical: bool, separation: int) -> BoxContainer:
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


func _pad(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _separator(vertical: bool = false) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color("#465040")
	line.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _picture(texture: Texture2D, extent: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = extent
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = load(ICON_PATH + id + ".png")
	return _icons[id]


func _scroll(parent: Control, horizontal: bool) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal else ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _style(fill: Color, line: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(5)
	return style


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_stylebox("normal", "Button", _style(INSET, BORDER, 4))
	theme.set_stylebox("hover", "Button", _style(Color("#3a4937"), Color("#82936c"), 4))
	theme.set_stylebox("pressed", "Button", _style(ACTIVE, GOLD, 4))
	theme.set_stylebox("hover_pressed", "Button", _style(ACTIVE, GOLD, 4))
	theme.set_stylebox("disabled", "Button", _style(Color("#263025"), Color("#47523f"), 4))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", LIGHT)
	theme.set_color("font_hover_color", "Button", LIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("#929780"))
	theme.set_constant("icon_max_width", "Button", 22)
	theme.set_stylebox("panel", "TooltipPanel", _style(Color("#263125"), BORDER, 4))
	theme.set_color("font_color", "TooltipLabel", LIGHT)
	var scrollbar := _style(Color("#263025"), Color("#263025"), 1)
	scrollbar.set_content_margin_all(3)
	var grabber := _style(Color("#647055"), Color("#647055"), 1)
	grabber.set_content_margin_all(2)
	for scroll_class in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", scroll_class, scrollbar)
		theme.set_stylebox("grabber", scroll_class, grabber)
		theme.set_stylebox("grabber_highlight", scroll_class, grabber)
		theme.set_stylebox("grabber_pressed", scroll_class, grabber)
	return theme

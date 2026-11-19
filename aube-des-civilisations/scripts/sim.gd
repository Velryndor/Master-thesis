extends RefCounted

const Catalog := preload("res://scripts/catalog.gd")
const WorldLayout := preload("res://scripts/world_layout.gd")
const SAVE_VERSION := 3
const WORKER_SPEED := 5.0
const NO_TARGET := Vector2i(-1, -1)

var age: int = 0
var tool: bool = false
var won: bool = false
var ticks: int = 0
var resources: Dictionary = {}
var buildings: Dictionary = {}
var terrain: Dictionary = {}
var deposits: Dictionary = {}
var sites: Dictionary = {}
var map_size: Vector2i = Vector2i.ZERO
var camp: Vector2i = Vector2i.ZERO
var gather_orders: Array[Vector2i] = []
var worker_position := Vector2.ZERO
var worker_state := "idle"
var worker_target := NO_TARGET
var worker_resource := ""
var worker_uses_tool: bool:
	get:
		return worker_resource == "food" and _order_amounts.get(worker_target) == Catalog.FOOD_TOOL_YIELD
var worker_work_progress: float:
	get:
		return clampf(_worker_elapsed / _phase_duration(), 0.0, 1.0) if worker_state == "working" else 0.0

# An empty reason records a successful production cycle.
var _last_production: Dictionary = {}
var _started_producers: Dictionary = {}
var _pathfinder: AStarGrid2D
var _route_cache: Dictionary = {}
var _worker_path: Array[Vector2i] = []
var _worker_distances := PackedFloat64Array()
var _worker_elapsed := 0.0
var _order_amounts: Dictionary = {}
var _reserved: Dictionary = {}


func new_game() -> void:
	var layout: Dictionary = WorldLayout.generate()
	terrain = layout.terrain
	sites = layout.deposits
	deposits = sites.duplicate()
	map_size = layout.map_size
	camp = layout.camp_cell
	age = 0
	tool = false
	won = false
	ticks = 0
	resources = {}
	for resource_id in Catalog.RESOURCES:
		resources[resource_id] = 0
	buildings = {camp: "camp"}
	_last_production.clear()
	_started_producers.clear()
	_pathfinder = _make_pathfinder(AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES)
	_route_cache.clear()
	gather_orders.clear()
	_order_amounts.clear()
	_reserved.clear()
	_begin_order()


func can_afford(cost: Dictionary) -> bool:
	for resource_id in cost:
		if resources.get(resource_id, 0) < cost[resource_id]:
			return false
	return true


func count_buildings(id: String) -> int:
	var count: int = 0
	for building_id in buildings.values():
		if building_id == id:
			count += 1
	return count


func gather_reason(cell: Vector2i) -> String:
	if _order_amounts.has(cell):
		return "Cette récolte est déjà prévue."
	if not deposits.has(cell):
		if sites.has(cell):
			return "La ressource de surface a déjà été récoltée."
		return "Il n'y a rien à récolter ici."
	if buildings.has(cell):
		return "Ce gisement est déjà exploité par un bâtiment."
	var resource_id: String = deposits[cell]
	var resource: Dictionary = Catalog.RESOURCES[resource_id]
	if resource.age > age:
		return "Cette ressource devient exploitable à l'époque « %s »." % Catalog.AGES[resource.age].name
	if _route_to(cell).is_empty():
		return "Le villageois ne peut pas atteindre cette case."
	if _gather_yield(resource_id, tool) > _free_stock(resource_id):
		return "Il manque de la place pour cette récolte dans le stock de %s." % resource.name.to_lower()
	return ""


func gather_amount(cell: Vector2i) -> int:
	if not gather_reason(cell).is_empty():
		return 0
	return _gather_yield(deposits[cell], tool)


func gather(cell: Vector2i) -> bool:
	var amount := gather_amount(cell)
	if amount == 0:
		return false
	var resource_id: String = deposits[cell]
	gather_orders.append(cell)
	_order_amounts[cell] = amount
	_reserved[resource_id] = _reserved.get(resource_id, 0) + amount
	if worker_state == "idle":
		_begin_order()
	return true


func update_harvest(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while delta > 0.0 and worker_state != "idle":
		var time_remaining := _phase_duration() - _worker_elapsed
		if delta < time_remaining:
			_worker_elapsed += delta
			_update_worker_position()
			break
		delta -= time_remaining
		_worker_elapsed = 0.0
		match worker_state:
			"outbound":
				worker_state = "working"
			"working":
				deposits.erase(worker_target)
				events.append(_harvest_event("harvested"))
				worker_state = "returning"
			"returning":
				var amount: int = _order_amounts[worker_target]
				_reserved[worker_resource] -= amount
				_add(worker_resource, amount)
				events.append(_harvest_event("deposited"))
				_order_amounts.erase(worker_target)
				gather_orders.pop_front()
				_begin_order()
		_update_worker_position()
	return events


func craft_reason() -> String:
	if tool:
		return "Le bâton de fouille est déjà fabriqué."
	return _stock_shortage(Catalog.TOOL_COST)


func craft() -> bool:
	if not craft_reason().is_empty():
		return false
	_spend(Catalog.TOOL_COST)
	tool = true
	return true


func place_reason(id: String, cell: Vector2i) -> String:
	if not Catalog.BUILDINGS.has(id) or id == "camp":
		return "Ce bâtiment ne peut pas être construit."
	var definition: Dictionary = Catalog.BUILDINGS[id]
	if definition.age > age:
		return "Ce bâtiment se débloque à l'époque « %s »." % Catalog.AGES[definition.age].name
	if buildings.has(cell):
		return "Cette case est déjà occupée."
	if _order_amounts.has(cell) and deposits.has(cell):
		return "Attendez que le villageois ait récolté cette ressource."
	var terrain_reason := _terrain_reason(definition, cell, deposits)
	if not terrain_reason.is_empty():
		return terrain_reason
	return _stock_shortage(definition.cost)


func place(id: String, cell: Vector2i) -> bool:
	if not place_reason(id, cell).is_empty():
		return false
	_spend(Catalog.BUILDINGS[id].cost)
	buildings[cell] = id
	return true


func demolish_reason(cell: Vector2i) -> String:
	if not buildings.has(cell):
		return "Il n'y a aucun bâtiment sur cette case."
	if cell == camp:
		return "Le campement d'origine doit rester en place."
	return ""


func demolish(cell: Vector2i) -> bool:
	if not demolish_reason(cell).is_empty():
		return false
	var cost: Dictionary = Catalog.BUILDINGS[buildings[cell]].cost
	for resource_id in cost:
		_add(resource_id, floori(cost[resource_id] * 0.5))
	buildings.erase(cell)
	_last_production.erase(cell)
	_started_producers.erase(cell)
	return true


func advance_reason() -> String:
	if won:
		return "La première mission orbitale a déjà décollé."
	var objective: Dictionary = Catalog.AGES[age]
	for building_id in objective.buildings:
		if count_buildings(building_id) < objective.buildings[building_id]:
			return "Construisez le bâtiment « %s »." % Catalog.BUILDINGS[building_id].name
	return _stock_shortage(objective.cost)


func advance() -> bool:
	if not advance_reason().is_empty():
		return false
	_spend(Catalog.AGES[age].cost)
	if age == Catalog.AGES.size() - 1:
		won = true
	else:
		age += 1
	return true


func tick() -> Array[Dictionary]:
	ticks += 1
	var events: Array[Dictionary] = []
	var cells_by_building: Dictionary = {}
	for cell in buildings:
		var id: String = buildings[cell]
		if not cells_by_building.has(id):
			cells_by_building[id] = []
		cells_by_building[id].append(cell)

	for id in Catalog.BUILDINGS:
		var definition: Dictionary = Catalog.BUILDINGS[id]
		if definition.output.is_empty() or not cells_by_building.has(id):
			continue
		for cell in cells_by_building[id]:
			if _produce(cell, definition):
				events.append({
					"cell": cell, "output": definition.output.duplicate(), "started": not _started_producers.has(cell),
				})
				_started_producers[cell] = true
	return events


func production_state(cell: Vector2i) -> String:
	if not buildings.has(cell):
		return ""
	var definition: Dictionary = Catalog.BUILDINGS[buildings[cell]]
	if definition.output.is_empty():
		return "service"
	if not _last_production.has(cell):
		return "waiting"
	return "working" if _last_production[cell].is_empty() else "blocked"


func production_status(cell: Vector2i) -> String:
	match production_state(cell):
		"service":
			return "En service"
		"waiting":
			return "En attente du prochain cycle"
		"working":
			return "En production"
		"blocked":
			return _last_production[cell]
	return ""


func export_state() -> Dictionary:
	var placements: Array = []
	for cell in buildings:
		placements.append({"x": cell.x, "y": cell.y, "id": buildings[cell]})
	var depleted: Array = []
	for cell in sites:
		if not deposits.has(cell):
			depleted.append({"x": cell.x, "y": cell.y})
	var orders: Array = []
	for cell in gather_orders:
		orders.append({"x": cell.x, "y": cell.y, "amount": _order_amounts[cell]})
	return {
		"version": SAVE_VERSION, "age": age, "tool": tool, "won": won,
		"ticks": ticks, "resources": resources.duplicate(), "buildings": placements,
		"harvest": {"depleted": depleted, "orders": orders, "phase": worker_state, "elapsed": _worker_elapsed},
	}


func import_state(data: Dictionary) -> bool:
	var version: Variant = data.get("version")
	var saved_age: Variant = data.get("age")
	var saved_ticks: Variant = data.get("ticks")
	var saved_tool: Variant = data.get("tool")
	var saved_won: Variant = data.get("won")
	if not _is_whole_in_range(version, SAVE_VERSION) or version < 1:
		return false
	if not _is_whole_in_range(saved_age, Catalog.AGES.size() - 1):
		return false
	if not _is_whole_in_range(saved_ticks, 2147483647):
		return false
	if typeof(saved_tool) != TYPE_BOOL or typeof(saved_won) != TYPE_BOOL:
		return false
	if saved_won and saved_age != Catalog.AGES.size() - 1:
		return false

	var saved_resources: Variant = data.get("resources")
	if typeof(saved_resources) != TYPE_DICTIONARY:
		return false
	var loaded_resources: Dictionary = {}
	for resource_id in Catalog.RESOURCES:
		var amount: Variant = saved_resources.get(resource_id)
		if not _is_whole_in_range(amount, Catalog.STOCK_LIMIT):
			return false
		loaded_resources[resource_id] = int(amount)

	var saved_buildings: Variant = data.get("buildings")
	if typeof(saved_buildings) != TYPE_ARRAY or saved_buildings.size() > map_size.x * map_size.y:
		return false
	var loaded_buildings: Dictionary = {}
	for placement in saved_buildings:
		var cell := _saved_cell(placement)
		if cell == NO_TARGET or loaded_buildings.has(cell):
			return false
		var id: Variant = placement.get("id")
		if typeof(id) != TYPE_STRING or not Catalog.BUILDINGS.has(id):
			return false
		if (cell == camp) != (id == "camp") or Catalog.BUILDINGS[id].age > saved_age:
			return false
		loaded_buildings[cell] = id
	if not loaded_buildings.has(camp):
		return false

	var harvest := {
		"deposits": sites.duplicate(), "orders": [], "amounts": {}, "reserved": {}, "phase": "idle", "elapsed": 0.0,
	}
	if version >= 2:
		harvest = _load_harvest(data.get("harvest"), int(version), int(saved_age), saved_tool, loaded_resources, loaded_buildings)
		if harvest.is_empty():
			return false
	for cell in loaded_buildings:
		var definition: Dictionary = Catalog.BUILDINGS[loaded_buildings[cell]]
		if cell != camp and not _terrain_reason(definition, cell, harvest.deposits).is_empty():
			return false

	age = int(saved_age)
	ticks = int(saved_ticks)
	tool = saved_tool
	won = saved_won
	resources = loaded_resources
	buildings = loaded_buildings
	deposits = harvest.deposits
	gather_orders.assign(harvest.orders)
	_order_amounts = harvest.amounts
	_reserved = harvest.reserved
	_begin_order()
	worker_state = harvest.phase
	_worker_elapsed = harvest.elapsed
	_update_worker_position()
	_last_production.clear()
	_started_producers.clear()
	return true


func _load_harvest(
	data: Variant, version: int, saved_age: int, saved_tool: bool, loaded_resources: Dictionary, loaded_buildings: Dictionary
) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var saved_depleted: Variant = data.get("depleted")
	var saved_orders: Variant = data.get("orders")
	var phase: Variant = data.get("phase")
	var elapsed: Variant = data.get("elapsed")
	if typeof(saved_depleted) != TYPE_ARRAY or saved_depleted.size() > sites.size():
		return {}
	if typeof(saved_orders) != TYPE_ARRAY or saved_orders.size() > sites.size():
		return {}
	if phase not in ["idle", "outbound", "working", "returning"] or saved_orders.is_empty() != (phase == "idle"):
		return {}
	if typeof(elapsed) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	if not is_finite(elapsed) or elapsed < 0.0 or (phase == "idle" and elapsed != 0.0):
		return {}

	var loaded_deposits := sites.duplicate()
	for entry in saved_depleted:
		var cell := _saved_cell(entry)
		if not loaded_deposits.has(cell) or Catalog.RESOURCES[sites[cell]].age > saved_age:
			return {}
		loaded_deposits.erase(cell)
	var orders: Array[Vector2i] = []
	var amounts: Dictionary = {}
	var reserved: Dictionary = {}
	for entry in saved_orders:
		var cell := _saved_cell(entry)
		if not sites.has(cell) or amounts.has(cell):
			return {}
		var returning: bool = orders.is_empty() and phase == "returning"
		if loaded_deposits.has(cell) == returning or (not returning and loaded_buildings.has(cell)):
			return {}
		var resource_id: String = sites[cell]
		var path := _route_to(cell)
		if Catalog.RESOURCES[resource_id].age > saved_age or path.size() < 2:
			return {}
		var amount: Variant = entry.get("amount")
		if not _is_whole_in_range(amount, Catalog.STOCK_LIMIT):
			return {}
		if amount != _gather_yield(resource_id, false) and amount != _gather_yield(resource_id, saved_tool):
			return {}
		if orders.is_empty():
			var travel_distance: float = _cumulative_distances(path)[-1]
			var duration := _order_duration(phase, travel_distance, resource_id, int(amount))
			if version == 2 and phase != "working":
				# Version 2 stored seconds along the old cardinal route. Keep the
				# completed fraction of the trip when moving onto the new route.
				var legacy_grid := _make_pathfinder(AStarGrid2D.DIAGONAL_MODE_NEVER)
				var legacy_path := legacy_grid.get_id_path(camp, cell)
				var legacy_duration := float(legacy_path.size() - 1) / WORKER_SPEED
				if legacy_duration <= 0.0 or elapsed > legacy_duration:
					return {}
				elapsed = (float(elapsed) / legacy_duration) * duration
			elif elapsed > duration:
				return {}
		reserved[resource_id] = reserved.get(resource_id, 0) + int(amount)
		if loaded_resources[resource_id] + reserved[resource_id] > Catalog.STOCK_LIMIT:
			return {}
		orders.append(cell)
		amounts[cell] = int(amount)
	return {
		"deposits": loaded_deposits, "orders": orders, "amounts": amounts, "reserved": reserved,
		"phase": phase, "elapsed": float(elapsed),
	}


func _saved_cell(entry: Variant) -> Vector2i:
	if typeof(entry) != TYPE_DICTIONARY:
		return NO_TARGET
	var x: Variant = entry.get("x")
	var y: Variant = entry.get("y")
	if not _is_whole_in_range(x, map_size.x - 1) or not _is_whole_in_range(y, map_size.y - 1):
		return NO_TARGET
	return Vector2i(int(x), int(y))


func _gather_yield(resource_id: String, has_tool: bool) -> int:
	match resource_id:
		"wood", "stone":
			return 4
		"food":
			return Catalog.FOOD_TOOL_YIELD if has_tool else Catalog.FOOD_HAND_YIELD
	return 2


func _make_pathfinder(diagonal_mode: AStarGrid2D.DiagonalMode) -> AStarGrid2D:
	var pathfinder := AStarGrid2D.new()
	pathfinder.region = Rect2i(Vector2i.ZERO, map_size)
	pathfinder.diagonal_mode = diagonal_mode
	pathfinder.update()
	for cell in terrain:
		if terrain[cell] == "water":
			pathfinder.set_point_solid(cell)
	return pathfinder


func _route_to(cell: Vector2i) -> Array[Vector2i]:
	if not _route_cache.has(cell):
		_route_cache[cell] = _pathfinder.get_id_path(camp, cell)
	return _route_cache[cell]


func _cumulative_distances(path: Array[Vector2i]) -> PackedFloat64Array:
	var distances := PackedFloat64Array([0.0])
	for index in range(1, path.size()):
		var segment_length := sqrt(path[index - 1].distance_squared_to(path[index]))
		distances.append(distances[-1] + segment_length)
	return distances


func _begin_order() -> void:
	worker_position = Vector2(camp)
	_worker_elapsed = 0.0
	if gather_orders.is_empty():
		worker_state = "idle"
		worker_target = NO_TARGET
		worker_resource = ""
		_worker_path = []
		_worker_distances.clear()
		return
	worker_state = "outbound"
	worker_target = gather_orders[0]
	worker_resource = sites[worker_target]
	_worker_path = _route_to(worker_target)
	_worker_distances = _cumulative_distances(_worker_path)


func _order_duration(phase: String, travel_distance: float, resource_id: String, amount: int) -> float:
	if phase != "working":
		return travel_distance / WORKER_SPEED
	match resource_id:
		"wood", "stone":
			return 2.0
		"food":
			return 1.1 if amount == Catalog.FOOD_TOOL_YIELD else 1.8
	return 2.6


func _phase_duration() -> float:
	return _order_duration(worker_state, _worker_distances[-1], worker_resource, _order_amounts[worker_target])


func _update_worker_position() -> void:
	if worker_state == "idle":
		worker_position = Vector2(camp)
		return
	if worker_state == "working":
		worker_position = Vector2(worker_target)
		return
	var total_distance: float = _worker_distances[-1]
	var distance := clampf(_worker_elapsed * WORKER_SPEED, 0.0, total_distance)
	if worker_state == "returning":
		distance = total_distance - distance
	var next_index := maxi(1, _worker_distances.bsearch(distance))
	var index := next_index - 1
	var segment_start: float = _worker_distances[index]
	var segment_length: float = _worker_distances[next_index] - segment_start
	var progress := (distance - segment_start) / segment_length
	worker_position = Vector2(_worker_path[index]).lerp(Vector2(_worker_path[next_index]), progress)


func _harvest_event(event_type: String) -> Dictionary:
	return {"type": event_type, "cell": worker_target, "resource": worker_resource, "amount": _order_amounts[worker_target]}


func _terrain_reason(definition: Dictionary, cell: Vector2i, live_deposits: Dictionary) -> String:
	if not Rect2i(Vector2i.ZERO, map_size).has_point(cell):
		return "Cette case est hors de la carte."
	if terrain.get(cell) == "water":
		return "Ce bâtiment doit être construit sur la terre ferme."
	if terrain.get(cell) == "bridge":
		return "Le pont doit rester libre pour le passage."
	if not definition.deposit.is_empty() and sites.get(cell) != definition.deposit:
		return "Placez le bâtiment sur un site « %s »." % Catalog.RESOURCES[definition.deposit].name
	if definition.deposit.is_empty() and live_deposits.has(cell):
		return "Choisissez un terrain libre ou récoltez d'abord la ressource de cette case."
	return ""


func _stock_shortage(cost: Dictionary) -> String:
	var missing := PackedStringArray()
	for resource_id in cost:
		var needed: int = cost[resource_id] - resources.get(resource_id, 0)
		if needed > 0:
			missing.append("%d %s" % [needed, Catalog.RESOURCES[resource_id].name.to_lower()])
	if missing.is_empty():
		return ""
	return "Ressources manquantes (%s)." % ", ".join(missing)


func _spend(cost: Dictionary) -> void:
	for resource_id in cost:
		resources[resource_id] -= cost[resource_id]


func _add(resource_id: String, amount: int) -> void:
	resources[resource_id] += mini(amount, _free_stock(resource_id))


func _free_stock(resource_id: String) -> int:
	return Catalog.STOCK_LIMIT - resources[resource_id] - _reserved.get(resource_id, 0)


func _produce(cell: Vector2i, definition: Dictionary) -> bool:
	if not can_afford(definition.input):
		_last_production[cell] = _stock_shortage(definition.input)
		return false
	for resource_id in definition.output:
		if definition.output[resource_id] > _free_stock(resource_id):
			_last_production[cell] = "Stock plein"
			return false
	_spend(definition.input)
	for resource_id in definition.output:
		_add(resource_id, definition.output[resource_id])
	_last_production[cell] = ""
	return true


func _is_whole_in_range(value: Variant, limit: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0 and value <= limit
	if typeof(value) == TYPE_FLOAT:
		return value >= 0.0 and value <= float(limit) and value == floor(value)
	return false

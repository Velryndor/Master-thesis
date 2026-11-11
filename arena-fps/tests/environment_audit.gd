extends SceneTree

func bounds(node: Node3D) -> AABB:
	var result := AABB()
	if node is MeshInstance3D:
		result = node.global_transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := bounds(child)
			if child_bounds.has_volume():
				result = result.merge(child_bounds) if result.has_volume() else child_bounds
	return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var failures: Array[String] = []
	var props := get_nodes_in_group("city_props")
	for i in range(props.size()):
		var box := bounds(props[i])
		if absf(box.position.y-0.03) > 0.005:
			failures.append("Prop not grounded: %s at %s" % [props[i].name,box.position])
		if box.position.x < -21.45 or box.end.x > 21.45 or box.position.z < -21.45 or box.end.z > 21.45:
			failures.append("Prop intersects boundary: %s" % props[i].name)
		for j in range(i+1,props.size()):
			if box.intersects(bounds(props[j])):
				failures.append("Props overlap: %s / %s" % [props[i].name,props[j].name])
	var buildings := get_nodes_in_group("city_buildings")
	for i in range(buildings.size()):
		for j in range(i+1,buildings.size()):
			if bounds(buildings[i]).intersects(bounds(buildings[j])):
				failures.append("Building envelopes overlap: %d / %d" % [i,j])
	# Every rail must connect to the balcony assembly; exclude the host facade.
	var balconies := get_nodes_in_group("city_balconies")
	for balcony in balconies:
		var parts := balcony.get_children()
		var connected: Array[int] = [0]
		var changed := true
		while changed:
			changed = false
			for i in range(parts.size()):
				if connected.has(i): continue
				for j in connected:
					if bounds(parts[i]).grow(0.002).intersects(bounds(parts[j])):
						connected.append(i)
						changed = true
						break
		if connected.size() != parts.size(): failures.append("Detached balcony railing")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: %d props grounded and separate; %d building envelopes separate; %d connected balcony assemblies" % [props.size(),buildings.size(),balconies.size()])
	quit(0 if failures.is_empty() else 1)

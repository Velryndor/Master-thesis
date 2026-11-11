extends SceneTree

func first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.has_meta("environment_collider"): return node
	for child in node.get_children():
		var found := first_mesh(child)
		if found != null: return found
	return null

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	var failures: Array[String] = []
	var checked := 0
	for group in ["city_props", "city_buildings", "city_balconies"]:
		for assembly in get_nodes_in_group(group):
			var mesh := first_mesh(assembly)
			if mesh == null:
				failures.append("Missing collider: " + str(assembly.name))
				continue
			var box := mesh.get_aabb()
			var start := box.get_center()
			var end := start
			start.y = box.end.y + 0.15
			end.y = box.position.y - 0.15
			var query := PhysicsRayQueryParameters3D.create(mesh.to_global(start),mesh.to_global(end),1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): failures.append("Shot passes through: " + str(assembly.name))
			checked += 1
			if str(assembly.name).begins_with("Wreck"):
				# Sweep the actual player capsule from beside the vehicle into its body.
				var pose: Transform3D = game.player.global_transform
				pose.origin = assembly.to_global(Vector3(-2.2,0,0))
				var motion: Vector3 = assembly.global_basis.x * 2.2
				if not game.player.test_move(pose,motion): failures.append("Player passes through car")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: shots blocked by %d environment assemblies; player blocked by all cars" % checked)
	quit(0 if failures.is_empty() else 1)

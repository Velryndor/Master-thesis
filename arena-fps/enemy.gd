extends CharacterBody3D

static var shared_sphere: SphereMesh
static var shared_materials: Dictionary = {}
static var shared_hit_shapes: Dictionary = {}
var damage_areas: Array[Area3D] = []
static var hit_flash_material: StandardMaterial3D
var flashing_meshes: Array[MeshInstance3D] = []

var arena: Node3D
var speed := 2.5
var health := 100
var contact_damage := 12
var attack_clock := 0.0
var flash_clock := 0.0
var body_mesh: MeshInstance3D
var phase := 0.0
var legs: Array[Node3D] = []
var shoulders: Node3D
var head_pivot: Node3D
var arms: Array[Node3D] = []
var knees: Array[Node3D] = []
var torso_color := Color("504d42")

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.35
	collider.shape = shape
	collider.position.y = 0.70
	add_child(collider)
	torso_color = [Color("565248"),Color("47565a"),Color("62493e"),Color("4c5340")][randi()%4]
	var skin: Color = [Color("8b927e"),Color("999681"),Color("7e8c81")][randi()%3]
	shoulders = Node3D.new()
	shoulders.position.y = 1.02
	shoulders.rotation.x = -0.14
	add_child(shoulders)
	body_mesh = oval(shoulders,Vector3(0,0.14,0),Vector3(0.32,0.48,0.21),torso_color)
	body_mesh.material_override = body_mesh.material_override.duplicate()
	oval(shoulders,Vector3(0,0.42,0.08),Vector3(0.33,0.22,0.22),torso_color.darkened(0.15))
	oval(self,Vector3(0,0.72,0.03),Vector3(0.27,0.21,0.19),Color("303532"))
	# Open shirt, irregular hem and dark stains break up the uniform silhouette.
	arena.box(shoulders,Vector3(0,0.15,-0.207),Vector3(0.09,0.65,0.025),skin.darkened(0.35))
	for i in range(5):
		oval(shoulders,Vector3(randf_range(-0.22,0.22),randf_range(-0.1,0.4),-0.2),Vector3(0.045,0.075,0.018),Color("443330"))
		var rag: MeshInstance3D = arena.box(shoulders,Vector3(-0.24+i*0.12,-0.29,-0.05),Vector3(0.085,randf_range(0.1,0.23),0.23),torso_color.darkened(0.2))
		rag.rotation.z = randf_range(-0.18,0.18)
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0,0.63,-0.06)
	shoulders.add_child(head_pivot)
	var head_hitbox := Area3D.new()
	head_hitbox.name = "HeadHitbox"
	head_hitbox.collision_layer = 8
	head_hitbox.collision_mask = 0
	head_hitbox.monitoring = false
	head_hitbox.set_meta("damage_target", self)
	head_hitbox.set_meta("headshot", true)
	damage_areas.append(head_hitbox)
	var head_shape := CollisionShape3D.new()
	head_shape.shape = hit_shape(Vector3(0.215,0.265,0.20))
	head_shape.position.y = 0.1
	head_hitbox.add_child(head_shape)
	head_pivot.add_child(head_hitbox)
	oval(head_pivot,Vector3(0,-0.09,0.02),Vector3(0.09,0.16,0.1),skin.darkened(0.1))
	oval(head_pivot,Vector3(0,0.1,0),Vector3(0.205,0.255,0.19),skin)
	oval(head_pivot,Vector3(0,-0.04,-0.06),Vector3(0.15,0.11,0.145),skin.darkened(0.18))
	oval(head_pivot,Vector3(0,0.07,-0.187),Vector3(0.035,0.065,0.05),skin.darkened(0.12))
	oval(head_pivot,Vector3(0,-0.035,-0.187),Vector3(0.09,0.035,0.016),Color("302528"))
	for side in [-1,1]:
		oval(head_pivot,Vector3(side*0.09,0.14,-0.169),Vector3(0.065,0.052,0.04),Color("323831"))
		var eye := oval(head_pivot,Vector3(side*0.09,0.14,-0.207),Vector3(0.022,0.019,0.012),Color("d8bf7b"))
		eye.material_override = eye.material_override.duplicate()
		eye.material_override.emission_enabled = true
		eye.material_override.emission = Color("9b6c32")
		oval(head_pivot,Vector3(side*0.2,0.08,0),Vector3(0.035,0.065,0.03),skin)
		var arm := Node3D.new()
		arm.position = Vector3(side*0.31,0.4,0)
		arm.rotation.z = side*0.14
		shoulders.add_child(arm)
		arms.append(arm)
		oval(arm,Vector3(side*0.035,-0.14,0),Vector3(0.115,0.23,0.12),torso_color)
		var elbow := Node3D.new()
		elbow.position = Vector3(side*0.05,-0.32,0)
		elbow.rotation.x = -0.35
		arm.add_child(elbow)
		oval(elbow,Vector3(0,-0.14,0),Vector3(0.075,0.2,0.08),skin)
		oval(elbow,Vector3(0,-0.33,0),Vector3(0.085,0.11,0.045),skin.darkened(0.1))
		for finger in range(4):
			oval(elbow,Vector3(-0.055+finger*0.035,-0.43,-0.018),Vector3(0.012,0.07,0.016),skin.darkened(0.15))
		var leg := Node3D.new()
		leg.position = Vector3(side*0.16,0.76,0.03)
		add_child(leg)
		legs.append(leg)
		oval(leg,Vector3(0,-0.18,0),Vector3(0.13,0.25,0.14),Color("353d3a"))
		var knee := Node3D.new()
		knee.position.y = -0.38
		leg.add_child(knee)
		knees.append(knee)
		oval(knee,Vector3(0,-0.15,0),Vector3(0.095,0.21,0.105),Color("41453b"))
		oval(knee,Vector3(0,-0.31,-0.075),Vector3(0.12,0.085,0.2),Color("252a27"))
	configure_damage_regions()
	configure_shadow_receivers(self)
	phase = randf()*TAU

func configure_shadow_receivers(node: Node) -> void:
	# Small overlapping meshes produce shadow-map acne at distance, especially
	# under the flashlight. Keep their lighting and cast shadows on the street,
	# but do not sample shadow maps on these assembled character surfaces.
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		node.material_override.disable_receive_shadows = true
	for child in node.get_children():
		configure_shadow_receivers(child)

func oval(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	if shared_sphere == null:
		shared_sphere = SphereMesh.new()
		shared_sphere.radius = 1
		shared_sphere.height = 2
		shared_sphere.radial_segments = 12
		shared_sphere.rings = 8
	mesh.mesh = shared_sphere
	if not shared_materials.has(color):
		var mat: StandardMaterial3D = arena.material(color)
		mat.disable_receive_shadows = true
		shared_materials[color] = mat
	mesh.material_override = shared_materials[color]
	parent.add_child(mesh)
	mesh.position = pos
	mesh.scale = dimensions
	var belongs_to_head := head_pivot != null and (parent == head_pivot or head_pivot.is_ancestor_of(parent))
	if not belongs_to_head and maxf(dimensions.x,maxf(dimensions.y,dimensions.z)) >= 0.1:
		# Follow the same animated pivot as the visible body part.
		var area := Area3D.new()
		area.name = "BodyHitbox"
		area.collision_layer = 4
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("damage_target",self)
		area.set_meta("headshot",false)
		var collider := CollisionShape3D.new()
		collider.shape = hit_shape(dimensions)
		area.add_child(collider)
		parent.add_child(area)
		area.position = pos
		damage_areas.append(area)
	return mesh

func hit_shape(dimensions: Vector3) -> Shape3D:
	if not shared_hit_shapes.has(dimensions):
		var hull := shared_sphere.create_convex_shape()
		var points := hull.points
		for i in range(points.size()): points[i] *= dimensions
		hull.points = points
		shared_hit_shapes[dimensions] = hull
	return shared_hit_shapes[dimensions]

func hurt(amount: int, hit_area: Area3D = null) -> void:
	if health <= 0: return
	health -= amount
	clear_hit_flash()
	if hit_area != null:
		for mesh in hit_area.get_meta("flash_meshes",[]):
			mesh.material_overlay = hit_flash_material
			flashing_meshes.append(mesh)
	flash_clock = 0.12
	if health <= 0: arena.enemy_killed(self)

func _physics_process(delta: float) -> void:
	if arena.paused or arena.dead or health <= 0: return
	attack_clock = maxf(0,attack_clock-delta)
	flash_clock = maxf(0,flash_clock-delta)
	if flash_clock <= 0 and not flashing_meshes.is_empty(): clear_hit_flash()
	var offset: Vector3 = arena.player.global_position-global_position
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	if distance > 0.1: rotation.y = atan2(-direction.x,-direction.z)
	var separation := Vector3.ZERO
	for other in arena.enemies:
		if other == self: continue
		var away: Vector3 = global_position-other.global_position
		away.y = 0
		if away.length_squared() < 0.9:
			separation += away.normalized()*1.5
	var movement := direction*speed+separation if distance > 1.1 else separation
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y = -1.0 if is_on_floor() else velocity.y-22*delta
	move_and_slide()
	phase += delta*(3.8+speed*0.35)
	var walking := distance > 1.1
	shoulders.rotation.z = sin(phase)*0.065
	shoulders.position.y = 1.02+absf(sin(phase))*0.025
	head_pivot.rotation.z = -0.12+sin(phase*0.5)*0.06
	var reaching := distance < 2.4
	for i in range(legs.size()):
		var step := sin(phase+i*PI)
		legs[i].rotation.x = step*(0.28 if i == 0 else 0.19) if walking else 0.0
		knees[i].rotation.x = maxf(0,-step)*0.3 if walking else 0.08
		arms[i].rotation.x = lerpf(arms[i].rotation.x,1.15 if reaching else 0.3+sin(phase+i*PI)*0.13,delta*5)
	if distance < 1.65 and absf(arena.player.position.y-position.y) < 2 and attack_clock <= 0:
		arena.take_damage(contact_damage)
		attack_clock = 1.0

func deactivate() -> void:
	clear_hit_flash()
	health = 0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	for area in damage_areas: area.collision_layer = 0
	set_physics_process(false)
	hide()

func activate(at: Vector3, move_speed: float, starting_health := 100, starting_damage := 12) -> void:
	clear_hit_flash()
	position = at
	health = starting_health
	contact_damage = starting_damage
	speed = move_speed
	attack_clock = 0.0
	flash_clock = 0.0
	velocity = Vector3.ZERO
	body_mesh.material_override.albedo_color = torso_color
	collision_layer = 16
	collision_mask = 1
	for area in damage_areas: area.collision_layer = 8 if area.get_meta("headshot",false) else 4
	show()
	set_physics_process(true)

func region_root(node: Node) -> Node:
	if node == head_pivot or head_pivot.is_ancestor_of(node): return head_pivot
	for limb in arms + legs:
		if node == limb or limb.is_ancestor_of(node): return limb
	return self

func collect_region_meshes(node: Node, regions: Dictionary) -> void:
	if node is MeshInstance3D:
		var region := region_root(node)
		if not regions.has(region): regions[region] = []
		regions[region].append(node)
	for child in node.get_children(): collect_region_meshes(child,regions)

func configure_damage_regions() -> void:
	if hit_flash_material == null:
		hit_flash_material = StandardMaterial3D.new()
		hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hit_flash_material.albedo_color = Color(1.0,0.79,0.58,0.55)
		hit_flash_material.disable_receive_shadows = true
	var regions: Dictionary = {}
	collect_region_meshes(self,regions)
	for area in damage_areas:
		var region := region_root(area)
		area.set_meta("damage_amount",68 if region == head_pivot else (34 if region == self else 17))
		area.set_meta("flash_meshes",regions.get(region,[]))

func clear_hit_flash() -> void:
	for mesh in flashing_meshes: mesh.material_overlay = null
	flashing_meshes.clear()
	flash_clock = 0.0

extends Node3D
## Deterministic ruined square. Decorative detail stays outside gameplay lanes.
var game: Node3D
var rng := RandomNumberGenerator.new()
var concrete: StandardMaterial3D
var asphalt: StandardMaterial3D
var brick: StandardMaterial3D
var rust: StandardMaterial3D
var timber: StandardMaterial3D
var car_footprints: Array[Rect2] = []

func textured(base: Color, scale_value: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.95
	var noise := FastNoiseLite.new()
	noise.seed = 91
	noise.frequency = 0.09
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color("626264"))
	ramp.set_color(1, Color("ddd8cc"))
	texture.color_ramp = ramp
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var relief := NoiseTexture2D.new()
	relief.width = 512
	relief.height = 512
	relief.noise = noise
	relief.seamless = true
	relief.as_normal_map = true
	relief.bump_strength = 0.5
	mat.normal_enabled = true
	mat.normal_texture = relief
	mat.normal_scale = 0.3
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_value
	return mat

func block(pos: Vector3, dimensions: Vector3, color: Color, solid := false, surface: Material = null) -> MeshInstance3D:
	var mesh: MeshInstance3D = game.box(self, pos, dimensions, color, solid)
	if surface != null: mesh.material_override = surface
	if dimensions.y < 0.04:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func _ready() -> void:
	rng.seed = 90421
	concrete = textured(Color("89877d"), 0.6)
	asphalt = textured(Color("454748"), 2.0)
	brick = textured(Color("a79787"), 0.22)
	brick.albedo_texture = load("res://textures/weathered_brick.png")
	brick.normal_scale = 0.12
	rust = textured(Color("635043"), 3.0)
	rust.metallic = 0.45
	timber = textured(Color("665a44"), 1.8)
	lighting()
	street()
	for side in [-1, 1]:
		for index in range(5):
			var x := -19.0 + index * 9.5
			var shop := -1
			if side == -1 and index == 1: shop = 0
			if side == -1 and index == 3: shop = 2
			if side == 1 and index == 2: shop = 1
			building(Vector3(x,0,side*26.2), side == 1, rng.randi_range(2,4), index, shop)
		for index in range(4):
			var facade := Node3D.new()
			# Side rows are rotated copies of the same facade generator.
			var start := get_child_count()
			building(Vector3(-15+index*10,0,26.2), true, rng.randi_range(2,4), index+1)
			var added: Array[Node] = []
			for i in range(start,get_child_count()): added.append(get_child(i))
			add_child(facade)
			for child in added: child.reparent(facade)
			facade.rotation.y = side * PI / 2
	# Boundary walls become concrete roadblocks and rubble at the ruined frontages.
	for side in [-1,1]:
		block(Vector3(side*22,1.3,0),Vector3(0.8,2.6,45),Color("79776c"),true,concrete)
		block(Vector3(0,1.3,side*22),Vector3(45,2.6,0.8),Color("79776c"),true,concrete)
		for p in [-17,-7,7,17]:
			lamp(Vector3(p,0.03,side*19.8))
	# Irregular abandoned positions: no mirrored rows or uniform parking angles.
	# Each car stays fully on the pavement, clear of the curb and boundary.
	for placement in [
		Vector3(-19.0,-14.6,0.55), Vector3(-19.65,-4.2,-0.22),
		Vector3(-19.1,10.8,2.55), Vector3(19.15,-12.3,-0.48),
		Vector3(19.7,1.8,3.28), Vector3(19.05,14.3,0.62),
		Vector3(-2.8,-19.15,1.18), Vector3(3.0,19.3,-1.32)
	]:
		wreck(Vector3(placement.x,0.03,placement.y),placement.z)
	for i in range(110):
		var edge := rng.randi_range(0,3)
		var point := Vector3(rng.randf_range(-21,21),0,rng.randf_range(19.4,21.5))
		point = point.rotated(Vector3.UP, edge*PI/2)
		if not debris_space_clear(point): continue
		var chunk := block(point+Vector3(0,0.18,0),Vector3(rng.randf_range(0.18,0.8),rng.randf_range(0.12,0.45),rng.randf_range(0.2,0.8)),Color("7c776b"),false,concrete)
		chunk.rotation = Vector3(rng.randf_range(-0.3,0.3),rng.randf()*TAU,rng.randf_range(-0.3,0.3))
		ground_mesh(chunk, ground_height(point))
		if i % 3 == 0: weeds(point)
	street_furniture()
	stabilize_details(self)
	# Distant skyline gives depth beyond the playable square.
	for i in range(18):
		var angle := i*TAU/18
		var height := rng.randf_range(10,28)
		block(Vector3(sin(angle)*62,height/2,cos(angle)*62),Vector3(10,height,12),Color("444e50"),false,concrete)

	build_environment_collisions()
	batch_static_boxes()

func lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("060d1d")
	sky_mat.sky_horizon_color = Color("15243b")
	sky_mat.ground_horizon_color = Color("101c2b")
	sky_mat.ground_bottom_color = Color("050a12")
	sky_mat.sky_energy_multiplier = 0.18
	sky_mat.ground_energy_multiplier = 0.08
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7593bd")
	env.ambient_light_energy = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("080e19")
	env.fog_density = 0.009
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24,-32,0)
	sun.light_color = Color("8faee0")
	sun.light_energy = 0.12
	# Compatibility renderer: avoid the shadow-map banding seen on this machine.
	sun.shadow_enabled = false
	add_child(sun)

func street() -> void:
	block(Vector3(0,-0.3,0),Vector3(46,0.6,46),Color.WHITE,true,asphalt)
	for side in [-1,1]:
		block(Vector3(side*19,0.015,0),Vector3(4,0.03,44),Color.WHITE,false,concrete)
		block(Vector3(0,0.015,side*19),Vector3(34,0.03,4),Color.WHITE,false,concrete)
		for i in range(-20,21,2):
			block(Vector3(side*17,0.045,i),Vector3(0.22,0.09,1.9),Color("b9b6a5"))
	for z in range(-13,16,5):
		for x in [-0.14,0.14]:
			block(Vector3(x,0.008,z),Vector3(0.08,0.014,2.3),Color("a99c6c"))
	for x in range(-6,7,2):
		block(Vector3(x,0.012,12),Vector3(1,0.018,3.5),Color("b7b5a3"))
	for i in range(35):
		var point := Vector3(rng.randf_range(-16,16),0.006,rng.randf_range(-16,16))
		var angle := rng.randf()*TAU
		for segment in range(rng.randi_range(3,6)):
			angle += rng.randf_range(-0.65,0.65)
			var length := rng.randf_range(0.12,0.65)
			var direction := Vector3(cos(angle),0,sin(angle))
			var crack := block(point+direction*length/2,Vector3(length,0.005,0.018),Color("212526"))
			crack.rotation.y = -angle
			point += direction*length
	for side in [-1,1]:
		for z in [-12,3,14]:
			# Drain grilles are physical slots, slightly above the sidewalk.
			block(Vector3(side*18,0.04,z),Vector3(0.65,0.018,1),Color("242c2d"))
			for bar in range(6):
				block(Vector3(side*18,0.055,z-0.4+bar*0.16),Vector3(0.58,0.018,0.035),Color("666b67"))


func building(origin: Vector3, flip: bool, floors: int, index: int, shop := -1) -> void:
	var start := get_child_count()
	building_meshes(origin, flip, floors, index, shop)
	var parts: Array[Node] = []
	for i in range(start,get_child_count()): parts.append(get_child(i))
	var assembly := Node3D.new()
	assembly.name = "Building"
	assembly.add_to_group("city_buildings")
	add_child(assembly)
	for part in parts: part.reparent(assembly)

func building_meshes(origin: Vector3, flip: bool, floors: int, index: int, shop: int) -> void:
	var front := -1.0 if flip else 1.0
	var height := floors*3.3
	var surf: Material = concrete if index%2 == 0 else brick
	# Floor slabs, pillars and irregular remnants expose the dark interiors.
	block(origin+Vector3(0,height/2,front*-3),Vector3(8.8,height,0.6),Color.WHITE,false,surf)
	for floor_index in range(floors+1):
		var y := floor_index*3.3
		block(origin+Vector3(0,y,0),Vector3(9.2,0.26,6.4),Color.WHITE,false,concrete)
		if floor_index == floors: continue
		for column in range(4):
			var x := -4.3+column*2.85
			block(origin+Vector3(x,y+1.65,front*2.8),Vector3(0.5,3.3,0.7),Color.WHITE,false,surf)
		for window in range(3):
			var x := -2.85+window*2.85
			var has_balcony := shop < 0 and floor_index > 0 and (floor_index+index)%2 == 0 and window == 1
			if has_balcony:
				# A full-height doorway opens onto the balcony slab, without a blocking sill.
				block(origin+Vector3(x,y+2.95,front*2.8),Vector3(2.4,0.4,0.45),Color.WHITE,false,surf)
				block(origin+Vector3(x,y+1.46,front*2.92),Vector3(2.16,2.58,0.08),Color("233339"))
				for jamb in [-1,0,1]:
					block(origin+Vector3(x+jamb*1.1,y+1.46,front*2.99),Vector3(0.075,2.6,0.08),Color("424b48"))
				continue
			if floor_index == floors-1 and rng.randf() < 0.4: continue
			block(origin+Vector3(x,y+0.55,front*2.8),Vector3(2.4,1.1,0.45),Color.WHITE,false,surf)
			block(origin+Vector3(x,y+2.95,front*2.8),Vector3(2.4,0.4,0.45),Color.WHITE,false,surf)
			block(origin+Vector3(x,y+1.12,front*3.08),Vector3(2.5,0.12,0.45),Color("6a6c64"))
			for frame_side in [-1,1]:
				block(origin+Vector3(x+frame_side*1.12,y+2,front*2.76),Vector3(0.07,1.7,0.1),Color("424b48"))
			if rng.randf() < 0.45:
				block(origin+Vector3(x,y+1.95,front*2.65),Vector3(2.2,1.7,0.08),Color("263b40"))
				block(origin+Vector3(x,y+1.95,front*2.8),Vector3(0.08,1.7,0.08),Color("303a3a"))
			else:
				var plank := block(origin+Vector3(x,y+1.7,front*2.95),Vector3(2.2,0.18,0.13),Color("655b48"))
				plank.rotation.z = rng.randf_range(-0.6,0.6)
	facade_details(origin, front, floors, index, shop >= 0)
	block(origin+Vector3(-2,height+0.5,-front),Vector3(1.6,0.8,1.1),Color("424e4d"))
	for vent in range(5):
		block(origin+Vector3(-2.6+vent*0.3,height+0.5,-front*1.57),Vector3(0.08,0.55,0.03),Color("222b2b"))
	block(origin+Vector3(4.1,height/2,front*3.35),Vector3(0.11,height,0.11),Color("5d655d"))
	for level in range(floors):
		block(origin+Vector3(4.1,level*3.3+0.6,front*3.2),Vector3(0.17,0.07,0.38),Color("535c53"))
	for i in range(5):
		var rod_height := rng.randf_range(0.4,1.6)
		block(origin+Vector3(rng.randf_range(-4,4),height+0.1+rod_height/2,front*2.8),Vector3(0.06,rod_height,0.06),Color("544f43"))
	if shop >= 0: shop_sign(origin, flip, shop)

func lamp(pos: Vector3) -> void:
	var start := get_child_count()
	block(pos+Vector3(0,2.6,0),Vector3(0.12,5.2,0.12),Color("343b3b"))
	block(pos+Vector3(0.45,5.1,0),Vector3(1,0.1,0.1),Color("343b3b"))
	game.box(self,pos+Vector3(0.85,5.02,0),Vector3(0.55,0.08,0.3),Color("ffdb91"),false,true)
	var light := OmniLight3D.new()
	light.position = pos+Vector3(0.85,4.7,0)
	light.light_color = Color("ffcd84")
	light.light_energy = 1.2
	light.omni_range = 6
	add_child(light)
	var parts: Array[Node] = []
	for i in range(start,get_child_count()): parts.append(get_child(i))
	var assembly := Node3D.new()
	assembly.name = "StreetLamp"
	assembly.add_to_group("city_props")
	add_child(assembly)
	for part in parts: part.reparent(assembly)

func wreck(pos: Vector3, angle: float) -> void:
	var car := Node3D.new()
	car.name = "Wreck"
	car.add_to_group("city_props")
	add_child(car)
	car.position = pos
	car.rotation.y = angle
	var paint: Color = [Color("4f5d58"),Color("665149"),Color("555f6b")][rng.randi_range(0,2)]
	# Chamfered bodywork replaces rectangular car blocks.
	game.weapon_part(car,Vector3(0,0.57,0),Vector3(1.65,0.58,3.5),0.18,paint,0.35)
	game.weapon_part(car,Vector3(0,1.02,0.12),Vector3(1.42,0.65,1.85),0.23,Color("17252d"),0.5)
	game.weapon_part(car,Vector3(0,1.38,0.12),Vector3(1.35,0.1,1.55),0.035,paint,0.3)
	var hood: MeshInstance3D = game.weapon_part(car,Vector3(0,0.92,-1.25),Vector3(1.5,0.08,0.95),0.025,paint.darkened(0.15),0.35)
	hood.rotation.x = -0.14
	for end in [-1,1]:
		game.weapon_part(car,Vector3(0,0.43,end*1.77),Vector3(1.63,0.15,0.16),0.04,Color("343a3b"),0.6)
		for side in [-1,1]:
			game.box(car,Vector3(side*0.58,0.68,end*1.757),Vector3(0.35,0.15,0.035),Color("868777") if end == -1 else Color("522e2a"))
	for side in [-1,1]:
		for z in [-0.55,0.75]:
			game.box(car,Vector3(side*0.72,1.04,z),Vector3(0.045,0.58,0.065),paint)
			game.box(car,Vector3(side*0.835,0.77,z),Vector3(0.035,0.04,0.18),Color("91918a"))
		game.box(car,Vector3(side*0.83,0.5,0.15),Vector3(0.025,0.025,1.4),Color("292f30"))
		var mirror: MeshInstance3D = game.weapon_part(car,Vector3(side*0.85,1.03,-0.6),Vector3(0.22,0.13,0.2),0.04,paint,0.3)
		mirror.rotation.y = side*0.2
	for i in range(7):
		game.box(car,Vector3(-0.4+i*0.13,0.6,-1.773),Vector3(0.06,0.18,0.02),Color("131b21"))
	for side in [-1,1]:
		for z in [-1,1]:
			var wheel := MeshInstance3D.new()
			var tire := CylinderMesh.new()
			tire.top_radius = 0.32
			tire.bottom_radius = 0.32
			tire.height = 0.18
			wheel.mesh = tire
			wheel.material_override = game.material(Color("202526"))
			wheel.position = Vector3(side*0.8,0.32,z)
			wheel.rotation.z = PI/2
			car.add_child(wheel)
			var hub := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.18
			disc.bottom_radius = 0.18
			disc.height = 0.025
			disc.radial_segments = 12
			hub.mesh = disc
			hub.material_override = rust
			hub.position = Vector3(side*0.895,0.32,z)
			hub.rotation.z = PI/2
			car.add_child(hub)

	var footprint := AABB()
	for part in car.get_children():
		if part is MeshInstance3D:
			var part_bounds: AABB = part.global_transform * part.get_aabb()
			footprint = footprint.merge(part_bounds) if footprint.has_volume() else part_bounds
	car_footprints.append(Rect2(Vector2(footprint.position.x,footprint.position.z),Vector2(footprint.size.x,footprint.size.z)))

func weeds(pos: Vector3) -> void:
	for i in range(4):
		var stem := block(pos+Vector3(i*0.08,0.17,0),Vector3(0.035,rng.randf_range(0.2,0.5),0.12),Color("586a46"))
		stem.set_meta("decorative_only", true)
		stem.rotation.z = rng.randf_range(-0.5,0.5)
		ground_mesh(stem, ground_height(pos))

func stabilize_details(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var bounds: Vector3 = child.get_aabb().size
			var smallest := minf(bounds.x,minf(bounds.y,bounds.z))
			var largest := maxf(bounds.x,maxf(bounds.y,bounds.z))
			# Tiny details cannot sustain stable shadow-map sampling at distance.
			# Keep shadow reception on road surfaces, walls and structural elements.
			if smallest < 0.1 and largest < 3.0 and child.material_override is StandardMaterial3D:
				child.material_override = child.material_override.duplicate()
				child.material_override.disable_receive_shadows = true
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stabilize_details(child)

func facade_details(origin: Vector3, front: float, floors: int, index: int, commercial: bool) -> void:
	if commercial:
		# Recessed storefronts and shutter slats give the ground floor a readable scale.
		for bay in [-1,1]:
			var center := origin + Vector3(bay*2.4,1.25,front*3.12)
			block(center,Vector3(1.85,2.4,0.08),Color("252f32"))
			for slat in range(12):
				block(center+Vector3(0,-1.05+slat*0.19,front*0.06),Vector3(1.8,0.14,0.04),Color("535955"),false,rust)
			var canopy := block(origin+Vector3(bay*2.4,2.8,front*3.42),Vector3(2.2,0.14,0.9),Color("485750"))
			canopy.rotation.x = front*0.13
	else:
		# Residential entrances are quieter than boarded shop fronts.
		block(origin+Vector3(-2.85,1.2,front*3.1),Vector3(1.15,2.4,0.12),Color("303b39"))
		block(origin+Vector3(-2.5,1.15,front*3.18),Vector3(0.04,0.17,0.04),Color("827b63"))
	# Window trim, balconies and rust streaks, all offset to avoid coplanar flicker.
	for floor_index in range(1,floors):
		var y := floor_index*3.3
		block(origin+Vector3(0,y+0.22,front*3.18),Vector3(8.8,0.12,0.19),Color("7b7c72"))
		# Keep commercial facades clear, including the tall hotel sign.
		if not commercial and (floor_index+index)%2 == 0:
			var balcony_start := get_child_count()
			block(origin+Vector3(0,y+0.1,front*3.65),Vector3(2.6,0.18,1.2),Color.WHITE,false,concrete)
			block(origin+Vector3(0,y+1.12,front*4.2),Vector3(2.6,0.06,0.06),Color("454b48"))
			for rail in range(8):
				block(origin+Vector3(-1.2+rail*0.34,y+0.64,front*4.2),Vector3(0.035,0.95,0.035),Color("454b48"))
			for side in [-1,1]:
				block(origin+Vector3(side*1.25,y+1.12,front*3.61),Vector3(0.06,0.06,1.24),Color("454b48"))
				for depth in [3.1,3.46,3.83,4.2]:
					block(origin+Vector3(side*1.25,y+0.64,front*depth),Vector3(0.05,0.95,0.05),Color("454b48"))
			var balcony_parts: Array[Node] = []
			for i in range(balcony_start,get_child_count()): balcony_parts.append(get_child(i))
			var balcony := Node3D.new()
			balcony.name = "Balcony"
			balcony.add_to_group("city_balconies")
			add_child(balcony)
			for part in balcony_parts: part.reparent(balcony)
		for stain in range(3):
			var x := -3.5+stain*3.1
			block(origin+Vector3(x,y+0.63,front*3.031),Vector3(0.09,0.7,0.012),Color("454940"))
	# Broken roof beam and varied roof equipment silhouettes.
	var beam := block(origin+Vector3(2.2,floors*3.3+0.3,front*1.8),Vector3(3.0,0.22,0.3),Color.WHITE,false,rust)
	beam.rotation.z = 0.18
	ground_mesh(beam, origin.y+floors*3.3+0.13)
	if index%2 == 1:
		block(origin+Vector3(1.5,floors*3.3+1.3,0),Vector3(0.06,2.6,0.06),Color("545e60"))
		for i in range(3):
			block(origin+Vector3(1.5,floors*3.3+1.7+i*0.3,0),Vector3(1.5-i*0.3,0.04,0.04),Color("545e60"))

func street_furniture() -> void:
	for side in [-1,1]:
		# Pavement joints and chipped curb segments.
		for z in range(-18,19,2):
			block(Vector3(side*19,0.032,z),Vector3(3.7,0.002,0.018),Color("494d49"))
		for x in [-12,12]:
			var bench := Node3D.new()
			bench.name = "Bench"
			bench.add_to_group("city_props")
			add_child(bench)
			bench.position = Vector3(x,0.03,side*20)
			bench.rotation.y = PI if side == -1 else 0.0
			for slat in range(4):
				var seat: MeshInstance3D = game.box(bench,Vector3(0,0.5,-0.195+slat*0.13),Vector3(2.0,0.075,0.1),Color.WHITE)
				seat.material_override = timber
			for leg in [-1,1]:
				game.box(bench,Vector3(leg*0.75,0.25,0),Vector3(0.08,0.5,0.5),Color("333d3e"))
				game.box(bench,Vector3(leg*0.75,0.8,0.27),Vector3(0.07,0.7,0.08),Color("333d3e"))
			for slat in range(3):
				var back: MeshInstance3D = game.box(bench,Vector3(0,0.75+slat*0.16,0.23),Vector3(2.0,0.12,0.08),Color.WHITE)
				back.material_override = timber
		# Individual facing panels break up the continuous boundary walls.
		for x in range(-20,21,4):
			block(Vector3(x,1.25,side*21.55),Vector3(3.8,2.45,0.12),Color.WHITE,false,concrete)
			block(Vector3(x,2.59,side*22),Vector3(3.9,0.12,1.0),Color("686b63"))
			for bolt in [-1,1]:
				block(Vector3(x+bolt*1.5,1.8,side*21.47),Vector3(0.09,0.09,0.035),Color("3b4343"))
		# Discarded boards and masonry sit along the edge, outside enemy routes.
		for i in range(8):
			var point := Vector3(rng.randf_range(-18,18),0,side*rng.randf_range(20,21))
			if not debris_space_clear(point): continue
			var plank := block(point,Vector3(rng.randf_range(0.7,1.5),0.06,0.16),Color.WHITE,false,timber)
			plank.rotation.y = rng.randf()*TAU
			ground_mesh(plank, ground_height(point))

func sign_text(parent: Node3D, text: String, pos: Vector3, scale_value: float, color: Color, stencil := false) -> void:
	var label := Label3D.new()
	label.text = text
	if stencil: label.font = load("res://fonts/BlackOpsOne-Regular.ttf")
	label.font_size = 64
	label.pixel_size = scale_value
	label.outline_size = 0
	label.position = pos
	label.modulate = color
	label.no_depth_test = false
	parent.add_child(label)

func shop_sign(origin: Vector3, flip: bool, kind: int) -> void:
	var sign := Node3D.new()
	sign.name = ["PharmacieDesHalles", "HotelDuNord", "CafeDesTilleuls"][kind]
	add_child(sign)
	sign.position = origin+Vector3(0,3.85,-3.55 if flip else 3.55)
	if flip: sign.rotation.y = PI
	if kind == 0:
		# An old, narrow enamel fascia with a separate projecting pharmacy cross.
		game.weapon_part(sign,Vector3(-0.35,0,0),Vector3(4.9,0.65,0.16),0.035,Color("718175"),0.25)
		sign_text(sign,"PHARMACIE DES HALLES",Vector3(-0.35,0,0.095),0.0045,Color("233c32"))
		var cross := Node3D.new()
		sign.add_child(cross)
		cross.position = Vector3(4.25,0.65,0.65)
		cross.rotation.y = PI/2
		# Anchor to the outer masonry pillar (x=4.25), not the window bay.
		# Pillar front is z=-0.40 in this sign's local coordinates.
		for y in [0.12,1.18]:
			game.box(sign,Vector3(4.25,y,-0.40),Vector3(0.24,0.26,0.10),Color("394440"))
			game.box(sign,Vector3(4.25,y,0.125),Vector3(0.08,0.08,1.1),Color("394440"))
			for bolt_y in [-0.085,0.085]:
				game.box(sign,Vector3(4.25,y+bolt_y,-0.335),Vector3(0.05,0.05,0.035),Color("797d72"))
		# The fascia is also fastened back into the solid wall below the windows.
		for x in [-2.0,1.3]:
			game.box(sign,Vector3(x,0,-0.29),Vector3(0.12,0.3,0.5),Color("394440"))
		game.box(cross,Vector3.ZERO,Vector3(0.36,1.15,0.16),Color("1d3028"))
		game.box(cross,Vector3.ZERO,Vector3(1.15,0.36,0.16),Color("1d3028"))
		for face in [-1,1]:
			game.box(cross,Vector3(0,0,face*0.09),Vector3(0.19,0.95,0.025),Color("427853"),false,true)
			# One unlit arm suggests a damaged luminous sign.
			game.box(cross,Vector3(-0.28,0,face*0.09),Vector3(0.38,0.19,0.025),Color("427853"),false,true)
	elif kind == 1:
		# Tall corner sign, with individual letters and a failed lamp.
		sign.position.y = origin.y + 5.0
		sign.position.x = origin.x + 4.25
		game.weapon_part(sign,Vector3.ZERO,Vector3(0.95,3.8,0.28),0.08,Color("3d302d"),0.35)
		for x in [-0.42,0.42]:
			game.box(sign,Vector3(x,0,0.16),Vector3(0.035,3.62,0.035),Color("9a7354"))
		for i in range(5):
			var color := Color("bc8a59") if i != 2 else Color("55483f")
			sign_text(sign,"HOTEL"[i],Vector3(0,1.38-i*0.67,0.16),0.009,color,true)
		for y in [-1.25,1.25]:
			# Anchor plates overlap the corner pillar face; arms reach the panel back.
			game.box(sign,Vector3(0,y,-0.40),Vector3(0.24,0.34,0.10),Color("4b4840"))
			game.box(sign,Vector3(0,y,-0.265),Vector3(0.12,0.12,0.31),Color("4b4840"))
			for bolt_y in [-0.12,0.12]:
				game.box(sign,Vector3(0,y+bolt_y,-0.335),Vector3(0.05,0.05,0.035),Color("827b69"))
	elif kind == 2:
		# Wooden board fixed to the solid spandrel below the first-floor windows.
		sign.position.x -= 1.2
		sign.position.y = origin.y + 3.78
		for y in [-0.38,0,0.38]:
			var plank: MeshInstance3D = game.box(sign,Vector3(0,y,0),Vector3(3.3,0.355,0.13),Color.WHITE)
			plank.material_override = timber
		for x in [-1.2,1.2]:
			# Wall face z=3.025; sign origin z=3.55. Rails overlap both surfaces.
			game.box(sign,Vector3(x,0,-0.53),Vector3(0.22,0.8,0.08),Color("373d39"))
			for y in [-0.3,0.3]:
				game.box(sign,Vector3(x,y,-0.29),Vector3(0.09,0.09,0.5),Color("373d39"))
				game.box(sign,Vector3(x,y,0.078),Vector3(0.055,0.055,0.03),Color("827b69"))
		sign_text(sign,"Le Tilleul",Vector3(0,0.15,0.085),0.008,Color("c4b58f"))
		sign_text(sign,"CAFÉ  •  DEPUIS 1958",Vector3(0,-0.3,0.085),0.0032,Color("a99b7b"))
		# Faded fabric awning directly beneath the board.
		for stripe in range(10):
			var fabric: MeshInstance3D = game.box(sign,Vector3(-1.8+stripe*0.4,-0.95,0.02),Vector3(0.395,0.055,1.1),Color("545b45") if stripe%2 == 0 else Color("89816a"))
			fabric.rotation.x = 0.16

func ground_height(point: Vector3) -> float:
	return 0.03 if (absf(point.x) >= 17 and absf(point.x) <= 21) or (absf(point.z) >= 17 and absf(point.z) <= 21) else 0.0

func ground_mesh(mesh: MeshInstance3D, level: float) -> void:
	var bounds: AABB = mesh.transform * mesh.get_aabb()
	mesh.position.y += level - bounds.position.y

func debris_space_clear(point: Vector3) -> bool:
	# Reserve full prop footprints plus clearance for the largest rubble piece.
	if absf(point.x) > 20.9 or absf(point.z) > 20.9: return false
	for footprint in car_footprints:
		if footprint.grow(0.8).has_point(Vector2(point.x,point.z)): return false
	for side in [-1,1]:
		for p in [-17,-7,7,17]:
			if absf(point.x-(p+0.4)) < 1.3 and absf(point.z-side*19.8) < 0.9: return false
		for x in [-12,12]:
			if absf(point.x-x) < 1.8 and absf(point.z-side*20) < 1.1: return false
	return true

func build_environment_collisions() -> void:
	# One static compound body, preserving each mesh's orientation and openings.
	# Small surface decals, grass and lettering must not create invisible obstacles.
	var meshes: Array[MeshInstance3D] = []
	collect_solid_meshes(self, meshes)
	var bodies: Dictionary = {}
	for mesh in meshes:
		# Spatially bounded bodies avoid a single collision object spanning the city.
		var sector := Vector2i(floori(mesh.global_position.x/12.0),floori(mesh.global_position.z/12.0))
		if not bodies.has(sector):
			var chunk := StaticBody3D.new()
			chunk.name = "CollisionSector_%s_%s" % [sector.x,sector.y]
			chunk.collision_layer = 1
			chunk.collision_mask = 0
			add_child(chunk)
			bodies[sector] = chunk
		var body: StaticBody3D = bodies[sector]
		var shape: Shape3D
		if mesh.mesh is BoxMesh:
			var box := BoxShape3D.new()
			box.size = mesh.mesh.size
			shape = box
		elif mesh.mesh is CylinderMesh:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = maxf(mesh.mesh.top_radius, mesh.mesh.bottom_radius)
			cylinder.height = mesh.mesh.height
			shape = cylinder
		else:
			shape = mesh.mesh.create_convex_shape()
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		collider.transform = global_transform.affine_inverse() * mesh.global_transform
		mesh.set_meta("environment_collider", collider)

func collect_solid_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and not child.get_meta("decorative_only", false):
			var size: Vector3 = child.get_aabb().size
			var has_body := false
			for part in child.get_children():
				if part is StaticBody3D: has_body = true
			if not has_body and minf(size.x,minf(size.y,size.z)) >= 0.025 and maxf(size.x,maxf(size.y,size.z)) >= 0.18:
				meshes.append(child)
		collect_solid_meshes(child, meshes)

func batch_static_boxes() -> void:
	# Draw repeated static boxes together, while retaining their original collision
	# shapes and per-sector visibility culling. No change to the actual geometry.
	var candidates: Array[MeshInstance3D] = []
	collect_boxes(self,candidates)
	var groups: Dictionary = {}
	for mesh in candidates:
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null: continue
		var sector := Vector2i(floori(mesh.global_position.x/12.0),floori(mesh.global_position.z/12.0))
		var key := str(sector)+"/"+str(mesh.cast_shadow)+"/"+str([
			mat.albedo_color,mat.roughness,mat.metallic,mat.emission_enabled,
			mat.emission,mat.emission_energy_multiplier,mat.disable_receive_shadows,
			mat.albedo_texture,mat.normal_enabled,mat.normal_texture,mat.normal_scale,
			mat.uv1_triplanar,mat.uv1_world_triplanar,mat.uv1_scale,mat.texture_filter])
		if not groups.has(key): groups[key] = []
		groups[key].append(mesh)
	var batches := 0
	var combined := 0
	for group in groups.values():
		if group.size() < 2: continue
		var first: MeshInstance3D = group[0]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		multi.mesh = cube
		multi.instance_count = group.size()
		for i in range(group.size()):
			var mesh: MeshInstance3D = group[i]
			var placement := global_transform.affine_inverse()*mesh.global_transform
			placement.basis = placement.basis.scaled_local(mesh.mesh.size)
			multi.set_instance_transform(i,placement)
			mesh.visible = false
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticBatch"
		batch.multimesh = multi
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		add_child(batch)
		batches += 1
		combined += group.size()
	set_meta("batched_mesh_count",combined)
	set_meta("static_batch_count",batches)
	print("Static scenery: %d meshes grouped into %d render batches" % [combined,batches])

func collect_boxes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.visible:
			result.append(child)
		collect_boxes(child,result)

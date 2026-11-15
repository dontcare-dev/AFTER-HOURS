extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const InteractableScript = preload("res://scripts/interactable.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const HauntingScript = preload("res://scripts/haunting.gd")

var player
var menu_camera: Camera3D
var elapsed := 0.0
var shift_duration := 360.0
var current_objective := "Report to the security office."
var completed := {}
var evidence := []
var decisions := {}
var discovered := {}
var door_states := {}
var paused := false
var terminal_open := false
var objectives_open := false
var ending := false
var ui: CanvasLayer
var clock_label: Label
var prompt_label: Label
var objective_label: Label
var stamina_bar: ProgressBar
var battery_label: Label
var message_label: Label
var overlay: ColorRect
var panel: PanelContainer
var feed: TextureRect
var feed_view: SubViewport
var feed_camera: Camera3D
var feed_index := 0
var feed_names = ["CENTRAL ATRIUM", "FOOD COURT", "EAST CORRIDOR", "PARKING LEVEL"]
var feed_positions = [Vector3(0, 5.2, -7), Vector3(12, 4.5, -15), Vector3(-12, 4.5, -12), Vector3(0, 5.0, 21)]
var anomaly_figure: Node3D
var haunting: Node3D
var anomaly_active := false
var event_flags := {}
var mall_materials := {}
var mall_lights: Array[OmniLight3D] = []
var flicker_restore: Array = []
var flicker_duration := 0.0
var next_flicker := 36.0
const WORLD_SCALE := 1.35

func _ready():
	build_world()
	build_player()
	build_menu_camera()
	build_haunting()
	build_ui()
	set_objective("Report to the security office.")
	show_message("SHIFT STARTED  /  12:00 AM", 4.0)
	show_story_intro()

func _process(delta):
	if paused or terminal_open or ending:
		return
	elapsed = minf(shift_duration, elapsed + delta)
	update_clock()
	update_hud()
	update_story_events()
	update_light_anomalies(delta)
	if elapsed >= shift_duration:
		finish_game()

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if terminal_open:
			close_terminal()
		elif paused:
			resume_game()
		else:
			open_pause()
	if event.is_action_pressed("objectives") and not paused and not terminal_open:
		objectives_open = !objectives_open
		show_objectives()
	if event is InputEventKey and event.pressed and terminal_open:
		if event.keycode == KEY_LEFT:
			change_camera(-1)
		elif event.keycode == KEY_RIGHT:
			change_camera(1)
		elif event.keycode == KEY_ENTER:
			close_terminal()

func build_world():
	var world_env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.024, 0.04)
	sky_material.sky_horizon_color = Color(0.06, 0.065, 0.07)
	sky_material.ground_bottom_color = Color(0.008, 0.009, 0.012)
	sky_material.ground_horizon_color = Color(0.035, 0.038, 0.04)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.34, 0.38)
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.sdfgi_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.glow_enabled = false
	environment.volumetric_fog_enabled = false
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.075, 0.08, 0.085)
	environment.fog_density = 0.004
	world_env.environment = environment
	add_child(world_env)
	var mall = Node3D.new()
	mall.name = "Mall"
	mall.scale = Vector3(WORLD_SCALE, 1.0, WORLD_SCALE)
	add_child(mall)
	var floor_mat = textured_material(Color(0.22, 0.22, 0.2), 0.22, 0.12, 0.028)
	var wall_mat = textured_material(Color(0.34, 0.33, 0.29), 0.82, 0.0, 0.018)
	var dark_mat = textured_material(Color(0.045, 0.052, 0.056), 0.7, 0.08, 0.04)
	var tile_mat = textured_material(Color(0.29, 0.29, 0.27), 0.16, 0.18, 0.055)
	var ceiling_mat = textured_material(Color(0.14, 0.15, 0.15), 0.9, 0.0, 0.02)
	box(mall, Vector3(0, -0.25, 0), Vector3(42, 0.5, 58), floor_mat, true)
	box(mall, Vector3(-12.0, 6.2, 0), Vector3(18.0, 0.5, 58), ceiling_mat, false)
	var skylight_material = material(Color(0.09, 0.13, 0.15, 0.24), 0.12, 0.08)
	skylight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box(mall, Vector3(0, 6.2, 0), Vector3(6.0, 0.16, 58), skylight_material, false)
	box(mall, Vector3(12.0, 6.2, 0), Vector3(18.0, 0.5, 58), ceiling_mat, false)
	for z in range(-27, 29, 6):
		box(mall, Vector3(0, 6.1, z), Vector3(6.2, 0.12, 0.12), material(Color(0.36, 0.38, 0.37), 0.24), false)
	box(mall, Vector3(-21, 3, 0), Vector3(0.5, 6, 58), wall_mat, true)
	box(mall, Vector3(21, 3, 0), Vector3(0.5, 6, 58), wall_mat, true)
	box(mall, Vector3(0, 3, -29), Vector3(42, 6, 0.5), wall_mat, true)
	box(mall, Vector3(0, 3, 29), Vector3(42, 6, 0.5), wall_mat, true)
	for x in [-15, -10, -5, 0, 5, 10, 15]:
		box(mall, Vector3(x, 0.012, 0), Vector3(0.035, 0.02, 56), tile_mat, false)
	for z in range(-25, 29, 5):
		box(mall, Vector3(0, 0.013, z), Vector3(40, 0.02, 0.035), tile_mat, false)
	for x in [-15, 0, 15]:
		for z in [-20, -5, 10, 25]:
			var light = OmniLight3D.new()
			light.position = Vector3(x, 5.55, z)
			light.light_color = Color(0.78, 0.82, 0.88)
			light.light_energy = 0.7 if z > -20 else 0.42
			light.omni_range = 11.0
			light.shadow_enabled = false
			mall.add_child(light)
			mall_lights.append(light)
			var fixture = box(mall, Vector3(x, 5.88, z), Vector3(2.2, 0.12, 0.48), material(Color(0.62, 0.65, 0.65), 0.2, 0.3), false)
	build_atrium_details(mall)
	box(mall, Vector3(-3.75, 2.2, -27), Vector3(2.5, 4.4, 0.3), wall_mat, true)
	box(mall, Vector3(3.75, 2.2, -27), Vector3(2.5, 4.4, 0.3), wall_mat, true)
	box(mall, Vector3(-3.75, 2.2, 27), Vector3(2.5, 4.4, 0.3), wall_mat, true)
	box(mall, Vector3(3.75, 2.2, 27), Vector3(2.5, 4.4, 0.3), wall_mat, true)
	box(mall, Vector3(-4.0, 2.4, 18), Vector3(1.0, 4.8, 0.4), wall_mat, true)
	box(mall, Vector3(1.25, 2.4, 18), Vector3(6.5, 4.8, 0.4), wall_mat, true)
	box(mall, Vector3(-4.0, 2.4, 18), Vector3(1.0, 4.8, 0.6), dark_mat, false)
	box(mall, Vector3(1.25, 2.4, 18), Vector3(6.5, 4.8, 0.6), dark_mat, false)
	box(mall, Vector3(-10, 2.0, -17), Vector3(8, 4, 0.35), wall_mat, true)
	box(mall, Vector3(10, 2.0, -17), Vector3(8, 4, 0.35), wall_mat, true)
	box(mall, Vector3(-10, 2.0, 14), Vector3(8, 4, 0.35), wall_mat, true)
	box(mall, Vector3(10, 2.0, 14), Vector3(8, 4, 0.35), wall_mat, true)
	build_escalator(mall)
	build_security_office(mall)
	build_food_court(mall)
	build_concourse_props(mall)
	build_parking(mall)
	build_doors(mall)
	build_anomaly_figure(mall)
	build_interactables(mall)
	var outside_light = DirectionalLight3D.new()
	outside_light.rotation_degrees = Vector3(-55, -25, 0)
	outside_light.light_energy = 0.12
	mall.add_child(outside_light)

func build_atrium_details(parent):
	if ResourceLoader.exists("res://assets/mall_column_cladding.glb"):
		for x in [-9.5, 9.5]:
			for z in [-22.0, -10.0, 2.0, 14.0, 25.0]:
				add_scene_asset(parent, "res://assets/mall_column_cladding.glb", Vector3(x, 0.0, z), Vector3.ZERO, Vector3(1.35, 1.42, 1.35))
	else:
		for x in [-9.5, 9.5]:
			for z in [-22.0, -10.0, 2.0, 14.0, 25.0]:
				var column = MeshInstance3D.new()
				var shaft = CylinderMesh.new()
				shaft.top_radius = 0.42
				shaft.bottom_radius = 0.56
				shaft.height = 5.7
				shaft.radial_segments = 24
				column.mesh = shaft
				column.position = Vector3(x, 2.85, z)
				column.material_override = material(Color(0.29, 0.3, 0.29), 0.32, 0.04)
				parent.add_child(column)
				for cap_y in [0.16, 5.52]:
					var cap = MeshInstance3D.new()
					var cap_mesh = CylinderMesh.new()
					cap_mesh.top_radius = 0.68
					cap_mesh.bottom_radius = 0.68
					cap_mesh.height = 0.18
					cap_mesh.radial_segments = 32
					cap.mesh = cap_mesh
					cap.position = Vector3(x, cap_y, z)
					cap.material_override = material(Color(0.48, 0.43, 0.34), 0.24, 0.08)
					parent.add_child(cap)
	for side in [-1, 1]:
		var index := 0
		for z in [-20, -10, 0, 10, 20]:
			build_storefront(parent, side, float(z), index)
			index += 1
	for position in [Vector3(-7.5, 0, -17), Vector3(7.5, 0, -17), Vector3(-7.5, 0, 17), Vector3(7.5, 0, 17)]:
		build_planter(parent, position)
	var chandelier = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = 1.15
	ring.outer_radius = 1.28
	ring.rings = 16
	ring.ring_segments = 48
	chandelier.mesh = ring
	chandelier.position = Vector3(0, 5.55, -2)
	chandelier.material_override = material(Color(0.52, 0.43, 0.29), 0.2, 0.22)
	parent.add_child(chandelier)
	for i in range(12):
		var angle = TAU * float(i) / 12.0
		var pendant = MeshInstance3D.new()
		var bulb = SphereMesh.new()
		bulb.radius = 0.09
		bulb.height = 0.18
		pendant.mesh = bulb
		pendant.position = Vector3(cos(angle) * 1.22, 5.22, -2 + sin(angle) * 1.22)
		pendant.material_override = material(Color(0.88, 0.72, 0.48), 0.18, 1.8)
		parent.add_child(pendant)

func build_storefront(parent, side: int, center_z: float, index: int):
	var front_x = side * 10.45
	var rear_x = side * 20.2
	var glass = material(Color(0.19, 0.28, 0.3, 0.22), 0.12, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.34
	glass.roughness = 0.12
	var frame = material(Color(0.12, 0.14, 0.15), 0.24, 0.08)
	var trim = material(Color(0.52, 0.43, 0.31), 0.25, 0.12)
	box(parent, Vector3(rear_x, 2.0, center_z), Vector3(0.3, 4.0, 9.6), material(Color(0.11, 0.12, 0.12)), true)
	for z_offset in [-4.7, 4.7]:
		box(parent, Vector3(side * 15.3, 2.0, center_z + z_offset), Vector3(9.8, 4.0, 0.25), frame, true)
	for z_offset in [-4.35, -2.05, 2.05, 4.35]:
		box(parent, Vector3(front_x, 2.0, center_z + z_offset), Vector3(0.16, 4.0, 0.12), frame, false)
	for z_offset in [-3.2, 3.2]:
		var pane = box(parent, Vector3(front_x, 2.05, center_z + z_offset), Vector3(0.055, 3.65, 2.05), glass, false)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sign_panel = box(parent, Vector3(front_x, 4.05, center_z), Vector3(0.28, 0.56, 8.9), frame, false)
	var sign_text = ["MERCURY / DEPARTMENT", "CLOTHING / STUDIO", "HOME & CO / LIVING", "TOYS / PLAYROOM", "NORTH STAR / CINEMA"][index]
	var sign = label_3d(parent, Vector3(front_x - side * 0.18, 4.02, center_z), sign_text, Color(0.83, 0.74, 0.56))
	var door = box(parent, Vector3(front_x, 1.75, center_z), Vector3(0.1, 3.45, 1.55), glass, false)
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(parent, Vector3(front_x - side * 0.09, 1.75, center_z - 0.82), Vector3(0.16, 3.55, 0.12), trim, false)
	box(parent, Vector3(front_x - side * 0.09, 1.75, center_z + 0.82), Vector3(0.16, 3.55, 0.12), trim, false)
	if side == 1 and index == 2 and ResourceLoader.exists("res://assets/retail_shopfloor.glb"):
		var shop_pack := load("res://assets/retail_shopfloor.glb") as PackedScene
		if shop_pack:
			var shop = shop_pack.instantiate()
			shop.position = Vector3(side * 15.3, 0.0, center_z)
			shop.rotation.y = -float(side) * PI * 0.5
			parent.add_child(shop)
			for mesh_node in shop.find_children("*", "MeshInstance3D", true, false):
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mesh_node.lod_bias = 1.5
	else:
		for shelf_z in [-2.8, 2.8]:
			box(parent, Vector3(side * 12.0, 1.1, center_z + shelf_z), Vector3(2.1, 0.14, 1.1), material(Color(0.2, 0.18, 0.15)), false)
			for tier in [1.5, 2.15]:
				box(parent, Vector3(side * 12.0, tier, center_z + shelf_z), Vector3(1.9, 0.08, 0.92), trim, false)
		for display_index in range(3):
			var display = MeshInstance3D.new()
			var shape = CylinderMesh.new()
			shape.top_radius = 0.35
			shape.bottom_radius = 0.42
			shape.height = 0.85
			display.mesh = shape
			display.position = Vector3(side * (12.3 + display_index * 1.8), 0.43, center_z + (display_index - 1) * 1.15)
			display.material_override = material(Color(0.31 + 0.035 * index, 0.27, 0.21), 0.38)
			parent.add_child(display)

func add_scene_asset(parent: Node3D, path: String, position: Vector3, rotation: Vector3 = Vector3.ZERO, asset_scale: Vector3 = Vector3.ONE) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed = load(path) as PackedScene
	if packed == null:
		return null
	var instance = packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.position = position
	instance.rotation = rotation
	instance.scale = asset_scale
	parent.add_child(instance)
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.lod_bias = 1.5
	return instance

func build_concourse_props(parent):
	if not ResourceLoader.exists("res://assets/concourse_litter_bin.glb"):
		return
	for position in [Vector3(6.0, 0.0, -14.0), Vector3(-6.0, 0.0, 12.0), Vector3(6.0, 0.0, 22.0)]:
		add_scene_asset(parent, "res://assets/concourse_litter_bin.glb", position)

func build_planter(parent, position: Vector3):
	if ResourceLoader.exists("res://assets/concourse_planter_bench.glb"):
		add_scene_asset(parent, "res://assets/concourse_planter_bench.glb", position)
		return
	var pot = MeshInstance3D.new()
	var pot_mesh = CylinderMesh.new()
	pot_mesh.top_radius = 0.48
	pot_mesh.bottom_radius = 0.34
	pot_mesh.height = 0.62
	pot.mesh = pot_mesh
	pot.position = position + Vector3(0, 0.31, 0)
	pot.material_override = material(Color(0.19, 0.2, 0.18), 0.72)
	parent.add_child(pot)
	for i in range(7):
		var leaf = MeshInstance3D.new()
		var leaf_mesh = SphereMesh.new()
		leaf_mesh.radius = 0.22
		leaf_mesh.height = 0.72
		leaf.mesh = leaf_mesh
		var angle = TAU * float(i) / 7.0
		leaf.position = position + Vector3(cos(angle) * 0.28, 0.86 + randf_range(0.0, 0.24), sin(angle) * 0.28)
		leaf.scale = Vector3(0.72, 1.0, 0.72)
		leaf.material_override = material(Color(0.09, 0.17 + randf() * 0.08, 0.12), 0.92)
		parent.add_child(leaf)

func build_escalator(parent):
	var ramp_size = Vector3(4.2, 0.18, 12.0)
	var ramp_transform = Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 1.0, 5.5))
	if ResourceLoader.exists("res://assets/concourse_escalator.glb"):
		add_scene_asset(parent, "res://assets/concourse_escalator.glb", Vector3(0, 0.0, 5.5), Vector3.ZERO, Vector3(3.0, 0.3, 1.2))
	else:
		var ramp = MeshInstance3D.new()
		var ramp_mesh = BoxMesh.new()
		ramp_mesh.size = ramp_size
		ramp.mesh = ramp_mesh
		ramp.position = ramp_transform.origin
		ramp.rotation.x = -0.12
		ramp.material_override = material(Color(0.17, 0.18, 0.18), 0.42, 0.05)
		parent.add_child(ramp)
	var ramp_body = StaticBody3D.new()
	ramp_body.transform = ramp_transform
	var ramp_collision = CollisionShape3D.new()
	var ramp_shape = BoxShape3D.new()
	ramp_shape.size = ramp_size
	ramp_collision.shape = ramp_shape
	ramp_body.add_child(ramp_collision)
	parent.add_child(ramp_body)
	if not ResourceLoader.exists("res://assets/concourse_escalator.glb"):
		for side in [-1.0, 1.0]:
			var rail = MeshInstance3D.new()
			var rail_mesh = CylinderMesh.new()
			rail_mesh.top_radius = 0.055
			rail_mesh.bottom_radius = 0.055
			rail_mesh.height = 12.0
			rail.mesh = rail_mesh
			rail.position = Vector3(side * 2.05, 1.65, 5.5)
			rail.rotation.x = PI / 2.0 - 0.12
			rail.material_override = material(Color(0.46, 0.47, 0.44), 0.18, 0.1)
			parent.add_child(rail)

func build_security_office(parent):
	var office = Node3D.new()
	office.name = "SecurityOffice"
	parent.add_child(office)
	box(office, Vector3(-13, 0.03, 23), Vector3(14, 0.08, 10), material(Color(0.12, 0.13, 0.13)), false)
	box(office, Vector3(-17.5, 1.0, 18.2), Vector3(5.0, 2.0, 0.25), material(Color(0.24, 0.25, 0.24)), true)
	box(office, Vector3(-8.5, 1.0, 18.2), Vector3(5.0, 2.0, 0.25), material(Color(0.24, 0.25, 0.24)), true)
	box(office, Vector3(-20, 1.0, 23), Vector3(0.25, 2.0, 10), material(Color(0.24, 0.25, 0.24)), true)
	box(office, Vector3(-6, 1.0, 23), Vector3(0.25, 2.0, 10), material(Color(0.24, 0.25, 0.24)), true)
	box(office, Vector3(-13, 0.95, 24.5), Vector3(6.5, 1.1, 1.6), material(Color(0.12, 0.095, 0.075)), true)
	box(office, Vector3(-13, 1.55, 24.5), Vector3(6.7, 0.12, 1.7), material(Color(0.22, 0.2, 0.17)), false)
	for i in range(4):
		box(office, Vector3(-15.5 + i * 1.65, 2.55, 18.55), Vector3(1.5, 0.95, 0.12), material(Color(0.025, 0.055, 0.06)), false)
		var screen_light = OmniLight3D.new()
		screen_light.position = Vector3(-15.5 + i * 1.65, 2.5, 19.2)
		screen_light.light_color = Color(0.18, 0.42, 0.46)
		screen_light.light_energy = 0.18
		screen_light.omni_range = 2.0
		office.add_child(screen_light)

func build_food_court(parent):
	for i in range(4):
		var x = 7.0 + i * 3.0
		var top = MeshInstance3D.new()
		var top_mesh = CylinderMesh.new()
		top_mesh.top_radius = 0.92
		top_mesh.bottom_radius = 0.92
		top_mesh.height = 0.14
		top_mesh.radial_segments = 32
		top.mesh = top_mesh
		top.position = Vector3(x, 0.88, -20)
		top.material_override = material(Color(0.26, 0.22, 0.17), 0.28)
		parent.add_child(top)
		var stem = MeshInstance3D.new()
		var stem_mesh = CylinderMesh.new()
		stem_mesh.top_radius = 0.16
		stem_mesh.bottom_radius = 0.22
		stem_mesh.height = 0.72
		stem.mesh = stem_mesh
		stem.position = Vector3(x, 0.42, -20)
		stem.material_override = material(Color(0.12, 0.13, 0.13), 0.3)
		parent.add_child(stem)
	box(parent, Vector3(15, 2, -27), Vector3(8, 4, 0.3), material(Color(0.28, 0.24, 0.19)), true)
	label_3d(parent, Vector3(15, 3, -27.25), "FOOD COURT", Color(0.72, 0.62, 0.45))

func build_parking(parent):
	box(parent, Vector3(0, -0.12, 34), Vector3(42, 0.3, 12), material(Color(0.075, 0.08, 0.085)), true)
	for x in [-17, -8, 1, 10, 18]:
		box(parent, Vector3(x, 2.2, 34), Vector3(0.35, 4.4, 0.35), material(Color(0.16, 0.17, 0.17)), true)
	var car_colors = [Color(0.12, 0.16, 0.18), Color(0.2, 0.18, 0.15), Color(0.11, 0.12, 0.13), Color(0.24, 0.22, 0.18)]
	for car_index in range(4):
		var x = [-14, -5, 4, 13][car_index]
		var car = MeshInstance3D.new()
		var shell = SphereMesh.new()
		shell.radius = 1.0
		shell.height = 1.0
		car.mesh = shell
		car.scale = Vector3(2.25, 0.62, 1.05)
		car.position = Vector3(x, 0.78, 35)
		car.material_override = material(car_colors[car_index], 0.24, 0.015)
		parent.add_child(car)
		var cabin = MeshInstance3D.new()
		var cabin_mesh = SphereMesh.new()
		cabin_mesh.radius = 1.0
		cabin_mesh.height = 1.0
		cabin.mesh = cabin_mesh
		cabin.scale = Vector3(1.05, 0.52, 0.83)
		cabin.position = Vector3(x - 0.1, 1.23, 35)
		var window_mat = material(Color(0.045, 0.075, 0.085), 0.12, 0.04)
		cabin.material_override = window_mat
		parent.add_child(cabin)
		for wheel_side in [-1.0, 1.0]:
			for wheel_end in [-1.0, 1.0]:
				var wheel = MeshInstance3D.new()
				var wheel_mesh = CylinderMesh.new()
				wheel_mesh.top_radius = 0.34
				wheel_mesh.bottom_radius = 0.34
				wheel_mesh.height = 0.18
				wheel.mesh = wheel_mesh
				wheel.rotation.z = PI / 2.0
				wheel.position = Vector3(x + wheel_end * 1.35, 0.42, 35 + wheel_side * 0.88)
				wheel.material_override = material(Color(0.018, 0.02, 0.022), 0.92)
				parent.add_child(wheel)
		var collider = StaticBody3D.new()
		collider.position = Vector3(x, 0.78, 35)
		var collision = CollisionShape3D.new()
		var collision_shape = BoxShape3D.new()
		collision_shape.size = Vector3(4.2, 1.2, 1.8)
		collision.shape = collision_shape
		collider.add_child(collision)
		parent.add_child(collider)
	for x in [-18, -9, 0, 9, 18]:
		var lamp = OmniLight3D.new()
		lamp.position = Vector3(x, 3.8, 34)
		lamp.light_energy = 0.3
		lamp.omni_range = 7.0
		parent.add_child(lamp)

func build_doors(parent):
	make_interactable(parent, Vector3(-3, 1.4, 18), "RESTRICTED DOOR", "door_restricted", true)
	make_interactable(parent, Vector3(0, 1.4, 27), "PARKING ACCESS", "door_parking", true)
	make_interactable(parent, Vector3(-13, 1.2, 18.8), "SECURITY OFFICE", "office_door", false)

func build_anomaly_figure(parent):
	anomaly_figure = Node3D.new()
	anomaly_figure.name = "DistantFigure"
	anomaly_figure.position = Vector3(0, 0, -23)
	parent.add_child(anomaly_figure)
	var torso = box(anomaly_figure, Vector3(0, 1.15, 0), Vector3(0.55, 1.5, 0.28), material(Color(0.018, 0.02, 0.023)), false)
	var head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	head.mesh = sphere
	head.position.y = 2.05
	head.material_override = material(Color(0.012, 0.013, 0.015))
	anomaly_figure.add_child(head)
	anomaly_figure.visible = false

func build_interactables(parent):
	make_interactable(parent, Vector3(-13, 1.8, 25.5), "CCTV TERMINAL", "cctv", false)
	make_interactable(parent, Vector3(-11, 1.4, 24.3), "SHIFT PHONE", "phone", false)
	make_interactable(parent, Vector3(15, 1.2, -19), "MAINTENANCE LOG", "document_log", true)
	make_interactable(parent, Vector3(0, 1.2, 33), "PARKING INCIDENT REPORT", "document_report", true)
	make_interactable(parent, Vector3(0, 1.2, 8), "SERVICE PANEL", "power_panel", false)
	make_interactable(parent, Vector3(-12, 1.2, -15), "MISSING EMPLOYEE NOTICE", "document_notice", true)
	make_interactable(parent, Vector3(0, 1.2, -26), "MAIN ENTRANCE", "exit", false)

func make_interactable(parent, pos: Vector3, title: String, action: String, single: bool):
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.position = pos
	area.display_name = title
	area.action_id = action
	area.one_shot = single
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.5
	shape.shape = sphere
	area.add_child(shape)
	parent.add_child(area)
	return area

func build_player():
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector3(-13 * WORLD_SCALE, 0.1, 21.5 * WORLD_SCALE)
	add_child(player)
	player.interacted.connect(_on_interacted)

func build_menu_camera():
	menu_camera = Camera3D.new()
	menu_camera.name = "TitleCamera"
	menu_camera.position = Vector3(0, 5.0, 17 * WORLD_SCALE)
	menu_camera.fov = 58.0
	add_child(menu_camera)
	menu_camera.look_at(Vector3(0, 2.5, -14 * WORLD_SCALE), Vector3.UP)

func build_haunting():
	haunting = Node3D.new()
	haunting.name = "HauntingDirector"
	haunting.set_script(HauntingScript)
	add_child(haunting)
	haunting.configure(player, self)

func haunt_encounter():
	show_message("MOVE. DO NOT LOOK BACK.", 3.5)
	if is_instance_valid(player.camera):
		player.camera.fov = 88.0
		var tween = create_tween()
		tween.tween_property(player.camera, "fov", 78.0, 1.2)

func build_ui():
	ui = CanvasLayer.new()
	add_child(ui)
	var crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.add_theme_color_override("font_color", Color(0.8, 0.82, 0.8, 0.7))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-5, -12)
	ui.add_child(crosshair)
	clock_label = make_label(ui, "12:00 AM", Vector2(28, 22), 23, Color(0.86, 0.85, 0.78))
	objective_label = make_label(ui, current_objective, Vector2(28, 58), 15, Color(0.7, 0.71, 0.68))
	objective_label.custom_minimum_size = Vector2(520, 32)
	prompt_label = make_label(ui, "", Vector2(0, 0), 17, Color(0.9, 0.89, 0.82))
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-180, -88)
	prompt_label.size = Vector2(360, 36)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(28, 98)
	stamina_bar.size = Vector2(150, 5)
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	ui.add_child(stamina_bar)
	battery_label = make_label(ui, "FLASHLIGHT  /  100%", Vector2(28, 111), 12, Color(0.62, 0.68, 0.67))
	message_label = make_label(ui, "", Vector2(0, 110), 18, Color(0.86, 0.84, 0.76))
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.size = Vector2(700, 40)
	message_label.position.x = -350
	var timer = Timer.new()
	timer.name = "MessageTimer"
	timer.one_shot = true
	timer.timeout.connect(func(): message_label.text = "")
	ui.add_child(timer)
	build_cctv_ui()
	build_overlay()

func build_cctv_ui():
	feed_view = SubViewport.new()
	feed_view.size = Vector2i(960, 540)
	feed_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	feed_view.size = Vector2i(640, 360)
	feed_view.world_3d = get_viewport().world_3d
	feed_camera = Camera3D.new()
	feed_camera.current = true
	feed_camera.fov = 74
	feed_view.add_child(feed_camera)
	ui.add_child(feed_view)
	feed = TextureRect.new()
	feed.texture = feed_view.get_texture()
	feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	feed.size = Vector2(900, 506)
	feed.position = Vector2(-450, -253)
	feed.visible = false
	ui.add_child(feed)

func build_overlay():
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.64)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	ui.add_child(overlay)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 470)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -235)
	panel.add_theme_stylebox_override("panel", panel_style())
	overlay.add_child(panel)

func make_label(parent, text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func textured_material(base_color: Color, roughness_value: float, metallic_value: float, frequency: float) -> StandardMaterial3D:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.52
	noise.fractal_lacunarity = 2.0
	var size = 256
	var albedo_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var normal_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var height_value = noise.get_noise_2d(float(x), float(y))
			var shade = clampf(0.72 + height_value * 0.28, 0.28, 1.0)
			albedo_image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
			var dx = noise.get_noise_2d(float(x + 1), float(y)) - noise.get_noise_2d(float(x - 1), float(y))
			var dy = noise.get_noise_2d(float(x), float(y + 1)) - noise.get_noise_2d(float(x), float(y - 1))
			var normal = Vector3(-dx * 2.2, -dy * 2.2, 1.0).normalized()
			normal_image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, 1.0))
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.albedo_texture = ImageTexture.create_from_image(albedo_image)
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(normal_image)
	mat.normal_scale = 0.28
	mat.roughness = roughness_value
	mat.metallic = metallic_value
	mat.uv1_scale = Vector3(4.0, 4.0, 4.0)
	return mat

func material(color: Color, roughness := 0.8, emission := 0.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func box(parent, pos: Vector3, size: Vector3, mat: Material, collision := false):
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	if collision:
		var body = StaticBody3D.new()
		body.position = pos
		var shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)
	return mesh_instance

func label_3d(parent, pos: Vector3, value: String, color: Color):
	var label = Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = 44
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _on_interacted(target):
	if target is Area3D:
		target.activate(self)

func handle_interaction(target):
	var id = target.action_id
	match id:
		"cctv":
			open_terminal()
		"phone":
			show_message("SUPERVISOR: Keep to the patrol route. If a camera shows someone, do not approach them.", 6.0)
			decisions["phone_warning_heard"] = true
		"document_log":
			collect_evidence("maintenance_log", "Maintenance log: The west corridor camera records a door that does not exist on the floor plan. Staff are instructed not to enter it.")
		"document_report":
			collect_evidence("parking_report", "Incident report: Guard Elias Venn clocked in at 00:03 and never clocked out. His patrol route ends beneath the old cinema.")
		"document_notice":
			collect_evidence("employee_notice", "Employee notice: Three night staff have resigned without collecting their final wages. Their access cards remain active.")
		"power_panel":
			if not completed.get("power", false):
				completed["power"] = true
				set_objective("Check camera 04 in the security office.")
				show_message("EAST WING POWER RESTORED", 3.0)
			else:
				show_message("The panel is already stable.", 2.0)
		"door_restricted":
			if elapsed < 180.0 and not completed.get("restricted_unlocked", false):
				show_message("ACCESS DENIED  /  SUPERVISOR KEY REQUIRED", 3.0)
			else:
				completed["restricted_unlocked"] = true
				set_objective("Find the incident report in the underground parking.")
				show_message("LOCK RELEASED", 2.0)
		"door_parking":
			if completed.get("restricted_unlocked", false):
				player.position = Vector3(0, 0.1, 31 * WORLD_SCALE)
				show_message("PARKING LEVEL  /  CAMERA SIGNAL WEAK", 3.0)
			else:
				show_message("The access lock is still engaged.", 2.0)
		"office_door":
			player.position = Vector3(-13 * WORLD_SCALE, 0.1, 21.5 * WORLD_SCALE) if player.position.z > 18 * WORLD_SCALE else Vector3(-13 * WORLD_SCALE, 0.1, 14 * WORLD_SCALE)
		"exit":
			if elapsed >= 300.0:
				finish_game()
			else:
				show_message("The main doors are locked until the shift ends.", 3.0)
		"inspect":
			show_message(target.description, 3.0)

func collect_evidence(key: String, text_value: String):
	if discovered.has(key):
		show_message("Already documented.", 2.0)
		return
	discovered[key] = true
	evidence.append(key)
	show_message(text_value, 7.0)
	if evidence.size() == 1:
		set_objective("Restore power at the east wing service panel.")
	elif evidence.size() >= 2:
		set_objective("Access the restricted maintenance corridor.")

func set_objective(value: String):
	current_objective = value
	if is_instance_valid(objective_label):
		objective_label.text = "OBJECTIVE  /  " + value

func show_message(value: String, duration := 3.0):
	if not is_instance_valid(message_label):
		return
	message_label.text = value
	var timer = ui.get_node_or_null("MessageTimer")
	if timer:
		timer.start(duration)

func update_clock():
	var total_minutes = int(floor(elapsed / shift_duration * 360.0))
	var hour = int(floor(total_minutes / 60.0))
	var minute = total_minutes % 60
	var display_hour = hour % 12
	if display_hour == 0:
		display_hour = 12
	clock_label.text = "%02d:%02d %s" % [display_hour, minute, "AM"]

func update_hud():
	stamina_bar.value = player.stamina
	battery_label.text = "FLASHLIGHT  /  %d%%" % int(player.flashlight_battery)
	var hit = player.ray.get_collider() if player.ray.is_colliding() else null
	if hit is Area3D and hit.has_method("activate"):
		prompt_label.text = "[ E ]  " + hit.display_name
	elif hit and hit.get_parent() is Area3D:
		prompt_label.text = "[ E ]  " + hit.get_parent().display_name
	else:
		prompt_label.text = ""

func update_story_events():
	if elapsed > 55.0 and not event_flags.get("first_call", false):
		event_flags["first_call"] = true
		show_message("RADIO: Did you hear that? Probably the shutters. Keep moving.", 5.0)
	if elapsed > 90.0 and not event_flags.get("lights", false):
		event_flags["lights"] = true
		show_message("A fluorescent ballast snaps somewhere above you.", 4.0)
	if elapsed > 125.0 and not event_flags.get("figure", false):
		event_flags["figure"] = true
		anomaly_active = true
		anomaly_figure.visible = true
		show_message("CAMERA MOVEMENT DETECTED  /  CENTRAL ATRIUM", 5.0)
	if elapsed > 160.0 and not event_flags.get("figure_gone", false):
		event_flags["figure_gone"] = true
		anomaly_figure.visible = false
	if elapsed > 220.0 and not event_flags.get("voice", false):
		event_flags["voice"] = true
		show_message("UNKNOWN VOICE: You weren't supposed to come back.", 5.0)
	if elapsed > 270.0 and not event_flags.get("final", false):
		event_flags["final"] = true
		set_objective("Return to the main entrance and leave the mall.")
		show_message("FINAL HOUR  /  THE FRONT DOORS ARE UNLOCKING", 5.0)

func update_light_anomalies(delta: float):
	if elapsed < 95.0:
		return
	if flicker_duration > 0.0:
		flicker_duration -= delta
		for item in flicker_restore:
			var lamp: OmniLight3D = item["node"]
			if is_instance_valid(lamp):
				lamp.light_energy = randf_range(0.0, 0.12) if randf() < 0.76 else item["energy"]
		if flicker_duration <= 0.0:
			for item in flicker_restore:
				var lamp: OmniLight3D = item["node"]
				if is_instance_valid(lamp):
					lamp.light_energy = item["energy"]
			flicker_restore.clear()
			next_flicker = randf_range(38.0, 68.0)
		return
	next_flicker -= delta
	if next_flicker > 0.0 or mall_lights.is_empty():
		return
	var chosen: Array = []
	for i in range(4):
		var lamp = mall_lights[randi_range(0, mall_lights.size() - 1)]
		if lamp not in chosen:
			chosen.append(lamp)
	for lamp in chosen:
		flicker_restore.append({"node": lamp, "energy": lamp.light_energy})
	flicker_duration = randf_range(2.0, 4.5)
	show_message("The lights above you begin to fail.", 3.0)

func open_terminal():
	terminal_open = true
	feed_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	feed.visible = true
	feed_index = 0
	set_feed_camera()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_message("CCTV  /  LEFT AND RIGHT ARROWS TO CHANGE CAMERA  /  ESC TO EXIT", 4.0)

func set_feed_camera():
	feed_camera.global_position = Vector3(feed_positions[feed_index].x * WORLD_SCALE, feed_positions[feed_index].y, feed_positions[feed_index].z * WORLD_SCALE)
	feed_camera.look_at(Vector3(0, 1.2, (feed_positions[feed_index].z - 10) * WORLD_SCALE), Vector3.UP)
	if feed_index == 1:
		feed_camera.look_at(Vector3(13 * WORLD_SCALE, 1, -20 * WORLD_SCALE), Vector3.UP)
	elif feed_index == 2:
		feed_camera.look_at(Vector3(-8 * WORLD_SCALE, 1, -10 * WORLD_SCALE), Vector3.UP)
	elif feed_index == 3:
		feed_camera.look_at(Vector3(0, 1, 34 * WORLD_SCALE), Vector3.UP)
	show_message("CAM %02d  /  %s" % [feed_index + 1, feed_names[feed_index]], 2.0)

func change_camera(direction: int):
	feed_index = posmod(feed_index + direction, feed_names.size())
	set_feed_camera()

func close_terminal():
	terminal_open = false
	feed_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	feed.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_story_intro():
	paused = true
	menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	var story = "NORTHSTAR MALL CLOSED EIGHT YEARS AGO. THE COMPANY SAID IT WAS A ROUTINE SHUTDOWN.\n\nNIGHT GUARD ELIAS VENN WAS THE LAST PERSON TO CLOCK IN. HIS SHIFT LOG SHOWS HE LEFT AT 6:00 AM. THE CAMERAS SHOW HIM WALKING INTO THE SEALED CINEMA AT 3:17 AM.\n\nTHE BUILDING WAS NEVER REOPENED. TONIGHT, YOU HAVE BEEN SENT TO CATALOGUE THE REMAINING RECORDS BEFORE THE SITE IS DEMOLISHED.\n\nYOUR NAME IS ALREADY WRITTEN IN THE SHIFT BOOK."
	show_menu("THE LAST SHIFT", [["CONTINUE", "intro_continue"], ["SKIP STORY", "intro_skip"]], story)
	var glide = create_tween()
	glide.set_parallel(true)
	glide.tween_property(menu_camera, "position", menu_camera.position + Vector3(0.0, -0.35, -4.5), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glide.tween_property(menu_camera, "rotation", menu_camera.rotation + Vector3(0.015, 0.07, 0.0), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func show_main_menu():
	paused = true
	menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	show_menu("AFTERHOURS", [["NEW SHIFT", "new"], ["CONTINUE", "load"], ["SETTINGS", "settings"], ["CREDITS", "credits"], ["EXIT", "exit"]], "A SHIFT THAT NEVER ENDS")

func open_pause():
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	show_menu("PAUSED", [["RESUME", "resume"], ["OBJECTIVES", "objectives"], ["SAVE GAME", "save"], ["LOAD GAME", "load"], ["MAIN MENU", "menu"]])

func resume_game():
	paused = false
	overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_objectives():
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	var list_text = "SHIFT RECORD\n\n" + current_objective + "\n\nEVIDENCE RECOVERED: " + str(evidence.size()) + "/3\n"
	for item in evidence:
		list_text += "\n• " + item.replace("_", " ").to_upper()
	show_menu("OBJECTIVES", [["BACK", "resume"], ["SAVE GAME", "save"]], list_text)

func show_menu(title_text: String, actions: Array, body_text := ""):
	for child in panel.get_children():
		child.queue_free()
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var brand = TextureRect.new()
	brand.texture = load("res://assets/afterhours_logo.svg")
	brand.custom_minimum_size = Vector2(440, 126)
	brand.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(brand)
	var title = Label.new()
	title.text = title_text if title_text != "AFTERHOURS" else "NIGHT SECURITY  /  SHIFT 001"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.72, 0.75, 0.72))
	layout.add_child(title)
	if body_text != "":
		var body = Label.new()
		body.text = body_text
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.y = 120
		layout.add_child(body)
	for action in actions:
		var button = Button.new()
		button.text = action[0]
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", menu_button_style(Color(0.055, 0.067, 0.071, 0.92), Color(0.24, 0.29, 0.29, 0.8)))
		button.add_theme_stylebox_override("hover", menu_button_style(Color(0.11, 0.14, 0.145, 0.98), Color(0.65, 0.57, 0.42, 0.95)))
		button.add_theme_stylebox_override("pressed", menu_button_style(Color(0.18, 0.2, 0.19, 1.0), Color(0.82, 0.7, 0.5, 1.0)))
		button.add_theme_stylebox_override("focus", menu_button_style(Color(0.08, 0.1, 0.11, 1.0), Color(0.65, 0.57, 0.42, 1.0)))
		button.add_theme_color_override("font_color", Color(0.78, 0.8, 0.77))
		button.add_theme_color_override("font_hover_color", Color(0.96, 0.88, 0.72))
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_menu_action.bind(action[1]))
		layout.add_child(button)

func _menu_action(action: String):
	match action:
		"intro_continue", "intro_skip":
			show_main_menu()
		"resume":
			resume_game()
		"objectives":
			show_objectives()
		"save":
			save_game()
		"load":
			load_game()
		"menu":
			get_tree().reload_current_scene()
		"new":
			elapsed = 0.0
			completed.clear()
			evidence.clear()
			discovered.clear()
			decisions.clear()
			event_flags.clear()
			player.position = Vector3(-13 * WORLD_SCALE, 0.1, 21.5 * WORLD_SCALE)
			player.camera.current = true
			if is_instance_valid(haunting):
				haunting.reset_hunt()
			set_objective("Report to the security office.")
			resume_game()
			show_message("SHIFT STARTED  /  12:00 AM", 4.0)
		"settings":
			show_settings()
		"credits":
			show_menu("CREDITS", [["BACK", "resume"]], "AFTERHOURS\nA psychological horror game\nBuilt with Godot 4.")
		"exit":
			get_tree().quit()

func show_settings():
	for child in panel.get_children():
		child.queue_free()
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	var sensitivity = HSlider.new()
	sensitivity.min_value = 0.0008
	sensitivity.max_value = 0.005
	sensitivity.step = 0.0001
	sensitivity.value = player.look_sensitivity
	make_setting_row(layout, "MOUSE SENSITIVITY", sensitivity)
	sensitivity.value_changed.connect(func(value): player.look_sensitivity = value)
	var volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	make_setting_row(layout, "MASTER VOLUME", volume)
	volume.value_changed.connect(func(value): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001))))
	var back = Button.new()
	back.text = "BACK"
	back.pressed.connect(func(): show_menu("PAUSED", [["RESUME", "resume"], ["OBJECTIVES", "objectives"], ["SAVE GAME", "save"], ["LOAD GAME", "load"], ["MAIN MENU", "menu"]]))
	layout.add_child(back)

func make_setting_row(parent: VBoxContainer, title_text: String, control: Control) -> Control:
	var row = VBoxContainer.new()
	var label = Label.new()
	label.text = title_text
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
	return row

func save_game():
	var data = {"elapsed": elapsed, "position": [player.position.x, player.position.y, player.position.z], "rotation": player.rotation.y, "objective": current_objective, "completed": completed, "evidence": evidence, "discovered": discovered, "decisions": decisions, "event_flags": event_flags}
	if SaveSystem.write_save(data):
		show_message("GAME SAVED", 2.0)
	else:
		show_message("SAVE FAILED", 3.0)

func load_game():
	var data = SaveSystem.read_save()
	if data.is_empty():
		show_message("NO VALID SAVE FOUND", 3.0)
		return
	elapsed = float(data.get("elapsed", 0.0))
	var pos = data.get("position", [-13 * WORLD_SCALE, 0.1, 14 * WORLD_SCALE])
	if pos is Array and pos.size() == 3:
		player.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player.rotation.y = float(data.get("rotation", 0.0))
	current_objective = str(data.get("objective", current_objective))
	completed = data.get("completed", {})
	evidence = data.get("evidence", [])
	discovered = data.get("discovered", {})
	decisions = data.get("decisions", {})
	event_flags = data.get("event_flags", {})
	set_objective(current_objective)
	resume_game()
	show_message("SAVE LOADED", 2.0)

func finish_game():
	if ending:
		return
	ending = true
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	var ending_title = "THE MORNING SHIFT"
	var ending_body = "At 6:00 AM the shutters rise. The mall is empty. Your incident report is already signed.\n\nEvidence recovered: %d / 3\n\nThe security office phone rings one last time." % evidence.size()
	if evidence.size() >= 3:
		ending_title = "THE NIGHT ARCHIVE"
		ending_body = "You leave with the records. By sunrise, the mall's official floor plan has changed again. Your name is listed among the missing guards.\n\nYou found enough to know the truth. You did not find a way to prove it."
	elif evidence.size() == 0:
		ending_title = "NO RECORD"
		ending_body = "You make it outside, but your shift log is blank. The company says you never worked there. The next night, another guard takes your place."
	show_menu(ending_title, [["PLAY AGAIN", "menu"]], ending_body)

func menu_button_style(fill_color: Color, edge_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = edge_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.023, 0.028, 0.78)
	style.border_color = Color(0.34, 0.34, 0.31, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(28)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 8)
	return style

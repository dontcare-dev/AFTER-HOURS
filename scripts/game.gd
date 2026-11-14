extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const InteractableScript = preload("res://scripts/interactable.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

var player
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
var anomaly_active := false
var event_flags := {}
var mall_materials := {}

func _ready():
	build_world()
	build_player()
	build_ui()
	set_objective("Report to the security office.")
	show_message("SHIFT STARTED  /  12:00 AM", 4.0)
	show_main_menu()

func _process(delta):
	if paused or terminal_open or ending:
		return
	elapsed = minf(shift_duration, elapsed + delta)
	update_clock()
	update_hud()
	update_story_events()
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
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.075, 0.08, 0.085)
	environment.fog_density = 0.009
	world_env.environment = environment
	add_child(world_env)
	var mall = Node3D.new()
	mall.name = "Mall"
	add_child(mall)
	var floor_mat = material(Color(0.19, 0.19, 0.18), 0.08)
	var wall_mat = material(Color(0.32, 0.31, 0.28))
	var dark_mat = material(Color(0.045, 0.05, 0.055))
	var tile_mat = material(Color(0.28, 0.28, 0.26), 0.12)
	var ceiling_mat = material(Color(0.13, 0.14, 0.14))
	box(mall, Vector3(0, -0.25, 0), Vector3(42, 0.5, 58), floor_mat, true)
	box(mall, Vector3(0, 6.2, 0), Vector3(42, 0.5, 58), ceiling_mat, false)
	box(mall, Vector3(-21, 3, 0), Vector3(0.5, 6, 58), wall_mat, true)
	box(mall, Vector3(21, 3, 0), Vector3(0.5, 6, 58), wall_mat, true)
	box(mall, Vector3(0, 3, -29), Vector3(42, 6, 0.5), wall_mat, true)
	box(mall, Vector3(0, 3, 29), Vector3(42, 6, 0.5), wall_mat, true)
	for x in [-15, -10, -5, 0, 5, 10, 15]:
		box(mall, Vector3(x, 0.012, 0), Vector3(0.035, 0.02, 56), tile_mat, false)
	for z in range(-25, 29, 5):
		box(mall, Vector3(0, 0.013, z), Vector3(40, 0.02, 0.035), tile_mat, false)
	for x in [-18, -12, -6, 0, 6, 12, 18]:
		for z in [-23, -13, -3, 7, 17, 25]:
			var light = OmniLight3D.new()
			light.position = Vector3(x, 5.55, z)
			light.light_color = Color(0.78, 0.82, 0.88)
			light.light_energy = 0.7 if z > -20 else 0.42
			light.omni_range = 10.0
			light.shadow_enabled = false
			mall.add_child(light)
			var fixture = box(mall, Vector3(x, 5.88, z), Vector3(2.2, 0.12, 0.48), material(Color(0.62, 0.65, 0.65), 0.2, 0.3), false)
	for side in [-1, 1]:
		for z in [-20, -10, 0, 10, 20]:
			var shop_x = side * 15.0
			box(mall, Vector3(shop_x, 2.0, z), Vector3(11.5, 4.0, 0.35), dark_mat, true)
			box(mall, Vector3(shop_x, 3.9, z), Vector3(11.5, 0.45, 0.5), wall_mat, false)
			var sign = label_3d(mall, Vector3(shop_x, 3.0, z - 0.28), ["MERCURY", "CLOTHING", "HOME & CO", "TOYS", "NORTH STAR"][posmod(z + 20, 5)], Color(0.72, 0.7, 0.62))
	box(mall, Vector3(0, 2.2, -27), Vector3(10, 4.4, 0.3), wall_mat, true)
	box(mall, Vector3(0, 2.2, 27), Vector3(10, 4.4, 0.3), wall_mat, true)
	box(mall, Vector3(0, 2.4, 18), Vector3(9, 4.8, 0.4), wall_mat, true)
	box(mall, Vector3(0, 2.4, 18), Vector3(4, 4.8, 0.6), dark_mat, false)
	box(mall, Vector3(-10, 2.0, -17), Vector3(8, 4, 0.35), wall_mat, true)
	box(mall, Vector3(10, 2.0, -17), Vector3(8, 4, 0.35), wall_mat, true)
	box(mall, Vector3(-10, 2.0, 14), Vector3(8, 4, 0.35), wall_mat, true)
	box(mall, Vector3(10, 2.0, 14), Vector3(8, 4, 0.35), wall_mat, true)
	for i in range(8):
		box(mall, Vector3(-2.8 + i * 0.8, 0.3 + i * 0.27, 9 - i * 0.9), Vector3(0.7, 0.2, 3.5), material(Color(0.24, 0.25, 0.25)), true)
	build_security_office(mall)
	build_food_court(mall)
	build_parking(mall)
	build_doors(mall)
	build_anomaly_figure(mall)
	build_interactables(mall)
	var outside_light = DirectionalLight3D.new()
	outside_light.rotation_degrees = Vector3(-55, -25, 0)
	outside_light.light_energy = 0.12
	mall.add_child(outside_light)

func build_security_office(parent):
	var office = Node3D.new()
	office.name = "SecurityOffice"
	parent.add_child(office)
	box(office, Vector3(-13, 0.03, 23), Vector3(14, 0.08, 10), material(Color(0.12, 0.13, 0.13)), false)
	box(office, Vector3(-13, 1.0, 18.2), Vector3(14, 2.0, 0.25), material(Color(0.24, 0.25, 0.24)), true)
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
		var table = box(parent, Vector3(x, 0.85, -20), Vector3(2.0, 0.12, 1.2), material(Color(0.24, 0.2, 0.16)), true)
		for side in [-1, 1]:
			box(parent, Vector3(x, 0.45, -20 + side * 1.0), Vector3(0.22, 0.85, 0.22), material(Color(0.12, 0.12, 0.11)), true)
	box(parent, Vector3(15, 2, -27), Vector3(8, 4, 0.3), material(Color(0.28, 0.24, 0.19)), true)
	label_3d(parent, Vector3(15, 3, -27.25), "FOOD COURT", Color(0.72, 0.62, 0.45))

func build_parking(parent):
	box(parent, Vector3(0, -0.12, 34), Vector3(42, 0.3, 12), material(Color(0.075, 0.08, 0.085)), true)
	for x in [-17, -8, 1, 10, 18]:
		box(parent, Vector3(x, 2.2, 34), Vector3(0.35, 4.4, 0.35), material(Color(0.16, 0.17, 0.17)), true)
	for x in [-14, -5, 4, 13]:
		box(parent, Vector3(x, 0.8, 35), Vector3(4.5, 1.4, 1.8), material(Color(0.12, 0.14, 0.16)), true)
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
	player.position = Vector3(-13, 0.1, 14)
	add_child(player)
	player.interacted.connect(_on_interacted)

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
	feed_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	overlay.color = Color(0, 0, 0, 0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	ui.add_child(overlay)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 340)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -170)
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
				player.position = Vector3(0, 0.1, 31)
				show_message("PARKING LEVEL  /  CAMERA SIGNAL WEAK", 3.0)
			else:
				show_message("The access lock is still engaged.", 2.0)
		"office_door":
			player.position = Vector3(-13, 0.1, 14) if player.position.z > 18 else Vector3(-13, 0.1, 20)
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

func open_terminal():
	terminal_open = true
	feed.visible = true
	feed_index = 0
	set_feed_camera()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_message("CCTV  /  LEFT AND RIGHT ARROWS TO CHANGE CAMERA  /  ESC TO EXIT", 4.0)

func set_feed_camera():
	feed_camera.global_position = feed_positions[feed_index]
	feed_camera.look_at(Vector3(0, 1.2, feed_positions[feed_index].z - 10), Vector3.UP)
	if feed_index == 1:
		feed_camera.look_at(Vector3(13, 1, -20), Vector3.UP)
	elif feed_index == 2:
		feed_camera.look_at(Vector3(-8, 1, -10), Vector3.UP)
	elif feed_index == 3:
		feed_camera.look_at(Vector3(0, 1, 34), Vector3.UP)
	show_message("CAM %02d  /  %s" % [feed_index + 1, feed_names[feed_index]], 2.0)

func change_camera(direction: int):
	feed_index = posmod(feed_index + direction, feed_names.size())
	set_feed_camera()

func close_terminal():
	terminal_open = false
	feed.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_main_menu():
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = true
	show_menu("AFTERHOURS", [["NEW SHIFT", "new"], ["CONTINUE", "load"], ["SETTINGS", "settings"], ["CREDITS", "credits"], ["EXIT", "exit"]], "NIGHT SECURITY  /  SHIFT 001")

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
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.82, 0.8, 0.72))
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
		button.custom_minimum_size.y = 38
		button.pressed.connect(_menu_action.bind(action[1]))
		layout.add_child(button)

func _menu_action(action: String):
	match action:
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
			player.position = Vector3(-13, 0.1, 14)
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
	layout.add_child(make_setting_row(layout, "MOUSE SENSITIVITY", sensitivity))
	sensitivity.value_changed.connect(func(value): player.look_sensitivity = value)
	var volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	layout.add_child(make_setting_row(layout, "MASTER VOLUME", volume))
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
	var pos = data.get("position", [-13, 0.1, 14])
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

func panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.045, 0.97)
	style.border_color = Color(0.34, 0.34, 0.31, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	return style

extends Node3D

var target: CharacterBody3D
var controller: Node
var reveal_cooldown := 28.0
var hunt_time := 0.0
var active := false
var drone_player: AudioStreamPlayer
var sting_player: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
var figure_torso: MeshInstance3D
var figure_head: MeshInstance3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var idle_time := 0.0

func configure(actor: CharacterBody3D, game: Node):
	target = actor
	controller = game
	rng.randomize()
	build_figure()
	build_audio()
	set_process(true)

func build_figure():
	var body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.006, 0.008, 0.011)
	body_material.roughness = 1.0
	body_material.emission_enabled = true
	body_material.emission = Color(0.008, 0.012, 0.018)
	body_material.emission_energy_multiplier = 0.2
	figure_torso = MeshInstance3D.new()
	var torso = figure_torso
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.31
	torso_mesh.height = 1.65
	torso.mesh = torso_mesh
	torso.position.y = 1.0
	torso.material_override = body_material
	add_child(torso)
	figure_head = MeshInstance3D.new()
	var head = figure_head
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position.y = 2.0
	head.material_override = body_material
	add_child(head)
	for side in [-1.0, 1.0]:
		var arm = Node3D.new()
		arm.position = Vector3(side * 0.34, 1.55, 0.0)
		var arm_mesh = MeshInstance3D.new()
		var arm_shape = CapsuleMesh.new()
		arm_shape.radius = 0.115
		arm_shape.height = 0.9
		arm_mesh.mesh = arm_shape
		arm_mesh.position = Vector3(0.0, -0.34, 0.0)
		arm_mesh.material_override = body_material
		arm.add_child(arm_mesh)
		add_child(arm)
		var leg = Node3D.new()
		leg.position = Vector3(side * 0.16, 0.55, 0.0)
		var leg_mesh = MeshInstance3D.new()
		var leg_shape = CapsuleMesh.new()
		leg_shape.radius = 0.14
		leg_shape.height = 1.05
		leg_mesh.mesh = leg_shape
		leg_mesh.position.y = -0.22
		leg_mesh.material_override = body_material
		leg.add_child(leg_mesh)
		add_child(leg)
		if side < 0.0:
			arm_left = arm
			leg_left = leg
		else:
			arm_right = arm
			leg_right = leg
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.035
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.09, 2.02, -0.205)
		var eye_material = StandardMaterial3D.new()
		eye_material.albedo_color = Color(0.32, 0.42, 0.45)
		eye_material.emission_enabled = true
		eye_material.emission = Color(0.22, 0.36, 0.42)
		eye_material.emission_energy_multiplier = 1.6
		eye.material_override = eye_material
		add_child(eye)
	visible = false

func build_audio():
	drone_player = AudioStreamPlayer.new()
	drone_player.name = "MallDrone"
	drone_player.stream = make_drone()
	drone_player.volume_db = -25.0
	add_child(drone_player)
	drone_player.play()
	sting_player = AudioStreamPlayer.new()
	sting_player.name = "EncounterSting"
	sting_player.volume_db = -13.0
	add_child(sting_player)

func make_drone() -> AudioStreamWAV:
	var rate = 22050
	var count = rate * 4
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t = float(i) / rate
		var sample = sin(t * TAU * 43.0) * 0.075 + sin(t * TAU * 51.5) * 0.045 + sin(t * TAU * 67.0) * 0.018
		sample += rng.randf_range(-0.008, 0.008)
		var envelope = minf(1.0, float(i) / 500.0) * minf(1.0, float(count - i) / 500.0)
		var value = int(clampf(sample * envelope, -1.0, 1.0) * 32767.0)
		bytes[i * 2] = value & 255
		bytes[i * 2 + 1] = (value >> 8) & 255
	var stream = AudioStreamWAV.new()
	stream.data = bytes
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream

func _process(delta):
	idle_time += delta
	if visible:
		figure_torso.position.y = 1.0 + sin(idle_time * 2.0) * 0.025
		figure_head.rotation.y = sin(idle_time * 0.8) * 0.18
		arm_left.rotation.z = -0.12 + sin(idle_time * 2.3) * 0.07
		arm_right.rotation.z = 0.12 - sin(idle_time * 2.3) * 0.07
		leg_left.rotation.x = sin(idle_time * 2.3) * 0.025
		leg_right.rotation.x = -sin(idle_time * 2.3) * 0.025
	if not is_instance_valid(target) or not is_instance_valid(controller):
		return
	if controller.paused or controller.terminal_open or controller.ending:
		return
	if not active:
		reveal_cooldown -= delta
		if reveal_cooldown <= 0.0 and controller.elapsed > 75.0:
			begin_hunt()
		return
	hunt_time += delta
	var to_player = target.global_position - global_position
	var distance = to_player.length()
	var camera_forward = -target.camera.global_transform.basis.z
	var to_figure = (global_position - target.camera.global_position).normalized()
	var watched = camera_forward.dot(to_figure) > 0.76 and distance < 24.0
	if watched:
		end_hunt()
		return
	if distance > 3.2:
		global_position += to_player.normalized() * delta * (0.75 + minf(hunt_time * 0.025, 0.9))
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	else:
		if controller.has_method("haunt_encounter"):
			controller.haunt_encounter()
		end_hunt()
	if hunt_time > 24.0:
		end_hunt()

func begin_hunt():
	active = true
	hunt_time = 0.0
	var behind = target.global_basis.z
	var side = target.global_basis.x * rng.randf_range(-5.0, 5.0)
	global_position = target.global_position + behind * rng.randf_range(10.0, 15.0) + side
	global_position.y = 0.0
	look_at(Vector3(target.global_position.x, 1.0, target.global_position.z), Vector3.UP)
	visible = true

func end_hunt():
	active = false
	visible = false
	reveal_cooldown = rng.randf_range(25.0, 42.0)

func reset_hunt():
	active = false
	visible = false
	hunt_time = 0.0
	reveal_cooldown = 20.0

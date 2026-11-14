extends CharacterBody3D

signal interacted(target)
var look_sensitivity := 0.0022
var stamina := 100.0
var flashlight_on := true
var crouched := false
var gravity := 18.0
var camera: Camera3D
var ray: RayCast3D
var lamp: SpotLight3D
var body_height := 1.7

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var capsule = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = body_height
	shape.radius = 0.34
	capsule.shape = shape
	capsule.position.y = body_height * 0.5
	add_child(capsule)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.55, 0)
	camera.current = true
	camera.fov = 78.0
	add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	camera.add_child(ray)
	lamp = SpotLight3D.new()
	lamp.position = Vector3(0.12, -0.12, -0.15)
	lamp.rotation_degrees.x = -5
	lamp.spot_range = 19.0
	lamp.spot_angle = 38.0
	lamp.light_energy = 2.2
	lamp.shadow_enabled = true
	camera.add_child(lamp)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * look_sensitivity)
		camera.rotate_x(-event.relative.y * look_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.48, 1.48)
	if event.is_action_pressed("flashlight"):
		flashlight_on = !flashlight_on
		lamp.visible = flashlight_on
	if event.is_action_pressed("crouch"):
		crouched = !crouched
		var target_height = 1.12 if crouched else body_height
		(camera.position.y) = target_height - 0.15
		($CollisionShape3D.shape as CapsuleShape3D).height = target_height
		$CollisionShape3D.position.y = target_height * 0.5
	if event.is_action_pressed("interact"):
		if ray.is_colliding():
			var hit = ray.get_collider()
			if hit is Area3D:
				interacted.emit(hit)
			elif hit.get_parent() is Area3D:
				interacted.emit(hit.get_parent())

func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var moving = direction.length() > 0.1
	var sprinting = Input.is_action_pressed("sprint") and stamina > 1.0 and not crouched and moving
	var speed = 4.5 if crouched else (7.0 if sprinting else 4.7)
	if sprinting:
		stamina = maxf(0.0, stamina - 24.0 * delta)
	else:
		stamina = minf(100.0, stamina + 14.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2
	var target = direction * speed
	velocity.x = move_toward(velocity.x, target.x, 18.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 18.0 * delta)
	move_and_slide()

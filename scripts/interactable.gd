extends Area3D

@export var action_id := "inspect"
@export var display_name := "Inspect"
@export_multiline var description := ""
@export var one_shot := false
var used := false

func _ready():
	monitoring = true
	monitorable = true
	if get_child_count() == 0:
		var shape = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 1.1
		shape.shape = sphere
		add_child(shape)

func activate(game):
	if one_shot and used:
		return
	used = true
	game.handle_interaction(self)

extends SceneTree

func _initialize():
	var project = ConfigFile.new()
	var result = project.load("res://project.godot")
	if result != OK:
		push_error("project.godot could not be loaded")
		quit(1)
		return
	var required = ["res://scenes/main.tscn", "res://scripts/game.gd", "res://scripts/player.gd", "res://scripts/interactable.gd", "res://scripts/save_system.gd"]
	for path in required:
		if not ResourceLoader.exists(path):
			push_error("Missing required resource: " + path)
			quit(1)
			return
	print("AFTERHOURS project validation passed")
	quit(0)

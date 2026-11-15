extends SceneTree

func _initialize():
	var project = ConfigFile.new()
	var result = project.load("res://project.godot")
	if result != OK:
		push_error("project.godot could not be loaded")
		quit(1)
		return
	var required = ["res://scenes/main.tscn", "res://scripts/game.gd", "res://scripts/player.gd", "res://scripts/interactable.gd", "res://scripts/save_system.gd", "res://scripts/haunting.gd", "res://assets/afterhours_logo.svg", "res://assets/afterhours_icon.svg"]
	for path in required:
		if not ResourceLoader.exists(path):
			push_error("Missing required resource: " + path)
			quit(1)
			return
	if bool(project.get_value("application", "boot_splash/show_image", true)):
		push_error("Default engine boot splash must remain disabled")
		quit(1)
		return
	if str(project.get_value("rendering", "renderer/rendering_method", "")) != "forward_plus":
		push_error("The project must use the Forward+ renderer")
		quit(1)
		return
	print("AFTERHOURS project validation passed")
	quit(0)

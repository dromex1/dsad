extends Area3D

# Przeciągniesz tu scenę LaptopUI.tscn (w kroku 5)
@export var laptop_ui_scene: PackedScene


# Ta funkcja jest wywoływana przez GRACZA, gdy ten kliknie na laptopa
func open_laptop_ui():
	# Sprawdź, czy UI nie jest już otwarte
	if get_tree().get_root().get_node_or_null("LaptopUI_Instance"):
		return
		
	if laptop_ui_scene:
		var ui_instance = laptop_ui_scene.instantiate()
		ui_instance.name = "LaptopUI_Instance"
		get_tree().get_root().add_child(ui_instance)
		
		# Pokaż myszkę i zatrzymaj grę
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true

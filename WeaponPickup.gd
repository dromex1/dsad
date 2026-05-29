extends RigidBody3D

func _ready():
	print("Spawned Weapon")

func interact():
	var save = get_node("/root/SaveManager")
	if save.inventory.has("pistolet"):
		save.inventory["pistolet"] += 1
	else:
		save.inventory["pistolet"] = 1
	save.save_game()
	
	# Szukamy gracza żeby zaktualizować okno ekwipunku jeśli jest otwarte
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_refresh_inventory_grid"):
		player._refresh_inventory_grid()
		
	queue_free()
	print("Pistolet picked up!")

extends RigidBody3D

## ID przedmiotu, np. "piwo", "energol", "kanister", "papieros", "pistolet"
var item_id: String = ""

## Ścieżki do modeli GLB przedmiotów
const ITEM_MODELS = {
	"piwo": "res://Modele/beercan.glb",
	"energol": "res://Modele/energycan.glb",
	"kanister": "res://Modele/gascan.glb",
	"papieros": "res://Modele/cigarette.glb",
	"pistolet": "res://Modele/tacos_map/walther_p88_gun.glb"
}

func _ready():
	add_to_group("interactable")
	print("Spawned item pickup: ", item_id)

func setup(id: String, item_scale: Vector3 = Vector3.ONE):
	item_id = id
	
	# Załaduj model 3D
	var model_path = ITEM_MODELS.get(id, "")
	if model_path == "":
		print("Brak modelu dla: ", id)
		return
	
	var scene = load(model_path)
	if not scene:
		print("Nie można załadować: ", model_path)
		return
		
	var model = scene.instantiate()
	model.scale = item_scale
	add_child(model)

func interact():
	var save = get_node("/root/SaveManager")
	if save.inventory.has(item_id):
		save.inventory[item_id] += 1
	else:
		save.inventory[item_id] = 1
	save.save_game()
	
	# Zaktualizuj UI gracza
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_refresh_inventory_grid"):
		player._refresh_inventory_grid()
		
	print("Podniesiono: ", item_id)
	queue_free()

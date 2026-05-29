extends Node

signal scooter_stats_updated
signal xp_updated(new_xp, new_level)
signal money_updated(new_amount)

# ĹšcieĹĽka do pliku zapisu
const SAVE_FILE_PATH = "user://settings.cfg"

# --- Ustawienia (Twoje) ---
var has_save_game = false
var music_vol_db = 0.0
var sfx_vol_db = 0.0
var graphics_quality = 1
var fov = 85.0
var screen_mode = 0 # 0=okno, 1=pelny ekran, 2=borderless
var vsync_enabled = false
var dynamic_shadows = true

# --- Globalna Zmiana Grafiki ---
func apply_graphics_settings(viewport: Viewport):
	# Zabezpieczenie przed brakiem viewportu
	if not viewport:
		viewport = get_viewport()
	
	print("Stosuję ustawienia grafiki dla poziomu: ", graphics_quality)
	var env_node = get_tree().root.find_child("WorldEnvironment", true, false)
	var env = null
	if env_node and env_node is WorldEnvironment:
		env = env_node.environment
	
	match graphics_quality:
		0: # NISKA
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.55  # Znaczące obniżenie renderu 3D względem 2D
			if env:
				env.ssao_enabled = false
				env.sdfgi_enabled = false
				env.glow_enabled = false
				env.volumetric_fog_enabled = false
				env.ssil_enabled = false
			
		1: # ŚREDNIA
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 0.85
			if env:
				env.ssao_enabled = true
				env.sdfgi_enabled = false
				env.glow_enabled = true
				env.volumetric_fog_enabled = false
				env.ssil_enabled = false
				
		2: # WYSOKA
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			if env:
				env.ssao_enabled = true
				env.sdfgi_enabled = true # Global Illumination
				env.glow_enabled = true
				env.ssil_enabled = true
				
	# Zastosuj cienie i vsync na koniec
	if env_node and env_node.get_parent():
		var sun = get_tree().root.find_child("DirectionalLight3D", true, false)
		if sun:
			sun.shadow_enabled = dynamic_shadows

# --- PieniÄ…dze i Ceny ---
var player_money = 40000.0:
	set(val):
		player_money = val
		money_updated.emit(player_money)
		save_game()  # Auto-save
var PRICE_PER_LITER = 6.50  # Domyślna cena PB95, aktualizowana z internetu
var oil_price_per_liter = 50.0  # Motul 800 2T
var oil_ratio = 0.02  # 1:50 (2% oleju do paliwa)

# Cena mieszanki (paliwo + olej)
func get_mix_price_per_liter() -> float:
	return PRICE_PER_LITER + (oil_ratio * oil_price_per_liter)

func get_oil_ml_for_liters(liters: float) -> float:
	return liters * oil_ratio * 1000.0  # ml oleju

# --- Ekwipunek ---
var inventory = {
	"piwo": 3,
	"energol": 3,
	"kanister": 1,
	"papieros": 5,
	"detka": 0,
	"cylinder_kit": 0,
	"pasek": 0,
	"swieca": 0,
	"przewod_paliwowy": 0,
	"pistolet": 0
}
var canister_fuel: float = 5.0  # Ile paliwa w kanistrze (max 5.0) - pełny na start
const CANISTER_MAX = 5.0

# --- Pistolet Amunicja ---
var pistol_ammo = 18
const PISTOL_AMMO_MAX = 18

const ITEM_NAMES = {
	"piwo": "Piwo",
	"energol": "Energol",
	"kanister": "Kanister",
	"papieros": "Papieros",
	"detka": "Dętka",
	"cylinder_kit": "Zestaw Cylinder",
	"pasek": "Pasek Napędowy",
	"swieca": "Świeca Zapłonowa",
	"przewod_paliwowy": "Przewód Paliwowy",
	"pistolet": "Pistolet Walther"
}

const ITEM_ICONS = {
	"piwo": "res://piwo.png",
	"energol": "res://energol.png",
	"kanister": "res://kanister.png",
	"papieros": "res://Modele/tacos_map/papieros.png",
	"detka": "res://detka.png",
	"cylinder_kit": "res://cylinder.png",
	"pasek": "res://pasek.png",
	"swieca": "res://swieca.png",
	"przewod_paliwowy": "res://przewodpali.png",
	"pistolet": "res://Modele/tacos_map/pistolet.png"
}

# --- System Uszkodzeń Pojazdu ---
var vehicle_broken: bool = false
var vehicle_damage_type: String = ""
var ride_time_accumulated: float = 0.0
var fast_breakdown_enabled: bool = false
const BREAKDOWN_INTERVAL = 900.0  # 15 minut = 900 sekund
const FAST_BREAKDOWN_INTERVAL = 5.0 # Dodatkowa komenda /awaria

const DAMAGE_TYPES = {
	"flat_tire": {
		"name": "Flak w kole",
		"description": "Dętka przebita, koło jest na płasko.",
		"required_part": "detka"
	},
	"engine_seize": {
		"name": "Zatarcie silnika",
		"description": "Silnik się zatarł, cylinder i tłok do wymiany.",
		"required_part": "cylinder_kit"
	},
	"chain_snap": {
		"name": "Zerwany pasek napędowy",
		"description": "Pasek napędowy pękł, skuter nie napędza koła.",
		"required_part": "pasek"
	},
	"spark_plug": {
		"name": "Spalona świeca",
		"description": "Świeca zapłonowa nie daje iskry.",
		"required_part": "swieca"
	},
	"fuel_leak": {
		"name": "Wyciek paliwa",
		"description": "Przewód paliwowy pęknięty, paliwo cieknie.",
		"required_part": "przewod_paliwowy"
	}
}

const REPAIR_PARTS_PRICES = {
	"detka": 25.0,
	"cylinder_kit": 350.0,
	"pasek": 80.0,
	"swieca": 15.0,
	"przewod_paliwowy": 40.0
}

const CONSUMABLE_PRICES = {
	"piwo": 4.50,
	"energol": 6.0,
	"papieros": 8.0,
	"kanister": 50.0,
	"pistolet": 1500.0
}

func use_item(item_id: String) -> bool:
	if not inventory.has(item_id): return false
	if item_id == "kanister": return true  # kanister nie zużywa się
	if inventory[item_id] <= 0: return false
	inventory[item_id] -= 1
	save_game()
	return true

# --- System XP / Level ---
var player_xp = 0
var player_level = 1

func xp_for_next_level() -> int:
	return player_level * 100

func add_xp(amount: int):
	player_xp += amount
	while player_xp >= xp_for_next_level():
		player_xp -= xp_for_next_level()
		player_level += 1
	save_game()
	xp_updated.emit(player_xp, player_level)

# --- Dane Gracza ---
var has_player_position = false
var player_position = Vector3.ZERO
var player_nickname = ""
var owned_scooters = []  # Lista posiadanych skuterów
var current_scooter_id = "yamahaaerox"  # Bieżący skuter

# --- Dane PojazdĂłw ---
var scooter_transforms = {}  # Słownik przechowujący pozycje każdego pojazdu: {"yamahaaerox": {"pos": ..., "rot": ...}, ...}
var has_bike_transform = false
var bike_position = Vector3.ZERO
var bike_rotation = Vector3.ZERO

# --- DOMYĹšLNE STATYSTYKI SKUTERĂ“W (Z kosztami) ---
const DEFAULT_STATS = {
	"yamahaaerox": {
		"display_name": "Yamaha Aerox",
		"fuel_tank_level": 0,
		"cooler_level": 0,
		"engine_level": 0,
		"tires_level": 0,
		"exhaust_level": 0,
		"weight_level": 0,
		"engine_70cc_level": 0,
		"max_speed": 7.0,
		"max_kmh": 45.0,
		"max_fuel": 5.0,
		"heating_rate": 1.10,
		"cooling_rate": 0.90,
		"grip": 5.0,
		"accel_mult": 1.0,
		"current_fuel": 1.0,
		"current_temperature": 32.0,
		"max_temperature": 140.0,
		"overheat_warning_temp": 120.0,
		"overheat_cooldown_temp": 100.0,
		"min_temperature": 32.0,
		"current_health": 100.0
	},
	"newaerox": {
		"display_name": "Yamaha Aerox New",
		"fuel_tank_level": 0,
		"cooler_level": 0,
		"engine_level": 0,
		"tires_level": 0,
		"exhaust_level": 0,
		"weight_level": 0,
		"engine_70cc_level": 0,
		"max_speed": 7.0,
		"max_kmh": 45.0,
		"max_fuel": 5.0,
		"heating_rate": 1.10,
		"cooling_rate": 0.90,
		"grip": 5.0,
		"accel_mult": 1.0,
		"current_fuel": 1.0,
		"current_temperature": 32.0,
		"max_temperature": 140.0,
		"overheat_warning_temp": 120.0,
		"overheat_cooldown_temp": 100.0,
		"min_temperature": 32.0,
		"current_health": 100.0
	},
	"aprilia": {
		"display_name": "Aprilia SR50",
		"fuel_tank_level": 0,
		"cooler_level": 0,
		"engine_level": 0,
		"tires_level": 0,
		"exhaust_level": 0,
		"weight_level": 0,
		"engine_70cc_level": 0,
		"max_speed": 7.0,
		"max_kmh": 45.0,
		"max_fuel": 5.0,
		"heating_rate": 1.10,
		"cooling_rate": 0.90,
		"grip": 5.0,
		"accel_mult": 1.0,
		"current_fuel": 1.0,
		"current_temperature": 32.0,
		"max_temperature": 140.0,
		"overheat_warning_temp": 120.0,
		"overheat_cooldown_temp": 100.0,
		"min_temperature": 32.0,
		"current_health": 100.0
	},
	"vespa": {
		"display_name": "Vespa Classic",
		"fuel_tank_level": 0,
		"cooler_level": 0,
		"engine_level": 0,
		"tires_level": 0,
		"exhaust_level": 0,
		"weight_level": 0,
		"engine_70cc_level": 0,
		"max_speed": 6.5,
		"max_kmh": 40.0,
		"max_fuel": 4.5,
		"heating_rate": 1.20,
		"cooling_rate": 0.85,
		"grip": 4.5,
		"accel_mult": 0.9,
		"current_fuel": 1.0,
		"current_temperature": 32.0,
		"max_temperature": 140.0,
		"overheat_warning_temp": 120.0,
		"overheat_cooldown_temp": 100.0,
		"min_temperature": 32.0,
		"current_health": 100.0
	}
}

# --- STATYSTYKI ULEPSZEĹ (Z kosztami) ---
var UPGRADES = {}

func _init():
	var common_upgrades = {
		"fuel_tank": { "name": "Powiększony Bak", "level_1_fuel": 7.5, "cost": 150.0 },
		"cooler": { "name": "Lepsza Chłodnica", "level_1_heating": 0.1, "level_1_cooling": 2.2, "cost": 200.0 },
		"engine": { "name": "Cylinder 55cc", "level_1_max_speed": 8.6, "level_1_max_kmh": 50.0, "cost": 450.0 },
		"tires": { "name": "Opony Sportowe", "level_1_grip": 8.5, "cost": 250.0 },
		"exhaust": { "name": "Wydech LeoVince", "level_1_accel": 1.25, "level_1_speed_add": 0.6, "cost": 380.0 },
		"engine_70cc": { "name": "MHR Team 70cc", "level_2_speed": 13.5, "level_2_kmh": 85.0, "cost": 950.0, "req_lvl": 5 },
		"weight": { "name": "Odchudzanie Ramy", "level_1_accel_add": 0.2, "cost": 320.0 }
	}
	
	for scooter_id in DEFAULT_STATS.keys():
		UPGRADES[scooter_id] = common_upgrades.duplicate(true)

var scooter_stats = {}
var auto_save_timer: Timer
var is_on_lift: bool = false
var active_quests = [
	{"id": "first_steps", "title": "Pierwsze Kroki", "desc": "ZrĂłb wheelie przez 3 sekundy", "reward_xp": 50, "reward_money": 100},
	{"id": "speed_demon", "title": "Demon PrÄ™dkoĹ›ci", "desc": "OsiÄ…gnij 60 km/h", "reward_xp": 80, "reward_money": 200}
]

func _ready():
	load_game()
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 10.0
	auto_save_timer.timeout.connect(save_game)
	add_child(auto_save_timer)
	auto_save_timer.start()

# --- ZAPIS ---
func save_game():
	var config = ConfigFile.new()
	config.set_value("SaveData", "has_save_game", has_save_game)
	config.set_value("Settings", "music_vol_db", music_vol_db)
	config.set_value("Settings", "sfx_vol_db", sfx_vol_db)
	config.set_value("Settings", "graphics_quality", graphics_quality)
	config.set_value("Settings", "fov", fov)
	config.set_value("Settings", "screen_mode", screen_mode)
	config.set_value("Settings", "vsync_enabled", vsync_enabled)
	config.set_value("Settings", "dynamic_shadows", dynamic_shadows)

	config.set_value("PlayerData", "player_xp", player_xp)
	config.set_value("PlayerData", "player_level", player_level)
	config.set_value("PlayerData", "player_nickname", player_nickname)
	
	config.set_value("ScooterStats", "stats", scooter_stats)
	
	config.set_value("PlayerData", "has_player_position", has_player_position)
	config.set_value("PlayerData", "player_position", player_position)
	config.set_value("PlayerData", "player_money", player_money)
	config.set_value("PlayerData", "owned_scooters", var_to_str(owned_scooters))
	config.set_value("PlayerData", "current_scooter_id", current_scooter_id)
	
	config.set_value("ScooterTransform", "scooter_transforms", var_to_str(scooter_transforms))
	config.set_value("ScooterTransform", "is_on_lift", is_on_lift)
	config.set_value("BikeTransform", "has_bike_transform", has_bike_transform)
	config.set_value("BikeTransform", "bike_position", bike_position)
	config.set_value("BikeTransform", "bike_rotation", bike_rotation)
	
	# Ekwipunek
	config.set_value("Inventory", "items", var_to_str(inventory))
	config.set_value("Inventory", "canister_fuel", canister_fuel)
	config.set_value("Inventory", "fuel_price", PRICE_PER_LITER)
	
	config.save(SAVE_FILE_PATH)

# --- WCZYTYWANIE ---
func load_game():
	var config = ConfigFile.new()
	var error = config.load(SAVE_FILE_PATH)
	
	if error != OK:
		print("Plik zapisu nie istnieje. Tworzenie nowego...")
		reset_all_data()
		return

	has_save_game = config.get_value("SaveData", "has_save_game", false)
	music_vol_db = config.get_value("Settings", "music_vol_db", 0.0)
	sfx_vol_db = config.get_value("Settings", "sfx_vol_db", 0.0)
	graphics_quality = config.get_value("Settings", "graphics_quality", 1)
	fov = config.get_value("Settings", "fov", 75.0)
	screen_mode = config.get_value("Settings", "screen_mode", 0)
	vsync_enabled = config.get_value("Settings", "vsync_enabled", false)
	dynamic_shadows = config.get_value("Settings", "dynamic_shadows", true)
	player_xp = config.get_value("PlayerData", "player_xp", 0)
	player_level = config.get_value("PlayerData", "player_level", 1)
	player_nickname = config.get_value("PlayerData", "player_nickname", "")
	scooter_stats = config.get_value("ScooterStats", "stats", DEFAULT_STATS.duplicate(true))
	
	# BEZPIECZNIK: Upewnij siÄ™, ĹĽe stare zapisy majÄ… nowe klucze (np. grip, accel_mult)
	for s_id in DEFAULT_STATS.keys():
		if not scooter_stats.has(s_id):
			scooter_stats[s_id] = DEFAULT_STATS[s_id].duplicate(true)
		else:
			for key in DEFAULT_STATS[s_id].keys():
				if not scooter_stats[s_id].has(key):
					scooter_stats[s_id][key] = DEFAULT_STATS[s_id][key]
	
	has_player_position = config.get_value("PlayerData", "has_player_position", false)
	player_position = config.get_value("PlayerData", "player_position", Vector3.ZERO)
	player_money = config.get_value("PlayerData", "player_money", 1000.0)
	
	# Ładowanie posiadanych skuterów
	var owned_str = config.get_value("PlayerData", "owned_scooters", "[]")
	owned_scooters = str_to_var(owned_str) if owned_str else []
	current_scooter_id = config.get_value("PlayerData", "current_scooter_id", "yamahaaerox")
	
	scooter_transforms = str_to_var(config.get_value("ScooterTransform", "scooter_transforms", "{}"))
	is_on_lift = config.get_value("ScooterTransform", "is_on_lift", false)
	has_bike_transform = config.get_value("BikeTransform", "has_bike_transform", false)
	bike_position = config.get_value("BikeTransform", "bike_position", Vector3.ZERO)
	bike_rotation = config.get_value("BikeTransform", "bike_rotation", Vector3.ZERO)
	
	# Ekwipunek
	var inv_str = config.get_value("Inventory", "items", "")
	if inv_str != "":
		var loaded_inv = str_to_var(inv_str)
		if loaded_inv is Dictionary:
			inventory = loaded_inv
			# Upewnij się że wszystkie klucze istnieją
			for key in ["piwo", "energol", "kanister"]:
				if not inventory.has(key):
					inventory[key] = 0
	canister_fuel = config.get_value("Inventory", "canister_fuel", 0.0)
	var saved_fuel_price = config.get_value("Inventory", "fuel_price", 6.50)
	PRICE_PER_LITER = saved_fuel_price

# --- FUNKCJA: Reset (dla "Nowej Gry") ---
func reset_all_data():
	print("RESETOWANIE ZAPISU DO STANU DOMYĹšLGO...")
	scooter_stats = DEFAULT_STATS.duplicate(true)
	has_player_position = false
	player_position = Vector3.ZERO
	scooter_transforms = {}
	is_on_lift = false
	has_bike_transform = false
	bike_position = Vector3.ZERO
	bike_rotation = Vector3.ZERO
	player_money = 1000.0
	player_level = 1
	player_xp = 0
	save_game()

# --- Funkcje UlepszeĹ„ ---

func get_scooter_stats(scooter_id: String):
	if scooter_stats.has(scooter_id): return scooter_stats[scooter_id]
	else:
		scooter_stats[scooter_id] = DEFAULT_STATS[scooter_id].duplicate(true)
		return scooter_stats[scooter_id]

# === NOWA FUNKCJA ZAMIAST STARYCH ===
# Ta funkcja kupuje wszystko z koszyka naraz
func try_buy_shopping_cart(scooter_id: String, cart_array: Array) -> bool:
	var total_cost = 0.0
	
	# 1. Oblicz Ĺ‚Ä…czny koszt
	for upgrade_type in cart_array:
		if UPGRADES[scooter_id].has(upgrade_type):
			total_cost += UPGRADES[scooter_id][upgrade_type]["cost"]
	
	# 2. SprawdĹş, czy nas staÄ‡
	if player_money < total_cost:
		print("Brak pieniÄ™dzy na zakup z koszyka!")
		return false # ZwrĂłÄ‡ 'false', jeĹ›li siÄ™ nie udaĹ‚o
	
	# 3. StaÄ‡ nas! Pobierz pieniÄ…dze i zastosuj ulepszenia
	player_money -= total_cost
	
	for upgrade_type in cart_array:
		var upgrade_info = UPGRADES[scooter_id][upgrade_type]
		var current_level_key = upgrade_type + "_level"
		
		# Zastosuj ulepszenie
		match upgrade_type:
			"fuel_tank":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["max_fuel"] = upgrade_info["level_1_fuel"]
				scooter_stats[scooter_id]["current_fuel"] = upgrade_info["level_1_fuel"]
			"cooler":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["heating_rate"] = upgrade_info["level_1_heating"]
				scooter_stats[scooter_id]["cooling_rate"] = upgrade_info["level_1_cooling"]
			"engine":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["max_speed"] = upgrade_info["level_1_max_speed"]
				scooter_stats[scooter_id]["max_kmh"] = upgrade_info["level_1_max_kmh"]
			"tires":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["grip"] = upgrade_info["level_1_grip"]
			"exhaust":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["accel_mult"] = upgrade_info["level_1_accel"]
				scooter_stats[scooter_id]["max_speed"] += upgrade_info["level_1_speed_add"]
			"engine_70cc":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["max_speed"] = upgrade_info["level_2_speed"]
				scooter_stats[scooter_id]["max_kmh"] = upgrade_info["level_2_kmh"]
			"weight":
				scooter_stats[scooter_id][current_level_key] = 1
				scooter_stats[scooter_id]["accel_mult"] += upgrade_info["level_1_accel_add"]
	
	save_game()
	emit_signal("scooter_stats_updated")
	print("Kupiono ulepszenia z koszyka!")
	return true # ZwrĂłÄ‡ 'true' (sukces)

# Ta funkcja resetuje i zwraca 30% kasy
func refund_and_reset_stats(scooter_id: String):
	var stats = scooter_stats[scooter_id]
	var refund_amount = 0.0
	
	# Oblicz zwrot 30%
	if stats["fuel_tank_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["fuel_tank"]["cost"] * 0.30
	if stats["cooler_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["cooler"]["cost"] * 0.30
	if stats["engine_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["engine"]["cost"] * 0.30
	if stats["tires_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["tires"]["cost"] * 0.30
	if stats["exhaust_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["exhaust"]["cost"] * 0.30
	if stats["weight_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["weight"]["cost"] * 0.30
	if stats.has("engine_70cc_level") and stats["engine_70cc_level"] > 0:
		refund_amount += UPGRADES[scooter_id]["engine_70cc"]["cost"] * 0.30
	
	player_money += refund_amount
	print("ZwrĂłcono %.2f zĹ‚" % refund_amount)
	
	# Zresetuj staty
	var temp_fuel = stats["current_fuel"]
	var temp_temp = stats["current_temperature"]
	scooter_stats[scooter_id] = DEFAULT_STATS[scooter_id].duplicate(true)
	scooter_stats[scooter_id]["current_fuel"] = min(temp_fuel, scooter_stats[scooter_id]["max_fuel"])
	scooter_stats[scooter_id]["current_temperature"] = temp_temp
	
	save_game()
	emit_signal("scooter_stats_updated")
	print("Zresetowano ulepszenia skutera.")

# --- Funkcja Tankowania ---
func try_buy_fuel(cost: float, amount_to_add: float, scooter_id: String) -> bool:
	if player_money < cost:
		print("Za maĹ‚o pieniÄ™dzy na tankowanie!")
		return false
	
	player_money -= cost
	scooter_stats[scooter_id]["current_fuel"] += amount_to_add
	scooter_stats[scooter_id]["current_fuel"] = min(scooter_stats[scooter_id]["current_fuel"], scooter_stats[scooter_id]["max_fuel"])
	
	save_game()
	return true

# --- Funkcje Aktualizacji Stanu ---
func update_player_position(pos: Vector3):
	player_position = pos
	has_player_position = true

func load_player_position():
	if has_player_position: return player_position
	else: return null

func update_scooter_state(scooter_id: String, fuel: float, temp: float, hp: float = 100.0):
	if scooter_stats.has(scooter_id):
		scooter_stats[scooter_id]["current_fuel"] = fuel
		scooter_stats[scooter_id]["current_temperature"] = temp
		scooter_stats[scooter_id]["current_health"] = hp

func update_scooter_transform(vehicle_name: String, pos: Vector3, rot: Vector3):
	if not scooter_transforms.has(vehicle_name):
		scooter_transforms[vehicle_name] = {}
	scooter_transforms[vehicle_name]["pos"] = pos
	scooter_transforms[vehicle_name]["rot"] = rot

func load_scooter_transform(vehicle_name: String):
	if scooter_transforms.has(vehicle_name):
		var transform_data = scooter_transforms[vehicle_name]
		if transform_data.has("pos") and transform_data.has("rot"):
			return {"pos": transform_data["pos"], "rot": transform_data["rot"]}
	return null

func update_bike_transform(pos: Vector3, rot: Vector3):
	bike_position = pos
	bike_rotation = rot

func remove_scooter_ownership(scooter_id: String):
	if owned_scooters.has(scooter_id):
		owned_scooters.erase(scooter_id)
		if scooter_stats.has(scooter_id):
			scooter_stats.erase(scooter_id)
		if scooter_transforms.has(scooter_id):
			scooter_transforms.erase(scooter_id)
		if current_scooter_id == scooter_id:
			current_scooter_id = ""
		save_game()
		print("Skuter " + scooter_id + " zostal zniszczony i usunięty z konta!")

	has_bike_transform = true

func load_bike_transform():
	if has_bike_transform:
		return {"pos": bike_position, "rot": bike_rotation}
	else:
		return null
func add_owned_scooter(scooter_id: String):
	if scooter_id not in owned_scooters:
		owned_scooters.append(scooter_id)
		save_game()

func has_owned_scooter(scooter_id: String) -> bool:
	return scooter_id in owned_scooters

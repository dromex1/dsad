@tool
extends CharacterBody3D

var BasicFPSPlayerScene : PackedScene = preload("basic_player_head.tscn")
var addedHead = false
@onready var pause_menu = get_node_or_null("%PauseBackground")

# Referencje do naszego "wzroku"
@onready var interaction_raycast = get_node_or_null("Head/Camera3D/InteractionRaycast")
# Referencja do napisu "kliknij"
@onready var interaction_prompt_label = get_node_or_null("PlayerUI/InteractionPromptLabel")
# Referencje do dĹşwiÄ™ku krokĂłw
@onready var footstep_player = get_node_or_null("FootstepPlayer")
@onready var footstep_timer = get_node_or_null("FootstepTimer")

@onready var pause_buttons = pause_menu.get_node_or_null("PauseButtons") if pause_menu else null
@onready var options_panel = pause_menu.get_node_or_null("OptionsPanel") if pause_menu else null
@onready var options_wstecz = options_panel.get_node_or_null("OptionsLayout/WsteczButton") if options_panel else null
@onready var music_slider = options_panel.get_node_or_null("OptionsLayout/MusicSlider") if options_panel else null
@onready var sfx_slider = options_panel.get_node_or_null("OptionsLayout/SFXSlider") if options_panel else null
@onready var graphic_options = options_panel.get_node_or_null("OptionsLayout/GraphicOptions") if options_panel else null

# --- Nowy panel opcji (Far Cry style) ---
var fancy_options: PanelContainer = null
var _fc_music_slider: HSlider = null
var _fc_sfx_slider: HSlider = null
var _fc_gfx_option: OptionButton = null
var _fc_grafika_content: VBoxContainer = null
var _fc_dzwiek_content: VBoxContainer = null
var _fc_tab_grafika: Button = null
var _fc_tab_dzwiek: Button = null
var _fc_music_val_label: Label = null
var _fc_sfx_val_label: Label = null
var _fc_fov_slider: HSlider = null
var _fc_fov_val_label: Label = null
var _fc_screen_mode: OptionButton = null
var _fc_vsync_check: CheckButton = null
var _fc_shadows_check: CheckButton = null
# --- HUD System ---
var current_vehicle = null # <--- FIX: Dodano referencję wykorzystywaną przez TabletUI do spawnowania skuterów
var hud_canvas: CanvasLayer = null
var hud_lvl_label: Label = null
var hud_xp_bar: ProgressBar = null
var hud_xp_label: Label = null
var hud_money_label: Label = null
var player_health: float = 100.0
var hud_hp_bar: ProgressBar = null
@onready var refuel_container = get_node_or_null("PlayerUI/RefuelContainer")
@onready var refuel_label = get_node_or_null("PlayerUI/RefuelContainer/RefuelLabel")
@onready var refuel_bar = get_node_or_null("PlayerUI/RefuelContainer/RefuelBar")
@onready var money_label = get_node_or_null("PlayerUI/MoneyLabel")

var current_held_item_node: Node3D = null

@export_group("Held Items Transforms")
@export_subgroup("Beer (piwo)")
@export var beer_pos: Vector3 = Vector3(0.5, -0.4, -0.8)
@export var beer_rot: Vector3 = Vector3(0, 0, 0)
@export var beer_scale: Vector3 = Vector3(1, 1, 1)

@export_subgroup("Energy (energol)")
@export var energy_pos: Vector3 = Vector3(0.5, -0.4, -0.8)
@export var energy_rot: Vector3 = Vector3(0, 0, 0)
@export var energy_scale: Vector3 = Vector3(1, 1, 1)

@export_subgroup("Gas (kanister)")
@export var gas_pos: Vector3 = Vector3(0.5, -0.4, -0.8)
@export var gas_rot: Vector3 = Vector3(0, 0, 0)
@export var gas_scale: Vector3 = Vector3(1, 1, 1)

@export_subgroup("Cigarette (papieros)")
@export var cig_pos: Vector3 = Vector3(0.5, -0.4, -0.8)
@export var cig_rot: Vector3 = Vector3(0, 0, 0)
@export var cig_scale: Vector3 = Vector3(1, 1, 1)

const ITEM_GLB_PATHS = {
	"piwo": "res://Modele/beercan.glb",
	"energol": "res://Modele/energycan.glb",
	"kanister": "res://Modele/gascan.glb",
	"papieros": "res://Modele/cigarette.glb"
}

# --- Inventory / Hotbar System ---
var inventory_open = false
var selected_hotbar_slot = 0
var hotbar_container: HBoxContainer = null
var hotbar_slots: Array = []  # Array of PanelContainer
var hotbar_icons: Array = []  # Array of TextureRect
var hotbar_labels: Array = []  # Array of Label
var inventory_panel: PanelContainer = null
var inventory_grid: GridContainer = null
var hotbar_item_ids = ["kanister", "piwo", "energol", "", ""]
var item_textures = {}

# --- Pistolet Amunicja HUD ---
var pistol_ammo_panel: PanelContainer = null
var pistol_ammo_label: Label = null
var reload_audio_player: AudioStreamPlayer = null

# --- Efekty konsumpcyjne ---
var alcohol_timer: float = 0.0
var energy_timer: float = 0.0
var base_speed: float = 0.0
var is_canister_refueling: bool = false
var _lpm_pressed: bool = false
var item_prompt_label: Label = null

# --- Chat System ---
var chat_ui: CanvasLayer = null
var chat_display: RichTextLabel = null
var chat_input: LineEdit = null

func _enter_tree():
	pass

## PLAYER MOVMENT SCRIPT ##
###########################

@export_category("Mouse Capture")
@export var CAPTURE_ON_START := true

@export_category("Movement")
@export_subgroup("Settings")
@export var SPEED := 5.0
@export var ACCEL := 50.0
@export var IN_AIR_SPEED := 3.0
@export var IN_AIR_ACCEL := 5.0
@export var JUMP_VELOCITY := 4.5
@export_subgroup("Head Bob")
@export var HEAD_BOB := true
@export var HEAD_BOB_FREQUENCY := 0.3
@export var HEAD_BOB_AMPLITUDE := 0.01
@export_subgroup("Clamp Head Rotation")
@export var CLAMP_HEAD_ROTATION := true
@export var CLAMP_HEAD_ROTATION_MIN := -90.0
@export var CLAMP_HEAD_ROTATION_MAX := 90.0

@export_category("Key Binds")
@export_subgroup("Mouse")
@export var MOUSE_ACCEL := true
@export var KEY_BIND_MOUSE_SENS := 0.005
@export var KEY_BIND_MOUSE_ACCEL := 50
@export_subgroup("Movement")
@export var KEY_BIND_UP := "ui_up"
@export var KEY_BIND_LEFT := "ui_left"
@export var KEY_BIND_RIGHT := "ui_right"
@export var KEY_BIND_DOWN := "ui_down"
@export var KEY_BIND_JUMP := "ui_accept"

@export_category("Advanced")
@export var UPDATE_PLAYER_ON_PHYS_STEP := true	# When check player is moved and rotated in _physics_process (fixed fps)
												# Otherwise player is updated in _process (uncapped)

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
# To keep track of current speed and acceleration
var speed = SPEED
var accel = ACCEL

# Used when lerping rotation to reduce stuttering when moving the mouse
var rotation_target_player : float
var rotation_target_head : float

# Used when bobing head
var head_start_pos : Vector3

# Current player tick, used in head bob calculation
var tick = 0

# --- System Uszkodzeń / Pchania ---
var is_pushing_vehicle: bool = false
var pushed_vehicle: Node3D = null

# --- System Papierosów ---
var smoke_timer: float = 0.0
var smoke_particles: GPUParticles3D = null
var base_speed_for_smoke: float = SPEED
var cigarette_haze: ColorRect = null
# --- System Broni ---
var weapon_model: Node3D = null
var weapon_audio: AudioStreamPlayer3D = null
var weapon_flash: OmniLight3D = null
var is_recoiling = false
var recoil_amount = 0.0

func _ready():
	if Engine.is_editor_hint():
		return
		
	_setup_third_person_camera() # Przygotowujemy kamerÄ™ TPP
	add_to_group("player")
	
	_create_chat_ui()
	
	if has_node("Head/Camera3D"):
		var camera = get_node("Head/Camera3D")
		camera.current = true
		print("Lokalna kamera aktywowana pomyślnie.")
		
		# Wczytanie modelu broni jako tscn zeby mozna bylo w edytorze zmieniac
		var weapon_scene = load("res://PistolViewModel.tscn")
		if weapon_scene:
			weapon_model = weapon_scene.instantiate()
			weapon_model.visible = false
			camera.add_child(weapon_model)
			print("BRON ZALADOWANA! weapon_model=", weapon_model, " children=", weapon_model.get_children())
			
			# Pobranie wewnetrznych elementow swiatla i dzwieku z zaimportowanego modelu
			weapon_audio = weapon_model.get_node_or_null("walther_p88_gun/GunshotSound")
			weapon_flash = weapon_model.get_node_or_null("walther_p88_gun/MuzzleFlash")
			print("weapon_audio=", weapon_audio, " weapon_flash=", weapon_flash)
		else:
			print("BLAD: Nie udalo sie zaladowac PistolViewModel.tscn!")
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# === System Pozycji ===
	var loaded_pos = SaveManager.load_player_position()
	if loaded_pos != null:
		set_deferred("global_position", loaded_pos)
		print("Wczytano pozycjÄ™ gracza: ", loaded_pos)
	else:
		print("Nie znaleziono zapisu pozycji, startujÄ™ domyĹ›lnie.")
	
	# Nickname - przechowujemy lokalnie
	var my_nick = SaveManager.get("player_nickname") if "player_nickname" in SaveManager else "Gracz"

	# Capture mouse if set to true
	if CAPTURE_ON_START:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	head_start_pos = $Head.position
	
	if footstep_player:
		footstep_player.volume_db = -40.0
	
	if options_panel:
		if options_wstecz and not options_wstecz.pressed.is_connected(_on_options_wstecz_pressed):
			options_wstecz.pressed.connect(_on_options_wstecz_pressed)
		if music_slider and not music_slider.value_changed.is_connected(_on_music_slider_value_changed):
			music_slider.value_changed.connect(_on_music_slider_value_changed)
		if sfx_slider and not sfx_slider.value_changed.is_connected(_on_sfx_slider_value_changed):
			sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
		if graphic_options and not graphic_options.item_selected.is_connected(_on_graphic_options_item_selected):
			graphic_options.item_selected.connect(_on_graphic_options_item_selected)
		
		# Wczytywanie aktualnych ustawieĹ„ (z zabezpieczeniem przed null)
		if music_slider:
			music_slider.value = db_to_linear(SaveManager.music_vol_db)
		if sfx_slider:
			sfx_slider.value = db_to_linear(SaveManager.sfx_vol_db)
		if graphic_options:
			graphic_options.select(SaveManager.graphics_quality)
			update_graphics_quality(SaveManager.graphics_quality)
		
	if pause_buttons:
		var wroc_btn = pause_buttons.get_node_or_null("WrocButton")
		var ustaw_btn = pause_buttons.get_node_or_null("UstawieniaButton")
		var wyj_btn = pause_buttons.get_node_or_null("WyjscieButton")
		if wroc_btn and not wroc_btn.pressed.is_connected(_on_wroc_button_pressed):
			wroc_btn.pressed.connect(_on_wroc_button_pressed)
		if ustaw_btn and not ustaw_btn.pressed.is_connected(_on_ustawienia_button_pressed):
			ustaw_btn.pressed.connect(_on_ustawienia_button_pressed)
		if wyj_btn and not wyj_btn.pressed.is_connected(_on_wyjscie_button_pressed):
			wyj_btn.pressed.connect(_on_wyjscie_button_pressed)
	
	_build_fancy_options()
	_setup_global_hud()
	_update_global_hud()
	_load_item_textures()
	_setup_hotbar()
	_setup_inventory_panel()
	_setup_item_prompt()
	_setup_item_prompt()
	_setup_smoke_effect()
	base_speed = SPEED
	
	# Wymuś reset ekwipunku na 3 itemy
	SaveManager.inventory["piwo"] = 3
	SaveManager.inventory["energol"] = 3
	SaveManager.inventory["papieros"] = 3
	SaveManager.inventory["kanister"] = 1
	SaveManager.canister_fuel = 5.0
	
	SaveManager.xp_updated.connect(_on_xp_updated)
	SaveManager.money_updated.connect(_on_money_updated)


func _physics_process(delta):
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	
	# Increment player tick, used in head bob motion
	tick += 1
	
	if UPDATE_PLAYER_ON_PHYS_STEP:
		move_player(delta)
		rotate_player(delta)
	
	if HEAD_BOB:
		# Only move head when on the floor and moving
		if velocity && is_on_floor():
			head_bob_motion()
		reset_head_bob(delta)
		
		# --- NOWA LOGIKA: DĹşwiÄ™k krokĂłw (z Timerem) ---

	# Sprawdzamy, czy jesteĹ›my na ziemi I czy siÄ™ ruszamy
	# velocity.length() > 0.1 sprawdza jakikolwiek ruch (WSAD)
	var is_walking = is_on_floor() and velocity.length() > 0.1

	if is_walking:
		# JeĹ›li idziemy, sprawdzamy, czy nasz timer "odpoczÄ…Ĺ‚"
		if footstep_timer and footstep_timer.is_stopped():
			# Timer odpoczÄ…Ĺ‚, wiÄ™c:
			# 1. OdtwĂłrz dĹşwiÄ™k kroku
			if footstep_player: footstep_player.play()
			# 2. Uruchom timer od nowa (na 0.5 sekundy)
			footstep_timer.start()
	else:
		if footstep_timer: footstep_timer.stop()

	# --- Pchanie Pojazdu ---
	if is_pushing_vehicle and is_instance_valid(pushed_vehicle):
		var push_offset = -self.global_transform.basis.z * 1.4
		pushed_vehicle.global_position = self.global_position + push_offset
		pushed_vehicle.global_position.y -= 0.6
		pushed_vehicle.rotation.y = self.rotation.y
		# Upewnij się, że opada na ziemię, jeśli to nie CharacterBody3D ustawiamy to z promieniami lub zostawiamy fizyce
		
	# --- Efekt Papierosa ---
	if smoke_timer > 0:
		smoke_timer -= delta
		if smoke_timer <= 0:
			_remove_smoke_effect()

	# --- Efekty konsumpcyjne ---
	if alcohol_timer > 0:
		alcohol_timer -= delta
		_apply_alcohol_effect(delta)
		if alcohol_timer <= 0:
			_remove_alcohol_effect()
	
	if energy_timer > 0:
		energy_timer -= delta
		_apply_energy_effect(delta)
		if energy_timer <= 0:
			SPEED = base_speed
			_remove_energy_effect()
			print("Efekt energola minął.")

	# Scroll - zmiana slotu hotbara
	if Input.is_action_just_released("scroll_up"):
		selected_hotbar_slot = (selected_hotbar_slot - 1) % 5
		if selected_hotbar_slot < 0: selected_hotbar_slot = 4
		_update_hotbar_selection()
	elif Input.is_action_just_released("scroll_down"):
		selected_hotbar_slot = (selected_hotbar_slot + 1) % 5
		_update_hotbar_selection()
	
	# Aktualizuj podpowiedź pod celownikiem
	_update_item_prompt()
	_update_hotbar()

func _setup_smoke_effect():
	# Cząsteczki dymu
	smoke_particles = GPUParticles3D.new()
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.3)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var pass1 = QuadMesh.new()
	pass1.size = Vector2(0.2, 0.2)
	pass1.material = mat
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 15.0
	process_mat.initial_velocity_min = 1.0
	process_mat.initial_velocity_max = 2.0
	process_mat.gravity = Vector3(0, 0.5, 0)
	process_mat.scale_min = 0.5
	process_mat.scale_max = 2.0
	process_mat.color = Color(1, 1, 1, 0.5)
	
	smoke_particles.process_material = process_mat
	smoke_particles.draw_pass_1 = pass1
	smoke_particles.amount = 30
	smoke_particles.lifetime = 1.5
	smoke_particles.emitting = false
	smoke_particles.position = Vector3(0, -0.2, -0.5) # Przed twarzą
	$Head.add_child(smoke_particles)
	
	# Mgiełka / Haze
	if not hud_canvas: return
	cigarette_haze = ColorRect.new()
	cigarette_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	cigarette_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cigarette_haze.color = Color(0.1, 0.1, 0.05, 0.0)
	hud_canvas.add_child(cigarette_haze)
	hud_canvas.move_child(cigarette_haze, 1)

func _remove_smoke_effect():
	if smoke_particles: smoke_particles.emitting = false
	SPEED = base_speed_for_smoke
	print("Efekt papierosa minął.")
	if cigarette_haze:
		var tw = create_tween()
		tw.tween_property(cigarette_haze, "color:a", 0.0, 2.0)
		
func teleport_to(pos: Vector3):
	global_position = pos
	print("Teleportowano do: ", pos)

func _create_chat_ui():
	var existing_ui = get_node_or_null("PlayerUI")
	if not existing_ui: return
	chat_ui = existing_ui
	
	# GĹ‚Ăłwny panel (tĹ‚o)
	var panel = PanelContainer.new()
	panel.name = "ChatPanel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.25, 0.1, 0.6) # Ciemnozielony przezroczysty jak w Roblox
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Pozycjonowanie w LWYM GĂ“RNYM ROGU (idealnie widoczne, jak Roblox)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(20, 20) # 20px od lewej i 20px od gĂłry
	panel.size = Vector2(450, 250)
	chat_ui.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "ChatContainer"
	panel.add_child(vbox)
	
	chat_display = RichTextLabel.new()
	chat_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_display.scroll_following = true
	chat_display.bbcode_enabled = true
	chat_display.add_theme_font_size_override("normal_font_size", 16)
	chat_display.add_theme_font_size_override("bold_font_size", 16)
	vbox.add_child(chat_display)
	
	chat_display.text = "[color=yellow]System:[/color] Witaj w lobby! Nacisnij Y aby pisac.\n"
	chat_display.text += "Chat '/tp @a' to teleport all players to Host.\n"
	
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "NaciĹ›nij Y, aby pisaÄ‡..."
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.2, 0.4, 0.2, 0.7) # JaĹ›niejszy zielony
	input_style.corner_radius_top_left = 3
	input_style.corner_radius_top_right = 3
	input_style.corner_radius_bottom_left = 3
	input_style.corner_radius_bottom_right = 3
	chat_input.add_theme_stylebox_override("normal", input_style)
	chat_input.add_theme_stylebox_override("focus", input_style)
	chat_input.add_theme_font_size_override("font_size", 16)
	chat_input.visible = false
	chat_input.text_submitted.connect(_on_chat_submitted)
	vbox.add_child(chat_input)


func _on_chat_submitted(text: String):
	chat_input.text = ""
	chat_input.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	text = text.strip_edges()
	if text == "": return
	
	# Obsługa komend
	if text == "/kasa":
		SaveManager.player_money += 50000.0
		SaveManager.save_game()
		chat_message("[color=green]System:[/color] Dodano 50000 zł na twoje konto!")
		return
	if text.begins_with("/give money"):
		var parts = text.split(" ")
		if parts.size() >= 3:
			var amount_str = parts[2]
			if amount_str.is_valid_int():
				var amount = int(amount_str)
				SaveManager.player_money += amount
				SaveManager.save_game()
				chat_message("[color=lime]System:[/color] Dodano %d zł! Razem: %.2f zł" % [amount, SaveManager.player_money])
			else:
				chat_message("[color=red]System:[/color] Błąd! Poprawna składnia: /give money <liczba>")
		else:
			chat_message("[color=red]System:[/color] Błąd! Poprawna składnia: /give money <liczba>")
		return
	
	if text == "/awaria":
		SaveManager.fast_breakdown_enabled = true
		SaveManager.ride_time_accumulated = 0.0
		chat_message("[color=orange]System:[/color] Tryb awarii włączony! Skuter zepsuje się za równe 5 sekund.")
		return
		
	if text.begins_with("/tp"):
		return
	
	var my_nick = "Gracz"
	chat_message("[color=#cccccc][[/color][color=#ffffff][b]" + my_nick + "[/b][/color][color=#cccccc]]:[/color] " + text)

func chat_message(msg: String):
	if chat_display:
		chat_display.text += msg + "\n"
		
	# WyĹ›wietlamy wiadomoĹ›Ä‡ lokalnie


func _process(delta):
	if Engine.is_editor_hint():
		return

	if !UPDATE_PLAYER_ON_PHYS_STEP:
		move_player(delta)
		rotate_player(delta)
		
	var cam = get_node_or_null("Head/Camera3D")
	if cam:
		var target_fov = SaveManager.fov
		if is_smoking_inhaling:
			target_fov += 12.0 # Wciąganie dymu = FOV wzrasta
		# Przenikaj powoli płynnie
		cam.fov = lerp(cam.fov, float(target_fov), 4.0 * delta)

func _input(event):
	# Klawisz I - ekwipunek
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory(!inventory_open)
			return
		# Q - wyrzuć przedmiot z hotbara (tylko gdy nie na skuterze)
		if event.keycode == KEY_Q and not inventory_open:
			_drop_hotbar_item()
			return
	
	# Sprawdzamy, czy gracz wcisnął pauzę
	if Input.is_action_just_pressed("pause"):
		is_pushing_vehicle = false # Zatrzymaj pchanie na ESC
		
		var gui_closed = false
		if inventory_open:
			_toggle_inventory(false)
			gui_closed = true
			
		var tablet = get_node_or_null("TabletUI")
		if is_instance_valid(tablet):
			tablet.close()
			gui_closed = true
			
		var laptop = get_node_or_null("LaptopUI")
		if is_instance_valid(laptop):
			laptop.queue_free()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			gui_closed = true
			
		if gui_closed:
			return
			
		toggle_pause()
		return 
		
	# Tablet pod TAB (Poprawnie w _input)
	if event is InputEventKey and event.pressed:
		# --- PCHANIE SKUTERA (Klawisz H) ---
		if event.keycode == KEY_H:
			if is_pushing_vehicle:
				# Przestań pchać
				is_pushing_vehicle = false
				pushed_vehicle = null
				print("Skończono pchać skuter.")
			else:
				# Rozpocznij pchanie jeśli blisko zepsutego skutera
				var near_v = _find_nearby_vehicle()
				if near_v and near_v.has_method("is_broken") or (near_v and near_v.get("is_broken") == true):
					is_pushing_vehicle = true
					pushed_vehicle = near_v
					print("Rozpoczęto pchanie skutera.")
				elif near_v:
					print("Skuter nie jest zepsuty.")
			return
			
		if event.keycode == KEY_TAB:
			var gui_open = inventory_open or is_instance_valid(get_node_or_null("LaptopUI")) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			if gui_open: return
			
			var existing = get_node_or_null("TabletUI")
			if existing: existing.close()
			else:
				var tablet = load("res://TabletUI.gd").new()
				tablet.name = "TabletUI"
				add_child(tablet)
			return
			
		# --- CHAT MULTIPLAYER (Klawisz Y) ---
		if event.keycode == KEY_Y:
			if chat_input and not chat_input.has_focus() and not chat_input.visible:
				chat_input.visible = true
				chat_input.grab_focus()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# Wyczyszczenie Ewentualnych bugĂłw literki Y
				get_viewport().set_input_as_handled()
			return
			
		# --- RELOAD (Klawisz R) ---
		if event.keycode == KEY_R and not inventory_open:
			var item_id = hotbar_item_ids[selected_hotbar_slot]
			if item_id == "pistolet":
				_reload_pistol()
			return

	if Engine.is_editor_hint():
		return
		
	# Listen for mouse movement and check if mouse is captured
	if event is InputEventMouseMotion && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		set_rotation_target(event.relative)
	
	# --- Obsługa kliknięć myszy dla przedmiotów ---
	var gui_open = inventory_open or is_instance_valid(get_node_or_null("TabletUI")) or is_instance_valid(get_node_or_null("LaptopUI")) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseButton and not gui_open:
		var item_id = hotbar_item_ids[selected_hotbar_slot]
		
		# Zwalnianie PPM (Wydech papierosa)
		if not event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
			if is_smoking_inhaling:
				is_smoking_inhaling = false
				_exhale_smoke()

		# Wciśnięcie klawiszy myszy
		if event.is_pressed():
			# PPM (button 2) - Pij piwo/energol/papieros
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if item_id in ["piwo", "energol"]:
					_use_hotbar_item(item_id)
					return
				elif item_id == "papieros":
					if SaveManager.use_item("papieros"):
						is_smoking_inhaling = true
						_update_hotbar()
						_refresh_inventory_grid()
						if SaveManager.inventory.get("papieros", 0) <= 0:
							hotbar_item_ids[selected_hotbar_slot] = ""
							_update_hotbar()
							_update_hotbar_selection()
					return
					
				# Fallback: interakcja z laptopem
				if interaction_raycast and interaction_raycast.is_colliding():
					var collider = interaction_raycast.get_collider()
					if collider.has_method("open_laptop_ui"):
						collider.open_laptop_ui()
						return
		
		# LPM (button 1) - Strzelanie / Tankowanie / Podnoszenie
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Pistolet ma priorytet - strzela zawsze
			if item_id == "pistolet":
				_shoot_pistol()
			if item_prompt_label:
				if gui_open:
					item_prompt_label.visible = false
				elif interaction_raycast and interaction_raycast.is_colliding():
					var collider = interaction_raycast.get_collider()
					if collider.has_method("interact"):
						item_prompt_label.text = "[LPM] Interakcja"
						item_prompt_label.visible = true
					elif collider.has_method("open_laptop_ui"):
						item_prompt_label.text = "[PPM] Włącz laptopa"
						item_prompt_label.show()
					elif collider.is_in_group("vehicle"):
						item_prompt_label.text = "Skuter"
						item_prompt_label.visible = true
					else:
						item_prompt_label.visible = false
				else:
					item_prompt_label.visible = false
			
			if item_id == "kanister":
				_try_canister_refuel()
				return
			
			if interaction_raycast and interaction_raycast.is_colliding():
				var collider = interaction_raycast.get_collider()
				if collider.has_method("interact"):
					collider.interact()
					return
	
	# Interakcja z podnośnikiem (Klawisz E)
	if Input.is_action_just_pressed("interact"):
		var billboard = get_tree().root.find_child("LiftBillboard", true, false)
		if billboard:
			var dist_to_lift = global_position.distance_to(billboard.global_position)
			if dist_to_lift < 4.0:
				var aerox = get_tree().root.find_child("Bike3", true, false)
				if aerox and aerox.has_method("teleport_to_lift"):
					var target_pos = billboard.global_position
					target_pos.y = 0.4
					aerox.teleport_to_lift(target_pos, Vector3(0, deg_to_rad(-90), 0))
					print("Skuter wstawiony na podnośnik pod napisem!")
				

func set_rotation_target(mouse_motion : Vector2):
	# Add player target to the mouse -x input
	rotation_target_player += -mouse_motion.x * KEY_BIND_MOUSE_SENS
	# Add head target to the mouse -y input
	rotation_target_head += -mouse_motion.y * KEY_BIND_MOUSE_SENS
	# Clamp rotation
	if CLAMP_HEAD_ROTATION:
		rotation_target_head = clamp(rotation_target_head, deg_to_rad(CLAMP_HEAD_ROTATION_MIN), deg_to_rad(CLAMP_HEAD_ROTATION_MAX))

func _shoot_pistol():
	if is_recoiling: return
	if SaveManager.pistol_ammo <= 0:
		print("Brak amunicji w magazynku! Wciśnij R aby przeładować.")
		# Można dodać dźwięk kliknięcia pustego magazynka
		return
		
	SaveManager.pistol_ammo -= 1
	_update_pistol_hud()
	
	is_recoiling = true
	print("STRZAL! weapon_model=", weapon_model, " weapon_audio=", weapon_audio, " weapon_flash=", weapon_flash)
	
	if weapon_audio and weapon_audio.stream:
		weapon_audio.play()
	else:
		print("BRAK AUDIO! weapon_audio=", weapon_audio)
		
	if weapon_flash:
		weapon_flash.light_energy = 5.0
		var f_tween = create_tween()
		f_tween.tween_property(weapon_flash, "light_energy", 0.0, 0.05)
	
	# Odrzut w górę
	rotation_target_head += deg_to_rad(2.5) 
	
	# Animacja samego modelu broni (lekko do tylu i obrot)
	if weapon_model:
		var w_tween = create_tween()
		w_tween.tween_property(weapon_model, "position", weapon_model.position + Vector3(0, 0, 0.1), 0.05)
		w_tween.tween_property(weapon_model, "rotation_degrees", weapon_model.rotation_degrees + Vector3(15, 0, 0), 0.05)
		w_tween.tween_property(weapon_model, "position", weapon_model.position, 0.1)
		w_tween.tween_property(weapon_model, "rotation_degrees", weapon_model.rotation_degrees, 0.1)
		w_tween.finished.connect(func(): is_recoiling = false)
	else:
		get_tree().create_timer(0.2).timeout.connect(func(): is_recoiling = false)
		
	# 1. Zapisywanie pozycji gracza i skryptów globalnych
	SaveManager.update_player_position(self.global_position)

	# Miejscie uderzenia pocisku (Bezpośrednie zapytanie z PhysicsServer zeby ominac maski Raycastu z bliska)
	var space_state = get_world_3d().direct_space_state
	var camera = get_node_or_null("Head/Camera3D")
	if camera:
		var origin = camera.global_position
		var end = origin + (-camera.global_transform.basis.z * 100.0)
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [self.get_rid()] # Ignoruj kolizję z graczem
		var result = space_state.intersect_ray(query)
		
		if result:
			var target = result.collider
			print("Pistolet trafił w: ", target)
			if target.has_method("take_damage"):
				target.take_damage(20.0)
				print("Zadano 20 dmg dla pojazdu!")

var is_third_person = false

func _reload_pistol():
	if SaveManager.pistol_ammo >= SaveManager.PISTOL_AMMO_MAX:
		return # Pełny magazynek
		
	if not reload_audio_player:
		reload_audio_player = AudioStreamPlayer.new()
		add_child(reload_audio_player)
	if not reload_audio_player.stream:
		var snd = load("res://Modele/reload.mp3")
		if snd: reload_audio_player.stream = snd
	if reload_audio_player.stream:
		reload_audio_player.play()
		
	# Zablokuj pistolet na sekundę podczas przeładowania
	is_recoiling = true
	await get_tree().create_timer(1.0).timeout
	SaveManager.pistol_ammo = SaveManager.PISTOL_AMMO_MAX
	SaveManager.save_game()
	_update_pistol_hud()
	is_recoiling = false
	print("Przeładowano! 18/INF")

var tp_arm: SpringArm3D = null
var tp_camera: Camera3D = null

func _setup_third_person_camera():
	tp_arm = SpringArm3D.new()
	tp_arm.name = "TP_Arm"
	# Ustawiamy wysiÄ™gnik nad gĹ‚owÄ… i za plecami
	tp_arm.position = Vector3(0, 0.5, 0)
	tp_arm.spring_length = 1.8
	tp_arm.margin = 0.2
	# Dodajemy maskÄ™ kolizji, ĹĽeby kamera nie przenikaĹ‚a przez Ĺ›ciany
	tp_arm.add_excluded_object(get_rid())
	add_child(tp_arm)
	
	tp_camera = Camera3D.new()
	tp_camera.name = "TP_Camera"
	tp_arm.add_child(tp_camera)
func rotate_player(delta):
	if MOUSE_ACCEL:
		# Shperical lerp between player rotation and target
		quaternion = quaternion.slerp(Quaternion(Vector3.UP, rotation_target_player), KEY_BIND_MOUSE_ACCEL * delta)
		# Same again for head
		$Head.quaternion = $Head.quaternion.slerp(Quaternion(Vector3.RIGHT, rotation_target_head), KEY_BIND_MOUSE_ACCEL * delta)
	else:
		# If mouse accel is turned off, simply set to target
		quaternion = Quaternion(Vector3.UP, rotation_target_player)
		$Head.quaternion = Quaternion(Vector3.RIGHT, rotation_target_head)
	
func move_player(delta):
	# Ciągły zapis pozycji
	SaveManager.update_player_position(self.global_position)
	
	# Check if not on floor
	if not is_on_floor():
		# Reduce speed and accel
		speed = IN_AIR_SPEED
		accel = IN_AIR_ACCEL
		# Add the gravity
		velocity.y -= gravity * delta
	else:
		# Set speed and accel to defualt
		speed = SPEED
		accel = ACCEL

	# Handle Jump.
	if Input.is_action_just_pressed(KEY_BIND_JUMP) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector(KEY_BIND_LEFT, KEY_BIND_RIGHT, KEY_BIND_UP, KEY_BIND_DOWN)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)

	move_and_slide()

func head_bob_motion():
	var pos = Vector3.ZERO
	pos.y += sin(tick * HEAD_BOB_FREQUENCY) * HEAD_BOB_AMPLITUDE
	pos.x += cos(tick * HEAD_BOB_FREQUENCY/2) * HEAD_BOB_AMPLITUDE * 2
	$Head.position += pos

func reset_head_bob(delta):
	# Lerp back to the staring position
	if $Head.position == head_start_pos:
		pass
	$Head.position = lerp($Head.position, head_start_pos, 2 * (1/HEAD_BOB_FREQUENCY) * delta)
	
func toggle_pause():
	if not pause_menu: 
		# JeĹ›li nie ma menu pauzy, po prostu przeĹ‚Ä…czamy myszkÄ™ i stan pauzy
		get_tree().paused = not get_tree().paused
		if get_tree().paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused
	
	if pause_buttons:
		pause_buttons.visible = true
	if options_panel:
		options_panel.visible = false
	if fancy_options:
		fancy_options.visible = false

	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_wroc_button_pressed() -> void:
	toggle_pause()


func _on_ustawienia_button_pressed() -> void:
	if pause_buttons:
		pause_buttons.visible = false
	if options_panel:
		options_panel.visible = false
	if fancy_options:
		fancy_options.visible = true


func _on_wyjscie_button_pressed() -> void:
	# WAĹ»NE: Musisz wyĹ‚Ä…czyÄ‡ pauzÄ™, zanim zmienisz scenÄ™!
	get_tree().paused = false
	# WrĂłÄ‡ do menu gĹ‚Ăłwnego
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_options_wstecz_pressed() -> void:
	if fancy_options:
		fancy_options.visible = false
	if options_panel:
		options_panel.visible = false
	if pause_buttons:
		pause_buttons.visible = true

func _on_music_slider_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)
	SaveManager.music_vol_db = db
	SaveManager.save_game()

func _on_sfx_slider_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
	SaveManager.sfx_vol_db = db
	SaveManager.save_game()

func _on_graphic_options_item_selected(index: int) -> void:
	SaveManager.graphics_quality = index
	SaveManager.save_game()
	update_graphics_quality(index)

func linear_to_db(linear_value: float) -> float:
	return lerp(-80.0, 10.0, linear_value)

func db_to_linear(db_value: float) -> float:
	return inverse_lerp(-80.0, 10.0, db_value)

func update_graphics_quality(index: int) -> void:
	SaveManager.graphics_quality = index
	SaveManager.apply_graphics_settings(get_viewport())

# =============================================
# ===  FAR CRY STYLE OPTIONS UI BUILDER     ===
# =============================================

func _build_fancy_options():
	if not pause_menu:
		return
	pause_menu.color = Color(0.03, 0.04, 0.03, 0.85)
	if options_panel:
		options_panel.visible = false

	# --- Panel gĹ‚Ăłwny ---
	fancy_options = PanelContainer.new()
	fancy_options.process_mode = Node.PROCESS_MODE_ALWAYS
	fancy_options.visible = false
	fancy_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	fancy_options.offset_left = 40
	fancy_options.offset_top = 30
	fancy_options.offset_right = -40
	fancy_options.offset_bottom = -30
	var panel_bg = StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.06, 0.07, 0.05, 0.92)
	panel_bg.set_corner_radius_all(0)
	panel_bg.content_margin_top = 20
	panel_bg.content_margin_bottom = 20
	panel_bg.content_margin_left = 30
	panel_bg.content_margin_right = 30
	fancy_options.add_theme_stylebox_override("panel", panel_bg)
	pause_menu.add_child(fancy_options)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	fancy_options.add_child(main_vbox)

	# --- TytuĹ‚ "OPCJE" ---
	var title = Label.new()
	title.text = "OPCJE"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	main_vbox.add_child(title)
	_add_spacer(main_vbox, 10)

	# --- Pasek zakĹ‚adek ---
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 0)
	main_vbox.add_child(tab_bar)

	_fc_tab_grafika = _make_tab_btn("GRAFIKA", true)
	_fc_tab_grafika.pressed.connect(_on_fc_tab_grafika)
	tab_bar.add_child(_fc_tab_grafika)

	_fc_tab_dzwiek = _make_tab_btn("DĹąWIĘK", false)
	_fc_tab_dzwiek.pressed.connect(_on_fc_tab_dzwiek)
	tab_bar.add_child(_fc_tab_dzwiek)

	# --- Zielona linia separatora ---
	var sep_line = ColorRect.new()
	sep_line.color = Color(0.3, 0.6, 0.15, 1.0)
	sep_line.custom_minimum_size = Vector2(0, 3)
	main_vbox.add_child(sep_line)
	_add_spacer(main_vbox, 14)

	# --- ZawartoĹ›Ä‡ zakĹ‚adki GRAFIKA ---
	_fc_grafika_content = VBoxContainer.new()
	_fc_grafika_content.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_fc_grafika_content)

	_fc_gfx_option = OptionButton.new()
	_fc_gfx_option.add_item("NISKA", 0)
	_fc_gfx_option.add_item("ĹšREDNIA", 1)
	_fc_gfx_option.add_item("WYSOKA", 2)
	_fc_gfx_option.select(SaveManager.graphics_quality)
	_fc_gfx_option.item_selected.connect(_on_graphic_options_item_selected)
	_add_setting_row(_fc_grafika_content, "JAKOĹšÄ† GRAFIKI", _fc_gfx_option)

	# POLE WIDZENIA (FOV)
	_fc_fov_slider = HSlider.new()
	_fc_fov_slider.min_value = 50.0
	_fc_fov_slider.max_value = 120.0
	_fc_fov_slider.step = 1.0
	_fc_fov_slider.value = SaveManager.fov
	_fc_fov_val_label = Label.new()
	_fc_fov_val_label.text = str(int(SaveManager.fov)) + "Â°"
	_fc_fov_slider.value_changed.connect(_on_fc_fov_changed)
	_add_setting_row_with_val(_fc_grafika_content, "POLE WIDZENIA", _fc_fov_slider, _fc_fov_val_label)

	# TRYB EKRANU
	_fc_screen_mode = OptionButton.new()
	_fc_screen_mode.add_item("OKNO", 0)
	_fc_screen_mode.add_item("PEĹ NY EKRAN", 1)
	_fc_screen_mode.add_item("OKNO BEZRAMKOWE", 2)
	_fc_screen_mode.select(SaveManager.screen_mode)
	_fc_screen_mode.item_selected.connect(_on_fc_screen_mode_changed)
	_add_setting_row(_fc_grafika_content, "TRYB EKRANU", _fc_screen_mode)

	# V-SYNC
	_fc_vsync_check = CheckButton.new()
	_fc_vsync_check.button_pressed = SaveManager.vsync_enabled
	_fc_vsync_check.toggled.connect(_on_fc_vsync_toggled)
	_add_setting_row(_fc_grafika_content, "V-SYNC", _fc_vsync_check)

	# CIENIE DYNAMICZNE
	_fc_shadows_check = CheckButton.new()
	_fc_shadows_check.button_pressed = SaveManager.dynamic_shadows
	_fc_shadows_check.toggled.connect(_on_fc_shadows_toggled)
	_add_setting_row(_fc_grafika_content, "CIENIE DYNAMICZNE", _fc_shadows_check)

	# --- ZawartoĹ›Ä‡ zakĹ‚adki DĹąWIĘK ---
	_fc_dzwiek_content = VBoxContainer.new()
	_fc_dzwiek_content.add_theme_constant_override("separation", 6)
	_fc_dzwiek_content.visible = false
	main_vbox.add_child(_fc_dzwiek_content)

	_fc_music_slider = HSlider.new()
	_fc_music_slider.min_value = 0.0
	_fc_music_slider.max_value = 1.0
	_fc_music_slider.step = 0.05
	_fc_music_slider.value = db_to_linear(SaveManager.music_vol_db)
	_fc_music_val_label = Label.new()
	_fc_music_val_label.text = str(int(_fc_music_slider.value * 100)) + " %"
	_fc_music_slider.value_changed.connect(_on_fc_music_changed)
	_add_setting_row_with_val(_fc_dzwiek_content, "GĹ OĹšNOĹšÄ† MUZYKI", _fc_music_slider, _fc_music_val_label)

	_fc_sfx_slider = HSlider.new()
	_fc_sfx_slider.min_value = 0.0
	_fc_sfx_slider.max_value = 1.0
	_fc_sfx_slider.step = 0.05
	_fc_sfx_slider.value = db_to_linear(SaveManager.sfx_vol_db)
	_fc_sfx_val_label = Label.new()
	_fc_sfx_val_label.text = str(int(_fc_sfx_slider.value * 100)) + " %"
	_fc_sfx_slider.value_changed.connect(_on_fc_sfx_changed)
	_add_setting_row_with_val(_fc_dzwiek_content, "GĹ OĹšNOĹšÄ† DĹąWIĘKĂ“W", _fc_sfx_slider, _fc_sfx_val_label)

	# --- Spacer aby pchnÄ…Ä‡ dolny pasek na dĂłĹ‚ ---
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	# --- Zielona linia dolna ---
	var sep_line2 = ColorRect.new()
	sep_line2.color = Color(0.3, 0.6, 0.15, 0.5)
	sep_line2.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(sep_line2)
	_add_spacer(main_vbox, 8)

	# --- Dolny pasek: WSTECZ | ZASTOSUJ ---
	var bottom_bar = HBoxContainer.new()
	main_vbox.add_child(bottom_bar)

	var wstecz_btn = Button.new()
	wstecz_btn.text = "WSTECZ"
	wstecz_btn.pressed.connect(_on_options_wstecz_pressed)
	bottom_bar.add_child(wstecz_btn)

	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer)

	var zastosuj_btn = Button.new()
	zastosuj_btn.text = "ZASTOSUJ"
	bottom_bar.add_child(zastosuj_btn)
	zastosuj_btn.pressed.connect(_on_fc_zastosuj)

	# --- Stylowanie caĹ‚ego panelu ---
	_fc_style_all(fancy_options)
	_fc_style_zastosuj(zastosuj_btn)
	update_graphics_quality(SaveManager.graphics_quality)

# --- Pomocnicze funkcje budowania ---

func _add_spacer(parent: Control, h: float):
	var s = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _make_tab_btn(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(140, 36)
	var tab_active = StyleBoxFlat.new()
	tab_active.bg_color = Color(0.22, 0.5, 0.12, 0.95)
	tab_active.set_corner_radius_all(0)
	tab_active.content_margin_left = 16
	tab_active.content_margin_right = 16
	tab_active.content_margin_top = 6
	tab_active.content_margin_bottom = 6
	var tab_inactive = StyleBoxFlat.new()
	tab_inactive.bg_color = Color(0.08, 0.1, 0.07, 0.6)
	tab_inactive.set_corner_radius_all(0)
	tab_inactive.content_margin_left = 16
	tab_inactive.content_margin_right = 16
	tab_inactive.content_margin_top = 6
	tab_inactive.content_margin_bottom = 6
	var tab_hover = StyleBoxFlat.new()
	tab_hover.bg_color = Color(0.18, 0.38, 0.1, 0.85)
	tab_hover.set_corner_radius_all(0)
	tab_hover.content_margin_left = 16
	tab_hover.content_margin_right = 16
	tab_hover.content_margin_top = 6
	tab_hover.content_margin_bottom = 6
	if active:
		btn.add_theme_stylebox_override("normal", tab_active)
		btn.add_theme_stylebox_override("pressed", tab_active)
	else:
		btn.add_theme_stylebox_override("normal", tab_inactive)
		btn.add_theme_stylebox_override("pressed", tab_active)
	btn.add_theme_stylebox_override("hover", tab_hover)
	btn.add_theme_stylebox_override("focus", tab_hover)
	btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.65))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	return btn

func _add_setting_row(parent: VBoxContainer, label_text: String, control: Control):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82))
	row.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(250, 30)
	row.add_child(control)
	# podkreĹ›lenie wiersza
	var line = ColorRect.new()
	line.color = Color(0.25, 0.3, 0.2, 0.3)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)

func _add_setting_row_with_val(parent: VBoxContainer, label_text: String, slider: HSlider, val_label: Label):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82))
	row.add_child(lbl)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 30)
	row.add_child(slider)
	val_label.custom_minimum_size = Vector2(70, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 20)
	val_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	row.add_child(val_label)
	var line = ColorRect.new()
	line.color = Color(0.25, 0.3, 0.2, 0.3)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)

# --- PrzeĹ‚Ä…czanie zakĹ‚adek ---

func _on_fc_tab_grafika():
	_fc_grafika_content.visible = true
	_fc_dzwiek_content.visible = false
	_fc_tab_grafika.button_pressed = true
	_fc_tab_dzwiek.button_pressed = false
	var active_st = StyleBoxFlat.new()
	active_st.bg_color = Color(0.22, 0.5, 0.12, 0.95)
	active_st.set_corner_radius_all(0)
	active_st.content_margin_left = 16
	active_st.content_margin_right = 16
	active_st.content_margin_top = 6
	active_st.content_margin_bottom = 6
	var inactive_st = StyleBoxFlat.new()
	inactive_st.bg_color = Color(0.08, 0.1, 0.07, 0.6)
	inactive_st.set_corner_radius_all(0)
	inactive_st.content_margin_left = 16
	inactive_st.content_margin_right = 16
	inactive_st.content_margin_top = 6
	inactive_st.content_margin_bottom = 6
	_fc_tab_grafika.add_theme_stylebox_override("normal", active_st)
	_fc_tab_dzwiek.add_theme_stylebox_override("normal", inactive_st)

func _on_fc_tab_dzwiek():
	_fc_grafika_content.visible = false
	_fc_dzwiek_content.visible = true
	_fc_tab_grafika.button_pressed = false
	_fc_tab_dzwiek.button_pressed = true
	var active_st = StyleBoxFlat.new()
	active_st.bg_color = Color(0.22, 0.5, 0.12, 0.95)
	active_st.set_corner_radius_all(0)
	active_st.content_margin_left = 16
	active_st.content_margin_right = 16
	active_st.content_margin_top = 6
	active_st.content_margin_bottom = 6
	var inactive_st = StyleBoxFlat.new()
	inactive_st.bg_color = Color(0.08, 0.1, 0.07, 0.6)
	inactive_st.set_corner_radius_all(0)
	inactive_st.content_margin_left = 16
	inactive_st.content_margin_right = 16
	inactive_st.content_margin_top = 6
	inactive_st.content_margin_bottom = 6
	_fc_tab_grafika.add_theme_stylebox_override("normal", inactive_st)
	_fc_tab_dzwiek.add_theme_stylebox_override("normal", active_st)

func _on_fc_music_changed(value: float):
	_fc_music_val_label.text = str(int(value * 100)) + " %"
	_on_music_slider_value_changed(value)

func _on_fc_sfx_changed(value: float):
	_fc_sfx_val_label.text = str(int(value * 100)) + " %"
	_on_sfx_slider_value_changed(value)

func _on_fc_zastosuj():
	SaveManager.save_game()
	_on_options_wstecz_pressed()

# --- GLOBAL HUD IMPLEMENTATION ---

func _setup_global_hud():
	if hud_canvas: return
	
	# Ukryj stare saldo
	if money_label: money_label.visible = false
	
	hud_canvas = CanvasLayer.new()
	hud_canvas.layer = 10
	add_child(hud_canvas)
	
	var margin = 20
	
	# BOX na gorze
	var top_box = HBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_box.offset_left = margin
	top_box.offset_top = margin
	top_box.offset_right = -margin
	top_box.add_theme_constant_override("separation", 30)
	hud_canvas.add_child(top_box)
	
	# Sekcja LVL i XP
	var lvl_xp_vbox = VBoxContainer.new()
	top_box.add_child(lvl_xp_vbox)
	
	hud_lvl_label = Label.new()
	hud_lvl_label.add_theme_font_size_override("font_size", 24)
	hud_lvl_label.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold
	hud_lvl_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_lvl_label.add_theme_constant_override("outline_size", 4)
	lvl_xp_vbox.add_child(hud_lvl_label)
	
	var xp_hbox = HBoxContainer.new()
	xp_hbox.add_theme_constant_override("separation", 10)
	lvl_xp_vbox.add_child(xp_hbox)
	
	hud_xp_bar = ProgressBar.new()
	hud_xp_bar.custom_minimum_size = Vector2(250, 14)
	hud_xp_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	bar_bg.set_corner_radius_all(4)
	hud_xp_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.6, 1.0, 0.9) # Blue
	bar_fill.set_corner_radius_all(4)
	hud_xp_bar.add_theme_stylebox_override("fill", bar_fill)
	xp_hbox.add_child(hud_xp_bar)
	
	hud_xp_label = Label.new()
	hud_xp_label.add_theme_font_size_override("font_size", 14)
	hud_xp_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	xp_hbox.add_child(hud_xp_label)
	
	# Sekcja PIENIADZE (Przeniesiona niĹĽej, ĹĽeby nie kolidowaÄ‡ z bindami)
	hud_money_label = Label.new()
	hud_money_label.add_theme_font_size_override("font_size", 28)
	hud_money_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4)) # Green
	hud_money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_money_label.add_theme_constant_override("outline_size", 6)
	hud_canvas.add_child(hud_money_label)
	
	hud_money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_money_label.offset_left = -250 # SzerokoĹ›Ä‡
	hud_money_label.offset_top = margin + 80 # NiĹĽej o 80px od gĂłry
	hud_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_money_label.offset_right = -margin
	
	hud_hp_bar = ProgressBar.new()
	hud_hp_bar.custom_minimum_size = Vector2(400, 25)
	hud_hp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Na dole nad ekwipunkiem
	hud_hp_bar.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - 200, get_viewport().get_visible_rect().size.y - 120)
	hud_hp_bar.max_value = 100.0
	hud_hp_bar.value = player_health
	hud_hp_bar.show_percentage = true
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	hp_bg.set_corner_radius_all(6)
	hud_hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	hp_fill.set_corner_radius_all(6)
	hud_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hud_canvas.add_child(hud_hp_bar)

func apply_damage(amount: float):
	player_health -= amount
	if player_health <= 0:
		player_health = 100.0
		if SaveManager.player_money >= 200.0:
			SaveManager.player_money -= 200.0
		SaveManager.save_game()
		
		# Teleport na start/spawn
		global_position = Vector3(0, 5, 0)
		print("Gracz umarl! Teleport na spawn.")
		
	if hud_hp_bar:
		hud_hp_bar.value = player_health

func _update_global_hud():
	if not hud_lvl_label: return
	hud_lvl_label.text = "POZIOM %d" % SaveManager.player_level
	if hud_xp_bar:
		hud_xp_bar.max_value = SaveManager.xp_for_next_level()
		hud_xp_bar.value = SaveManager.player_xp
	if hud_xp_label:
		hud_xp_label.text = "%d / %d XP" % [SaveManager.player_xp, SaveManager.xp_for_next_level()]
	if hud_money_label:
		hud_money_label.text = "%.2f zĹ‚" % SaveManager.player_money

func _on_xp_updated(_xp, _lvl):
	_update_global_hud()

func _on_money_updated(_amount):
	_update_global_hud()


func _on_fc_fov_changed(value: float):
	_fc_fov_val_label.text = str(int(value)) + "Â°"
	SaveManager.fov = value
	var cam = get_node_or_null("Head/Camera3D")
	if cam:
		cam.fov = value

func _on_fc_screen_mode_changed(index: int):
	SaveManager.screen_mode = index
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _on_fc_vsync_toggled(enabled: bool):
	SaveManager.vsync_enabled = enabled
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_fc_shadows_toggled(enabled: bool):
	SaveManager.dynamic_shadows = enabled
	var light = get_tree().current_scene.get_node_or_null("DirectionalLight3D")
	if light:
		light.shadow_enabled = enabled

# --- Stylowanie Far Cry ---

func _fc_style_all(root: Node):
	for child in root.get_children():
		if child is Button and not (child == _fc_tab_grafika or child == _fc_tab_dzwiek):
			var n = StyleBoxFlat.new()
			n.bg_color = Color(0.1, 0.12, 0.08, 0.8)
			n.set_border_width_all(1)
			n.border_color = Color(0.3, 0.4, 0.2, 0.4)
			n.set_corner_radius_all(2)
			n.content_margin_top = 8
			n.content_margin_bottom = 8
			n.content_margin_left = 16
			n.content_margin_right = 16
			var h = n.duplicate()
			h.bg_color = Color(0.18, 0.3, 0.1, 0.9)
			h.border_color = Color(0.4, 0.6, 0.2, 0.7)
			child.add_theme_stylebox_override("normal", n)
			child.add_theme_stylebox_override("hover", h)
			child.add_theme_stylebox_override("pressed", h)
			child.add_theme_stylebox_override("focus", h)
			child.add_theme_color_override("font_color", Color(0.8, 0.85, 0.75))
			child.add_theme_color_override("font_hover_color", Color.WHITE)
			if child is OptionButton:
				var popup = child.get_popup()
				if popup:
					var pp = StyleBoxFlat.new()
					pp.bg_color = Color(0.07, 0.09, 0.06, 0.96)
					pp.set_border_width_all(1)
					pp.border_color = Color(0.3, 0.45, 0.15, 0.5)
					popup.add_theme_stylebox_override("panel", pp)
					var ph = StyleBoxFlat.new()
					ph.bg_color = Color(0.2, 0.35, 0.1, 0.9)
					popup.add_theme_stylebox_override("hover", ph)
					popup.add_theme_color_override("font_color", Color(0.85, 0.9, 0.8))
					popup.add_theme_color_override("font_hover_color", Color.WHITE)
		if child is HSlider:
			var sl_bg = StyleBoxFlat.new()
			sl_bg.bg_color = Color(0.15, 0.18, 0.12, 0.7)
			sl_bg.set_corner_radius_all(2)
			sl_bg.content_margin_top = 5
			sl_bg.content_margin_bottom = 5
			var sl_fill = StyleBoxFlat.new()
			sl_fill.bg_color = Color(0.75, 0.8, 0.7, 0.9)
			sl_fill.set_corner_radius_all(2)
			sl_fill.content_margin_top = 5
			sl_fill.content_margin_bottom = 5
			var sl_hl = sl_fill.duplicate()
			sl_hl.bg_color = Color(0.85, 0.9, 0.8, 0.95)
			child.add_theme_stylebox_override("slider", sl_bg)
			child.add_theme_stylebox_override("grabber_area", sl_fill)
			child.add_theme_stylebox_override("grabber_area_highlight", sl_hl)
		_fc_style_all(child)

func _fc_style_zastosuj(btn: Button):
	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.85, 0.72, 0.1, 0.95)
	n.set_corner_radius_all(2)
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	n.content_margin_left = 24
	n.content_margin_right = 24
	var h = n.duplicate()
	h.bg_color = Color(0.95, 0.82, 0.15, 1.0)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus", h)
	btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.05))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.02))
	btn.add_theme_font_size_override("font_size", 20)

	btn.custom_minimum_size = Vector2(0, 50)
	return btn

# ============================================
# === INVENTORY / HOTBAR SYSTEM ===
# ============================================

func _load_item_textures():
	var paths = SaveManager.ITEM_ICONS
	for id in paths:
		if paths[id] != "":
			if ResourceLoader.exists(paths[id]):
				item_textures[id] = load(paths[id])
				print("✓ Załadowano teksturę: %s -> %s" % [id, paths[id]])
			else:
				print("✗ Brak tekstury: ", paths[id])

func _setup_hotbar():
	# Pistolet Amunicja HUD - Tworzymy niezależnie
	if hud_canvas:
		pistol_ammo_panel = PanelContainer.new()
		pistol_ammo_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		pistol_ammo_panel.position = Vector2(-250, -180) # Trochę wyżej niż hotbar
		pistol_ammo_panel.visible = false
		var style_ammo = StyleBoxFlat.new()
		style_ammo.bg_color = Color(0.1, 0.05, 0.05, 0.9)
		style_ammo.set_corner_radius_all(8)
		style_ammo.set_border_width_all(2)
		style_ammo.border_color = Color(0.8, 0.2, 0.2, 0.8)
		style_ammo.set_content_margin_all(15)
		pistol_ammo_panel.add_theme_stylebox_override("panel", style_ammo)
		
		var vbox_ammo = VBoxContainer.new()
		pistol_ammo_panel.add_child(vbox_ammo)
		
		var tit = Label.new()
		tit.text = "GLOCK 19"
		tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tit.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox_ammo.add_child(tit)
		
		pistol_ammo_label = Label.new()
		pistol_ammo_label.text = "18/∞"
		pistol_ammo_label.add_theme_font_size_override("font_size", 32)
		pistol_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_ammo.add_child(pistol_ammo_label)
		
		hud_canvas.add_child(pistol_ammo_panel)

	# Użyj istniejącego InventoryBar z PlayerUI
	var inv_bar = get_node_or_null("PlayerUI/InventoryBar")
	if inv_bar:
		print("✓ Znaleziono InventoryBar w scenie!")
		hotbar_container = inv_bar
		# Znajdź istniejące Panele (Panel, Panel2, Panel3, Panel4, Panel5)
		var panel_names = ["Panel", "Panel2", "Panel3", "Panel4", "Panel5"]
		for pname in panel_names:
			var panel = inv_bar.get_node_or_null(pname)
			if panel:
				hotbar_slots.append(panel)
				# Wyczyść istniejącą zawartość
				for child in panel.get_children():
					child.queue_free()
				# Dodaj VBox z ikoną i labelem
				var vbox = VBoxContainer.new()
				vbox.alignment = BoxContainer.ALIGNMENT_CENTER
				vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
				panel.add_child(vbox)
				
				var icon = TextureRect.new()
				icon.custom_minimum_size = Vector2(56, 56)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				vbox.add_child(icon)
				hotbar_icons.append(icon)
				
				var lbl = Label.new()
				lbl.add_theme_font_size_override("font_size", 11)
				lbl.add_theme_color_override("font_color", Color.WHITE)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(lbl)
				hotbar_labels.append(lbl)
			else:
				print("✗ Brak panelu: ", pname)
		
		_update_hotbar_selection()
		_update_hotbar()
		return
	
	# Fallback - stwórz nowy na hud_canvas
	print("InventoryBar nie znaleziony, tworzę nowy...")
	if not hud_canvas: return
	
	# Stworzenie hotbaru elementów GUI (tylko w razie braku)
	hotbar_container = HBoxContainer.new()
	hotbar_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hotbar_container.add_theme_constant_override("separation", 10)
	hud_canvas.add_child(hotbar_container)

	for i in range(5):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(70, 70)
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		slot_style.set_border_width_all(2)
		slot_style.border_color = Color(0.3, 0.3, 0.3, 0.8)
		slot_style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_panel.add_child(vbox)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vbox.add_child(icon)
		
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		
		hotbar_container.add_child(slot_panel)
		hotbar_slots.append(slot_panel)
		hotbar_icons.append(icon)
		hotbar_labels.append(lbl)
	
	hotbar_container.position = Vector2(-185, -90)
	_update_hotbar_selection()
	_update_hotbar()

func _update_hotbar_selection():
	for i in range(hotbar_slots.size()):
		var style = StyleBoxFlat.new()
		if i == selected_hotbar_slot:
			style.bg_color = Color(0.15, 0.15, 0.1, 0.85)
			style.set_border_width_all(3)
			style.border_color = Color(1.0, 0.85, 0.2, 1.0)  # Złota ramka
		else:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
			style.set_border_width_all(2)
			style.border_color = Color(0.3, 0.3, 0.3, 0.8)
		style.set_corner_radius_all(6)
		hotbar_slots[i].add_theme_stylebox_override("panel", style)
		
	var selected_item_id = ""
	if selected_hotbar_slot >= 0 and selected_hotbar_slot < hotbar_item_ids.size():
		selected_item_id = hotbar_item_ids[selected_hotbar_slot]
		
	if weapon_model:
		weapon_model.visible = (selected_item_id == "pistolet")
	
	if pistol_ammo_panel:
		pistol_ammo_panel.visible = (selected_item_id == "pistolet")
		if pistol_ammo_panel.visible: _update_pistol_hud()

	_update_held_item(selected_item_id)

func _update_pistol_hud():
	if pistol_ammo_label:
		pistol_ammo_label.text = "%d/∞" % SaveManager.pistol_ammo

func _update_held_item(item_id: String):
	if current_held_item_node:
		current_held_item_node.queue_free()
		current_held_item_node = null
		
	if not ITEM_GLB_PATHS.has(item_id):
		return
		
	var path = ITEM_GLB_PATHS[item_id]
	var scene = load(path)
	if not scene: return
	
	var item_node = scene.instantiate()
	var cam = get_node_or_null("Head/Camera3D")
	if cam:
		cam.add_child(item_node)
		current_held_item_node = item_node
		
		# Przypisz transformację z inspektora w zależności od podanego itemku
		if item_id == "piwo":
			item_node.position = beer_pos
			item_node.rotation_degrees = beer_rot
			item_node.scale = beer_scale
		elif item_id == "energol":
			item_node.position = energy_pos
			item_node.rotation_degrees = energy_rot
			item_node.scale = energy_scale
		elif item_id == "kanister":
			item_node.position = gas_pos
			item_node.rotation_degrees = gas_rot
			item_node.scale = gas_scale
		elif item_id == "papieros":
			item_node.position = cig_pos
			item_node.rotation_degrees = cig_rot
			item_node.scale = cig_scale
		

func _update_hotbar():
	for i in range(hotbar_slots.size()):
		var item_id = hotbar_item_ids[i]
		if item_id == "" or not SaveManager.inventory.has(item_id):
			if i < hotbar_icons.size(): hotbar_icons[i].texture = null
			if i < hotbar_labels.size(): hotbar_labels[i].text = ""
			continue
		
		# Automatycznie usun z hotbara jesli count = 0 (nie kanister)
		var count = SaveManager.inventory.get(item_id, 0)
		if item_id != "kanister" and count <= 0:
			hotbar_item_ids[i] = ""
			if i < hotbar_icons.size(): hotbar_icons[i].texture = null
			if i < hotbar_labels.size(): hotbar_labels[i].text = ""
			continue
		
		if item_textures.has(item_id) and i < hotbar_icons.size():
			hotbar_icons[i].texture = item_textures[item_id]
		
		if i < hotbar_labels.size():
			if item_id == "kanister":
				var pct = (SaveManager.canister_fuel / SaveManager.CANISTER_MAX) * 100.0
				hotbar_labels[i].text = "%.0f%%" % pct
			else:
				hotbar_labels[i].text = "x%d" % count

func _setup_inventory_panel():
	if not hud_canvas: return
	
	# Ciemne tło (overlay)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.name = "InventoryOverlay"
	hud_canvas.add_child(overlay)
	
	inventory_panel = PanelContainer.new()
	inventory_panel.custom_minimum_size = Vector2(500, 450)
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-250, -225)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.05, 0.95)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.3, 0.5, 0.2, 0.9)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	inventory_panel.add_child(main_vbox)
	
	# Tytuł
	var title = Label.new()
	title.text = "EKWIPUNEK"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	var hint = Label.new()
	hint.text = "Kliknij przedmiot aby przenieść do paska | ESC zamknij"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(hint)
	
	# Separator
	var sep = ColorRect.new()
	sep.color = Color(0.3, 0.5, 0.2, 0.6)
	sep.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(sep)
	
	# Grid z przedmiotami
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 3
	inventory_grid.add_theme_constant_override("h_separation", 15)
	inventory_grid.add_theme_constant_override("v_separation", 15)
	main_vbox.add_child(inventory_grid)
	
	inventory_panel.visible = false
	hud_canvas.add_child(inventory_panel)

func _toggle_inventory(open: bool):
	inventory_open = open
	inventory_panel.visible = open
	
	# Overlay (ciemne tło)
	var overlay = hud_canvas.get_node_or_null("InventoryOverlay")
	if overlay:
		overlay.visible = open
	
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_inventory_grid()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_inventory_grid():
	# Wyczyść stare
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# Dodaj aktualne przedmioty
	var items_to_show = SaveManager.inventory.keys()
	for item_id in items_to_show:
		var count = SaveManager.inventory.get(item_id, 0)
		# Ukryj przedmioty z count 0 (oprocz kanistra)
		if item_id == "kanister":
			if count <= 0:
				continue
		elif count <= 0:
			continue
		
		var item_panel = PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(130, 140)
		var item_style = StyleBoxFlat.new()
		item_style.bg_color = Color(0.12, 0.15, 0.1, 0.9)
		item_style.set_border_width_all(2)
		item_style.border_color = Color(0.4, 0.5, 0.3, 0.7)
		item_style.set_corner_radius_all(8)
		item_style.content_margin_top = 10
		item_style.content_margin_bottom = 10
		item_style.content_margin_left = 10
		item_style.content_margin_right = 10
		item_panel.add_theme_stylebox_override("panel", item_style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)
		item_panel.add_child(vbox)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		if item_textures.has(item_id):
			icon.texture = item_textures[item_id]
		vbox.add_child(icon)
		
		var name_lbl = Label.new()
		name_lbl.text = SaveManager.ITEM_NAMES.get(item_id, item_id)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)
		
		var count_lbl = Label.new()
		if item_id == "kanister":
			var pct = (SaveManager.canister_fuel / SaveManager.CANISTER_MAX) * 100.0
			count_lbl.text = "%.0f%% paliwa" % pct
		else:
			count_lbl.text = "x%d" % count
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(count_lbl)
		
		# Przycisk "Na pasek"
		var equip_btn = Button.new()
		equip_btn.text = "→ Na pasek"
		equip_btn.add_theme_font_size_override("font_size", 13)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.35, 0.15, 0.9)
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_top = 4
		btn_style.content_margin_bottom = 4
		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color(0.3, 0.5, 0.2, 1.0)
		equip_btn.add_theme_stylebox_override("normal", btn_style)
		equip_btn.add_theme_stylebox_override("hover", btn_hover)
		equip_btn.add_theme_stylebox_override("pressed", btn_hover)
		equip_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
		equip_btn.pressed.connect(_equip_to_hotbar.bind(item_id))
		vbox.add_child(equip_btn)
		
		inventory_grid.add_child(item_panel)

func _equip_to_hotbar(item_id: String):
	# Nie dodawaj jesli count = 0
	var count = SaveManager.inventory.get(item_id, 0)
	if item_id != "kanister" and count <= 0:
		print("Nie masz %s!" % item_id)
		return
	# Sprawdz czy juz jest na hotbarze
	for i in range(5):
		if hotbar_item_ids[i] == item_id:
			print("%s juz jest na pasku!" % item_id)
			return
	# Znajdz pierwszy pusty slot
	for i in range(5):
		if hotbar_item_ids[i] == "":
			hotbar_item_ids[i] = item_id
			_update_hotbar()
			_refresh_inventory_grid()
			return
	# Jak nie ma pustego - nadpisz wybrany slot
	hotbar_item_ids[selected_hotbar_slot] = item_id
	_update_hotbar()
	_refresh_inventory_grid()

func _drop_hotbar_item():
	var item_id = hotbar_item_ids[selected_hotbar_slot]
	if item_id == "":
		return
	
	# Sprawdź czy mamy ten przedmiot w ekwipunku
	if item_id != "kanister": # kanister nie zużywa się z inventory
		if SaveManager.inventory.get(item_id, 0) <= 0:
			hotbar_item_ids[selected_hotbar_slot] = ""
			_update_hotbar()
			_update_hotbar_selection()
			return
		SaveManager.inventory[item_id] -= 1
		SaveManager.save_game()
	
	var iname = SaveManager.ITEM_NAMES.get(item_id, item_id)
	print("Wyrzucono %s z paska." % iname)
	
	# Pobierz skalę przedmiotu z ustawień gracza
	var drop_scale = Vector3.ONE
	match item_id:
		"piwo": drop_scale = beer_scale
		"energol": drop_scale = energy_scale
		"kanister": drop_scale = gas_scale
		"papieros": drop_scale = cig_scale
		"pistolet": drop_scale = Vector3(1, 1, 1) # pistolet ma swój własny WeaponPickup
	
	# Tworzenie pickupa
	var cam = get_node_or_null("Head/Camera3D")
	if cam:
		if item_id == "pistolet":
			# Pistolet - użyj istniejącego WeaponPickup.tscn
			var w_scene = load("res://WeaponPickup.tscn")
			if w_scene:
				var w = w_scene.instantiate()
				get_tree().root.add_child(w)
				w.global_position = cam.global_position - cam.global_transform.basis.z * 1.5
				w.apply_central_impulse(-cam.global_transform.basis.z * 6.0 + Vector3(0, 1.5, 0))
		else:
			# Generyczny pickup dla piwa, energola, kanistra, papierosa
			var pickup = RigidBody3D.new()
			pickup.mass = 1.0
			pickup.collision_layer = 1
			pickup.collision_mask = 3
			pickup.add_to_group("interactable")
			
			# Dodaj collision shape
			var col = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.3, 0.3, 0.3)
			col.shape = shape
			pickup.add_child(col)
			
			# Załaduj model z ITEM_GLB_PATHS
			var model_path = ITEM_GLB_PATHS.get(item_id, "")
			if model_path != "":
				var scene = load(model_path)
				if scene:
					var model = scene.instantiate()
					model.scale = drop_scale
					pickup.add_child(model)
			
			# Dodaj skrypt do podnoszenia
			var script_code = """extends RigidBody3D
var item_id = \"%s\"
func interact():
	var save = get_node(\"/root/SaveManager\")
	if save.inventory.has(item_id):
		save.inventory[item_id] += 1
	else:
		save.inventory[item_id] = 1
	save.save_game()
	var player = get_tree().get_first_node_in_group(\"player\")
	if player and player.has_method(\"_refresh_inventory_grid\"):
		player._refresh_inventory_grid()
	print(\"Podniesiono: \", item_id)
	queue_free()
""" % item_id
			var scr = GDScript.new()
			scr.source_code = script_code
			scr.reload()
			pickup.set_script(scr)
			
			get_tree().root.add_child(pickup)
			pickup.global_position = cam.global_position - cam.global_transform.basis.z * 1.5
			pickup.apply_central_impulse(-cam.global_transform.basis.z * 5.0 + Vector3(0, 1.5, 0))
	
	# Wyrzucony z hotbaru
	if SaveManager.inventory.get(item_id, 0) <= 0:
		hotbar_item_ids[selected_hotbar_slot] = ""
	
	_update_hotbar()
	_update_hotbar_selection()
	_refresh_inventory_grid()

func _update_item_prompt():
	if not item_prompt_label: return
	
	# Ukryj podpowiedzi gdy jakiekolwiek GUI jest otwarte
	if inventory_open or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		item_prompt_label.visible = false
		return
	
	# Check for pushing vehicle first
	if is_pushing_vehicle:
		item_prompt_label.text = "Nacisnij [H] aby przestac pchac"
		item_prompt_label.visible = true
		return
		
	# Push tip - TYLKO gdy celownik (raycast) trafia w zepsuty skuter
	if interaction_raycast and interaction_raycast.is_colliding():
		var ray_target = interaction_raycast.get_collider()
		if ray_target and ray_target.is_in_group("vehicle"):
			var is_vehicle_broken = false
			if ray_target.has_method("is_broken"):
				is_vehicle_broken = ray_target.is_broken()
			elif "is_broken" in ray_target:
				is_vehicle_broken = ray_target.is_broken
			if is_vehicle_broken:
				item_prompt_label.text = "Skuter zepsuty! Nacisnij [H] aby pchac"
				item_prompt_label.visible = true
				return
	# Laptop interaction tip
	if interaction_raycast and interaction_raycast.is_colliding():
		var ray_target = interaction_raycast.get_collider()
		if ray_target and ray_target.has_method("open_laptop_ui"):
			item_prompt_label.text = "Otworz laptop [PPM]"
			item_prompt_label.visible = true
			return
		elif ray_target and ray_target.has_method("interact"):
			item_prompt_label.text = "Podnieś przedmiot [LPM]"
			item_prompt_label.visible = true
			return

	var item_id = hotbar_item_ids[selected_hotbar_slot]
	
	if item_id in ["piwo", "energol", "papieros"]:
		var iname = SaveManager.ITEM_NAMES.get(item_id, item_id)
		var count = SaveManager.inventory.get(item_id, 0)
		if count > 0:
			var action_verb = "Zapal" if item_id == "papieros" else "Wypij"
			item_prompt_label.text = "%s %s [PPM]" % [action_verb, iname]
			item_prompt_label.visible = true
		else:
			item_prompt_label.text = "Brak %s!" % iname
			item_prompt_label.visible = true
	elif item_id == "kanister":
		var pct = (SaveManager.canister_fuel / SaveManager.CANISTER_MAX) * 100.0
		# Jeśli pusto
		if SaveManager.canister_fuel <= 0:
			item_prompt_label.text = "Kanister pusty!"
			item_prompt_label.visible = true
			return
			
		# Pokaz prompt gdy celuje lub po prostu stoi blisko skutera (5m)
		var near_vehicle = _find_nearby_vehicle()
		var raycast_hit = false
		if interaction_raycast and interaction_raycast.is_colliding():
			var collider = interaction_raycast.get_collider()
			if collider and collider.is_in_group("vehicle"):
				near_vehicle = collider
				raycast_hit = true
				
		if near_vehicle != null:
			item_prompt_label.text = "Napełnij skuter [LPM] (%.0f%%)" % pct
			item_prompt_label.visible = true
		else:
			item_prompt_label.text = "Kanister: %.0f%%" % pct
			item_prompt_label.visible = true
	else:
		item_prompt_label.visible = false

func _find_nearby_vehicle():
	var vehicles = get_tree().get_nodes_in_group("vehicle")
	for v in vehicles:
		if global_position.distance_to(v.global_position) < 5.0:
			return v
	return null

func _setup_item_prompt():
	if not hud_canvas: return
	item_prompt_label = Label.new()
	item_prompt_label.add_theme_font_size_override("font_size", 18)
	item_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	item_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	item_prompt_label.add_theme_constant_override("outline_size", 4)
	item_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	item_prompt_label.position = Vector2(-150, 30)
	item_prompt_label.size = Vector2(300, 30)
	item_prompt_label.visible = false
	hud_canvas.add_child(item_prompt_label)

func _use_hotbar_item(item_id: String):
	if is_drinking: return # Zabezpieczenie przed spamowaniem picia
	
	if item_id == "kanister":
		_try_canister_refuel()
	elif item_id == "piwo":
		if SaveManager.use_item("piwo"):
			_play_drinking_anim(item_id)
			return # NIE aktualizuj hotbaru teraz - zrobi to _play_drinking_anim po animacji
	elif item_id == "energol":
		if SaveManager.use_item("energol"):
			_play_drinking_anim(item_id)
			return # NIE aktualizuj hotbaru teraz
	elif item_id == "papieros":
		if SaveManager.use_item("papieros"):
			print("Zapalono szluga!")
			
	# Update HUD/Ikonek (tylko dla NIE-pijących akcji)
	_update_item_prompt()
	var count = SaveManager.inventory.get(item_id, 0)
	if item_id != "kanister" and count <= 0:
		hotbar_item_ids[selected_hotbar_slot] = ""
		
	_update_hotbar()
	_update_hotbar_selection()
	_refresh_inventory_grid()

var is_drinking = false
func _play_drinking_anim(item_id: String):
	if not current_held_item_node: return
	is_drinking = true
	
	# Dźwięk otwierania najpierw
	var open_audio = AudioStreamPlayer.new()
	var ost = load("res://openingcan.mp3")
	if ost: 
		open_audio.stream = ost
		add_child(open_audio)
		open_audio.play()
		open_audio.finished.connect(open_audio.queue_free)
	
	# Czekamy krótko aż puszka się 'otworzy'
	await get_tree().create_timer(1.2).timeout
	
	# Odtwórz dźwięk picia
	var drink_audio = AudioStreamPlayer.new()
	var st = load("res://Modele/drinking.mp3")
	if st:
		drink_audio.stream = st
		drink_audio.volume_db = 2.0
		add_child(drink_audio)
		drink_audio.play()
		drink_audio.finished.connect(drink_audio.queue_free)
	
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var original_rot = current_held_item_node.rotation_degrees
	# Bardziej płynne i widoczne pochylenie (możesz zmienić sign jeśli rotacja się odwróci złą stroną)
	var tilt_rot = original_rot + Vector3(60, -20, 0)
	var original_pos = current_held_item_node.position
	var tilt_pos = original_pos + Vector3(0.0, -0.15, 0.15) # Podniesienie i przybliżenie do twarzy
	
	# Animacja do ust
	tw.tween_property(current_held_item_node, "rotation_degrees", tilt_rot, 0.6)
	tw.parallel().tween_property(current_held_item_node, "position", tilt_pos, 0.6)
	
	# Czekamy ułamek sekundy "pijąc"
	tw.tween_interval(0.8)
	
	# Wrzucamy puszke na stare miejsce
	tw.tween_property(current_held_item_node, "rotation_degrees", original_rot, 0.6)
	tw.parallel().tween_property(current_held_item_node, "position", original_pos, 0.6)
	
	await get_tree().create_timer(2.0).timeout
	
	if item_id == "piwo":
		alcohol_timer = 40.0
		print("Efekt piwa wchodzi!")
	elif item_id == "energol":
		energy_timer = 30.0
		print("Efekt energola wchodzi!")
		var bspeed = base_speed
		SPEED = bspeed * 1.5
	
	# Dopiero teraz aktualizujemy hotbar (po zakończeniu animacji)
	var count = SaveManager.inventory.get(item_id, 0)
	if count <= 0:
		hotbar_item_ids[selected_hotbar_slot] = ""
	_update_hotbar()
	_update_hotbar_selection()
	_refresh_inventory_grid()
		
	is_drinking = false

var is_smoking_inhaling = false

func _exhale_smoke():
	print("Wydmuchuje dym!")
	# Tworzymy luźne GPU Particles jeśli nie ma lub pokazujemy istniejące
	# Odpalenie FOV powrotnego zostawiamy w procesie
	var existing = get_node_or_null("Head/Camera3D/SmokeExhale")
	if not existing:
		existing = GPUParticles3D.new()
		existing.name = "SmokeExhale"
		existing.emitting = false
		existing.amount = 12
		existing.lifetime = 2.0
		existing.one_shot = true
		existing.explosiveness = 0.8
		
		# Prosty Particle Process dla dymu
		var mat = ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, -1) # do przodu
		mat.spread = 15.0
		mat.gravity = Vector3(0, 0.5, 0)
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 3.5
		
		# Dodajemy gradient dla koloru (od białego do przezroczystego ciemnego)
		var grad = Gradient.new()
		grad.add_point(0.0, Color.WHITE)
		grad.add_point(0.5, Color(0.8, 0.8, 0.8, 0.5))
		grad.add_point(1.0, Color(0.5, 0.5, 0.5, 0.0))
		var grad_tex = GradientTexture1D.new()
		grad_tex.gradient = grad
		mat.color_ramp = grad_tex
		mat.scale_min = 0.5
		mat.scale_max = 1.5
		
		existing.process_material = mat
		
		var mesh = QuadMesh.new()
		var dmat = StandardMaterial3D.new()
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dmat.albedo_color = Color(0.8, 0.8, 0.8, 0.6)
		dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mesh.material = dmat
		existing.draw_pass_1 = mesh
		
		get_node("Head/Camera3D").add_child(existing)
		existing.position = Vector3(0, -0.2, -0.5) # Pod twarzą przód
		
	existing.restart()

func _play_can_sound():
	var sound = AudioStreamPlayer.new()
	var stream = load("res://openingcan.mp3")
	if stream:
		sound.stream = stream
		sound.volume_db = -5.0
		add_child(sound)
		sound.play()
		sound.finished.connect(sound.queue_free)

func _try_canister_refuel():
	if SaveManager.canister_fuel <= 0:
		print("Kanister pusty!")
		return
	
	# Znajdź najbliższy skuter w zasięgu 5m
	var vehicles = get_tree().get_nodes_in_group("vehicle")
	var closest_vehicle = null
	var closest_dist = 5.0  # Maksymalna odległość
	
	for v in vehicles:
		var dist = global_position.distance_to(v.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_vehicle = v
	
	if closest_vehicle:
		_start_canister_refuel(closest_vehicle)
	else:
		print("Podejdź bliżej skutera, aby zatankować z kanistra.")

func _start_canister_refuel(vehicle):
	if is_canister_refueling: return
	is_canister_refueling = true
	
	var missing = vehicle.max_fuel - vehicle.current_fuel
	var to_add = min(missing, SaveManager.canister_fuel)
	
	if to_add < 0.05:
		print("Bak pełny lub kanister pusty.")
		is_canister_refueling = false
		return
	
	var refuel_time = max(1.0, to_add * 2.0)
	
	if refuel_container:
		refuel_container.visible = true
	if refuel_bar:
		refuel_bar.value = 0
		refuel_bar.max_value = 100
	if refuel_label:
		refuel_label.text = "Dolewanie z kanistra..."
	
	var tween = create_tween()
	if refuel_bar:
		tween.tween_property(refuel_bar, "value", 100, refuel_time)
	else:
		tween.tween_interval(refuel_time)
	
	await tween.finished
	
	# Dolej paliwo
	vehicle.current_fuel += to_add
	if vehicle.current_fuel > vehicle.max_fuel:
		vehicle.current_fuel = vehicle.max_fuel
	vehicle.has_fuel = true
	SaveManager.canister_fuel -= to_add
	if SaveManager.canister_fuel < 0:
		SaveManager.canister_fuel = 0
	SaveManager.save_game()
	
	if refuel_container:
		refuel_container.visible = false
	is_canister_refueling = false
	print("Zatankowano %.2f L z kanistra!" % to_add)

# --- Efekty Alkoholu ---
var drunk_overlay: ColorRect = null
var drunk_canvas: CanvasLayer = null  # Osobna warstwa PONIŻEJ HUD

func _apply_alcohol_effect(_delta):
	var cam = get_node_or_null("Head/Camera3D")
	if not cam: return
	var time = float(Time.get_ticks_msec()) / 1000.0
	
	# DUŻE kołysanie kamery
	var sway_x = sin(time * 1.3) * 0.14
	var sway_z = cos(time * 0.9) * 0.12
	var sway_y = sin(time * 0.6) * 0.05
	cam.rotation.z = sway_z
	
	# Przechylanie głowy
	var head = get_node_or_null("Head")
	if head:
		head.rotation.z = sway_x
		head.rotation.x += sway_y * _delta
	
	# Pulsujące FOV - mocne rozjeżdżanie ekranu
	var fov_wobble = sin(time * 0.7) * 8.0 + sin(time * 1.8) * 3.0
	cam.fov = 75.0 + fov_wobble
	
	# Shader rozmycia
	if not drunk_overlay:
		_create_drunk_overlay()
	if drunk_overlay:
		drunk_overlay.visible = true
		if drunk_canvas:
			drunk_canvas.visible = true
		var mat = drunk_overlay.material as ShaderMaterial
		if mat:
			var blur_pulse = 0.5 + sin(time * 1.5) * 0.25 + cos(time * 0.8) * 0.15
			mat.set_shader_parameter("intensity", blur_pulse)
			mat.set_shader_parameter("time_val", time)

func _remove_alcohol_effect():
	var cam = get_node_or_null("Head/Camera3D")
	if cam:
		cam.rotation.z = 0
		cam.fov = 75.0
	var head = get_node_or_null("Head")
	if head:
		head.rotation.z = 0
	if drunk_overlay:
		drunk_overlay.visible = false
	if drunk_canvas:
		drunk_canvas.visible = false
	print("Efekt alkoholu minął.")

func _create_drunk_overlay():
	# Osobny CanvasLayer PONIŻEJ HUD - shader łapie TYLKO świat 3D, GUI pozostaje ostre
	drunk_canvas = CanvasLayer.new()
	drunk_canvas.layer = 0  # Warstwa 0 = między światem 3D a HUD (który jest na 1+)
	add_child(drunk_canvas)
	
	drunk_overlay = ColorRect.new()
	drunk_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drunk_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float time_val = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5);
    vec2 dir = uv - center;
    float dist = length(dir);
    
    // === FALOWANIE EKRANU (wave distortion) ===
    float wave_x = sin(uv.y * 8.0 + time_val * 1.5) * 0.004 * intensity;
    float wave_y = cos(uv.x * 6.0 + time_val * 1.1) * 0.003 * intensity;
    vec2 distorted_uv = uv + vec2(wave_x, wave_y);
    
    // === ZOOM PULSE - ekran sie rozjezdza ===
    float zoom_pulse = sin(time_val * 0.7) * 0.012 * intensity;
    vec2 zoomed_uv = center + (distorted_uv - center) * (1.0 + zoom_pulse);
    
    // === CHROMATIC ABERRATION - mocne rozdzielenie kolorow ===
    float aberration = intensity * 0.012 * (1.0 + sin(time_val * 1.2) * 0.6);
    vec4 col_r = texture(SCREEN_TEXTURE, zoomed_uv + dir * aberration * 1.5);
    vec4 col_g = texture(SCREEN_TEXTURE, zoomed_uv);
    vec4 col_b = texture(SCREEN_TEXTURE, zoomed_uv - dir * aberration * 1.5);
    vec4 color = vec4(col_r.r, col_g.g, col_b.b, 1.0);
    
    // === DUZE ROZMYCIE GAUSSOWSKIE (12 sampli) ===
    float blur_str = intensity * 0.008 * (1.0 + dist * 2.0);
    // Pulsowanie rozmycia
    blur_str *= (1.0 + sin(time_val * 2.0) * 0.4);
    
    vec4 blur = vec4(0.0);
    // Pierscien 1 (blisko)
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(blur_str, 0.0));
    blur += texture(SCREEN_TEXTURE, zoomed_uv - vec2(blur_str, 0.0));
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(0.0, blur_str));
    blur += texture(SCREEN_TEXTURE, zoomed_uv - vec2(0.0, blur_str));
    // Pierscien 2 (diagonale)
    float d = blur_str * 0.707;
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(d, d));
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(-d, d));
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(d, -d));
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(-d, -d));
    // Pierscien 3 (daleko)
    float far = blur_str * 1.8;
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(far, 0.0));
    blur += texture(SCREEN_TEXTURE, zoomed_uv - vec2(far, 0.0));
    blur += texture(SCREEN_TEXTURE, zoomed_uv + vec2(0.0, far));
    blur += texture(SCREEN_TEXTURE, zoomed_uv - vec2(0.0, far));
    blur /= 12.0;
    
    // Im dalej od srodka = wiecej blura (rogi mocniej rozmyte)
    float blur_mix = smoothstep(0.05, 0.6, dist) * intensity * 0.9;
    // Dodatkowy blur na calym ekranie (pijacki efekt)
    blur_mix = max(blur_mix, intensity * 0.35);
    color = mix(color, blur, blur_mix);
    
    // === PODWOJNE WIDZENIE (ghost image) ===
    float ghost_offset = intensity * 0.008 * sin(time_val * 0.9);
    vec4 ghost = texture(SCREEN_TEXTURE, zoomed_uv + vec2(ghost_offset, ghost_offset * 0.5));
    color = mix(color, ghost, intensity * 0.15);
    
    // === ZOLTY ODCIEN PIJACKI ===
    color.rgb = mix(color.rgb, color.rgb * vec3(1.08, 1.02, 0.82), intensity * 0.4);
    
    // === CIEMNE ROGI (vignette) ===
    float dark_vig = smoothstep(0.25, 0.85, dist);
    color.rgb *= 1.0 - dark_vig * intensity * 0.55;
    
    COLOR = color;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.5)
	mat.set_shader_parameter("time_val", 0.0)
	drunk_overlay.material = mat
	drunk_overlay.visible = false
	drunk_canvas.add_child(drunk_overlay)

# --- Efekty Energola ---
var energy_vignette: ColorRect = null

func _apply_energy_effect(_delta):
	if not energy_vignette:
		_create_energy_vignette()
	if energy_vignette:
		energy_vignette.visible = true
		var time = float(Time.get_ticks_msec()) / 1000.0
		var pulse = 0.3 + sin(time * 2.0) * 0.1
		var mat = energy_vignette.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("intensity", pulse)

func _remove_energy_effect():
	if energy_vignette:
		energy_vignette.visible = false
	print("Efekt energola minął.")

func _create_energy_vignette():
	if not hud_canvas: return
	energy_vignette = ColorRect.new()
	energy_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	energy_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
void fragment() {
    vec2 uv = UV;
    float dist = distance(uv, vec2(0.5));
    float vignette = smoothstep(0.2, 0.85, dist);
    COLOR = vec4(0.15, 0.85, 0.3, vignette * intensity);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.3)
	energy_vignette.material = mat
	energy_vignette.visible = false
	hud_canvas.add_child(energy_vignette)

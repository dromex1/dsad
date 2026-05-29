extends CharacterBody3D

# --- Ustawienia Roweru ---
@export var max_speed = 7.0 
@export var acceleration = 5.0 
@export var deceleration = 10.0
@export var turn_speed = 3.0
@export var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var grip = 5.0 # Przyczepność opon

# --- Ścieżki do Węzłów Gracza ---
@export var player_camera_path: NodePath = "Head/Camera3D" 
@export var player_collision_path: NodePath = "CollisionShape3D"

# --- Referencje do Węzłów Roweru ---
@onready var model_roweru = $model_roweru 
@onready var prompt_label = $PromptLabel
@onready var interact_zone = $InteractZone

# Referencje do dźwięków i UI
@onready var ride_sound_player = $RideSoundPlayer # Dźwięk jazdy
@onready var bell_sound_player = $BellSoundPlayer
@onready var bell_timer = $BellTimer
@onready var bind_label = $CanvasLayer/BindLabel

# --- Zmienne Stanu ---
var player_in_area = false
var is_mounted = false
var player_node = null
var player_camera = null
var player_camera_original_parent = null
var player_collision_shape = null
var camera_rotation_h = 0.0
@export var mouse_sensitivity = 0.005
@export var camera_h_max = 80.0
@export var camera_h_min = -80.0

# -----------------------------------------------------------------

func _ready():
	add_to_group("vehicle")
	# --- NOWY BLOK: Wczytywanie Pozycji Roweru ---
	var loaded_transform = SaveManager.load_bike_transform()
	if loaded_transform != null:
		global_position = loaded_transform["pos"]
		global_rotation = loaded_transform["rot"]
		print("Wczytano pozycję roweru: ", global_position)
	# -------------------------------------------
	
	# Podłącz sygnały (Twój kod)
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)
	
	# --- ZMIANA: Włączamy fizykę ZAWSZE, aby zapisywać pozycję ---
	set_physics_process(true)
	
	# Włącz sprawdzanie klawiszy co klatkę (Twój kod)
	set_process(true)

# Wykrywa wejście gracza do strefy
func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = true
		player_node = body 
		if not is_mounted:
			prompt_label.visible = true

# Wykrywa wyjście gracza ze strefy (z poprawką)
func _on_body_exited(body):
	if is_mounted:
		return
	if body.is_in_group("player"):
		player_in_area = false
		player_node = null
		prompt_label.visible = false

# Sprawdzanie klawiszy [E] i [Q]
func _process(_delta):
	# Zamiast włączać/wyłączać fizykę, sprawdzamy 'is_mounted' wewnątrz
	if not is_mounted:
		# Jeśli nikt nie jedzie, sprawdzaj interakcję [E]
		if Input.is_action_just_pressed("interact"):
			if player_in_area and not is_mounted:
				mount_bike()
		return # Zakończ _process, jeśli nikt nie jedzie

	# --- Poniższy kod wykona się tylko, gdy is_mounted = true ---
	
	if Input.is_action_just_pressed("interact"):
		if is_mounted:
			dismount_bike()
			
	if Input.is_action_just_pressed("bell"):
		if is_mounted and bell_timer.is_stopped():
			bell_sound_player.play()
			bell_timer.start()

func mobile_look(relative: Vector2):
	if not is_mounted:
		return
	camera_rotation_h -= relative.x * mouse_sensitivity
	camera_rotation_h = clamp(camera_rotation_h, deg_to_rad(camera_h_min), deg_to_rad(camera_h_max))

# Fizyka i sterowanie rowerem
func _physics_process(_delta):
	# --- NOWA LINIA: Zapisuj pozycję roweru ZAWSZE ---
	SaveManager.update_bike_transform(self.global_position, self.global_rotation)

	# --- NOWY BLOK: Sprawdź, czy ktoś jedzie ---
	# Jeśli nikt nie jedzie, tylko spadaj (grawitacja) i zakończ
	if not is_mounted:
		if not is_on_floor():
			velocity.y -= gravity * _delta
		move_and_slide()
		return
	# ---------------------------------------------

	# --- Poniższy kod wykona się tylko, gdy is_mounted = true ---

	# --- Grawitacja ---
	if not is_on_floor():
		velocity.y -= gravity * _delta

	# --- Input ---
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# --- Prędkość Lokalna ---
	var local_velocity = transform.basis.inverse() * velocity

	# --- Logika Ruchu (Przyspieszanie / Hamowanie) ---
	if input_dir.y != 0:
		var target_z_speed = input_dir.y * max_speed 
		local_velocity.z = move_toward(local_velocity.z, target_z_speed, acceleration * _delta)
	else:
		local_velocity.z = move_toward(local_velocity.z, 0, deceleration * _delta)

	# --- Przyczepność (boki - oś X) ---
	local_velocity.x = move_toward(local_velocity.x, 0, grip * _delta)
	velocity = transform.basis * local_velocity
	
	# --- Obracanie (tylko podczas ruchu) ---
	var is_moving = abs(local_velocity.z) > 0.1
	if is_moving:
		var turn = -input_dir.x * turn_speed * _delta
		rotate_y(turn)

	if player_camera:
		player_camera.rotation.y = camera_rotation_h
	
	# --- Dźwięk i Ruch ---
	manage_ride_sound(local_velocity.z)
	
	move_and_slide()

# --------- FUNKCJE WSIADANIA / ZSIADANIA ---------

func mount_bike():
	if player_node == null: return
	
	player_camera = player_node.get_node_or_null(player_camera_path)
	player_collision_shape = player_node.get_node_or_null(player_collision_path)

	if player_camera == null or player_collision_shape == null:
		printerr("BŁĄD: Nie znaleziono kamery lub kolizji gracza!")
		return

	is_mounted = true
	player_in_area = false
	prompt_label.visible = false

	player_node.visible = false
	player_node.set_physics_process(false)
	player_node.set_process_input(false)
	player_collision_shape.disabled = true 
	
	# Ukryj UI gracza
	var player_ui = player_node.get_node_or_null("PlayerUI")
	if player_ui: player_ui.visible = false

	player_camera_original_parent = player_camera.get_parent()
	player_camera.get_parent().remove_child(player_camera)
	add_child(player_camera) 
	
	player_camera.position = Vector3(0.0, 0.7, 0.2) 
	player_camera.rotation = Vector3.ZERO
	camera_rotation_h = 0.0
	
	# set_physics_process(true) # <-- Ta linia jest już niepotrzebna
	bind_label.visible = true

func dismount_bike():
	if player_node == null or player_camera == null or player_camera_original_parent == null:
		return

	is_mounted = false

	player_node.global_position = global_position + (transform.basis * Vector3(1.2, 0.5, 0))
	player_node.visible = true
	player_node.set_physics_process(true)
	player_node.set_process_input(true)
	player_collision_shape.disabled = false 

	# Pokaż UI gracza
	var player_ui = player_node.get_node_or_null("PlayerUI")
	if player_ui: player_ui.visible = true

	player_camera.get_parent().remove_child(player_camera)
	player_camera_original_parent.add_child(player_camera)
	
	player_camera.position = Vector3.ZERO 
	player_camera.rotation = Vector3.ZERO
	
	player_camera = null
	player_camera_original_parent = null
	player_collision_shape = null

	# set_physics_process(false) # <-- Ta linia jest już niepotrzebna
	velocity = Vector3.ZERO # <-- Ale ta jest kluczowa!
	
	ride_sound_player.stop()
	bind_label.visible = false

# --------- FUNKCJA DŹWIĘKU JAZDY ---------

func manage_ride_sound(forward_speed):
	var current_speed = abs(forward_speed)
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)

	if speed_ratio > 0.1 and not ride_sound_player.playing:
		ride_sound_player.play()
	elif speed_ratio < 0.1 and ride_sound_player.playing:
		ride_sound_player.stop()

	if ride_sound_player.playing:
		var target_db = lerp(-60.0, 0.0, speed_ratio)
		ride_sound_player.volume_db = target_db

extends CharacterBody3D

var is_engine_running = false
var is_kicking = false
var kick_sounds = []
var kick_player: AudioStreamPlayer3D

# --- Ustawienia Pojazdu ---
var max_speed: float
@export var acceleration = 3.0 
@export var deceleration = 6.0
@export var turn_speed = 2.0
@export var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var grip = 8.0 
@export var push_speed = 2.0
var accel_mult = 1.0
var is_locked_on_lift: bool = false
@export var vehicle_name = "Default"  # Nazwa pojazdu dla SaveManager
@onready var interaction_raycast = get_node_or_null("../Basic FPS Player/Head/InteractionRayCast")

# --- Ustawienia Paliwa i Prędkościomierza ---
var max_kmh: float
var max_fuel: float
var current_fuel: float
@export var fuel_consumption_rate = 5.0 / 600.0

# --- Ustawienia Temperatury ---
var current_temperature: float
var max_temperature: float
var overheat_warning_temp: float
var overheat_cooldown_temp: float
var min_temperature: float
var heating_rate: float
var cooling_rate: float

# --- Zmienne Stanu ---
var current_health: float = 100.0
var max_health: float = 100.0
var has_fuel = true
var is_overheated = false
var is_accelerating_with_fuel = false
var auto_save_timer = 0.0  # Timer do auto-save co 5 sekund
var is_broken: bool = false  # Czy skuter jest zepsuty
var breakdown_notification_label: Label = null

# --- Wheelie ---
var is_doing_wheelie = false
var health_bar_ui: ProgressBar
var is_wheelie_failed: bool = false
var wheelie_angle = 0.0
var wheelie_max_angle = -0.6
var wheelie_speed = 2.5
var wheelie_lean = 0.0
var wheelie_lean_max = 0.4
var wheelie_lean_speed = 3.0
var wheelie_drift_force = 4.0

# --- Ustawienia Sterowania Myszką ---
@export var mouse_sensitivity = 0.005
@export var camera_h_max = 80.0 
@export var camera_h_min = -80.0
var camera_rotation_h = 0.0

# --- Ścieżki do Węzłów Gracza ---
@export var player_camera_path: NodePath = "Head/Camera3D" 
@export var player_collision_path: NodePath = "CollisionShape3D"

# --- Referencje do Węzłów Pojazdu ---
var model_roweru: Node3D  # Dynamicznie przypisywany w _ready()
@onready var prompt_label = $PromptLabel
@onready var interact_zone = $InteractZone

# Referencje do dźwięków
@onready var bell_sound_player = $BellSoundPlayer
@onready var bell_timer = $BellTimer
@onready var idle_sound_player = $IdleSoundPlayer
@onready var accel_sound_player = $AccelSoundPlayer

# --- Referencje do UI ---
@onready var bind_label = $CanvasLayer/BindLabel
@onready var speed_label = $CanvasLayer/SpeedLabel
@onready var fuel_progress_bar = $CanvasLayer/FuelProgressBar
@onready var fuel_percent_label = $CanvasLayer/FuelPercentLabel
@onready var speedometer_sprite = $CanvasLayer/Speedometr
@onready var temp_label = $CanvasLayer/TempLabel
@onready var temp_warning_label = $CanvasLayer/TempWarningLabel
@onready var benzyna_label = $CanvasLayer/Benzyna
@onready var exhaust_smoke = get_node_or_null("ExhaustSmoke/GPUParticles3D")

# --- Zmienne Stanu Gracza ---
var player_in_area = false
var is_mounted = false
var player_node = null
var player_camera = null
var player_camera_original_parent = null
var player_collision_shape = null

# --- Wheelie Rewards ---
var wheelie_timer = 0.0
var wheelie_reward_interval = 1.5
var wheelie_combo = 0

func _ready():
	load_stats_from_save_manager()
	
	var loaded_transform = SaveManager.load_scooter_transform(vehicle_name)
	if loaded_transform != null:
		global_position = loaded_transform["pos"]
		global_rotation = loaded_transform["rot"]
		is_locked_on_lift = SaveManager.is_on_lift
	
	has_fuel = (current_fuel > 0)
	is_overheated = (current_temperature >= max_temperature)
	
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)
	SaveManager.scooter_stats_updated.connect(load_stats_from_save_manager)
	
	# Dynamicznie znajdź model (może być "model_roweru", "sr50", itp.)
	model_roweru = null
	for child in get_children():
		if child is Node3D and child.name in ["model_roweru", "sr50", "old_bike"]:
			model_roweru = child
			print("✓ Znaleziony model: %s" % child.name)
			break
	
	if not model_roweru:
		# Fallback: weź pierwsze Node3D dziecko które nie jest UI ani collision
		for child in get_children():
			if child is Node3D and child.name not in ["InteractZone", "CanvasLayer", "ExhaustSmoke", "BellTimer", "PromptLabel", "CollisionShape3D", "BellSoundPlayer", "IdleSoundPlayer", "AccelSoundPlayer"]:
				model_roweru = child
				print("✓ Fallback model: %s" % child.name)
				break
	
	if not model_roweru:
		print("✗ BŁĄD: Nie znaleziono modelu pojazdu!")
	
	set_physics_process(true)
	set_process(true)
	set_process_input(true)
	
	kick_sounds = [
		preload("res://1kop.mp3"),
		preload("res://2kop.mp3"),
		preload("res://3kop.mp3"),
		preload("res://4kop.mp3")
	]
	kick_player = AudioStreamPlayer3D.new()
	add_child(kick_player)
	
	if vehicle_name == "aprilia":
		accel_sound_player.stream = load("res://Modele/gaz (mp3cut.net) (1).mp3")
	else:
		accel_sound_player.stream = load("res://vespaprzyspieszenie.mp3")
		
	_setup_health_ui()
	
	update_temperature_ui()
	_setup_exhaust_smoke()
	_setup_speedometer()
	
	# Sprawdź czy skuter był zepsuty (z save)
	if SaveManager.vehicle_broken:
		is_broken = true
	add_to_group("vehicle")
	
	_setup_explosion_effects()

func _setup_explosion_effects():
	explosion_audio = AudioStreamPlayer3D.new()
	var wybuch = load("res://wybuch.mp3")
	if wybuch:
		explosion_audio.stream = wybuch
		explosion_audio.max_distance = 150.0
	add_child(explosion_audio)
	
	explosion_particles = GPUParticles3D.new()
	explosion_particles.emitting = false
	explosion_particles.one_shot = false
	explosion_particles.amount = 60
	explosion_particles.lifetime = 1.2
	explosion_particles.position = Vector3(0, 0.5, 0)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1.5, 1.5)
	mesh.material = mat
	explosion_particles.draw_pass_1 = mesh
	
	var mat_process = ParticleProcessMaterial.new()
	mat_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat_process.emission_sphere_radius = 0.8
	mat_process.direction = Vector3(0, 1, 0)
	mat_process.spread = 100.0
	mat_process.initial_velocity_min = 1.0
	mat_process.initial_velocity_max = 4.0
	mat_process.gravity = Vector3(0, 3, 0)
	mat_process.damping_min = 1.0
	mat_process.damping_max = 2.0
	mat_process.angle_min = -180.0
	mat_process.angle_max = 180.0
	
	# Skalowanie w czasie
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat_process.scale_curve = scale_tex
	
	# Kolorowanie
	var color_grad = Gradient.new()
	color_grad.add_point(0.0, Color(1.0, 1.0, 0.8, 1.0))
	color_grad.add_point(0.1, Color(1.0, 0.5, 0.0, 1.0))
	color_grad.add_point(0.5, Color(0.8, 0.1, 0.0, 0.6))
	color_grad.add_point(1.0, Color(0.2, 0.2, 0.2, 0.0))
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = color_grad
	mat_process.color_ramp = color_tex
	
	explosion_particles.process_material = mat_process
	add_child(explosion_particles)

func _exit_tree():
	if is_instance_valid(idle_sound_player): idle_sound_player.stop()
	if is_instance_valid(accel_sound_player): accel_sound_player.stop()
	if is_instance_valid(kick_player): kick_player.stop()

func load_stats_from_save_manager():
	var stats = SaveManager.get_scooter_stats(vehicle_name)
	if stats:
		self.max_speed = stats["max_speed"]
		self.max_kmh = stats["max_kmh"]
		self.max_fuel = stats["max_fuel"]
		self.heating_rate = stats["heating_rate"]
		self.cooling_rate = stats["cooling_rate"]
		self.current_fuel = stats["current_fuel"]
		self.current_temperature = stats["current_temperature"]
		self.max_temperature = stats["max_temperature"]
		self.overheat_warning_temp = stats["overheat_warning_temp"]
		self.overheat_cooldown_temp = stats["overheat_cooldown_temp"]
		self.min_temperature = stats["min_temperature"]
		self.grip = stats["grip"]
		self.accel_mult = stats["accel_mult"]
		if stats.has("current_health"):
			self.current_health = stats["current_health"]
		else:
			self.current_health = 100.0
	
	if is_node_ready():
		update_fuel_ui()
		update_temperature_ui()

func refuel():
	# Pełni bak
	current_fuel = max_fuel
	has_fuel = true
	# Załaduj stats z SaveManager aby zsynchronizować
	load_stats_from_save_manager()
	update_fuel_ui()
	print("Skuter zatankowany! Paliwo: %.2f L" % current_fuel)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = true
		player_node = body 

func _on_body_exited(body):
	if is_mounted: return
	if body.is_in_group("player"):
		player_in_area = false
		player_node = null

func _input(event):
	if is_mounted and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation_h -= event.relative.x * mouse_sensitivity
		camera_rotation_h = clamp(camera_rotation_h, deg_to_rad(camera_h_min), deg_to_rad(camera_h_max))

func mobile_look(relative: Vector2):
	if not is_mounted:
		return
	camera_rotation_h -= relative.x * mouse_sensitivity
	camera_rotation_h = clamp(camera_rotation_h, deg_to_rad(camera_h_min), deg_to_rad(camera_h_max))

func _process(_delta):
	if not is_mounted:
		if Input.is_action_just_pressed("interact"):
			if player_in_area and player_node != null and not is_mounted:
				mount_bike()
		return

	if Input.is_action_just_pressed("interact"):
		dismount_bike()
			
	if Input.is_key_pressed(KEY_M):
		if is_mounted and bell_timer.is_stopped():
			bell_sound_player.play()
			bell_timer.start()

	if Input.is_action_just_pressed("bell"):
		if is_engine_running:
			is_engine_running = false
			idle_sound_player.stop()
			accel_sound_player.stop()
	elif Input.is_action_pressed("bell"):
		if is_broken:
			prompt_label.text = "SKUTER ZEPSUTY! Popchnij do garażu."
			prompt_label.visible = true
		elif current_health <= 0:
			prompt_label.text = "SILNIK ZNISZCZONY!"
			prompt_label.visible = true
		elif not is_engine_running and not is_kicking:
			is_kicking = true
			if kick_sounds.size() > 0:
				kick_player.stream = kick_sounds[randi() % kick_sounds.size()]
				kick_player.play()
	else:
		if is_kicking:
			is_kicking = false
			kick_player.stop()
			
	if is_kicking and not kick_player.playing:
		is_kicking = false
		prompt_label.visible = false
		if has_fuel and not is_overheated and current_health > 0 and not is_broken:
			is_engine_running = true
			idle_sound_player.play()
			accel_sound_player.play()

	if is_mounted:
		var viewport_size = get_viewport().get_visible_rect().size
		if health_bar_ui:
			health_bar_ui.position = Vector2(viewport_size.x - 320, viewport_size.y - 40)
			health_bar_ui.value = current_health
		
		var local_vel = transform.basis.inverse() * velocity
		var moving_forward = local_vel.z < -0.5
		var pressed_wheelie = Input.is_key_pressed(KEY_ALT) and moving_forward and has_fuel and not is_overheated and current_health > 0
		is_doing_wheelie = pressed_wheelie

func _physics_process(_delta):
	# Zapisz pozycje skutera na serwer
	SaveManager.update_scooter_transform(vehicle_name, self.global_position, self.global_rotation)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# --- CHŁODZENIE NIEZALEŻNIE OD TEGO CZY GRACZ SIEDZI ---
	var is_heating = false
	if is_mounted:
		is_heating = (is_engine_running and input_dir.y < 0 and has_fuel and not is_overheated and not is_broken)
	
	if is_heating:
		current_temperature += heating_rate * _delta
	else:
		current_temperature -= cooling_rate * _delta
	current_temperature = clamp(current_temperature, min_temperature, max_temperature)

	if is_overheated:
		if current_temperature <= overheat_cooldown_temp:
			is_overheated = false
			temp_warning_label.visible = false
		else:
			var time_left = (current_temperature - overheat_cooldown_temp) / cooling_rate
			temp_warning_label.text = "SILNIK PRZEGRZANY! Poczekaj... (%.0f s)" % time_left
			temp_warning_label.visible = true
	elif current_temperature >= max_temperature:
		is_overheated = true
	elif current_temperature >= overheat_warning_temp:
		temp_warning_label.text = "OSTRZEŻENIE: Silnik może się przegrzać!"
		temp_warning_label.visible = true
	else:
		temp_warning_label.visible = false
		
	if is_node_ready():
		update_temperature_ui()

	# --- FIZYKA OFF-MOUNT ---
	if not is_mounted:
		if is_locked_on_lift:
			velocity = Vector3.ZERO
		elif not is_on_floor():
			velocity.y -= gravity * _delta
		manage_scooter_sound(false, _delta)
		
		# Spalanie idle kiedy nie siedzimy na skuterze
		if is_engine_running:
			current_fuel -= fuel_consumption_rate * 0.1 * _delta
			if current_fuel <= 0:
				current_fuel = 0
				has_fuel = false
				is_engine_running = false
				idle_sound_player.stop()
				accel_sound_player.stop()
		
		move_and_slide()
		return
		
	SaveManager.update_player_position(self.global_position)
	if not is_on_floor():
		velocity.y -= gravity * _delta

	# Timer jazdy dla systemu uszkodzeń
	if is_engine_running and not is_broken:
		SaveManager.ride_time_accumulated += _delta
		var current_limit = SaveManager.FAST_BREAKDOWN_INTERVAL if SaveManager.fast_breakdown_enabled else SaveManager.BREAKDOWN_INTERVAL
		if SaveManager.ride_time_accumulated >= current_limit:
			if SaveManager.fast_breakdown_enabled:
				SaveManager.fast_breakdown_enabled = false
			_trigger_breakdown()
	
	is_accelerating_with_fuel = (is_engine_running and input_dir.y < 0 and has_fuel and not is_overheated and not is_broken)

	update_temperature_ui()
	
	if is_engine_running:
		var drain = fuel_consumption_rate if is_accelerating_with_fuel else fuel_consumption_rate * 0.1
		current_fuel -= drain * _delta
		if current_fuel <= 0:
			current_fuel = 0
			has_fuel = false
			is_engine_running = false
			idle_sound_player.stop()
			accel_sound_player.stop()
		update_fuel_ui()

	var local_velocity = transform.basis.inverse() * velocity
	var target_z_speed = 0.0
	var current_accel = deceleration 

	if input_dir.y < 0:
		if is_accelerating_with_fuel:
			target_z_speed = input_dir.y * max_speed
			var speed_progress = (abs(local_velocity.z) / max_speed)
			current_accel = acceleration * (1.0 - speed_progress * 0.5) * accel_mult
		else:
			target_z_speed = input_dir.y * push_speed
			current_accel = deceleration 
	elif input_dir.y > 0:
		target_z_speed = input_dir.y * push_speed 
		current_accel = deceleration
	
	local_velocity.z = move_toward(local_velocity.z, target_z_speed, current_accel * _delta)
	var speed_factor = clamp(abs(local_velocity.z) / max_speed, 0.5, 1.5)
	local_velocity.x = move_toward(local_velocity.x, 0, grip * speed_factor * _delta)
	velocity = transform.basis * local_velocity
	
	var is_moving = abs(local_velocity.z) > 0.1
	if is_moving:
		var speed_ratio = clamp(abs(local_velocity.z) / (max_speed * 0.5), 0.3, 1.0)
		var adjusted_turn_speed = turn_speed / speed_ratio
		var lean_influence = clamp(abs(local_velocity.z) / max_speed, 0.4, 1.2)
		
		if is_doing_wheelie:
			var lean_target = input_dir.x * wheelie_lean_max * lean_influence
			wheelie_lean = move_toward(wheelie_lean, lean_target, wheelie_lean_speed * _delta)
			var drift = -input_dir.x * wheelie_drift_force * _delta
			velocity += transform.basis.x * drift
			var turn = -input_dir.x * adjusted_turn_speed * 0.15 * _delta
			rotate_y(turn)
		else:
			var normal_lean_target = input_dir.x * (wheelie_lean_max * 0.6) * lean_influence
			wheelie_lean = move_toward(wheelie_lean, normal_lean_target, wheelie_lean_speed * _delta)
			var turn = -input_dir.x * adjusted_turn_speed * 0.6 * _delta
			rotate_y(turn)
	else:
		wheelie_lean = move_toward(wheelie_lean, 0.0, wheelie_lean_speed * 2.0 * _delta)
	
	if player_camera:
		player_camera.rotation.y = camera_rotation_h

	var kmh_ratio = max_kmh / max_speed
	var current_kmh = abs(local_velocity.z) * kmh_ratio
	speed_label.text = "%.0f km/h" % current_kmh
	manage_scooter_sound(is_accelerating_with_fuel, _delta)
	move_and_slide()

	if is_doing_wheelie:
		wheelie_angle = move_toward(wheelie_angle, wheelie_max_angle, wheelie_speed * _delta)
	else:
		wheelie_angle = move_toward(wheelie_angle, 0.0, wheelie_speed * 1.5 * _delta)
	
	var applied_wheelie_angle = wheelie_angle
	if vehicle_name == "aprilia":
		applied_wheelie_angle = wheelie_angle  # Aprilia - ten sam kierunek co reszta
		
	if model_roweru:
		model_roweru.rotation.x = applied_wheelie_angle
		model_roweru.rotation.z = wheelie_lean
		if is_mounted and is_doing_wheelie:
			pass
	
	if player_camera:
		player_camera.rotation.x = applied_wheelie_angle
		player_camera.rotation.z = wheelie_lean

	if is_doing_wheelie:
		wheelie_timer += _delta
		if wheelie_timer >= wheelie_reward_interval:
			wheelie_timer -= wheelie_reward_interval
			wheelie_combo += 1
			var money_reward = 2.0 + wheelie_combo
			var xp_reward = 3 + wheelie_combo * 2
			SaveManager.player_money += money_reward
			SaveManager.add_xp(xp_reward)
			_spawn_reward_marker("+%.0f zł" % money_reward, Color(0.2, 0.9, 0.2), -200)
			_spawn_reward_marker("+%d XP" % xp_reward, Color(0.3, 0.7, 1.0), 200)
	else:
		if wheelie_combo > 0:
			wheelie_combo = 0
		wheelie_timer = 0.0

	SaveManager.update_scooter_state(vehicle_name, current_fuel, current_temperature)

func mount_bike():
	if player_node == null: return
	player_camera = player_node.get_node_or_null(player_camera_path)
	player_collision_shape = player_node.get_node_or_null(player_collision_path)
	if player_camera == null or player_collision_shape == null: return

	is_mounted = true
	player_in_area = false
	prompt_label.visible = false

	var is_tpp = player_node.get("is_third_person")
	var model = player_node.get_node_or_null("CharacterModel")
	
	if model:
		model.get_parent().remove_child(model)
		model_roweru.add_child(model)
		model.position = Vector3(0, 0, 0.1) 
		model.rotation = Vector3.ZERO
		model.visible = is_tpp
		
	player_node.visible = is_tpp
	player_node.set_physics_process(false) 
	player_node.set_process_input(false)
	player_collision_shape.disabled = true 

	var player_ui = player_node.get_node_or_null("PlayerUI")
	if player_ui: player_ui.visible = false

	player_camera_original_parent = player_camera.get_parent()
	player_camera.get_parent().remove_child(player_camera)
	add_child(player_camera) 
	
	if is_tpp:
		var tp_arm = player_node.get_node_or_null("TP_Arm")
		if tp_arm:
			tp_arm.get_parent().remove_child(tp_arm)
			add_child(tp_arm)
			tp_arm.position = Vector3(0, 1.2, 0.5) 
	
	player_camera.position = Vector3(-0.005, 0.8, 0.2) 
	player_camera.rotation = Vector3.ZERO
	camera_rotation_h = 0.0
	
	bind_label.visible = true
	speed_label.visible = true
	fuel_progress_bar.visible = true
	fuel_percent_label.visible = true
	speedometer_sprite.visible = true
	temp_label.visible = true
	benzyna_label.visible = true
	if health_bar_ui: health_bar_ui.visible = true
	
	update_fuel_ui()
	update_temperature_ui()
	if is_engine_running:
		idle_sound_player.play()
		accel_sound_player.play()

func dismount_bike():
	if player_node == null or player_camera == null or player_camera_original_parent == null:
		return
	
	# Bezpieczna kontrola model_roweru
	if model_roweru == null:
		print("BŁĄD: model_roweru jest null w dismount_bike!")
		return
		
	is_mounted = false
	
	player_node.global_position = global_position + (transform.basis * Vector3(1.2, 0.5, 0))
	player_node.visible = true
	
	var model = model_roweru.get_node_or_null("CharacterModel")
	if model:
		model_roweru.remove_child(model)
		player_node.add_child(model)
		model.position.y = 0.4
		model.rotation = Vector3(0, PI, 0)
		var is_tpp = player_node.get("is_third_person")
		model.visible = is_tpp
		
	player_node.set_physics_process(true)
	player_node.set_process_input(true)
	player_collision_shape.disabled = false 
	var player_ui = player_node.get_node_or_null("PlayerUI")
	if player_ui: player_ui.visible = true

	var tp_arm = get_node_or_null("TP_Arm")
	if tp_arm:
		remove_child(tp_arm)
		player_node.add_child(tp_arm)
		tp_arm.position = Vector3(0, 0.5, 0)

	player_camera.get_parent().remove_child(player_camera)
	player_camera_original_parent.add_child(player_camera)
	player_camera.position = Vector3.ZERO 
	player_camera.rotation = Vector3.ZERO
	
	player_camera = null
	player_camera_original_parent = null
	player_collision_shape = null
	velocity = Vector3.ZERO
	# Usunięto wyłączanie silnika, będzie chodził w tle
	
	bind_label.visible = false
	speed_label.visible = false
	fuel_progress_bar.visible = false
	fuel_percent_label.visible = false
	speedometer_sprite.visible = false
	temp_label.visible = false
	temp_warning_label.visible = false
	benzyna_label.visible = false
	if health_bar_ui: health_bar_ui.visible = false
	
	# Ustaw max distance na audio playerach żeby dźwięk cichł z odległością
	if idle_sound_player:
		idle_sound_player.max_distance = 25.0
		idle_sound_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if accel_sound_player:
		accel_sound_player.max_distance = 25.0
		accel_sound_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

func update_fuel_ui():
	if not is_node_ready(): return
	var fuel_percent = (current_fuel / max_fuel) * 100.0
	fuel_progress_bar.value = fuel_percent
	fuel_percent_label.text = "%d %%" % fuel_percent

func update_temperature_ui():
	if not is_node_ready(): return
	temp_label.text = "%.0f °C" % current_temperature

func manage_scooter_sound(is_accelerating_now, delta):
	if not is_engine_running:
		if exhaust_smoke: exhaust_smoke.emitting = false
		idle_sound_player.volume_db = move_toward(idle_sound_player.volume_db, -80.0, 160.0 * delta)
		accel_sound_player.volume_db = move_toward(accel_sound_player.volume_db, -80.0, 160.0 * delta)
		return
		
	if not has_fuel or is_overheated:
		if exhaust_smoke: exhaust_smoke.emitting = false
		idle_sound_player.volume_db = move_toward(idle_sound_player.volume_db, -80.0, 160.0 * delta)
		accel_sound_player.volume_db = move_toward(accel_sound_player.volume_db, -80.0, 160.0 * delta)
	elif is_accelerating_now:
		accel_sound_player.volume_db = move_toward(accel_sound_player.volume_db, 0.0, 160.0 * delta)
		idle_sound_player.volume_db = move_toward(idle_sound_player.volume_db, -80.0, 160.0 * delta)
		if exhaust_smoke: exhaust_smoke.emitting = true
	else:
		idle_sound_player.volume_db = move_toward(idle_sound_player.volume_db, 0.0, 160.0 * delta)
		accel_sound_player.volume_db = move_toward(accel_sound_player.volume_db, -80.0, 160.0 * delta)
		if exhaust_smoke: exhaust_smoke.emitting = true

func _setup_exhaust_smoke():
	if not exhaust_smoke: return
	
	# Particle system is already configured in the scene, just enable it
	exhaust_smoke.emitting = true

func _setup_speedometer():
	if not speedometer_sprite: return
	
	# Try to load speedometer texture
	var texture_paths = [
		"res://speedometer.png",
		"res://licznik.png",
		"res://assets/speedometer.png",
		"res://UI/speedometer.png"
	]
	
	for path in texture_paths:
		if ResourceLoader.exists(path):
			speedometer_sprite.texture = load(path)
			return
	
	# If no texture found, hide the speedometer
	speedometer_sprite.visible = false

func _spawn_reward_marker(text: String, color: Color, x_offset: float):
	var canvas = $CanvasLayer
	if not canvas: return
	var marker = Label.new()
	marker.text = text
	marker.add_theme_font_size_override("font_size", 32)
	marker.add_theme_color_override("font_color", color)
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	marker.add_theme_constant_override("outline_size", 6)
	var viewport_size = get_viewport().get_visible_rect().size
	marker.position = Vector2(viewport_size.x / 2.0 + x_offset, viewport_size.y * 0.4)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(marker)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(marker, "position:y", marker.position.y - 120, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(marker, "modulate:a", 0.0, 1.4).set_delay(0.4)
	tw.chain().tween_callback(marker.queue_free)

func _setup_health_ui():
	health_bar_ui = ProgressBar.new()
	health_bar_ui.size = Vector2(300, 30)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.8, 0.1, 0.1)
	health_bar_ui.add_theme_stylebox_override("fill", style_box)
	health_bar_ui.show_percentage = true
	health_bar_ui.max_value = 100.0
	health_bar_ui.visible = false
	$CanvasLayer.add_child(health_bar_ui)

# --- System Uszkodzeń ---
func _trigger_breakdown():
	var damage_keys = SaveManager.DAMAGE_TYPES.keys()
	var random_key = damage_keys[randi() % damage_keys.size()]
	var damage_info = SaveManager.DAMAGE_TYPES[random_key]
	
	is_broken = true
	SaveManager.vehicle_broken = true
	SaveManager.vehicle_damage_type = random_key
	SaveManager.ride_time_accumulated = 0.0
	SaveManager.save_game()
	
	# Wyłącz silnik
	is_engine_running = false
	idle_sound_player.stop()
	accel_sound_player.stop()
	
	# Powiadomienie na ekranie
	_show_breakdown_notification(damage_info["name"])
	print("AWARIA! %s" % damage_info["name"])

func _show_breakdown_notification(damage_name: String):
	var canvas = $CanvasLayer
	if not canvas: return
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.05, 0.05, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚠ AWARIA SKUTERA!"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = damage_name + "\nPopchnij skuter do garażu i napraw go na laptopie."
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(1, 0.9, 0.8))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(viewport_size.x / 2.0 - 250, viewport_size.y * 0.2)
	panel.custom_minimum_size = Vector2(500, 0)
	canvas.add_child(panel)
	
	# Animacja: pojaw + zniknij po 5s
	panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0)
	tw.tween_property(panel, "modulate:a", 0.0, 1.0)
	tw.tween_callback(panel.queue_free)

func repair_vehicle():
	is_broken = false
	SaveManager.vehicle_broken = false
	SaveManager.vehicle_damage_type = ""
	current_health = max_health
	if explosion_particles:
		explosion_particles.emitting = false
	SaveManager.save_game()
	if health_bar_ui:
		health_bar_ui.value = current_health
	print("Skuter naprawiony!")

var is_exploded = false

func interact():
	if is_mounted:
		dismount_bike()
	elif player_in_area and player_node != null and not is_mounted:
		mount_bike()

var explosion_audio: AudioStreamPlayer3D = null
var explosion_particles: GPUParticles3D = null

func take_damage(amount: float):
	if is_exploded:
		return
		
	current_health -= amount
	if current_health < 0:
		current_health = 0
		
	if health_bar_ui:
		health_bar_ui.value = current_health
		
	SaveManager.update_scooter_state(vehicle_name, current_fuel, current_temperature, current_health)
	
	if current_health <= 0 and not is_exploded:
		_explode()

func _explode():
	is_exploded = true
	is_broken = true
	is_engine_running = false
	if idle_sound_player: idle_sound_player.stop()
	if accel_sound_player: accel_sound_player.stop()
	if exhaust_smoke: exhaust_smoke.emitting = false
	
	if explosion_audio:
		explosion_audio.play()
		
	if explosion_particles:
		explosion_particles.emitting = true
		
	if is_mounted:
		dismount_bike()
		
	_trigger_breakdown()
	print("BOOM! Skuter wybuchl.")
	
	# Usunięcie z SaveManager
	SaveManager.remove_scooter_ownership(vehicle_name)
	
	# Skuter zniknie po 10 sekundach
	await get_tree().create_timer(10.0).timeout
	if explosion_particles:
		explosion_particles.emitting = false
	queue_free()

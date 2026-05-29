extends CharacterBody3D

@export var max_speed = 5.0 # wolna jazda ~18km/h
const ACCEL = 2.0
const TURN_SPEED = 1.5
const GRAVITY = 9.8

@onready var ray_center = $RayCastCenter
@onready var ray_left = $RayCastLeft
@onready var ray_right = $RayCastRight

var is_stopped = false
var current_speed = 0.0
var spawn_position: Vector3
var time_off_road: float = 0.0

func _ready():
	print("Police AI Ready! Global pos: ", global_position)
	spawn_position = global_position
	add_to_group("police")
	randomize()
	_schedule_next_stop()

var current_turn_dir: float = 0.0

func _physics_process(delta):
	# Grawitacja
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	if is_stopped:
		current_speed = move_toward(current_speed, 0, ACCEL * delta * 2)
	else:
		current_speed = move_toward(current_speed, max_speed, ACCEL * delta)
	
	# Edge Detection - sprawdzaj gdzie jest droga
	var target_turn_dir = 0.0
	
	var left_colliding = ray_left.is_colliding()
	var right_colliding = ray_right.is_colliding()
	var center_colliding = ray_center.is_colliding()

	var left_valid = left_colliding and "Autobana" in ray_left.get_collider().name
	var right_valid = right_colliding and "Autobana" in ray_right.get_collider().name
	var center_valid = center_colliding and "Autobana" in ray_center.get_collider().name

	if left_valid and right_valid:
		var left_y = ray_left.get_collision_point().y
		var right_y = ray_right.get_collision_point().y
		
		# Skrecaj w strone wyzszego gruntu (Płynna poprawka)
		var diff = right_y - left_y
		target_turn_dir = clamp(diff * 15.0, -1.0, 1.0)
	elif left_valid and not right_valid:
		target_turn_dir = 1.0
	elif right_valid and not left_valid:
		target_turn_dir = -1.0
	
	# Jesli zaden raycast nie trafia w autostradę - samochod spadl z drogi
	if not center_valid and not left_valid and not right_valid:
		time_off_road += delta
		
		# Znajdz gdzie jest ulica
		var all_nodes = get_tree().root.find_children("*Autobana*", "MeshInstance3D", true, false)
		var closest = null
		var dist = INF
		if all_nodes.size() > 0:
			for node in all_nodes:
				var d = global_position.distance_to(node.global_position)
				if d < dist:
					dist = d
					closest = node
					
		if closest:
			var dir_to = global_position.direction_to(closest.global_position)
			var current_forward = -global_transform.basis.z
			var angle_to = current_forward.signed_angle_to(dir_to, Vector3.UP)
			target_turn_dir = clamp(angle_to * 2.0, -1.0, 1.0)
			# Zwolnij by wyciągnąć skręt
			current_speed = move_toward(current_speed, max_speed * 0.4, ACCEL * delta)
		else:
			target_turn_dir = sin(Time.get_ticks_msec() * 0.005) * 4.0
	else:
		time_off_road = 0.0
	
	# Jesli spadl ponizej mapy - respawn
	if global_position.y < -20:
		var all_nodes = get_tree().root.find_children("*Autobana*", "MeshInstance3D", true, false)
		if all_nodes.size() > 0:
			global_position = all_nodes[0].global_position
		else:
			global_position = spawn_position
		global_position.y += 1.0
		velocity = Vector3.ZERO
		current_speed = 0.0
		time_off_road = 0.0
		print("Policja: respawn - spadla pod mape")
	
	current_turn_dir = lerp(current_turn_dir, float(target_turn_dir), 4.0 * delta)
	rotate_y(current_turn_dir * TURN_SPEED * delta)
	
	# Jedz DO PRZODU (w kierunku +Z modelu, bo model Kia moze byc odwrocony)
	var forward = -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed

	move_and_slide()

func _schedule_next_stop():
	await get_tree().create_timer(randf_range(20.0, 50.0)).timeout
	is_stopped = true
	await get_tree().create_timer(randf_range(3.0, 8.0)).timeout
	is_stopped = false
	_schedule_next_stop()

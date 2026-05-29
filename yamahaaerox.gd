extends "res://VehicleBase.gd"

func _ready():
	vehicle_name = "yamahaaerox"
	exhaust_smoke = get_node_or_null("ExhaustSmoke")
	super._ready()
	_setup_multiplayer_sync()

func _setup_exhaust_smoke():
	if not exhaust_smoke: return
	
	if exhaust_smoke is GPUParticles3D:
		exhaust_smoke.emitting = true
	elif exhaust_smoke is CPUParticles3D:
		exhaust_smoke.emitting = true
		exhaust_smoke.amount = 15
		exhaust_smoke.lifetime = 1.2
		
		var mesh = QuadMesh.new()
		mesh.size = Vector2(0.15, 0.15) 
		exhaust_smoke.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1, 1, 1, 0.5) 
		mat.albedo_texture = load("res://smoketexture/T_smoke_b7.png")
		mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
		
		# Tylko jeśli CPUParticles3D ma te opcje:
		if "direction" in exhaust_smoke: exhaust_smoke.direction = Vector3(0, 1, 1)
		if "spread" in exhaust_smoke: exhaust_smoke.spread = 25.0
		if "gravity" in exhaust_smoke: exhaust_smoke.gravity = Vector3(0, 0.8, 0)
		if "angle_max" in exhaust_smoke: exhaust_smoke.angle_max = 360.0
		
		var curve = Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.0))

func _setup_multiplayer_sync():
	var sync = MultiplayerSynchronizer.new()
	add_child(sync)
	
	var config = SceneReplicationConfig.new()
	config.add_property(".:global_position")
	config.add_property(".:global_rotation")
	config.add_property(".:wheelie_angle")
	sync.replication_config = config

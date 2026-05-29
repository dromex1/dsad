extends Node3D

func _ready():
	var anim_player = $AnimationPlayer
	anim_player.play("rig|rig|sit")  # wpisz dokładną nazwę animacji
	#anim_player.get_animation("rig|rig|sit").loop = true  # 🔁 zapętlenie animacji

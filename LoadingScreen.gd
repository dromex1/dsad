extends CanvasLayer

# --- EKRAN ŁADOWANIA (Dynamiczny) ---

var progress_bar: ProgressBar
var percent_label: Label
var tip_label: Label
var target_scene = "res://scena_gry.tscn"
var progress = []

func _ready():
	target_scene = _get_target_scene()
	_build_ui()
	# Rozpoczynamy ładowanie w tle
	ResourceLoader.load_threaded_request(target_scene)

func _process(_delta):
	var status = ResourceLoader.load_threaded_get_status(target_scene, progress)
	
	# Aktualizacja UI
	var p_val = progress[0] * 100
	progress_bar.value = p_val
	percent_label.text = "%d %%" % int(p_val)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			# Zakończono! Czekamy chwilę dla efektu i wchodzimy
			var new_scene = ResourceLoader.load_threaded_get(target_scene)
			get_tree().change_scene_to_packed(new_scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			print("BŁĄD ŁADOWANIA SCENY!")
			get_tree().change_scene_to_file("res://main_menu.tscn")


func _get_target_scene() -> String:
	if OS.has_feature("ios") or OS.has_feature("mobile"):
		return "res://scena_gry_mobile.tscn"
	return "res://scena_gry.tscn"

func _build_ui():
	# Tło
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	
	var center = Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	add_child(center)
	
	# Pasek postępu
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(600, 30)
	progress_bar.position = Vector2(-300, 50)
	progress_bar.show_percentage = false
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1)
	sb_bg.set_border_width_all(2)
	sb_bg.border_color = Color(0.3, 0.3, 0.3)
	progress_bar.add_theme_stylebox_override("background", sb_bg)
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.2, 0.5, 0.8) # Ładny niebieski
	progress_bar.add_theme_stylebox_override("fill", sb_fill)
	
	center.add_child(progress_bar)
	
	# Procenty
	percent_label = Label.new()
	percent_label.text = "0 %"
	percent_label.position = Vector2(-20, 90)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(percent_label)
	
	# Napis Ładowanie
	var load_txt = Label.new()
	load_txt.text = "ŁADOWANIE ŚWIATA..."
	load_txt.position = Vector2(-300, 10)
	load_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_txt.custom_minimum_size = Vector2(600, 0)
	load_txt.add_theme_font_size_override("font_size", 24)
	center.add_child(load_txt)
	
	# Tipy (podpowiedzi)
	tip_label = Label.new()
	tip_label.text = "PORADA: Pamiętaj o regularnym serwisowaniu skutera na podnośniku!"
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip_label.offset_bottom = -50
	tip_label.modulate = Color(0.7, 0.7, 0.7)
	add_child(tip_label)

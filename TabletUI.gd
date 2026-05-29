extends CanvasLayer

# --- TABLET KASKADERA (Premium Version) ---

var tablet_root: PanelContainer
var content_container: VBoxContainer

func _ready():
	_build_ui()
	_update_content()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Mała animacja pojawiania się (scale up)
	tablet_root.scale = Vector2(0.9, 0.9)
	tablet_root.modulate.a = 0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tablet_root, "scale", Vector2(1,1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tablet_root, "modulate:a", 1.0, 0.2)

func _input(event):
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_cancel"): # TAB lub ESC
		close()

func _build_ui():
	# Ciemna przesłona tła
	var bg_dim = ColorRect.new()
	bg_dim.color = Color(0, 0, 0, 0.4)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_dim)
	
	tablet_root = PanelContainer.new()
	tablet_root.custom_minimum_size = Vector2(650, 850)
	tablet_root.pivot_offset = Vector2(325, 425)
	add_child(tablet_root)
	
	tablet_root.set_anchors_preset(Control.PRESET_CENTER)
	tablet_root.offset_left = -325
	tablet_root.offset_top = -425
	tablet_root.offset_right = 325
	tablet_root.offset_bottom = 425
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.92) # Glassmorphism base
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	style.set_content_margin_all(25)
	tablet_root.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 25)
	tablet_root.add_child(main_vbox)
	
	# Nagłówek
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "iWIEJSKI OS v3.0"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var time_lbl = Label.new()
	time_lbl.text = "LTE 4G | 21:37"
	time_lbl.modulate.a = 0.6
	header.add_child(time_lbl)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 30)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_container)

func _update_content():
	for child in content_container.get_children():
		child.queue_free()
		
	# --- SEKCJA PROFIL ---
	var prof_box = _create_section_box("TWÓJ PROFIL", Color(0.2, 0.5, 1.0))
	content_container.add_child(prof_box)
	
	var p_vbox = prof_box.get_child(0)
	var xp_pct = float(SaveManager.player_xp) / SaveManager.xp_for_next_level() * 100
	
	p_vbox.add_child(_create_stat_row("Poziom:", str(SaveManager.player_level)))
	p_vbox.add_child(_create_stat_row("Doświadczenie:", "%d / %d XP (%d%%)" % [SaveManager.player_xp, SaveManager.xp_for_next_level(), int(xp_pct)]))
	p_vbox.add_child(_create_stat_row("Stan konta:", "%.2f zł" % SaveManager.player_money, Color.GREEN))
	
	# --- SEKCJA ZADANIA ---
	var quest_box = _create_section_box("AKTYWNE ZADANIA", Color(1.0, 0.8, 0.2))
	content_container.add_child(quest_box)
	var q_vbox = quest_box.get_child(0)
	
	if SaveManager.active_quests.is_empty():
		var none = Label.new()
		none.text = "Brak aktywnych zleceń. Szukaj ich w terenie!"
		none.modulate.a = 0.5
		q_vbox.add_child(none)
	else:
		for quest in SaveManager.active_quests:
			var q_item = VBoxContainer.new()
			q_vbox.add_child(q_item)
			
			var q_t = Label.new()
			q_t.text = "• " + quest["title"]
			q_t.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
			q_item.add_child(q_t)
			
			var q_d = Label.new()
			q_d.text = "  " + quest["desc"]
			q_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			q_d.modulate.a = 0.7
			q_item.add_child(q_d)

	# --- SEKCJA POJAZD ---
	var bike_box = _create_section_box("TWÓJ AEROX", Color(0.4, 1.0, 0.6))
	content_container.add_child(bike_box)
	var b_vbox = bike_box.get_child(0)
	
	var scooter_id = "yamahaaerox"
	var stats = SaveManager.get_scooter_stats(scooter_id)
	var upgrades = SaveManager.UPGRADES[scooter_id]
	var found_any = false
	
	for key in upgrades.keys():
		if stats.has(key + "_level") and stats[key + "_level"] > 0:
			var p_lbl = Label.new()
			p_lbl.text = "✓ " + upgrades[key]["name"] + " (Poz. %d)" % stats[key + "_level"]
			p_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
			b_vbox.add_child(p_lbl)
			found_any = true
	
	if not found_any:
		var series = Label.new()
		series.text = "Skuter jest całkowicie seryjny."
		series.modulate.a = 0.5
		b_vbox.add_child(series)

	# --- SEKCJA MOJE SKUTERY ---
	var my_scooters_box = _create_section_box("MOJE SKUTERY", Color(0.8, 0.6, 0.2))
	content_container.add_child(my_scooters_box)
	var s_vbox = my_scooters_box.get_child(0)
	
	var owned_scooters = SaveManager.owned_scooters
	if owned_scooters.is_empty():
		var none = Label.new()
		none.text = "Brak zakupionych skuterów. Odwiedź sklep!"
		none.modulate.a = 0.5
		s_vbox.add_child(none)
	else:
		for scooter_key in owned_scooters:
			var scooter_info = _get_scooter_info(scooter_key)
			var s_item = HBoxContainer.new()
			s_item.add_theme_constant_override("separation", 10)
			s_vbox.add_child(s_item)
			
			# Nazwa skutera
			var s_name = Label.new()
			s_name.text = scooter_info["display_name"]
			s_name.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
			s_item.add_child(s_name)
			
			# Spacer
			var s_spacer = Control.new()
			s_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_item.add_child(s_spacer)
			
			# Przycisk spawu
			var spawn_btn = Button.new()
			spawn_btn.text = "SPAWŃ OBOK MNIE"
			spawn_btn.custom_minimum_size = Vector2(150, 30)
			spawn_btn.pressed.connect(_on_spawn_scooter.bindv([scooter_key]))
			s_item.add_child(spawn_btn)
			_style_tablet_btn(spawn_btn)

func _create_section_box(title: String, accent: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.03)
	st.set_content_margin_all(15)
	st.set_corner_radius_all(10)
	pc.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	pc.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(lbl)
	
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = accent
	sep.modulate.a = 0.3
	vbox.add_child(sep)
	
	return pc

func _create_stat_row(label: String, val: String, val_color: Color = Color.WHITE) -> HBoxContainer:
	var hb = HBoxContainer.new()
	var l = Label.new()
	l.text = label
	l.modulate.a = 0.7
	hb.add_child(l)
	
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(s)
	
	var v = Label.new()
	v.text = val
	v.add_theme_color_override("font_color", val_color)
	hb.add_child(v)
	return hb

func close():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tablet_root, "scale", Vector2(0.9, 0.9), 0.15)
	tween.tween_property(tablet_root, "modulate:a", 0.0, 0.15)
	tween.finished.connect(queue_free)

func _get_scooter_info(scooter_key: String) -> Dictionary:
	var scooter_list = {
		"newaerox": {"display_name": "Nowy Aerox"},
		"aprilia": {"display_name": "Aprilia SR50"},
		"yamahaaerox": {"display_name": "Yamaha Aerox"}
	}
	return scooter_list.get(scooter_key, {"display_name": "Nieznany skuter"})

func _on_spawn_scooter(scooter_key: String):
	var player = get_tree().root.find_child("Basic FPS Player", true, false)
	if not player:
		print("Nie znaleziono gracza!")
		return
	
	# Pobierz wszystkie pojazdy i usuń ten sam model, jeśli już istnieje na mapie
	var existing_vehicles = get_tree().get_nodes_in_group("vehicle")
	for v in existing_vehicles:
		if v.get("vehicle_name") == scooter_key:
			v.queue_free()
	
	# Pobierz scenę skutera
	var scooter_info = {
		"newaerox": "res://skutery/NewAerox.tscn",
		"aprilia": "res://skutery/AprilliaSR50.tscn",
		"yamahaaerox": "res://yamahaaerox.tscn"
	}
	
	var scene_path = scooter_info.get(scooter_key)
	if not scene_path:
		print("Nieznana scena skutera: " + scooter_key)
		return
	
	# Wczytaj i dodaj nowy skuter
	var scene_resource = load(scene_path)
	if not scene_resource:
		print("BŁĄD: Nie znaleziono pliku sceny: " + scene_path)
		return
	var new_scooter = scene_resource.instantiate()
	
	# BARDZO WAŻNE: Wymuś ID skutera zanim załaduje statystyki
	new_scooter.vehicle_name = scooter_key
	
	get_tree().root.add_child(new_scooter)
	new_scooter.global_position = player.global_position + Vector3.FORWARD * 2
	new_scooter.global_position.y += 0.5
	
	# Ustaw jako aktualny pojazd
	player.current_vehicle = new_scooter
	SaveManager.current_scooter_id = scooter_key
	SaveManager.save_game()
	
	print("Spawniutto skuter (bez klonowania): " + scooter_key)

func _style_tablet_btn(btn: Button):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.3, 0.6, 1.0, 0.7)
	style_normal.set_corner_radius_all(6)
	style_normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.4, 0.7, 1.0, 0.8)
	style_hover.set_corner_radius_all(6)
	style_hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color.WHITE)

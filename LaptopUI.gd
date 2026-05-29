extends CanvasLayer

# --- Nowy System UI (Programowy) ---
var laptop_root: PanelContainer = null
var main_vbox: VBoxContainer = null
var items_grid: GridContainer = null
var cart_label: Label = null
var money_label: Label = null
var lvl_xp_label: Label = null
var pay_button_new: Button = null
var tuning_view: ScrollContainer = null
var tuning_tab_btn: Button = null

# --- Diagnostyka ---
var diagnostics_view: VBoxContainer = null
var analysis_tab_btn: Button = null
var diagnostics_label: Label = null
var repair_btn: Button = null

# Referencje do dźwięków (muszą pasować do .tscn)
@onready var upgrade_sound_player = $UpgradeSoundPlayer
@onready var nav_click_player = $NavClickPlayer

# Logika
var current_scooter_id = ""
var shopping_cart = []
var total_cost = 0.0

func _ready():
	# CAŁKOWITA CZYSTKA STAREGO UI
	for child in get_children():
		if child is Control:
			child.hide()
			child.process_mode = Node.PROCESS_MODE_DISABLED
	
	current_scooter_id = SaveManager.current_scooter_id
	if current_scooter_id == "": current_scooter_id = "yamahaaerox"
	
	_build_laptop_ui()
	_update_info_bar()
	update_button_states()
	
	# Podłącz sygnały globalne
	SaveManager.xp_updated.connect(func(_x,_l): _update_info_bar())
	SaveManager.money_updated.connect(func(_m): _update_info_bar())

func _build_laptop_ui():
	# Główny kontener
	laptop_root = PanelContainer.new()
	laptop_root.custom_minimum_size = Vector2(900, 600)
	add_child(laptop_root)
	
	# Centrowanie na środku ekranu
	laptop_root.set_anchors_preset(Control.PRESET_CENTER)
	laptop_root.offset_left = -450
	laptop_root.offset_top = -300
	laptop_root.offset_right = 450
	laptop_root.offset_bottom = 300
	laptop_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	laptop_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.07, 0.96)
	style.border_width_top = 4
	style.border_color = Color(0.3, 0.6, 0.2) # Zielony akcent
	style.set_corner_radius_all(4)
	style.set_content_margin_all(20)
	laptop_root.add_theme_stylebox_override("panel", style)
	
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	laptop_root.add_child(main_vbox)
	
	# --- TOP BAR ---
	var top_bar = HBoxContainer.new()
	main_vbox.add_child(top_bar)
	
	var title = Label.new()
	title.text = "TUNING CENTER PRO"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.3))
	top_bar.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	if SaveManager.owned_scooters.size() > 0:
		var selector_hbox = HBoxContainer.new()
		top_bar.add_child(selector_hbox)
		var sel_lbl = Label.new()
		sel_lbl.text = "Wybrany:"
		selector_hbox.add_child(sel_lbl)
		
		var selector = OptionButton.new()
		selector.custom_minimum_size = Vector2(150, 0)
		for s_id in SaveManager.owned_scooters:
			var display_name = SaveManager.ITEM_NAMES.get(s_id, s_id.capitalize())
			selector.add_item(display_name)
		
		# Znajdz indeks aktualnego
		var idx = SaveManager.owned_scooters.find(current_scooter_id)
		if idx >= 0:
			selector.select(idx)
		else:
			selector.select(0)
			if SaveManager.owned_scooters.size() > 0:
				current_scooter_id = SaveManager.owned_scooters[0]
				
		selector.item_selected.connect(func(i):
			current_scooter_id = SaveManager.owned_scooters[i]
			shopping_cart.clear()
			update_button_states()
		)
		selector_hbox.add_child(selector)
	
	var scooter_sel_spacer = Control.new()
	scooter_sel_spacer.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(scooter_sel_spacer)
	
	var info_vbox = VBoxContainer.new()
	top_bar.add_child(info_vbox)
	
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	info_vbox.add_child(money_label)
	
	lvl_xp_label = Label.new()
	lvl_xp_label.add_theme_font_size_override("font_size", 14)
	lvl_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_vbox.add_child(lvl_xp_label)
	
	# --- TABS ---
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tabs_hbox)
	
	tuning_tab_btn = _create_tab_button("WYPOSAŻENIE / TUNING", true)
	tuning_tab_btn.pressed.connect(_show_tuning)
	tabs_hbox.add_child(tuning_tab_btn)
	
	analysis_tab_btn = _create_tab_button("ANALIZA POJAZDU", false)
	analysis_tab_btn.pressed.connect(_show_diagnostics)
	tabs_hbox.add_child(analysis_tab_btn)
	
	_update_info_bar()
	
	# --- CONTENT AREA ---
	var content_root = Control.new()
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_root)
	
	# TUNING VIEW
	tuning_view = ScrollContainer.new()
	tuning_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(tuning_view)
	
	items_grid = GridContainer.new()
	items_grid.columns = 3
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 15)
	items_grid.add_theme_constant_override("v_separation", 15)
	tuning_view.add_child(items_grid)
	
	# DIAGNOSTICS VIEW
	diagnostics_view = VBoxContainer.new()
	diagnostics_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	diagnostics_view.alignment = BoxContainer.ALIGNMENT_CENTER
	diagnostics_view.add_theme_constant_override("separation", 20)
	diagnostics_view.visible = false
	content_root.add_child(diagnostics_view)
	
	var diag_title = Label.new()
	diag_title.text = "SKANOWANIE SYSTEMÓW POJAZDU..."
	diag_title.add_theme_font_size_override("font_size", 24)
	diag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostics_view.add_child(diag_title)
	
	diagnostics_label = Label.new()
	diagnostics_label.text = "Status: Oczekujący"
	diagnostics_label.add_theme_font_size_override("font_size", 18)
	diagnostics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostics_view.add_child(diagnostics_label)
	
	var repair_center = CenterContainer.new()
	diagnostics_view.add_child(repair_center)
	repair_btn = Button.new()
	repair_btn.text = "NAPRAW SKUTER"
	repair_btn.custom_minimum_size = Vector2(250, 50)
	repair_btn.pressed.connect(_on_repair_pressed)
	repair_btn.visible = false
	_style_btn(repair_btn, Color(0.2, 0.7, 0.3))
	repair_center.add_child(repair_btn)
	
	# --- BOTTOM BAR ---
	var bottom_bar = HBoxContainer.new()
	main_vbox.add_child(bottom_bar)

	
	var reset_btn = Button.new()
	reset_btn.text = "RESETUJ ULEPSZENIA (Zwrot 30%)"
	reset_btn.pressed.connect(_on_reset_stats)
	bottom_bar.add_child(reset_btn)
	_style_btn(reset_btn, Color(0.6, 0.2, 0.2))
	
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer2)
	
	cart_label = Label.new()
	cart_label.text = "Koszyk: 0.00 zł"
	bottom_bar.add_child(cart_label)
	
	pay_button_new = Button.new()
	pay_button_new.text = "ZAPŁAĆ I WYJDŹ"
	pay_button_new.pressed.connect(_on_pay_pressed)
	bottom_bar.add_child(pay_button_new)
	_style_btn(pay_button_new, Color(0.2, 0.5, 0.8))

	_build_tuning_grid()


	
	# Pozostawiamy puste, zbudujemy na końcu funkcji _build_laptop_ui


func _update_info_bar():
	if money_label:
		money_label.text = "Portfel: %.2f zł" % SaveManager.player_money
	if lvl_xp_label:
		lvl_xp_label.text = "LVL %d (%d/%d XP)" % [SaveManager.player_level, SaveManager.player_xp, SaveManager.xp_for_next_level()]

func update_button_states():
	# Wyczyść i przebuduj grid
	for child in items_grid.get_children():
		child.queue_free()
	
	total_cost = 0.0
	var upgrades = SaveManager.UPGRADES[current_scooter_id]
	var stats = SaveManager.get_scooter_stats(current_scooter_id)
	
	for key in upgrades.keys():
		var up_data = upgrades[key]
		var card = _create_upgrade_card(key, up_data, stats)
		items_grid.add_child(card)
	
	cart_label.text = "Łącznie: %.2f zł" % total_cost
	if total_cost > 0:
		pay_button_new.text = "KUP ZAZNACZONE (%.2f zł)" % total_cost
	else:
		pay_button_new.text = "WYJDŹ"

func _create_upgrade_card(key: String, data: Dictionary, stats: Dictionary):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(270, 160)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.11)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	vbox.add_child(name_label)
	
	var desc = Label.new()
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Dynamiczny opis na podstawie typu
	match key:
		"fuel_tank": desc.text = "Pojemność: %.1f L" % data["level_1_fuel"]
		"cooler": desc.text = "Szybsze chłodzenie, mniejsze grzanie."
		"engine": desc.text = "Większa prędkość i moc."
		"tires": desc.text = "Lepsza przyczepność w zakrętach."
		"exhaust": desc.text = "Lepsze przyspieszenie i dźwięk."
		"engine_70cc": desc.text = "Ekstremalna moc (Wymaga LVL 5)."
		"weight": desc.text = "Lżejszy skuter = lepszy start."
	vbox.add_child(desc)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 35)
	vbox.add_child(btn)
	
	# Logika stanu przycisku
	var installed = stats.has(key + "_level") and stats[key + "_level"] > 0
	var in_cart = key in shopping_cart
	var locked = data.has("req_lvl") and SaveManager.player_level < data["req_lvl"]
	
	if installed:
		btn.text = "ZAINSTALOWANO"
		btn.disabled = true
		_style_btn(btn, Color(0.3, 0.4, 0.3))
	elif locked:
		btn.text = "POZIOM %d WYMAGANY" % data["req_lvl"]
		btn.disabled = true
		_style_btn(btn, Color(0.3, 0.3, 0.3))
	elif in_cart:
		btn.text = "W KOSZYKU"
		btn.pressed.connect(func(): _toggle_cart(key))
		total_cost += data["cost"]
		_style_btn(btn, Color(0.7, 0.6, 0.2))
	else:
		btn.text = "KUP: %.2f zł" % data["cost"]
		btn.disabled = SaveManager.player_money < data["cost"]
		btn.pressed.connect(func(): _toggle_cart(key))
		_style_btn(btn, Color(0.2, 0.4, 0.1))
	
	return panel

func _toggle_cart(key: String):
	if key in shopping_cart:
		shopping_cart.erase(key)
	else:
		shopping_cart.append(key)
	nav_click_player.play()
	update_button_states()

func _on_reset_stats():
	SaveManager.refund_and_reset_stats(current_scooter_id)
	shopping_cart.clear()
	upgrade_sound_player.play()
	update_button_states()

func _on_pay_pressed():
	if shopping_cart.is_empty():
		_close_all()
		return
		
	var success = SaveManager.try_buy_shopping_cart(current_scooter_id, shopping_cart)
	if success:
		upgrade_sound_player.play()
		_close_all()
	else:
		nav_click_player.play()

func _close_all():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SaveManager.emit_signal("scooter_stats_updated")
	queue_free()

func _style_btn(btn: Button, color: Color):
	var n = StyleBoxFlat.new()
	n.bg_color = color
	n.set_corner_radius_all(3)
	var h = n.duplicate()
	h.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_font_size_override("font_size", 13)

func _create_tab_button(label: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 40)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.2) if active else Color(0.1, 0.1, 0.1)
	style.border_width_bottom = 3 if active else 0
	style.border_color = Color(0.4, 0.9, 0.3)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover_style)
	return btn

func _style_tab_btn(btn: Button, active: bool):
	var style = btn.get_theme_stylebox("normal").duplicate()
	style.bg_color = Color(0.2, 0.25, 0.2) if active else Color(0.1, 0.1, 0.1)
	style.border_width_bottom = 3 if active else 0
	btn.add_theme_stylebox_override("normal", style)

func _build_tuning_grid():
	update_button_states()

func _show_tuning():
	nav_click_player.play()
	tuning_view.visible = true
	diagnostics_view.visible = false
	_style_tab_btn(tuning_tab_btn, true)
	_style_tab_btn(analysis_tab_btn, false)

func _show_diagnostics():
	nav_click_player.play()
	tuning_view.visible = false
	diagnostics_view.visible = true
	_style_tab_btn(tuning_tab_btn, false)
	_style_tab_btn(analysis_tab_btn, true)
	
	repair_btn.visible = false
	
	if SaveManager.vehicle_broken:
		diagnostics_label.text = "Skanowanie usterek w toku..."
		diagnostics_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
		
		var tw = create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func():
			var temp = SaveManager.DAMAGE_TYPES[SaveManager.vehicle_damage_type]
			var part_id = temp["required_part"]
			var part_name = SaveManager.ITEM_NAMES[part_id]
			
			var has_part = SaveManager.inventory.get(part_id, 0) > 0
			if has_part:
				diagnostics_label.text = "Wykryto usterkę: %s.\nMasz wymaganą część (%s)." % [temp["name"], part_name]
				diagnostics_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
				repair_btn.visible = true
			else:
				diagnostics_label.text = "Wykryto usterkę: %s.\nBrak części: %s. Kup w sklepie!" % [temp["name"], part_name]
				diagnostics_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		)
	else:
		diagnostics_label.text = "Skanowanie zakończone.\nPojazd jest w pełni sprawny."
		diagnostics_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))

func _on_repair_pressed():
	if not SaveManager.vehicle_broken: return
	
	var part_id = SaveManager.DAMAGE_TYPES[SaveManager.vehicle_damage_type]["required_part"]
	
	if SaveManager.inventory.get(part_id, 0) > 0:
		SaveManager.inventory[part_id] -= 1
		SaveManager.vehicle_broken = false
		SaveManager.vehicle_damage_type = ""
		SaveManager.save_game()
		
		# Napraw fizycznie w świecie (np. poprzez wezwanie metody na pojeździe, jeśli istnieje)
		var vehicles = get_tree().get_nodes_in_group("vehicle")
		for v in vehicles:
			if v.has_method("repair_vehicle"):
				v.repair_vehicle()
				
		upgrade_sound_player.play()
		_show_diagnostics() # Odśwież widok
	else:
		print("Błąd! Nie masz części.")

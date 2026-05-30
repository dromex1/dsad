extends Node3D

# Dostępne skutery do kupienia
var scooters = {
	"newaerox": {
		"name": "Nowy Aerox",
		"price": 2000,
		"model_path": "res://skutery/newaerox/aerox.obj",
		"scene_path": "res://skutery/NewAerox.tscn"
	},
	"aprilia": {
		"name": "Aprilia SR50",
		"price": 1500,
		"model_path": "res://skutery/aprillia sr50/aprillia.obj",
		"scene_path": "res://skutery/AprilliaSR50.tscn"
	}
}

var current_scooter = "newaerox"  # Domyślnie jest Aerox
var shop_area: Area3D
var shop_gui: Control
var player_in_shop = false
var gui_background: ColorRect
var tween_animation: Tween

func _ready():
	# Utworzenie Area3D dla sklepu
	shop_area = Area3D.new()
	shop_area.name = "ShopArea"
	add_child(shop_area)
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(4, 2.5, 4)
	shop_area.add_child(collision_shape)
	
	# Prompt do wejścia
	var prompt = Label3D.new()
	prompt.name = "ShopPrompt"
	prompt.text = "Sklep\nNaciśnij [E]"
	prompt.font_size = 24
	prompt.position.y = 1.5
	prompt.visible = false
	add_child(prompt)
	
	# GUI sklepu
	shop_gui = create_shop_gui()
	shop_gui.visible = false
	
	# Sygnały
	shop_area.body_entered.connect(_on_body_entered)
	shop_area.body_exited.connect(_on_body_exited)
	
	set_process_input(true)

func create_shop_gui() -> Control:
	# Create a CanvasLayer to hold the GUI (above the 3D world)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ShopGUILayer"
	add_child(canvas_layer)
	
	# Create root container that fills the screen
	var root = Control.new()
	root.name = "ShopGUIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	canvas_layer.add_child(root)
	
	# Create background that dims the screen
	gui_background = ColorRect.new()
	gui_background.color = Color(0, 0, 0, 0)  # Start transparent
	gui_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	gui_background.offset_left = 0
	gui_background.offset_top = 0
	gui_background.offset_right = 0
	gui_background.offset_bottom = 0
	root.add_child(gui_background)
	
	# Main panel container (like laptop UI)
	var panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(900, 600)
	root.add_child(panel_container)
	
	# Explicit centering
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -450
	panel_container.offset_top = -300
	panel_container.offset_right = 450
	panel_container.offset_bottom = 300
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.07, 0.96)  # Dark greenish-gray
	style.border_width_top = 4
	style.border_color = Color(0.4, 0.9, 0.3)  # Green accent
	style.set_corner_radius_all(4)
	style.set_content_margin_all(20)
	panel_container.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	panel_container.add_child(main_vbox)
	
	# --- TOP BAR ---
	var top_bar = HBoxContainer.new()
	main_vbox.add_child(top_bar)
	
	var title = Label.new()
	title.text = "SKLEP SKUTERÓW"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.3))
	top_bar.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	var money_label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.text = "0 zł"
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	top_bar.add_child(money_label)
	
	var scooters_label = Label.new()
	scooters_label.text = "SKUTERY"
	scooters_label.add_theme_font_size_override("font_size", 20)
	scooters_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	main_vbox.add_child(scooters_label)
	
	# --- CONTENT AREA (Grid of scooters) ---
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.add_theme_constant_override("separation", 20)
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(scroll_vbox)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	scroll_vbox.add_child(grid)
	
	# Dodaj każdy skuter
	for scooter_key in scooters.keys():
		var scooter_data = scooters[scooter_key]
		var item = create_scooter_item(scooter_key, scooter_data)
		grid.add_child(item)
		
	# --- CZĘŚCI ZAMIENNE ---
	var parts_label = Label.new()
	parts_label.text = "CZĘŚCI NAPRAWCZE"
	parts_label.add_theme_font_size_override("font_size", 20)
	parts_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	scroll_vbox.add_child(parts_label)
	
	var grid_parts = GridContainer.new()
	grid_parts.columns = 3
	grid_parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_parts.add_theme_constant_override("h_separation", 15)
	grid_parts.add_theme_constant_override("v_separation", 15)
	scroll_vbox.add_child(grid_parts)
	
	for part_id in SaveManager.REPAIR_PARTS_PRICES.keys():
		var item = create_part_item(part_id, SaveManager.REPAIR_PARTS_PRICES[part_id])
		grid_parts.add_child(item)
		
	# --- PRODUKTY SPOŻYWCZE ---
	var consumables_label = Label.new()
	consumables_label.text = "PRODUKTY SPOŻYWCZE I PŁYNY"
	consumables_label.add_theme_font_size_override("font_size", 20)
	consumables_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	scroll_vbox.add_child(consumables_label)
	
	var grid_consumables = GridContainer.new()
	grid_consumables.columns = 3
	grid_consumables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_consumables.add_theme_constant_override("h_separation", 15)
	grid_consumables.add_theme_constant_override("v_separation", 15)
	scroll_vbox.add_child(grid_consumables)
	
	for cons_id in SaveManager.CONSUMABLE_PRICES.keys():
		var item = create_part_item(cons_id, SaveManager.CONSUMABLE_PRICES[cons_id])
		grid_consumables.add_child(item)
	
	# --- BOTTOM BAR ---
	var bottom_bar = HBoxContainer.new()
	main_vbox.add_child(bottom_bar)
	
	var close_btn = Button.new()
	close_btn.text = "ZAMKNIJ [ESC]"
	close_btn.pressed.connect(_on_close_shop)
	close_btn.custom_minimum_size = Vector2(150, 40)
	bottom_bar.add_child(close_btn)
	_style_btn(close_btn, Color(0.6, 0.2, 0.2))
	
	return root

func _style_btn(btn: Button, color: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.set_corner_radius_all(4)
	style_hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color.WHITE)

func create_scooter_item(scooter_key: String, scooter_data: Dictionary) -> Control:
	# Panel card like in laptop UI
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 200)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.11, 0.9)
	card_style.border_width_left = 3
	card_style.border_color = Color(0.4, 0.9, 0.3)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Nazwa skutera
	var name_label = Label.new()
	name_label.text = scooter_data["name"].to_upper()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Opis (placeholder)
	var desc_label = Label.new()
	desc_label.text = "Wydajny skuter do jazdy po mieście"
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(desc_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Bottom bar z przyciskiem i ceną
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(bottom_hbox)
	
	# Cena
	var price_label = Label.new()
	price_label.text = "%d zł" % scooter_data["price"]
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	bottom_hbox.add_child(price_label)
	
	var price_spacer = Control.new()
	price_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(price_spacer)
	
	# Przycisk kupienia
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 35)
	buy_btn.text = "KUP"
	buy_btn.pressed.connect(_on_buy_scooter.bindv([scooter_key, scooter_data]))
	bottom_hbox.add_child(buy_btn)
	_style_btn(buy_btn, Color(0.4, 0.9, 0.3))
	
	return panel

func create_part_item(part_id: String, price: float) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 140)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	card_style.border_width_left = 3
	card_style.border_color = Color(0.4, 0.6, 0.9)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(top_hbox)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path = SaveManager.ITEM_ICONS.get(part_id, "")
	if tex_path != "":
		var tex = load(tex_path)
		if tex: icon.texture = tex
	top_hbox.add_child(icon)
	
	var name_label = Label.new()
	name_label.text = SaveManager.ITEM_NAMES.get(part_id, part_id).to_upper()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_hbox.add_child(name_label)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	var bottom_hbox = HBoxContainer.new()
	vbox.add_child(bottom_hbox)
	
	var price_label = Label.new()
	price_label.text = "%.2f zł" % price
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	bottom_hbox.add_child(price_label)
	
	var price_spacer = Control.new()
	price_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(price_spacer)
	
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(80, 30)
	buy_btn.text = "KUP"
	buy_btn.pressed.connect(_on_buy_part.bindv([part_id, price]))
	bottom_hbox.add_child(buy_btn)
	_style_btn(buy_btn, Color(0.3, 0.5, 0.8))
	
	return panel

func _on_buy_part(part_id: String, price: float):
	if SaveManager.player_money >= price:
		SaveManager.player_money -= price
		if SaveManager.inventory.has(part_id):
			SaveManager.inventory[part_id] += 1
		else:
			SaveManager.inventory[part_id] = 1
			
		SaveManager.save_game()
		update_money_display()
		print("Kupiono %s za %.2f zł" % [part_id, price])
	else:
		print("Nie masz wystarczająco pieniędzy!")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_shop = true
		var prompt = get_node_or_null("ShopPrompt")
		if prompt:
			prompt.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_shop = false
		var prompt = get_node_or_null("ShopPrompt")
		if prompt:
			prompt.visible = false
		_on_close_shop()

func _input(event):
	if player_in_shop and Input.is_action_just_pressed("interact") and not shop_gui.visible:
		_on_open_shop()
		return
	if player_in_shop and event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_E and not shop_gui.visible:
				_on_open_shop()
			elif event.keycode == KEY_ESCAPE and shop_gui.visible:
				_on_close_shop()

func _on_open_shop():
	shop_gui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_money_display()
	
	# Fade in animation
	if tween_animation:
		tween_animation.kill()
	tween_animation = create_tween().set_parallel(true)
	shop_gui.modulate.a = 0.0
	tween_animation.tween_property(shop_gui, "modulate:a", 1.0, 0.3)
	tween_animation.tween_property(gui_background, "color", Color(0, 0, 0, 0.9), 0.3).from(Color(0, 0, 0, 0))

func _on_close_shop():
	if not shop_gui.visible:
		return
	
	# Fade out animation
	if tween_animation:
		tween_animation.kill()
	tween_animation = create_tween().set_parallel(true)
	tween_animation.tween_property(shop_gui, "modulate:a", 0.0, 0.3)
	tween_animation.tween_property(gui_background, "color", Color(0, 0, 0, 0), 0.3)
	await tween_animation.finished
	
	shop_gui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_buy_scooter(scooter_key: String, scooter_data: Dictionary):
	var player = get_tree().root.find_child("Basic FPS Player", true, false)
	if not player:
		print("Nie znaleziono gracza!")
		return
	
	var price = scooter_data["price"]
	
	# Sprawdzenie czy gracz ma dość pieniędzy
	if SaveManager.player_money < price:
		show_message("Za mało pieniędzy! Brakuje: %d zł" % (price - SaveManager.player_money), Color.RED)
		return
	
	# Odebranie pieniędzy i dodanie do kolekcji
	SaveManager.player_money -= price
	SaveManager.add_owned_scooter(scooter_key)
	SaveManager.current_scooter_id = scooter_key
	
	# Szukamy dowolnego pojazdu u gracza
	var current_vehicle = null
	for child in player.get_children():
		if child is CharacterBody3D and child.is_in_group("vehicle"):
			current_vehicle = child
			break
	
	# Jeśli nie ma pojazdu, spawniujemy nowy obok gracza
	if not current_vehicle:
		var scene_path = scooter_data["scene_path"]
		var scene = load(scene_path)
		current_vehicle = scene.instantiate()
		# Dodaj do sceny NAJPIERW, potem ustaw pozycję
		get_tree().root.add_child(current_vehicle)
		# Teraz możemy ustawić global_position bezpiecznie
		await get_tree().process_frame
		current_vehicle.global_position = player.global_position + Vector3.FORWARD * 2
		print("Spawniowano nowy skuter: " + scooter_key)
	else:
		# Mamy pojazd, wymieniamy model
		swap_scooter_model(current_vehicle, scooter_key)
		# Ustawiamy nową nazwę pojazdu
		if current_vehicle.has_meta("vehicle_name"):
			current_vehicle.vehicle_name = scooter_key
	
	SaveManager.save_game()
	update_money_display()
	show_message("Zakupiono: %s!" % scooter_data["name"], Color.GREEN)
	
	# Potwierdzenie
	show_message("Kupiłeś %s! -%d zł" % [scooter_data["name"], price], Color.GREEN)
	current_scooter = scooter_key

func swap_scooter_model(vehicle_node: Node3D, scooter_key: String):
	var scooter_data = scooters[scooter_key]
	
	# Usuwamy stary model
	var old_model = vehicle_node.get_node_or_null("model_roweru")
	if old_model:
		for child in old_model.get_children():
			child.queue_free()
	
	# Ładujemy nowy model
	var resource = load(scooter_data["model_path"])
	if resource:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = resource
		
		if old_model:
			old_model.add_child(mesh_instance)
		else:
			vehicle_node.add_child(mesh_instance)
		
		print("Zmieniono model na: ", scooter_data["name"])
	else:
		print("Nie udało się załadować modelu: ", scooter_data["model_path"])

func update_money_display():
	var money_label = shop_gui.find_child("MoneyLabel", true, false)
	if money_label:
		money_label.text = "Pieniądze: %d zł" % SaveManager.player_money

func show_message(text: String, _color: Color):
	# Prostoty Message popup
	print("[SKLEP] ", text)
	# Tutaj można dodać animowaną wiadomość na ekranie

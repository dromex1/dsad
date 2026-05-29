extends Control

# Referencje do węzłów
@onready var OptionsPanel = $OptionsPanel
@onready var MenuButtons = $MenuButtons
@onready var MusicSlider = $OptionsPanel/OptionsLayout/MusicHBox/MusicSlider
@onready var SFXSlider = $OptionsPanel/OptionsLayout/SFXHBox/SFXSlider
@onready var GraphicsOptions = $OptionsPanel/OptionsLayout/GraphicsHBox/GraphicOptions
@onready var ContinueButton = $MenuButtons/ContinueButton
@onready var click_sound_player = $ClickSoundPlayer # Zakładam, że go dodałeś

func _ready():
	# Na starcie schowaj panel opcji
	OptionsPanel.visible = false

	# === WAŻNA ZMIANA ===
	# NIE wywołujemy SaveManager.load_game() tutaj!
	# SaveManager jest w Autoload i sam się wczytuje RAZ na starcie gry.
	# ======================

	# Ustaw widoczność przycisku KONTYNUUJ
	ContinueButton.visible = SaveManager.has_save_game

	# Zastosuj wczytane ustawienia do suwaków i audio
	MusicSlider.value = db_to_linear(SaveManager.music_vol_db)
	SFXSlider.value = db_to_linear(SaveManager.sfx_vol_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), SaveManager.music_vol_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), SaveManager.sfx_vol_db)
	GraphicsOptions.select(SaveManager.graphics_quality)
	_on_graphics_options_item_selected(SaveManager.graphics_quality)
	
	_style_menu_ui()

func _on_start_button_pressed():
	click_sound_player.play()
	SaveManager.reset_all_data()
	print("Ładowanie nowej gry...")
	get_tree().change_scene_to_file("res://intro_scene.tscn")

func _on_options_button_pressed():
	click_sound_player.play()
	OptionsPanel.visible = true
	MenuButtons.visible = false

func _on_quit_button_pressed():
	click_sound_player.play()
	get_tree().quit()

func _on_wstecz_button_pressed():
	click_sound_player.play()
	OptionsPanel.visible = false
	MenuButtons.visible = true

func _on_continue_button_pressed():
	click_sound_player.play()
	get_tree().change_scene_to_file("res://LoadingScreen.tscn")

func linear_to_db(linear_value):
	return lerp(-80.0, 10.0, linear_value)

func db_to_linear(db_value):
	return inverse_lerp(-80.0, 10.0, db_value)

func _on_music_slider_value_changed(value):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)
	SaveManager.music_vol_db = db
	SaveManager.save_game()

func _on_sfx_slider_value_changed(value):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
	SaveManager.sfx_vol_db = db
	SaveManager.save_game()

func _on_graphics_options_item_selected(index):
	SaveManager.graphics_quality = index
	SaveManager.apply_graphics_settings(get_viewport())
	SaveManager.save_game()

# ========================================
# ===   STYLOWANIE GUI - CIEMNY MOTYW  ===
# ========================================

func _style_menu_ui():
	# --- Style przycisków ---
	var btn_n = StyleBoxFlat.new()
	btn_n.bg_color = Color(0.1, 0.12, 0.08, 0.85)
	btn_n.set_border_width_all(1)
	btn_n.border_color = Color(0.3, 0.4, 0.2, 0.5)
	btn_n.set_corner_radius_all(4)
	btn_n.content_margin_top = 10
	btn_n.content_margin_bottom = 10
	btn_n.content_margin_left = 20
	btn_n.content_margin_right = 20

	var btn_h = StyleBoxFlat.new()
	btn_h.bg_color = Color(0.2, 0.32, 0.12, 0.9)
	btn_h.set_border_width_all(2)
	btn_h.border_color = Color(0.45, 0.65, 0.2, 0.8)
	btn_h.set_corner_radius_all(4)
	btn_h.content_margin_top = 10
	btn_h.content_margin_bottom = 10
	btn_h.content_margin_left = 20
	btn_h.content_margin_right = 20

	var btn_p = StyleBoxFlat.new()
	btn_p.bg_color = Color(0.14, 0.25, 0.08, 0.9)
	btn_p.set_border_width_all(2)
	btn_p.border_color = Color(0.35, 0.55, 0.15, 0.8)
	btn_p.set_corner_radius_all(4)
	btn_p.content_margin_top = 10
	btn_p.content_margin_bottom = 10
	btn_p.content_margin_left = 20
	btn_p.content_margin_right = 20

	# --- Styl panelu opcji ---
	var panel_st = StyleBoxFlat.new()
	panel_st.bg_color = Color(0.06, 0.08, 0.05, 0.92)
	panel_st.set_border_width_all(2)
	panel_st.border_color = Color(0.3, 0.45, 0.15, 0.4)
	panel_st.set_corner_radius_all(6)
	panel_st.content_margin_top = 24
	panel_st.content_margin_bottom = 24
	panel_st.content_margin_left = 28
	panel_st.content_margin_right = 28

	# --- Style suwaków ---
	var sl_bg = StyleBoxFlat.new()
	sl_bg.bg_color = Color(0.14, 0.16, 0.12, 0.8)
	sl_bg.set_corner_radius_all(3)
	sl_bg.content_margin_top = 5
	sl_bg.content_margin_bottom = 5

	var sl_fill = StyleBoxFlat.new()
	sl_fill.bg_color = Color(0.32, 0.55, 0.15, 0.9)
	sl_fill.set_corner_radius_all(3)
	sl_fill.content_margin_top = 5
	sl_fill.content_margin_bottom = 5

	var sl_fill_hl = StyleBoxFlat.new()
	sl_fill_hl.bg_color = Color(0.4, 0.65, 0.2, 0.95)
	sl_fill_hl.set_corner_radius_all(3)
	sl_fill_hl.content_margin_top = 5
	sl_fill_hl.content_margin_bottom = 5

	OptionsPanel.add_theme_stylebox_override("panel", panel_st)
	_apply_btn_style(MenuButtons, btn_n, btn_h, btn_p)
	_apply_btn_style(OptionsPanel, btn_n, btn_h, btn_p)
	_apply_slider_style(OptionsPanel, sl_bg, sl_fill, sl_fill_hl)
	_apply_label_style(MenuButtons)
	_apply_label_style(OptionsPanel)

func _apply_btn_style(node: Node, n: StyleBoxFlat, h: StyleBoxFlat, p: StyleBoxFlat):
	if node is Button:
		node.add_theme_stylebox_override("normal", n.duplicate())
		node.add_theme_stylebox_override("hover", h.duplicate())
		node.add_theme_stylebox_override("pressed", p.duplicate())
		node.add_theme_stylebox_override("focus", h.duplicate())
		node.add_theme_color_override("font_color", Color(0.82, 0.88, 0.78))
		node.add_theme_color_override("font_hover_color", Color(1, 1, 0.88))
		node.add_theme_color_override("font_pressed_color", Color(0.75, 0.85, 0.65))
		if node is OptionButton:
			var popup = node.get_popup()
			if popup:
				var pop_panel = StyleBoxFlat.new()
				pop_panel.bg_color = Color(0.08, 0.1, 0.07, 0.96)
				pop_panel.set_border_width_all(1)
				pop_panel.border_color = Color(0.3, 0.45, 0.15, 0.5)
				pop_panel.set_corner_radius_all(4)
				popup.add_theme_stylebox_override("panel", pop_panel)
				var pop_hover = StyleBoxFlat.new()
				pop_hover.bg_color = Color(0.2, 0.35, 0.12, 0.9)
				popup.add_theme_stylebox_override("hover", pop_hover)
				popup.add_theme_color_override("font_color", Color(0.82, 0.88, 0.78))
				popup.add_theme_color_override("font_hover_color", Color(1, 1, 0.88))
	for child in node.get_children():
		_apply_btn_style(child, n, h, p)

func _apply_slider_style(node: Node, bg: StyleBoxFlat, fill: StyleBoxFlat, hl: StyleBoxFlat):
	if node is HSlider:
		node.add_theme_stylebox_override("slider", bg.duplicate())
		node.add_theme_stylebox_override("grabber_area", fill.duplicate())
		node.add_theme_stylebox_override("grabber_area_highlight", hl.duplicate())
	for child in node.get_children():
		_apply_slider_style(child, bg, fill, hl)

func _apply_label_style(node: Node):
	if node is Label:
		node.add_theme_color_override("font_color", Color(0.88, 0.92, 0.84))
	for child in node.get_children():
		_apply_label_style(child)

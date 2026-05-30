extends CanvasLayer

const MOVE_ACTIONS: Dictionary = {
	"left": "ui_left",
	"right": "ui_right",
	"up": "ui_up",
	"down": "ui_down",
}

var joystick_touch_id: int = -1
var look_touch_id: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_radius: float = 130.0
var joystick_activation_size: Vector2 = Vector2(460, 460)
var joystick_fixed_offset: Vector2 = Vector2(220, 250)
var look_sensitivity: float = 1.0
var pressed_actions: Dictionary = {}

var root_control: Control
var joystick_base: Panel
var joystick_knob: Panel
var action_button: Button
var start_button: Button
var use_button: Button
var pause_button: Button
var jump_button: Button
var refuel_button: Button
var tablet_button: Button
var inventory_button: Button
var push_button: Button
var reload_button: Button
var hotbar_prev_button: Button
var hotbar_next_button: Button
var wheelie_button: Button


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
	_build_ui()


func _exit_tree() -> void:
	_release_all()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_pointer_over_button(event):
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if event.pressed:
		if _is_over_menu_or_ui(event.position):
			return
		if _is_in_joystick_zone(event.position, viewport_size) and joystick_touch_id == -1:
			joystick_touch_id = event.index
			joystick_center = _get_joystick_center(viewport_size)
			joystick_base.global_position = joystick_center - joystick_base.size * 0.5
			joystick_knob.position = joystick_base.size * 0.5 - joystick_knob.size * 0.5
			joystick_base.visible = true
		elif look_touch_id == -1:
			look_touch_id = event.index
	else:
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_vector = Vector2.ZERO
			joystick_base.visible = false
			_update_move_actions(Vector2.ZERO)
		elif event.index == look_touch_id:
			look_touch_id = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_id:
		var offset: Vector2 = event.position - joystick_center
		if offset.length() > joystick_radius:
			offset = offset.normalized() * joystick_radius
		joystick_vector = offset / joystick_radius
		joystick_knob.position = joystick_base.size * 0.5 - joystick_knob.size * 0.5 + offset
		_update_move_actions(joystick_vector)
	elif event.index == look_touch_id:
		_apply_look(event.relative * look_sensitivity)


func _is_in_joystick_zone(position: Vector2, viewport_size: Vector2) -> bool:
	var zone: Rect2 = Rect2(Vector2(0, viewport_size.y - joystick_activation_size.y), joystick_activation_size)
	return zone.has_point(position)


func _get_joystick_center(viewport_size: Vector2) -> Vector2:
	return Vector2(joystick_fixed_offset.x, viewport_size.y - joystick_fixed_offset.y)


func _is_over_menu_or_ui(position: Vector2) -> bool:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control == null:
		return false
	if _is_own_control(hovered_control):
		return false
	return hovered_control.get_global_rect().has_point(position)


func _is_own_control(control: Control) -> bool:
	var current: Node = control
	while current != null:
		if current == root_control:
			return true
		current = current.get_parent()
	return false


func _update_move_actions(vector: Vector2) -> void:
	var threshold: float = 0.22
	_set_action("left", vector.x < -threshold)
	_set_action("right", vector.x > threshold)
	_set_action("up", vector.y < -threshold)
	_set_action("down", vector.y > threshold)


func _set_action(short_name: String, pressed: bool) -> void:
	var action_name: String = MOVE_ACTIONS[short_name]
	if pressed_actions.get(action_name, false) == pressed:
		return
	pressed_actions[action_name] = pressed
	var input_event: InputEventAction = InputEventAction.new()
	input_event.action = action_name
	input_event.pressed = pressed
	Input.parse_input_event(input_event)


func _press_action(action_name: String) -> void:
	var input_event: InputEventAction = InputEventAction.new()
	input_event.action = action_name
	input_event.pressed = true
	Input.parse_input_event(input_event)


func _release_action(action_name: String) -> void:
	var input_event: InputEventAction = InputEventAction.new()
	input_event.action = action_name
	input_event.pressed = false
	Input.parse_input_event(input_event)


func _tap_action(action_name: String) -> void:
	Input.action_press(action_name)
	await get_tree().process_frame
	Input.action_release(action_name)


func _set_key(keycode: int, pressed: bool) -> void:
	var input_event: InputEventKey = InputEventKey.new()
	input_event.keycode = keycode
	input_event.physical_keycode = keycode
	input_event.pressed = pressed
	Input.parse_input_event(input_event)


func _tap_key(keycode: int) -> void:
	_set_key(keycode, true)
	_set_key(keycode, false)


func _tap_mouse(button_index: int) -> void:
	var input_event: InputEventMouseButton = InputEventMouseButton.new()
	input_event.button_index = button_index
	input_event.pressed = true
	Input.parse_input_event(input_event)
	input_event = InputEventMouseButton.new()
	input_event.button_index = button_index
	input_event.pressed = false
	Input.parse_input_event(input_event)


func _get_player() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		return player
	return get_tree().root.find_child("Basic FPS Player", true, false)


func _try_use_selected_item() -> bool:
	var player: Node = _get_player()
	if player == null or not player.has_method("_use_hotbar_item"):
		return false
	var hotbar_items = player.get("hotbar_item_ids")
	var selected_slot = player.get("selected_hotbar_slot")
	if not (hotbar_items is Array) or not (selected_slot is int):
		return false
	if selected_slot < 0 or selected_slot >= hotbar_items.size():
		return false
	var item_id: String = str(hotbar_items[selected_slot])
	if item_id in ["piwo", "energol", "papieros"]:
		player.call("_use_hotbar_item", item_id)
		return true
	return false


func _mobile_action_pressed() -> void:
	var item_id: String = ""
	var player: Node = _get_player()
	if player != null and player.has_method("get_selected_hotbar_item"):
		item_id = player.get_selected_hotbar_item()
	
	if item_id == "pistolet":
		if player.has_method("_shoot_pistol"):
			player._shoot_pistol()
		return
	
	if _try_use_selected_item():
		return
	
	var vehicle: Node = get_tree().get_first_node_in_group("vehicle")
	if vehicle != null and vehicle.has_method("interact"):
		vehicle.interact()
		return
	
	Input.action_press("interact")
	_set_key(KEY_E, true)


func _mobile_action_released() -> void:
	_release_action("interact")
	_set_key(KEY_E, false)


func _apply_look(relative: Vector2) -> void:
	var mounted_vehicle: Node = _get_mounted_vehicle()
	if mounted_vehicle != null and mounted_vehicle.has_method("mobile_look"):
		mounted_vehicle.mobile_look(relative)
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_rotation_target") and player.is_physics_processing():
		player.set_rotation_target(relative)


func _get_mounted_vehicle() -> Node:
	for vehicle in get_tree().get_nodes_in_group("vehicle"):
		var vehicle_node: Node = vehicle as Node
		if vehicle_node != null and vehicle_node.get("is_mounted") == true:
			return vehicle_node
	return null


func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	joystick_base = _make_circle_panel(Color(0.05, 0.06, 0.05, 0.34), 260)
	joystick_base.visible = false
	root_control.add_child(joystick_base)

	joystick_knob = _make_circle_panel(Color(0.85, 0.9, 0.82, 0.55), 96)
	joystick_base.add_child(joystick_knob)

	action_button = _make_button("AKCJA", Vector2(156, 156), Control.PRESET_BOTTOM_RIGHT, Vector2(-182, -180))
	action_button.button_down.connect(func():
		_mobile_action_pressed()
	)
	action_button.button_up.connect(func():
		_mobile_action_released()
	)

	start_button = _make_button("START", Vector2(112, 112), Control.PRESET_BOTTOM_RIGHT, Vector2(-332, -120))
	start_button.button_down.connect(func(): _press_action("bell"))
	start_button.button_up.connect(func(): _release_action("bell"))

	use_button = _make_button("UŻYJ", Vector2(112, 112), Control.PRESET_BOTTOM_RIGHT, Vector2(-120, -342))
	use_button.button_down.connect(func(): _tap_mouse(MOUSE_BUTTON_RIGHT))

	pause_button = _make_button("II", Vector2(72, 72), Control.PRESET_TOP_RIGHT, Vector2(-92, 24))
	pause_button.pressed.connect(func():
		_tap_action("pause")
	)

	jump_button = _make_button("SKOK", Vector2(104, 104), Control.PRESET_BOTTOM_LEFT, Vector2(36, -142))
	jump_button.pressed.connect(func():
		_tap_action("ui_accept")
		_tap_key(KEY_SPACE)
	)

	refuel_button = _make_button("TANK", Vector2(96, 96), Control.PRESET_BOTTOM_RIGHT, Vector2(-446, -116))
	refuel_button.pressed.connect(func():
		_tap_action("refuel")
		_tap_key(KEY_G)
	)

	tablet_button = _make_button("TAB", Vector2(82, 72), Control.PRESET_TOP_LEFT, Vector2(24, 24))
	tablet_button.pressed.connect(func(): _tap_key(KEY_TAB))

	inventory_button = _make_button("INV", Vector2(82, 72), Control.PRESET_TOP_LEFT, Vector2(116, 24))
	inventory_button.pressed.connect(func(): _tap_key(KEY_I))

	push_button = _make_button("PCHAJ", Vector2(96, 82), Control.PRESET_BOTTOM_RIGHT, Vector2(-448, -214))
	push_button.button_down.connect(func():
		_press_action("refuel")
		_set_key(KEY_H, true)
	)
	push_button.button_up.connect(func():
		_release_action("refuel")
		_set_key(KEY_H, false)
	)

	reload_button = _make_button("R", Vector2(72, 72), Control.PRESET_TOP_RIGHT, Vector2(-176, 24))
	reload_button.pressed.connect(func(): _tap_key(KEY_R))

	hotbar_prev_button = _make_button("<", Vector2(72, 72), Control.PRESET_BOTTOM_LEFT, Vector2(36, -236))
	hotbar_prev_button.pressed.connect(func(): _tap_action("scroll_up"))

	hotbar_next_button = _make_button(">", Vector2(72, 72), Control.PRESET_BOTTOM_LEFT, Vector2(124, -236))
	hotbar_next_button.pressed.connect(func(): _tap_action("scroll_down"))

	wheelie_button = _make_button("WHEEL", Vector2(108, 82), Control.PRESET_BOTTOM_RIGHT, Vector2(-570, -116))
	wheelie_button.button_down.connect(func(): _set_key(KEY_ALT, true))
	wheelie_button.button_up.connect(func(): _set_key(KEY_ALT, false))


func _make_button(text: String, size: Vector2, preset: int, position: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.size = size
	button.set_anchors_preset(preset)
	button.position = position
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.06, 0.05, 0.46)
	normal.border_color = Color(0.8, 0.9, 0.75, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(80)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.38, 0.16, 0.7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	root_control.add_child(button)
	return button


func _make_circle_panel(color: Color, size_px: float) -> Panel:
	var panel: Panel = Panel.new()
	panel.size = Vector2(size_px, size_px)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(size_px * 0.5))
	style.border_color = Color(0.8, 0.9, 0.75, 0.35)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _is_pointer_over_button(event: InputEvent) -> bool:
	var position: Vector2 = Vector2.INF
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		position = event.position
	if position == Vector2.INF:
		return false
	for button in [action_button, start_button, use_button, pause_button, jump_button, refuel_button, tablet_button, inventory_button, push_button, reload_button, hotbar_prev_button, hotbar_next_button, wheelie_button]:
		var control_button: Button = button as Button
		if control_button != null and control_button.get_global_rect().has_point(position):
			return true
	return false


func _release_all() -> void:
	for action_name in MOVE_ACTIONS.values():
		_release_action(str(action_name))
	_release_action("interact")
	_release_action("bell")
	_release_action("pause")
	_release_action("refuel")
	_release_action("ui_accept")
	_set_key(KEY_H, false)
	_set_key(KEY_E, false)
	_set_key(KEY_ALT, false)

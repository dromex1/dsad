extends Area3D

@onready var refuel_prompt = $RefuelPrompt
@onready var refuel_complete_sound = $RefuelCompleteSound

var vehicle_in_area = null
var is_refueling = false
var current_refuel_cost = 0.0
var current_missing_fuel = 0.0

const SECONDS_PER_LITER = 4.0

func _ready():
	set_process(true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("vehicle") and body.has_method("refuel"):
		vehicle_in_area = body

func _on_body_exited(body):
	if body == vehicle_in_area:
		refuel_prompt.visible = false
		vehicle_in_area = null
		is_refueling = false 

func _process(_delta):
	if not is_refueling and vehicle_in_area:
		current_missing_fuel = vehicle_in_area.max_fuel - vehicle_in_area.current_fuel
		
		var mix_price = SaveManager.get_mix_price_per_liter()
		var oil_ml = SaveManager.get_oil_ml_for_liters(current_missing_fuel)
		
		if current_missing_fuel < 0.1:
			# Sprawdź czy można napełnić kanister
			var canister_space = SaveManager.CANISTER_MAX - SaveManager.canister_fuel
			if SaveManager.inventory.get("kanister", 0) > 0 and canister_space > 0.1:
				var canister_cost = canister_space * mix_price
				var canister_oil_ml = SaveManager.get_oil_ml_for_liters(canister_space)
				refuel_prompt.text = "Bak pełny | [H] Napełnij kanister %.1f L (%.2f zł + %.0f ml oleju)" % [canister_space, canister_cost, canister_oil_ml]
			else:
				refuel_prompt.text = "Bak pełny"
			refuel_prompt.visible = true
		else:
			current_refuel_cost = current_missing_fuel * mix_price
			
			var canister_text = ""
			var canister_space = SaveManager.CANISTER_MAX - SaveManager.canister_fuel
			if SaveManager.inventory.get("kanister", 0) > 0 and canister_space > 0.1:
				var canister_cost = canister_space * mix_price
				var canister_oil_ml = SaveManager.get_oil_ml_for_liters(canister_space)
				canister_text = "\n[H] Napełnij kanister %.1f L (%.2f zł + %.0f ml oleju)" % [canister_space, canister_cost, canister_oil_ml]
			
			refuel_prompt.text = "[G] Zatankuj %.2f L (%.2f zł + %.0f ml oleju)%s" % [current_missing_fuel, current_refuel_cost, oil_ml, canister_text]
			refuel_prompt.visible = true
			
			if Input.is_action_just_pressed("refuel"):
				start_refueling_process()
		
		# Napełnianie kanistra klawiszem H
		if Input.is_key_pressed(KEY_H) and not is_refueling:
			_fill_canister()
	
	elif not vehicle_in_area:
		refuel_prompt.visible = false

func _fill_canister():
	if SaveManager.inventory.get("kanister", 0) <= 0:
		show_player_message("NIE MASZ KANISTRA")
		return
	
	var space = SaveManager.CANISTER_MAX - SaveManager.canister_fuel
	if space < 0.1:
		show_player_message("KANISTER PEŁNY")
		return
	
	var mix_price = SaveManager.get_mix_price_per_liter()
	var cost = space * mix_price
	
	if SaveManager.player_money < cost:
		show_player_message("BRAK PIENIĘDZY")
		return
	
	is_refueling = true
	refuel_prompt.visible = false
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		SaveManager.player_money -= cost
		SaveManager.canister_fuel = SaveManager.CANISTER_MAX
		SaveManager.save_game()
		is_refueling = false
		return
	
	var refuel_time = max(1.0, space * (SECONDS_PER_LITER / 2.0))
	
	if player.refuel_container:
		player.refuel_container.visible = true
	if player.refuel_bar:
		player.refuel_bar.value = 0
		player.refuel_bar.max_value = 100
	
	var tween = create_tween()
	if player.refuel_bar:
		tween.tween_property(player.refuel_bar, "value", 100, refuel_time)
	else:
		tween.tween_interval(refuel_time)
	if player.refuel_label:
		animate_dots(player.refuel_label, refuel_time, "Napełnianie kanistra")
	
	await tween.finished
	refuel_complete_sound.play()
	
	SaveManager.player_money -= cost
	SaveManager.canister_fuel = SaveManager.CANISTER_MAX
	SaveManager.save_game()
	
	if player.refuel_container:
		player.refuel_container.visible = false
	is_refueling = false

func start_refueling_process():
	if SaveManager.player_money < current_refuel_cost:
		print("Brak pieniędzy!")
		show_player_message("BRAK PIENIĘDZY")
		return

	var refuel_time = max(1.0, current_missing_fuel * (SECONDS_PER_LITER / 2.0))
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		SaveManager.try_buy_fuel(current_refuel_cost, current_missing_fuel, "yamahaaerox")
		return

	is_refueling = true
	refuel_prompt.visible = false
	
	if player.refuel_container:
		player.refuel_container.visible = true
	if player.refuel_bar:
		player.refuel_bar.value = 0
		player.refuel_bar.max_value = 100
	
	var tween = create_tween()
	if player.refuel_bar:
		tween.tween_property(player.refuel_bar, "value", 100, refuel_time)
	else:
		tween.tween_interval(refuel_time)
	if player.refuel_label:
		animate_dots(player.refuel_label, refuel_time, "Tankowanie")
	
	await tween.finished
	refuel_complete_sound.play()
	
	if vehicle_in_area:
		SaveManager.try_buy_fuel(current_refuel_cost, current_missing_fuel, vehicle_in_area.vehicle_name)
		vehicle_in_area.refuel() 
	
	if player.refuel_container:
		player.refuel_container.visible = false
	is_refueling = false

func animate_dots(label_node, duration, base_text = "Tankowanie"):
	var timer = 0.0
	while is_refueling and timer < duration:
		label_node.text = base_text + " ."
		await get_tree().create_timer(0.4).timeout
		timer += 0.4; if not is_refueling: break
		label_node.text = base_text + " . ."
		await get_tree().create_timer(0.4).timeout
		timer += 0.4; if not is_refueling: break
		label_node.text = base_text + " . . ."
		await get_tree().create_timer(0.4).timeout
		timer += 0.4

func show_player_message(text: String):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	if player.refuel_container:
		player.refuel_container.visible = true
	if player.refuel_label:
		player.refuel_label.text = text
	if player.refuel_bar:
		player.refuel_bar.visible = false
	
	await get_tree().create_timer(2.0).timeout
	
	if player.refuel_container:
		player.refuel_container.visible = false
	if player.refuel_bar:
		player.refuel_bar.visible = true

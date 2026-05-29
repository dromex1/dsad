extends Node

const PROJECT_ID = "wiejskidev"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents/"

var player_id = ""
var player_name = ""

var update_timer: Timer
var commands_timer: Timer

func _ready():
	randomize()
	player_id = str(randi() % 9000 + 1000) 
	
	if SaveManager and SaveManager.player_nickname != "":
		player_name = SaveManager.player_nickname
	else:
		player_name = "Gracz_" + player_id
	
	update_timer = Timer.new()
	update_timer.wait_time = 3.0
	update_timer.autostart = true
	update_timer.timeout.connect(_update_player_status)
	add_child(update_timer)
	
	commands_timer = Timer.new()
	commands_timer.wait_time = 2.0
	commands_timer.autostart = true
	commands_timer.timeout.connect(_fetch_commands)
	add_child(commands_timer)

	_update_player_status()
	print("[WKS-FIRESTORE] Zainicjalizowano połączenie z Firestore! ID: ", player_id)

func _update_player_status():
	# W Firestore robimy PATCH na konkretny dokument
	var url = FIRESTORE_URL + "players/" + player_id
	
	var money = 0.0
	var session_hours = 0.0
	if SaveManager:
		money = SaveManager.player_money
		session_hours = float(Time.get_ticks_msec()) / 1000.0 / 3600.0
		
	var data = {
		"fields": {
			"id": { "stringValue": player_id },
			"name": { "stringValue": player_name },
			"sessionHours": { "doubleValue": session_hours },
			"money": { "doubleValue": money },
			"online": { "booleanValue": true },
			"lastPulse": { "integerValue": int(Time.get_unix_time_from_system()) }
		}
	}
	
	var headers = ["Content-Type: application/json"]
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res, code, _h, body):
		if code != 200:
			var err = body.get_string_from_utf8() if body else ""
			print("[WKS-FIRESTORE BŁĘD] Błąd wysyłania statusu: ", code, " | ", err)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))

func _fetch_commands():
	var url = FIRESTORE_URL + "server_commands/" + player_id
	var headers = ["Content-Type: application/json"]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res, code, _h, body):
		if code == 200:
			_on_command_received(_res, code, _h, body)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_command_received(_res, _code, _headers, body):
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var doc = json.data
		if typeof(doc) == TYPE_DICTIONARY and doc.has("fields"):
			var fields = doc["fields"]
			var status = fields.get("status", {}).get("stringValue", "")
			
			if status == "pending":
				var doc_name = doc["name"] # pełna ścieżka do wykonania HTTP_DELETE
				_process_command(fields, doc_name)

func _process_command(fields, doc_name):
	var action = fields.get("command", {}).get("stringValue", "")
	var payload = fields.get("payload", {}).get("stringValue", "")
	
	print("[WKS-ADMIN] Otrzymano komendę Firestore: ", action)
	
	if action == "give_money":
		if SaveManager:
			SaveManager.player_money += float(payload)
			print("Dodano gotówkę: ", float(payload))
	elif action == "kick":
		print("KICK: Wyrzucanie do menu!")
		get_tree().change_scene_to_file("res://main_menu.tscn")
	elif action == "warn":
		print("WARN: ", payload)
		_show_warn_popup(payload)
	elif action == "tp_to":
		if get_tree().current_scene.has_node("Gracz") and get_tree().current_scene.has_node("PUNKT_STARTOWY"):
			var gr = get_tree().current_scene.get_node("Gracz")
			gr.global_position = get_tree().current_scene.get_node("PUNKT_STARTOWY").global_position
			print("Zostałeś przeteleportowany!")
			
	_delete_command(doc_name)

func _show_warn_popup(reason):
	var canvas = CanvasLayer.new()
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bg.position = Vector2(20, -180)
	bg.size = Vector2(500, 150)
	
	var label = Label.new()
	label.text = "⚠️ OSTRZEŻENIE OD ADMINA ⚠️\n" + reason + "\nJeśli dostaniesz kolejnego warna, otrzymasz BAN na 2 Dni!"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.add_child(label)
	canvas.add_child(bg)
	add_child(canvas)
	
	# Usunięcie po 15 sekundach
	await get_tree().create_timer(15.0).timeout
	if canvas != null:
		canvas.queue_free()

func _delete_command(doc_name):
	var url = "https://firestore.googleapis.com/v1/" + doc_name
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res, _code, _h, _b): http.queue_free())
	http.request(url, [], HTTPClient.METHOD_DELETE)

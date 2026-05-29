extends Node

# Multiplayer system wyłączony - gra jest w trybie Single-Player
# NetworkManager trzymany jako pusty autoload dla kompatybilności


# Adres docelowy serwera dedykowanego w internecie
const GLOBAL_SERVER_IP = "10.183.232.135" # Twoje IP z ZeroTier

func join_global_server():
	emit_signal("lan_status_changed", "ŁĄCZENIE Z GŁÓWNYM SERWEREM...")
	print("Próba połączenia ze stałym serwerem globalnym (Internet)...")
	join_game(GLOBAL_SERVER_IP)

# ===========================================
# ===      SYGNAŁY POŁĄCZENIA SIECIOWEGO  ===
# ===========================================

func _on_peer_connected(id):
	print("Gracz dołączył: ", id)
	emit_signal("player_joined_notify", "Gracz #%d" % id)
	if multiplayer.is_server():
		# Dajemy klientowi czas na załadowanie sceny gry
		await get_tree().create_timer(1.5).timeout
		_do_spawn_player(id)

func _on_peer_disconnected(id):
	print("Gracz wyszedł: ", id)
	# Usuwamy gracza
	var p = get_tree().root.find_child(str(id), true, false)
	if p: p.queue_free()
	# Usuwamy też jego skuter
	var b = get_tree().root.find_child("Bike_" + str(id), true, false)
	if b: b.queue_free()

func _on_connected_to_server():
	emit_signal("connection_success")
	emit_signal("lan_status_changed", "POŁĄCZONO! Ładowanie świata...")
	print("Połączono z serwerem!")
	
	# Klient ładuje scenę gry
	get_tree().change_scene_to_file("res://scena_gry.tscn")
	
	# Czekamy na pełne wczytanie sceny
	await get_tree().create_timer(0.8).timeout
	
	# Usuwamy wbudowanego gracza single-player
	_remove_builtin_player()
	
	# Serwer sam stworzy naszego NetPlayera
	print("Klient czeka na spawn od serwera...")

func _on_connection_failed():
	emit_signal("connection_failed")
	emit_signal("lan_status_changed", "POŁĄCZENIE NIEUDANE!")
	print("Połączenie odrzucone.")
	
	# Auto-ukryj po 3s
	await get_tree().create_timer(3.0).timeout
	emit_signal("lan_status_changed", "")

# ===========================================
# ===      WEWNĘTRZNE FUNKCJE SPAWNU      ===
# ===========================================

func _remove_builtin_player():
	var scene = get_tree().current_scene
	if not scene:
		print("Ostrzeżenie: current_scene jest null, nie mogę usunąć gracza.")
		return
	
	var existing = scene.find_child("Basic FPS Player", false, false)
	if existing:
		existing.set_physics_process(false)
		existing.set_process(false)
		existing.set_process_input(false)
		if existing.has_node("Head/Camera3D"):
			existing.get_node("Head/Camera3D").current = false
		existing.queue_free()
		print("Usunięto wbudowanego gracza ze sceny (tryb multiplayer).")
	else:
		print("Info: Wbudowany gracz nie znaleziony (prawdopodobnie już usunięty).")

func _do_spawn_player(id):
	if not multiplayer.is_server():
		return
	
	if get_tree().root.find_child(str(id), true, false):
		print("Gracz ", id, " już istnieje, pomijam spawn.")
		return
	
	print(">>> Spawnowanie gracza o ID: ", id)
	
	var player_scene = load("res://NetPlayer.tscn")
	var player = player_scene.instantiate()
	player.name = str(id)
	
	var world = get_tree().current_scene
	if not world:
		print("BŁĄD KRYTYCZNY: current_scene jest null! Nie mogę zespawnować gracza.")
		return
	
	var offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	var spawn_pos = Vector3(0, 0.5, -95) + offset
	
	player.position = spawn_pos
	world.add_child(player, true)
	print(">>> Gracz ", id, " zespawnowany w: ", spawn_pos)
	
	# Wymuszamy teleportację (na wypadek gdyby klient w międzyczasie ustawił (0,0,0) zanim odebrał pakiet)
	# Czekamy małą chwilę, żeby klient na pewno zespawnował węzeł
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(player):
		player.rpc("teleport_to", spawn_pos)
	
	# Spawnowanie skutera obok gracza
	var bike_scene = load("res://yamahaaerox.tscn")
	var bike = bike_scene.instantiate()
	bike.name = "Bike_" + str(id)
	world.add_child(bike, true)
	bike.global_position = player.global_position + Vector3(1.5, 0.2, 0)
	print(">>> Skuter dla gracza ", id, " zespawnowany w: ", bike.global_position)
	
	# Pokazujemy powiadomienie na ekranie hosta
	_show_join_notification(id)

func _show_join_notification(id):
	# Tworzymy powiadomienie w lewym dolnym rogu
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var label = Label.new()
	label.text = "🎮 Gracz #%d dołączył do gry!" % id
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(20, 640)
	canvas.add_child(label)
	
	# Animacja: pojawia się, trwa 4s, znika
	var tween = create_tween()
	label.modulate.a = 0.0
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(canvas.queue_free)

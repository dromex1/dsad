extends Control

# Referencje do naszych węzłów
@onready var loading_bar = $LoadingBar
@onready var prompt_label = $PromptLabel

# Ścieżka do sceny, którą chcemy załadować
var scene_path = "res://scena_gry.tscn"

# Zmienna do śledzenia statusu
var is_loading = false
var progress = [0.0] # Używamy tablicy, żeby przekazać ją do funkcji (taka sztuczka w Godot)

func _ready():
	scene_path = _get_target_scene()


func _input(event):
	if event is InputEventScreenTouch and event.pressed and not is_loading:
		_start_loading()


# Ta funkcja działa w każdej klatce
func _process(_delta):

	# --- ETAP 1: Oczekiwanie na Spację ---
	# Jeśli jeszcze nie ładujemy gry
	if not is_loading:
		# I jeśli gracz wcisnął Spację
		if Input.is_action_just_pressed("ui_accept"):
			_start_loading()

	# --- ETAP 2: Ładowanie w toku ---
	# Jeśli ładujemy grę
	else:
		# Sprawdź status ładowania
		var status = ResourceLoader.load_threaded_get_status(scene_path, progress)

		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Ładowanie trwa. Aktualizuj pasek postępu.
			# progress[0] to wartość od 0.0 do 1.0
			loading_bar.value = progress[0] * 100 # Pasek postępu jest od 0 do 100

		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			# ŁADOWANIE UKOŃCZONE!
			print("Ładowanie ukończone!")
			# Wyłącz tę funkcję _process, żeby nie działała dalej
			set_process(false) 

			# WAŻNE: Ustawiamy flagę, że mamy zapis gry
			SaveManager.has_save_game = true
			SaveManager.save_game()

			# Pobierz załadowaną scenę
			var scene_resource = ResourceLoader.load_threaded_get(scene_path)
			# Przełącz się na nową scenę
			get_tree().change_scene_to_packed(scene_resource)

		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			# Coś poszło nie tak
			print("BŁĄD: Nie udało się załadować sceny gry!")
			prompt_label.text = "BŁĄD ŁADOWANIA!"
			# Możesz tu dodać np. `get_tree().quit()`


func _start_loading():
	print("Rozpoczynam ?adowanie w tle...")
	is_loading = true
	prompt_label.text = "?ADOWANIE... CZEKAJ."
	ResourceLoader.load_threaded_request(scene_path)


func _get_target_scene() -> String:
	if OS.has_feature("ios") or OS.has_feature("mobile"):
		return "res://scena_gry_mobile.tscn"
	return "res://scena_gry.tscn"

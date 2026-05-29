extends CharacterBody3D

# --- Ustawienia Gracza ---
@export var PREDKOSC = 5.0
@export var PREDKOSC_SKOKU = 4.5
@export var CZULOSC_MYSZY = 0.002 # Jak szybko się rozglądamy

# Pobieramy grawitację z ustawień projektu
@export var grawitacja: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Referencja do naszej kamery
@onready var kamera = $Camera3D


func _ready():
	# Ten kod "chwyta" kursor myszy i chowa go, żebyśmy mogli się rozglądać
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# --- NOWY KOD DO TELEPORTACJI ---
	# Czekamy, aż cała scena (mapa) będzie gotowa
	await get_tree().process_frame

	# Szukamy w całej grze węzła o nazwie "PUNKT_STARTOWY"
	var spawn_point = get_tree().get_root().find_child("PUNKT_STARTOWY", true, false)

	# Jeśli go znaleźliśmy
	if spawn_point:
		# Teleportuj gracza (czyli 'siebie') do globalnej pozycji tego punktu
		global_transform.origin = spawn_point.global_transform.origin
		print("Gracz teleportowany do PUNKTU_STARTOWEGO!")
	else:
		print("BŁĄD: Nie znaleziono 'PUNKT_STARTOWY' na mapie!")
	# --- KONIEC NOWEGO KODU ---


# Ta funkcja łapie ruchy myszki
func _input(event):
	# Sprawdzamy, czy to był ruch myszką
	if event is InputEventMouseMotion:
		# Obracamy całego gracza (w lewo/prawo)
		rotate_y(-event.relative.x * CZULOSC_MYSZY)
		# Obracamy tylko kamerę (w górę/dół)
		kamera.rotate_x(-event.relative.y * CZULOSC_MYSZY)
		# Blokujemy kamerę, żeby nie zrobiła "fikołka" (patrzenie za siebie)
		kamera.rotation.x = clamp(kamera.rotation.x, deg_to_rad(-90), deg_to_rad(90))


# Ta funkcja działa w każdej klatce fizyki (do ruchu)
func _physics_process(delta):
	var predkosc = velocity # Bierzemy aktualną prędkość (np. spadania)

	# Dodajemy grawitację (jeśli nie jesteśmy na ziemi)
	if not is_on_floor():
		predkosc.y -= grawitacja * delta

	# Sprawdzamy, czy gracz wcisnął skok
	if Input.is_action_just_pressed("jump") and is_on_floor():
		predkosc.y = PREDKOSC_SKOKU

	# Pobieramy kierunek z klawiszy WASD
	var kierunek_ruchu = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# 'Transform.basis' sprawia, że poruszamy się "do przodu" względem kamery, a nie "na północ"
	var kierunek = (transform.basis * Vector3(kierunek_ruchu.x, 0, kierunek_ruchu.y)).normalized()

	# Zastosuj ruch
	if kierunek:
		predkosc.x = kierunek.x * PREDKOSC
		predkosc.z = kierunek.z * PREDKOSC
	else:
		# Zwalniamy (efekt "poślizgu" na lodzie)
		predkosc.x = move_toward(predkosc.x, 0, PREDKOSC)
		predkosc.z = move_toward(predkosc.z, 0, PREDKOSC)

	# Zapisz nową prędkość i wykonaj ruch
	velocity = predkosc
	move_and_slide()

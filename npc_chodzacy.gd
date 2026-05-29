extends CharacterBody3D

# --- Konfiguracja Prędkości ---
@export var predkosc_ruchu: float = 3.0

# --- Kierunek (Globalny) ---
@export var kierunek_ruchu: Vector3 = Vector3(0, 0, -1)

# --- SKRÓT DO ANIMACJI ---
@onready var animation_player = $male_casual_walk/AnimationPlayer


# Ta funkcja uruchomi się raz na starcie
func _ready():
	# Wpisz tutaj DOKŁADNĄ nazwę animacji chodu
	var nazwa_animacji = "rig|rig|walk"
	
	# Sprawdzamy, czy taka animacja w ogóle istnieje
	if animation_player.has_animation(nazwa_animacji):
		
		# 1. Pobieramy obiekt animacji z odtwarzacza
		var anim = animation_player.get_animation(nazwa_animacji)
		
		# 2. USTAWIAMY TRYB ZAPĘTLANIA
		# Animation.LOOP_LINEAR to jest standardowa pętla (jak przycisk 🔁)
		anim.loop_mode = Animation.LOOP_LINEAR
		
		# 3. Dopiero teraz ją odtwarzamy
		animation_player.play(nazwa_animacji)
		
	else:
		# Drukujemy błąd, jeśli nazwa jest zła
		print("BŁĄD: Nie mogę znaleźć animacji o nazwie: ", nazwa_animacji)


# Ta funkcja jest wywoływana w pętli fizyki
func _physics_process(_delta):
	var kierunek = kierunek_ruchu.normalized()
	velocity = kierunek * predkosc_ruchu
	move_and_slide()

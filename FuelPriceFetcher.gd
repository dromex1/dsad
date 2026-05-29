extends Node

# FuelPriceFetcher - pobiera ceny paliwa PB95 z internetu
# Fallback: 6.50 zl/L jesli brak internetu

var http_request: HTTPRequest
const FALLBACK_PRICE = 6.50
var has_fetched = false

func _ready():
	http_request = HTTPRequest.new()
	http_request.timeout = 15.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# Pierwsze pobranie po 3 sekundach
	get_tree().create_timer(3.0).timeout.connect(fetch_fuel_price)
	
	# Potem co 10 minut
	var timer = Timer.new()
	timer.wait_time = 600.0
	timer.timeout.connect(fetch_fuel_price)
	add_child(timer)
	timer.start()

func fetch_fuel_price():
	print("FuelPriceFetcher: Pobieram ceny paliwa z Autocentrum...")
	var url = "https://www.autocentrum.pl/paliwa/ceny-paliw/"
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
		"Accept-Language: pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7"
	]
	var error = http_request.request(url, headers)
	if error != OK:
		print("FuelPriceFetcher: Blad HTTP request: ", error)
		_use_fallback()

func _try_fallback_api():
	pass

func _on_request_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("FuelPriceFetcher: HTTP error %d (result: %d). Fallback: %.2f zl/L" % [response_code, result, FALLBACK_PRICE])
		_use_fallback()
		return
	
	var html = body.get_string_from_utf8()
	var price = _find_pb95_price(html)
	
	if price > 0:
		SaveManager.PRICE_PER_LITER = price
		has_fetched = true
		print("FuelPriceFetcher: Cena PB95: %.2f zl/L (mieszanka: %.2f zl/L)" % [price, SaveManager.get_mix_price_per_liter()])
	else:
		print("FuelPriceFetcher: Nie znaleziono ceny w HTML, fallback.")
		_use_fallback()

func _find_pb95_price(html: String) -> float:
	# Szukaj ceny w formacie X,XX lub X.XX w poblizu "95" lub "Pb95" lub "benzyna"
	var search_terms = ["Pb 95", "PB95", "Pb95", "benzyna 95", "95", "E5", "pb95"]
	
	for term in search_terms:
		var pos = html.findn(term)
		if pos >= 0:
			# Szukaj ceny w okolicy (500 znakow dalej)
			var area = html.substr(pos, 500)
			var price = _extract_price(area)
			if price > 0:
				return price
	
	# Fallback - szukaj jakiejkolwiek ceny paliwa
	return _scan_for_fuel_price(html)

func _extract_price(text: String) -> float:
	for i in range(text.length() - 3):
		var ch = text[i]
		if ch >= "5" and ch <= "8":
			if i + 3 < text.length():
				var sep = text[i + 1]
				if sep == "," or sep == ".":
					var d1 = text[i + 2]
					var d2 = text[i + 3]
					if d1 >= "0" and d1 <= "9" and d2 >= "0" and d2 <= "9":
						var price_str = ch + "." + d1 + d2
						var price = float(price_str)
						if price >= 5.50 and price <= 8.50:
							return price
	return 0.0

func _scan_for_fuel_price(html: String) -> float:
	# Skanuj caly HTML w poszukiwaniu ceny w przedziale 5.50-8.50
	var idx = 0
	while idx < html.length() - 4:
		var ch = html[idx]
		if ch >= "5" and ch <= "8":
			if idx + 3 < html.length():
				var sep = html[idx + 1]
				if sep == "," or sep == ".":
					var d1 = html[idx + 2]
					var d2 = html[idx + 3]
					if d1 >= "0" and d1 <= "9" and d2 >= "0" and d2 <= "9":
						var price_str = ch + "." + d1 + d2
						var price = float(price_str)
						if price >= 5.50 and price <= 8.50:
							return price
		idx += 1
	return 0.0

func _use_fallback():
	if not has_fetched:
		SaveManager.PRICE_PER_LITER = FALLBACK_PRICE
		print("FuelPriceFetcher: Ustawiono cene fallback: %.2f zl/L" % FALLBACK_PRICE)

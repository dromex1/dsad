extends Node3D

# Gas Price Sign - wyświetla aktualne ceny paliwa
# Dodaj swój model 3D jako dziecko tego node'a

@onready var price_label: Label3D = $PriceLabel

func _ready():
	_update_prices()
	var timer = Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(_update_prices)
	add_child(timer)
	timer.start()

func _update_prices():
	var pb95 = SaveManager.PRICE_PER_LITER
	var mix = SaveManager.get_mix_price_per_liter()
	var oil_ml_per_l = SaveManager.oil_ratio * 1000.0  # ml oleju na litr paliwa
	var oil_cost_per_l = SaveManager.oil_ratio * SaveManager.oil_price_per_liter
	
	price_label.text = "CENY PALIW\n\nPB95        %.2f zl/L\nMotul 800   %.0f zl/L\nDawka oleju %.0f ml/L\nKoszt oleju +%.2f zl/L\n\nMIESZANKA   %.2f zl/L" % [pb95, SaveManager.oil_price_per_liter, oil_ml_per_l, oil_cost_per_l, mix]

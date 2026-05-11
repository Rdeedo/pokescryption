extends Node

func _ready():
	UIManager.register_price_label($PriceLabel)
	UIManager.set_price(UIManager.price_value)
	UIManager.register_scale_label($ScaleNumber)
	
	UIManager.register_result_popup($ResultPopup)
	$ResultPopup/PlayAgainButton.pressed.connect(_on_play_again_pressed)

func _on_play_again_pressed():
	UIManager.reset_game()

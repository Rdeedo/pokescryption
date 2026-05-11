extends Node

var price_value := 2
var price_label: Label = null
var scale_value := 0
var scale_label: Label = null
var result_popup: PopupPanel = null
var game_over := false

func register_price_label(label: Label):
	price_label = label
	
func register_scale_label(label: Label):
	scale_label = label

func register_result_popup(popup: PopupPanel):
	result_popup = popup
	
func set_price(value: int):
	price_value = value
	if price_label:
		price_label.text = "₽: %d" % price_value

func update_scale(delta: int):
	scale_value += delta
	scale_label.text = str(scale_value)

	if scale_value >= 8:
		player_wins()
	elif scale_value <= -8:
		enemy_wins()

func player_wins():
	game_over = true
	result_popup.get_node("ResultLabel").text = "YOU WIN!"
	result_popup.popup_centered()

func enemy_wins():
	game_over = true
	result_popup.get_node("ResultLabel").text = "YOU LOSE!"
	result_popup.popup_centered()

func reset_game():
	game_over = false
	scale_value = 0
	price_value = 1

	if scale_label:
		scale_label.text = "0"
	if price_label:
		price_label.text = "₽: 1"

	if result_popup:
		result_popup.hide()

	var world = get_tree().get_first_node_in_group("world_root")
	if world and world.has_method("reset_board"):
		world.reset_board()

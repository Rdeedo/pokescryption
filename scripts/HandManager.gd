extends Node

var selected_card = null
var click_consumed_by_card := false

func _process(_delta):
	click_consumed_by_card = false

func select_card(card):
	if selected_card and selected_card != card:
		selected_card.deselect_card()

	selected_card = card
	card.select_card()

func clear_selection():
	if selected_card:
		selected_card.deselect_card()
	selected_card = null

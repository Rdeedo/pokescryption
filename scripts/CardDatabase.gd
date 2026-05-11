extends Node

var card_paths: Array = []

func _ready():
	var dir = DirAccess.open("res://assets/models/cards/data/")
	for file in dir.get_files():
		if file.ends_with(".tres"):
			card_paths.append("res://assets/models/cards/data/" + file)

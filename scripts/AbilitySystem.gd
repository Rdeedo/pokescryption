extends Node

enum Trigger {
	ON_PLAY,
	ON_ATTACK,
	ON_DAMAGED,
	ON_DEATH,
	ON_TURN_END
}

func trigger(card, trigger_type: int, data := {}):
	if card == null or not is_instance_valid(card):
		return

	var ability: String = card.ability if card.has_method("ability") == false else card.ability
	if ability == "None":
		return

	match ability:
		"Flame Body":
			_flame_body(card, trigger_type, data)
		"Levitate":
			_levitate(card, trigger_type, data)
		"Shell Armor":
			_shell_armor(card, trigger_type, data)
		"Poison Point":
			_poison_point(card, trigger_type, data)
		"Poison Touch":
			_poison_touch(card, trigger_type, data)
		"Static":
			_static(card, trigger_type, data)
		"Earth Eater":
			_earth_eater(card, trigger_type, data)
		"Aerilate":
			_aerilate(card, trigger_type, data)
		"Payday":
			_payday(card, trigger_type, data)
		"Queenly Majesty":
			_queenly_majesty(card, trigger_type, data)
		"Moxie":
			_moxie(card, trigger_type, data)
		"Friend guard":
			_friend_guard(card, trigger_type, data)
		"Effect Spore":
			_effect_spore(card, trigger_type, data)
		"Psychic Terrain":
			_psychic_terrain(card, trigger_type, data)
		"Self Destruct":
			_self_destruct(card, trigger_type, data)
		"Cursed Body":
			_cursed_body(card, trigger_type, data)
		"Parental Bond":
			_parental_bond(card, trigger_type, data)
		"Swift Swim":
			_swift_swim(card, trigger_type, data)
		_:
			pass

func _flame_body(_card, trigger_type, data):
	if trigger_type == Trigger.ON_DAMAGED and data.has("attacker"):
		data.attacker.apply_status("Burn")

func _poison_point(_card, trigger_type, data):
	if trigger_type == Trigger.ON_DAMAGED and data.has("attacker"):
		data.attacker.apply_status("Poison")

func _static(_card, trigger_type, data):
	if trigger_type == Trigger.ON_DAMAGED and data.has("attacker"):
		data.attacker.apply_status("Paralyzed")

func _effect_spore(_card, trigger_type, data):
	if trigger_type == Trigger.ON_DAMAGED and data.has("attacker"):
		var statuses = ["Burn", "Poison", "Paralyzed"]
		data.attacker.apply_status(statuses.pick_random())

func _poison_touch(card, trigger_type, data):
	if trigger_type == Trigger.ON_ATTACK and data.has("target"):
		data.target.die(card)

func _shell_armor(_card, _trigger_type, _data):
	# handled in Card.take_damage via armor_used
	pass

func _queenly_majesty(_card, _trigger_type, _data):
	# handled in Card.take_damage via min(damage, 1)
	pass

func _payday(_card, trigger_type, _data):
	if trigger_type == Trigger.ON_DEATH:
		UIManager.set_price(UIManager.price_value + 3)

func _moxie(card, trigger_type, data):
	if trigger_type == Trigger.ON_ATTACK and data.has("target"):
		var target = data.target
		if target.current_health - card.attack <= 0:
			card.attack += 1
			card.update_visuals()

func _self_destruct(card, trigger_type, _data):
	if trigger_type == Trigger.ON_DEATH:
		var trainer = get_tree().get_first_node_in_group("trainer")
		if trainer and trainer.has_method("get_adjacent_cards"):
			var neighbors = trainer.get_adjacent_cards(card)
			for n in neighbors:
				if n and is_instance_valid(n):
					n.take_damage(999, card)

func _friend_guard(card, trigger_type, _data):
	if trigger_type == Trigger.ON_PLAY:
		var trainer = get_tree().get_first_node_in_group("trainer")
		if trainer and trainer.has_method("get_adjacent_cards"):
			for ally in trainer.get_adjacent_cards(card):
				if ally and is_instance_valid(ally):
					ally.max_health += 2
					ally.current_health += 2
					ally.update_visuals()
					
func _psychic_terrain(_card, trigger_type, _data):
	if trigger_type == Trigger.ON_PLAY:
		var trainer = get_tree().get_first_node_in_group("trainer")
		if trainer and trainer.has_method("move_random_enemy"):
			trainer.move_random_enemy()

func _cursed_body(_card, _trigger_type, _data):
	# Implement in targeting: only allow attackers with ability != "None"
	pass

func _levitate(_card, _trigger_type, _data):
	# Implement in targeting: ignore normal slot restrictions
	pass

func _aerilate(_card, _trigger_type, _data):
	# Implement in targeting: allow direct player hit
	pass

func _earth_eater(card, trigger_type, _data):
	if trigger_type == Trigger.ON_TURN_END:
		card.underground = true

func _parental_bond(card, trigger_type, data):
	if trigger_type == Trigger.ON_ATTACK and data.has("target"):
		var target = data.target
		target.take_damage(card.attack, card)
		if target and is_instance_valid(target) and target.current_health > 0:
			target.take_damage(card.attack, card)

func _swift_swim(_card, _trigger_type, _data):
	# Implement in attack ordering (Trainer.gd)
	pass

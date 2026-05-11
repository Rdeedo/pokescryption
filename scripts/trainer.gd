extends CharacterBody3D

const STEP_DISTANCE = 1.7
const TURN_ANGLE = 90.0
const STEP_TIME = 0.15
const TURN_TIME = 0.12

var busy := false
var can_interact := false
var interact_ray: RayCast3D
var table_camera: Camera3D = null
var player_camera: Camera3D = null
var original_pos: Vector3
var in_table_view := false
var mouse_ray: RayCast3D
var button_locked := false
var card_placement_locked := false
var CardScene := preload("res://scenes/base_card.tscn")
var card_slots: Array
var placed_cards := {}
var player_spawn: Node3D
var enemy_spawn: Node3D
var enemy_state: String = "defend"
var shift_map = {
	"slot1": "slot5",
	"slot2": "slot6",
	"slot3": "slot7",
	"slot4": "slot8"
}
var attack_map = {
	"slot9": "slot5",
	"slot10": "slot6",
	"slot11": "slot7",
	"slot12": "slot8"
}

var attack_map_enemy = {
	"slot5": "slot9",
	"slot6": "slot10",
	"slot7": "slot11",
	"slot8": "slot12"
}

var hand_cards: Array = []
var hand_positions: Array = []
var max_hand_size := 8
var player_hand: Node3D
var has_entered_table := false
var current_hovered_card: Node3D = null
var hover_scale := Vector3(0.65, 0.65, 0.65)
var base_scale := Vector3(0.5, 0.5, 0.5)
var hover_height := 0.25

func _ready():
	player_camera = $camera_mount/Camera3D
	interact_ray = $interact_ray

func set_enemy_state(new_state: String):
	enemy_state = new_state

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if Input.is_action_just_pressed("interact") and not busy:
		if in_table_view:
			exit_table_view()
		else:
			try_interact()
		return

	if in_table_view:
		handle_table_mouse_input()
	
	if busy or in_table_view:
		move_and_slide()
		return

	if Input.is_action_just_pressed("look_left"):
		smooth_turn(TURN_ANGLE)

	if Input.is_action_just_pressed("look_right"):
		smooth_turn(-TURN_ANGLE)

	if Input.is_action_just_pressed("forward"):
		smooth_step(-transform.basis.z)

	if Input.is_action_just_pressed("backward"):
		smooth_step(transform.basis.z)
	
	move_and_slide()

func get_slot_from_collider(collider: Node) -> Node3D:
	var node := collider
	while node and not node.is_in_group("card_slot"):
		node = node.get_parent()
	return node
		
func get_empty_slots() -> Array:
	var empty := []
	for slot in card_slots:
		if slot.is_in_group("row2") or slot.is_in_group("row3"):
			continue
		if not placed_cards.has(slot):
			empty.append(slot)
	return empty

func try_interact():
	var hit = interact_ray.get_collider()

	if hit == null:
		return

	if hit.is_in_group("table"):
		interact_with_table(hit)
		return

	var parent = hit.get_parent()
	if parent and parent.is_in_group("table"):
		interact_with_table(parent)
		return

func handle_table_mouse_input():
	if UIManager.game_over:
		return
	
	if Input.is_action_just_pressed("click"):
		var mouse_pos = get_viewport().get_mouse_position()

		var from = table_camera.project_ray_origin(mouse_pos)
		var to = from + table_camera.project_ray_normal(mouse_pos) * 20.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			var hit = result.collider

			if hit.is_in_group("button"):
				on_table_button_pressed()
				return

			var slot = get_slot_from_collider(hit)
			if slot:
				on_card_slot_clicked(slot)

			
func on_card_slot_clicked(slot):
	if UIManager.game_over:
		return
		
	if placed_cards.has(slot):
		var c = placed_cards[slot]
		if c == null or not is_instance_valid(c):
			placed_cards.erase(slot)
		else:
			return
		
	if HandManager.click_consumed_by_card:
		HandManager.click_consumed_by_card = false
		return 
	
	var card = HandManager.selected_card
	if card == null:
		print("No card selected")
		return
	
	if UIManager.price_value < card.cost:
		flash_card_red(card)
		return

	hand_cards.erase(card)
	update_hand_positions()

	card.get_parent().remove_child(card)
	add_child(card)
	
	$CardSFX.play()
	await animate_card_to_slot(card, slot)

	placed_cards[slot] = card
	UIManager.set_price(UIManager.price_value - card.cost)

	HandManager.clear_selection()


func animate_card_to_slot(card: Node3D, slot: Node3D) -> Signal:
	var tween = create_tween()

	tween.tween_property(
		card,
		"global_transform:origin",
		slot.global_transform.origin,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if card.get_parent():
			card.get_parent().remove_child(card)
		slot.add_child(card)
		card.transform = Transform3D.IDENTITY
	)

	return tween.finished

func debug_print_placed_cards():
	print("=== placed_cards ===")
	for slot in placed_cards.keys():
		print("slot:", slot.name, "groups:", slot.get_groups())

func on_table_button_pressed():
	if button_locked:
		return  
	
	if UIManager.game_over:
		return
	
	$ButtonSFX.play()
	
	button_locked = true  
	card_placement_locked = true
	debug_print_placed_cards()
	await perform_player_attacks()
	end_player_turn()
	
	set_enemy_state("attack")

	for slot in card_slots:
			if slot.is_in_group("row1") and placed_cards.has(slot):
				await shift_card_down(slot)
				
	for i in range(2): 
		if randf() < 0.4:
			await place_random_card()
		else:
			print("Enemy attempted attack but failed the 50% chance")
	
	await perform_enemy_attacks()
	end_enemy_turn()
	
	draw_card()
	UIManager.set_price(UIManager.price_value + 1)
	
	set_enemy_state("defend")
	button_locked = false
	card_placement_locked = false

func perform_player_attacks():
	for slot in placed_cards.keys():
		if slot.is_in_group("row3"):
			var card = placed_cards[slot]
			if card == null or not is_instance_valid(card):
				continue

			# Swift Swim / turn order handled elsewhere if needed

			var target_name = attack_map.get(slot.name, null)
			if target_name == null:
				continue

			var target_slot = slot.get_parent().get_node(target_name)
			if target_slot == null:
				continue

			var target_card = placed_cards.get(target_slot, null)

			# Levitate / Aerilate / Cursed Body can modify targeting later

			var sig = animate_attack(card, target_slot)
			await sig

			if target_card and is_instance_valid(target_card):
				# Parental Bond, Poison Touch, Moxie, etc
				AbilitySystem.trigger(card, AbilitySystem.Trigger.ON_ATTACK, {"target": target_card})
				target_card.take_damage(card.attack, card)
			else:
				handle_attack_on_empty_slot(card, target_slot)


func perform_enemy_attacks():
	print("perform_enemy_attacks: start")

	for slot in placed_cards.keys():
		# debug
		print("Checking slot:", slot.name, "groups:", slot.get_groups())

		if not slot.is_in_group("row2"):
			continue

		var card = placed_cards[slot]
		if card == null or not is_instance_valid(card):
			print("Skipping: no valid card in slot", slot.name)
			continue

		# status/paralyzed check
		if card.status == "Paralyzed":
			print("Card is paralyzed, skipping attack:", card.name)
			card.status = "None"  # paralyzed lasts one turn
			continue

		# target lookup
		var target_name = attack_map_enemy.get(slot.name, null)
		if target_name == null:
			print("No target mapped for slot", slot.name)
			continue

		var target_slot = slot.get_parent().get_node_or_null(target_name)
		if target_slot == null:
			print("Target slot node not found:", target_name)
			continue

		var target_card = placed_cards.get(target_slot, null)
		
		if target_card == null or not is_instance_valid(target_card):
			print("Enemy attacking empty slot:", target_slot.name)

			# Animate anyway
			var sig = animate_attack(card, target_slot)
			await sig

			handle_attack_on_empty_slot(card, target_slot)
			continue


		# Cursed Body / targeting rules: if implemented, check here
		if card.ability == "Cursed Body" and target_card.ability == "None":
			print("Cursed Body rule: cannot be attacked by abilityless card; skipping")
			continue

		# Animate and attack
		print("Animating attack from", card.name, "to", target_card.name)
		var sig = animate_attack(card, target_slot)
		await sig

		# Re-check target after animation
		if target_card != null and is_instance_valid(target_card):
			# trigger OnAttack for attacker (abilities like Parental Bond, Poison Touch)
			AbilitySystem.trigger(card, AbilitySystem.Trigger.ON_ATTACK, {"target": target_card})
			target_card.take_damage(card.attack, card)
			# trigger any post-attack logic (moxie handled in AbilitySystem)
		else:
			print("Target died during animation:", target_name)
			handle_attack_on_empty_slot(card, target_slot)

	print("perform_enemy_attacks: end")

func remove_dead_card(card):
	for slot in placed_cards.keys():
		if placed_cards[slot] == card:
			placed_cards.erase(slot)
			return

func end_player_turn():
	for slot in placed_cards.keys():
		var card = placed_cards[slot]
		if card and is_instance_valid(card):
			card.on_turn_end()

func end_enemy_turn():
	for slot in placed_cards.keys():
		var card = placed_cards[slot]
		if card and is_instance_valid(card):
			card.on_turn_end()


func handle_attack_on_empty_slot(card, target_slot):
	print("Attack hit an empty slot:", target_slot.name)

	var amount: int = card.attack

	if card.is_in_group("player_card"):
		UIManager.update_scale(amount)

	elif card.is_in_group("enemy_card"):
		UIManager.update_scale(-amount)

func shift_card_down(top_slot: Node3D):
	var top_name = top_slot.name

	if not shift_map.has(top_name):
		print("No shift mapping for:", top_name)
		return

	var mid_slot_path = shift_map[top_name]
	var mid_slot = top_slot.get_parent().get_node(mid_slot_path)

	if placed_cards.has(mid_slot):
		print("Middle slot already filled:", mid_slot.name)
		return

	var card = placed_cards[top_slot]
	placed_cards.erase(top_slot)

	await animate_card_to_slot(card, mid_slot)
	placed_cards[mid_slot] = card
	print("Shifted card from", top_slot.name, "to", mid_slot.name)

func animate_attack(card: Node3D, target_slot: Node3D) -> Signal:
	var tween = create_tween()

	var start_pos = card.global_transform.origin
	var target_pos = target_slot.global_transform.origin

	tween.tween_property(
		card,
		"global_transform:origin",
		target_pos,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		card,
		"global_transform:origin",
		start_pos,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	return tween.finished

func place_random_card():
	var empty_slots = get_empty_slots()
	if empty_slots.is_empty():
		return

	var slot = empty_slots.pick_random()
	var card_data_path = CardDatabase.card_paths.pick_random()
	var card_data: CardData = load(card_data_path)

	var card = CardScene.instantiate()
	get_tree().current_scene.add_child(card)
	card.set_data(card_data)
	card.add_to_group("enemy_card")
	print("instantiated card root:", card)
	print("children:", card.get_children())

	$CardSFX.play()

	card.global_transform.origin = enemy_spawn.global_transform.origin
	card.global_transform.origin.y = slot.global_transform.origin.y + 0.02

	await animate_card_to_slot(card, slot)

	placed_cards[slot] = card
	
func interact_with_table(table):
	busy = true
	in_table_view = true
	original_pos = global_transform.origin

	var tabletop = table.get_node("Tabletop")
	card_slots = tabletop.get_node("card_layout").get_children()
	table_camera = table.get_node("table_camera")
	mouse_ray = table_camera.get_node("mouse_ray")
	player_spawn = tabletop.get_node("player_spawn")
	enemy_spawn = tabletop.get_node("enemy_spawn")
	hand_positions = tabletop.get_node("player_hand").get_children()
	player_hand = tabletop.get_node("player_hand")
	var right_shift = transform.basis.x * 0.5
	var target_pos = global_transform.origin + right_shift

	var tween = create_tween()
	tween.tween_property(
		self,
		"global_transform:origin",
		target_pos,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		player_camera.current = false
		table_camera.current = true
		busy = false
	)
	if not has_entered_table:
		for i in range(2):
			draw_card()
		has_entered_table = true

	
func exit_table_view():
	busy = true
	in_table_view = false

	if table_camera:
		table_camera.current = false
	player_camera.current = true

	var tween = create_tween()
	tween.tween_property(
		self,
		"global_transform:origin",
		original_pos,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		busy = false
	)

func smooth_turn(angle_deg: float) -> void:
	busy = true
	var target_rot = rotation
	target_rot.y += deg_to_rad(angle_deg)

	var tween = create_tween()
	tween.tween_property(self, "rotation", target_rot, TURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): busy = false)

func smooth_step(dir: Vector3) -> void:
	busy = true

	var motion = dir.normalized() * STEP_DISTANCE

	if test_move(global_transform, motion):
		busy = false
		return  

	var target_pos = global_transform.origin + motion

	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin", target_pos, STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): busy = false)

func update_hand_positions():
	if hand_cards.is_empty():
		return
	
	var count = hand_cards.size()
	var arc_angle = deg_to_rad(30) 
	var radius = 1.5 

	for i in range(count):
		var t = (i - ((count - 1) / 2.0)) / float(count - 1)
		if is_nan(t) or is_inf(t):
			t = 0

		var angle = t * arc_angle

		var x = radius * sin(angle)
		var y = radius * (1 - cos(angle)) * -1  

		var target_pos = player_hand.global_transform.origin + Vector3(x, y, 0)

		var rot_y = -angle
		var forward_tilt = deg_to_rad(20)

		var card = hand_cards[i]
		if card == current_hovered_card:
			continue
		card.scale = Vector3(0.5, 0.5, 0.5)

		var tween = create_tween()

		tween.tween_property(
			card,
			"global_transform:origin",
			target_pos,
			0.25
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		tween.tween_property(
			card,
			"rotation",
			Vector3(forward_tilt, rot_y, 0),
			0.25
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
func draw_card():
	if hand_cards.size() >= max_hand_size:
		print("Hand is full")
		return null

	var card_data_path = CardDatabase.card_paths.pick_random()
	var card_data: CardData = load(card_data_path)

	var card = CardScene.instantiate()
	get_tree().current_scene.add_child(card)
	card.set_data(card_data)
	card.add_to_group("player_card")
	print("instantiated card root:", card)
	print("children:", card.get_children())

	card.global_transform.origin = player_spawn.global_transform.origin

	hand_cards.append(card)
	update_hand_positions()

	return card

func flash_card_red(card):
	var mesh = card.mesh
	if mesh == null:
		return

	var mat = mesh.get_active_material(0)
	if mat == null:
		return

	var original_color = mat.albedo_color
	mat.albedo_color = Color(1, 0, 0)

	var tween = create_tween()
	tween.tween_property(mat, "albedo_color", original_color, 0.6)

func reset_board():
	# Remove all cards
	for slot in placed_cards.keys():
		var card = placed_cards[slot]
		if card and is_instance_valid(card):
			card.queue_free()
	placed_cards.clear()

	# Reset hand
	for card in hand_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	hand_cards.clear()

	update_hand_positions()

	# Reset enemy state
	enemy_state = "defend"

	# Draw starting cards again
	for i in range(2):
		draw_card()

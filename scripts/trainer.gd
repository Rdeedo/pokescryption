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
var CardScene := preload("res://scenes/base_card.tscn")
var card_slots: Array
var placed_cards := {}
var player_spawn: Node3D
var enemy_spawn: Node3D
var enemy_state: String = "defend"

func _ready():
	player_camera = $camera_mount/Camera3D
	interact_ray = $interact_ray

func set_enemy_state(new_state: String):
	enemy_state = new_state
	print("Enemy state changed to:", enemy_state)

func _physics_process(delta: float) -> void:
	# Gravity + jumping
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

	# Turning
	if Input.is_action_just_pressed("look_left"):
		smooth_turn(TURN_ANGLE)

	if Input.is_action_just_pressed("look_right"):
		smooth_turn(-TURN_ANGLE)

	# Stepping
	if Input.is_action_just_pressed("forward"):
		smooth_step(-transform.basis.z)

	if Input.is_action_just_pressed("backward"):
		smooth_step(transform.basis.z)
	
	move_and_slide()

func get_empty_slots() -> Array:
	var empty := []
	for slot in card_slots:
		if slot.is_in_group("no_random"):
			continue
		if not placed_cards.has(slot):
			empty.append(slot)
	return empty

func try_interact():
	var hit = interact_ray.get_collider()
	print("Ray hit:", hit)

	if hit == null:
		return

	# Case 1: the hit node itself is the table
	if hit.is_in_group("table"):
		print("Table root hit")
		interact_with_table(hit)
		return

	# Case 2: the hit node is a child of the table
	var parent = hit.get_parent()
	if parent and parent.is_in_group("table"):
		print("Table parent hit")
		interact_with_table(parent)
		return

	print("Hit something, but it's not a table")

func handle_table_mouse_input():
	if Input.is_action_just_pressed("click"):
		var mouse_pos = get_viewport().get_mouse_position()

		var from = table_camera.project_ray_origin(mouse_pos)
		var to = from + table_camera.project_ray_normal(mouse_pos) * 20.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			var hit = result.collider

			# Card slot click
			if hit.is_in_group("card_slot"):
				on_card_slot_clicked(hit)
				return

			# Button click (still works if you want it for something else)
			if hit.is_in_group("button"):
				on_table_button_pressed(hit)
				return

func on_card_slot_clicked(slot):
	if placed_cards.has(slot):
		return

	var card = CardScene.instantiate()
	get_tree().current_scene.add_child(card)  # spawn globally

	# Start at player spawn
	card.global_transform.origin = player_spawn.global_transform.origin

	# Animate into place
	animate_card_to_slot(card, slot)

	# Track it
	placed_cards[slot] = card
	
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

func on_table_button_pressed(button):
	# Enemy always attempts an attack
	set_enemy_state("attack")

	# 50% chance to place a card
	if randf() < 0.5:
		await place_random_card()
	else:
		print("Enemy attempted attack but failed the 50% chance")

	# After the attempt (success or fail), return to defend
	set_enemy_state("defend")

func place_random_card() -> void:
	var empty_slots = get_empty_slots()
	if empty_slots.is_empty():
		print("No empty slots available")
		return

	var slot = empty_slots[randi() % empty_slots.size()]

	var card = CardScene.instantiate()
	get_tree().current_scene.add_child(card)

	card.global_transform.origin = enemy_spawn.global_transform.origin

	# Animate card into place
	await animate_card_to_slot(card, slot)

	placed_cards[slot] = card
	
func interact_with_table(table):
	busy = true
	in_table_view = true
	# Save original position
	original_pos = global_transform.origin

	print("Interacting with table")
	# Get the table's camera
	var tabletop = table.get_node("Tabletop")
	card_slots = tabletop.get_node("card_layout").get_children()
	table_camera = table.get_node("table_camera")
	mouse_ray = table_camera.get_node("mouse_ray")
	player_spawn = tabletop.get_node("player_spawn")
	enemy_spawn = tabletop.get_node("enemy_spawn")
	# Step 1: shift player slightly to the right
	var right_shift = transform.basis.x * 0.5
	var target_pos = global_transform.origin + right_shift

	var tween = create_tween()
	tween.tween_property(
		self,
		"global_transform:origin",
		target_pos,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Step 2: switch camera after movement
	tween.finished.connect(func():
		print("player_camera:", player_camera)
		print("table_camera:", table_camera)
		player_camera.current = false
		table_camera.current = true
		busy = false
	)
	
func exit_table_view():
	busy = true
	in_table_view = false

	# Swap cameras immediately
	if table_camera:
		table_camera.current = false
	player_camera.current = true

	# Now tween the player back to their original position
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

	# --- CORRECT PHYSICS CHECK ---
	# test_move() == true means BLOCKED
	if test_move(global_transform, motion):
		busy = false
		return  # can't move

	# Movement is safe → tween to the new position
	var target_pos = global_transform.origin + motion

	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin", target_pos, STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): busy = false)

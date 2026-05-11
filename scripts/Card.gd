extends Node3D
class_name Card

@onready var mesh: MeshInstance3D = $MeshInstance3D
var data: CardData
var is_hovered = false
var base_color: Color = Color(0.0, 1.0, 1.0)
var hover_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var is_selected := false

var max_health := 1
var current_health := 1
var attack := 1
var cost := 1
var ability: String = "None"

var status: String = "None" # "Burn", "Poison", "Paralyzed"
var turns_alive := 0
var armor_used := false
var underground := false
var moxie_kills := 0

@onready var health_label: Label = $CardUI/UI/HealthLabel
@onready var attack_label: Label = $CardUI/UI/AttackLabel
@onready var name_label: Label = $CardUI/UI/NameLabel
@onready var cost_label: Label = $CardUI/UI/CostLabel
@onready var ability_label: RichTextLabel = $CardUI/UI/AbilityLabel

func _ready():
	var mat = $MeshInstance3D.get_active_material(0)
	if mat:
		mesh.set_surface_override_material(0, mat.duplicate())

	$CardUI.render_target_update_mode = SubViewport.UPDATE_ALWAYS

var card_data

func set_data(data):
	card_data = data
	max_health = data.health
	current_health = data.health
	attack = data.attack
	cost = data.cost
	ability = data.ability
	update_visuals()

	await get_tree().process_frame
	await get_tree().process_frame

	_update_material()

func update_visuals():
	if is_instance_valid(health_label):
		health_label.text = str(current_health)

	if is_instance_valid(attack_label):
		attack_label.text = str(attack)

	if is_instance_valid(name_label) and card_data:
		name_label.text = card_data.card_name

	if is_instance_valid(cost_label):
		cost_label.text = str(cost)

	if is_instance_valid(ability_label):
		ability_label.text = ability

func _update_material():
	var tex = $CardUI.get_texture()
	if tex == null:
		return

	var mat = mesh.get_surface_override_material(0)
	mat.albedo_texture = tex

	update_status_color()


func _apply_card_hover():
	var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.4, 0.4)  # soft white glow
	mat.emission_energy = 1.5

func _reset_card_hover():
	var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
	if mat == null:
		return
	mat.emission_enabled = false

func _on_area_3d_mouse_entered():
	_apply_card_hover()

func _on_area_3d_mouse_exited():
	_reset_card_hover()

func select_card():
	is_selected = true
	_show_selected_visual()

func deselect_card():
	is_selected = false
	_hide_selected_visual()

func _show_selected_visual():
	var mat := mesh.get_surface_override_material(0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy = 2.0

func _hide_selected_visual():
	var mat := mesh.get_surface_override_material(0)
	mat.emission_enabled = false

func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		HandManager.click_consumed_by_card = true
		HandManager.select_card(self)

func apply_status(s: String):
	status = s
	update_status_color()


func take_damage(amount: int, attacker: Card = null):
	# Queenly Majesty cap
	AbilitySystem.trigger(self, AbilitySystem.Trigger.ON_DAMAGED, {"attacker": attacker, "damage": amount})
	# Shell Armor etc may modify or cancel damage via fields
	if ability == "Queenly Majesty":
		amount = min(amount, 1)

	if ability == "Shell Armor" and not armor_used:
		armor_used = true
		return

	if underground:
		return

	current_health -= amount
	update_visuals()
	flash_damage()
	
	if attacker:
		AbilitySystem.trigger(self, AbilitySystem.Trigger.ON_DAMAGED, {"attacker": attacker})

	if current_health <= 0:
		die(attacker)

func die(killer: Card = null):
	AbilitySystem.trigger(self, AbilitySystem.Trigger.ON_DEATH, {"killer": killer})

	var trainer = get_tree().get_first_node_in_group("trainer")
	if trainer:
		trainer.remove_dead_card(self)

	queue_free()

func on_turn_end():
	if status == "Burn" or status == "Poison":
		print("Applying burn/poison damage")
		take_damage(1)

	if status == "Paralyzed":
		print("Clearing paralysis")
		status = "None"

	update_status_color()
	turns_alive += 1
	AbilitySystem.trigger(self, AbilitySystem.Trigger.ON_TURN_END, {})


	
func flash_damage():
	var mat = mesh.get_active_material(0)
	var original = mat.albedo_color

	mat.albedo_color = Color(1, 0.2, 0.2)

	var tween = create_tween()
	tween.tween_property(mat, "albedo_color", original, 0.3)

func update_status_color():
	var mat := mesh.get_surface_override_material(0)
	if mat == null:
		return

	match status:
		"Burn":
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.2, 0.2)
			mat.emission_energy = 1.4
		"Poison":
			mat.emission_enabled = true
			mat.emission = Color(0.6, 0.2, 0.8)
			mat.emission_energy = 1.4
		"Paralyzed":
			mat.emission_enabled = true
			mat.emission = Color(1.0, 1.0, 0.2)
			mat.emission_energy = 1.4
		_:
			mat.emission_enabled = false

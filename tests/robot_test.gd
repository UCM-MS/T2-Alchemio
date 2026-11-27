extends SceneTree

const Abilities = preload("res://scripts/robot_abilities.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	var arena = game.collection_map
	arena.set_physics_process(false)
	arena.ball_spawn_in = 100.0
	await process_frame

	var names := {}
	for substance in game.research.catalog.substances:
		if substance.atoms.size() < 2 or not substance.get("assembly", true):
			check(not Abilities.MODULES.has(substance.id), "Single atoms and mixtures have no module")
			continue
		var ability: Dictionary = Abilities.MODULES.get(substance.id, {})
		check(not ability.is_empty() and not names.has(ability.get("name")), "Each molecule has a distinct module")
		names[ability.get("name")] = true

	game.inventory.credit({"hydrogen": 1, "oxygen": 1, "water": 1, "H": 1})
	game._show_robot()
	var dialog = game.robot_dialog
	var drag := {"type": "laboratory_portion", "id": "H", "inventory": game.inventory}
	check(arena.controls_blocked and not dialog._can_drop_module(Vector2.ZERO, drag), "Robot dialog pauses collection and rejects an atom")
	drag.id = "hydrogen"
	check(dialog._can_drop_module(Vector2.ZERO, drag), "Molecule can be dropped into robot slot")
	dialog._drop_module(Vector2.ZERO, drag)
	check(game.inventory.robot_module == "hydrogen" and game.inventory.stock.hydrogen == 0, "Slot reserves one molecule")
	var save: Dictionary = game.save_service.snapshot(game.inventory, game.research)
	var restored: Dictionary = game.save_service.validate(save)
	check(restored.get("robot_module") == "hydrogen" and restored.inventory.hydrogen == 0, "Save restores the module without duplicating stock")
	dialog.hide()
	check(not arena.controls_blocked, "Closing Robot returns player controls")

	arena.collector.aim_at(arena.collector.position + Vector2.RIGHT * 100.0)
	var atom = arena.free_atoms[0]
	atom.position = arena.collector.position + Vector2.RIGHT * 220.0
	atom.velocity = Vector2.ZERO
	for id in [1, 2]:
		arena.free_atoms[id].position = arena.collector.position + Vector2(-270.0, 185.0)
	var before: Vector2 = atom.position
	check(arena.activate_ability() and arena.ability_cooldown == 5.0, "Hook starts a five-second cooldown")
	check(not arena.activate_ability(), "Cannot cast twice during cooldown")
	arena._advance_hook(0.25)
	check(0 in arena.hook_targets, "Traveling hook hits an atom along its path")
	arena._advance_free_atoms(0.07)
	check(atom.position.x < before.x, "Hook pulls the hit atom toward the robot")
	arena.hook_targets.clear()

	arena._advance_free_atoms(0.01)
	check(arena.free_atoms[1].position.distance_to(arena.free_atoms[2].position) < atom.RADIUS, "Free particles pass through each other")
	arena.collect_atom(1)
	arena.collect_atom(2)
	var first = arena.collector.bag.atoms[0]
	var second = arena.collector.bag.atoms[1]
	first.position = Vector2.ZERO
	second.position = Vector2.ZERO
	arena._advance_bag(0.01)
	check(first.position.distance_to(second.position) < arena.collector.bag.ATOM_RADIUS, "Bag particles pass through each other")

	check(game.inventory.equip_robot_module("oxygen") and game.inventory.stock.hydrogen == 1, "Swapping modules returns the earlier molecule")
	game._robot_module_changed()
	check(not arena.activate_ability(), "Swapping modules keeps the current cooldown")
	arena.ability_cooldown = 0.0
	atom.position = arena.collector.position + Vector2.RIGHT * 120.0
	atom.velocity = Vector2(65.0, 18.0)
	arena._spawn_ball()
	var ball = arena.balls[0]
	ball.position = arena.collector.position + Vector2.LEFT * 160.0
	ball.velocity = Vector2(150.0, 25.0)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	arena._unhandled_key_input(key)
	check(atom.velocity.is_equal_approx(Vector2(-65.0, -18.0)) and ball.velocity.is_equal_approx(Vector2(-150.0, -25.0)), "Space activates the pulse and reverses nearby atoms and black balls")
	game._process(0.0)
	check(game.ability_label.text.contains("5.0 s"), "Map displays the cooldown")

	arena.robot_module = "methane"
	arena.ability_cooldown = 0.0
	var origin: Vector2 = arena.collector.position
	check(arena.activate_ability(), "Speed module activates")
	Input.action_press("move_right")
	arena._physics_process(0.1)
	Input.action_release("move_right")
	check(is_equal_approx(arena.collector.position.x - origin.x, arena.collector.SPEED * 0.2), "Speed module doubles steering speed")
	check(is_equal_approx(arena.ability_cooldown, 4.9), "Cooldown ticks down while collecting")

	arena.robot_module = "water"
	arena.ability_cooldown = 0.0
	origin = arena.collector.position
	arena.collector.aim_at(origin + Vector2.RIGHT * 100.0)
	check(arena.activate_ability() and is_equal_approx(arena.collector.position.x - origin.x, 205.0), "Blink displaces the robot immediately")
	check(game.inventory.unequip_robot_module() and game.inventory.stock.oxygen == 1, "Removing the module returns it to stock")

	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ROBOT PASS: modules, drag/drop, save, Space, hook, pulse, boost, blink, cooldown, pass-through")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

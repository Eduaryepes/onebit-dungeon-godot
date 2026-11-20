extends SceneTree

## Headless automated test suite for OneBit Dungeon.
## Run with: godot --headless --script res://tests/run_tests.gd

var _failures: Array[String] = []


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


var _ran: bool = false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("=== OneBit Dungeon Headless Tests ===")
	_test_initial_state()
	_test_movement_and_walls()
	_test_combat_and_enemy_ai()
	_test_pickups_and_potion()
	_test_key_and_win_condition()
	_test_sprites_and_scene_load()

	if _failures.is_empty():
		print("ALL TESTS PASSED!")
		quit(0)
	else:
		print("TESTS FAILED (%d):" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)
	return true


func _test_initial_state() -> void:
	var logic := DungeonLogic.new()
	_assert(logic.width == 13 and logic.height == 19, "Map dimensions should be 13x19")
	_assert(logic.player_hp == 12 and logic.player_atk == 2, "Initial player stats mismatch")
	_assert(logic.enemies.size() >= 4, "Expected at least 4 enemies on level 1")
	_assert(logic.items.size() >= 5, "Expected items on level 1")
	_assert(logic.state == DungeonLogic.State.PLAYING, "Initial state should be PLAYING")
	_assert(not logic.has_key, "Player should start without key")


func _test_movement_and_walls() -> void:
	var logic := DungeonLogic.new()
	var start: Vector2i = logic.player_pos
	# Move left into open tile
	_assert(logic.step_move(Vector2i.LEFT), "Should move left from start")
	_assert(logic.player_pos == start + Vector2i.LEFT, "Player pos should update")
	_assert(logic.turns == 1, "Turn counter should increment")

	# Move up into wall or test explicit wall collision
	logic.player_pos = Vector2i(1, 1)
	var prev_turns: int = logic.turns
	_assert(not logic.step_move(Vector2i.UP), "Should not move into top wall")
	_assert(logic.turns == prev_turns, "Failed wall bump should not consume turn")


func _test_combat_and_enemy_ai() -> void:
	var logic := DungeonLogic.new()
	logic.enemies.clear()
	logic.player_pos = Vector2i(6, 16)
	logic.enemies.append({
		"id": 99,
		"kind": "slime",
		"pos": Vector2i(7, 16),
		"hp": 4,
		"max_hp": 4,
		"atk": 1,
	})
	# Hit 1: slime takes 2 dmg (hp 2), then retaliates (player hp 11)
	_assert(logic.step_move(Vector2i.RIGHT), "Bump attack should succeed")
	_assert(logic.enemies.size() == 1 and logic.enemies[0]["hp"] == 2, "Slime should have 2 HP left")
	_assert(logic.player_hp == 11, "Slime should retaliate for 1 HP")

	# Hit 2: slime dies, player gets +3 coins
	_assert(logic.step_move(Vector2i.RIGHT), "Second bump attack should kill slime")
	_assert(logic.enemies.is_empty(), "Slime should be removed after death")
	_assert(logic.coins == 3, "Killing slime should award 3 coins")


func _test_pickups_and_potion() -> void:
	var logic := DungeonLogic.new()
	logic.enemies.clear()
	logic.items.clear()
	logic.player_pos = Vector2i(6, 16)
	logic.items.append({"kind": "sword", "pos": Vector2i(7, 16)})
	_assert(logic.step_move(Vector2i.RIGHT), "Should step onto sword")
	_assert(logic.player_atk == 3, "Sword should increase ATK to 3")

	# Test potion healing
	logic.player_hp = 5
	logic.potions = 1
	_assert(logic.use_potion(), "Should use potion when injured")
	_assert(logic.player_hp == 10, "Potion should heal +5 HP")
	_assert(logic.potions == 0, "Potion count should decrease")
	_assert(not logic.use_potion(), "Should fail when out of potions")


func _test_key_and_win_condition() -> void:
	var logic := DungeonLogic.new()
	logic.enemies.clear()
	# Stepping on exit without key should NOT win
	logic.player_pos = logic.exit_pos + Vector2i.DOWN
	_assert(logic.step_move(Vector2i.UP), "Should step onto locked exit")
	_assert(logic.state == DungeonLogic.State.PLAYING, "Cannot win without key")

	# Pick up key, then step on exit -> WON
	logic.items.clear()
	logic.player_pos = logic.exit_pos + Vector2i(0, 2)
	logic.items.append({"kind": "key", "pos": logic.exit_pos + Vector2i.DOWN})
	_assert(logic.step_move(Vector2i.UP), "Should pick up key")
	_assert(logic.has_key, "Player should now have key")
	_assert(logic.tiles[logic.exit_pos.y][logic.exit_pos.x] == DungeonLogic.Tile.EXIT_OPEN, "Exit tile should unlock")
	_assert(logic.step_move(Vector2i.UP), "Should step onto open exit")
	_assert(logic.state == DungeonLogic.State.WON, "Player should win upon reaching unlocked exit")


func _test_sprites_and_scene_load() -> void:
	var sprites: Dictionary = PixelSprites.build_all()
	_assert(sprites.has("hero") and sprites.has("wall") and sprites.has("exit_open"), "Sprites dictionary incomplete")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_assert(packed != null, "scenes/main.tscn should load cleanly")
	var instance := packed.instantiate()
	_assert(instance != null, "scenes/main.tscn should instantiate cleanly")
	get_root().add_child(instance)
	_assert(instance.logic != null, "Main scene should initialize DungeonLogic in _ready()")
	_assert(instance.board != null and instance.board.logic == instance.logic, "DungeonBoard should bind to logic")
	get_root().remove_child(instance)
	instance.free()

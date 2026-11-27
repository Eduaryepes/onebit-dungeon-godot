extends SceneTree

## Headless automated test suite for OneBit Dungeon.
## Run with: godot --headless --script res://tests/run_tests.gd

var _failures: Array[String] = []
var _ran: bool = false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("=== OneBit Dungeon Headless Tests ===")
	_test_initial_state()
	_test_all_levels_reachable()
	_test_movement_and_walls()
	_test_combat_and_combo()
	_test_weapons_mechanics()
	_test_pickups_and_potion()
	_test_multi_level_progression_and_win()
	_test_sprites_audio_and_scene_load()

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
	_assert(logic.total_levels() == 5, "Should have 5 handcrafted levels")
	_assert(logic.width == 13 and logic.height == 19, "Map dimensions should be 13x19")
	_assert(logic.player_hp == 12 and logic.player_atk == 2, "Initial player stats mismatch")
	_assert(logic.equipped_weapon == "sword", "Player should start with sword")
	_assert(logic.enemies.size() >= 4, "Expected at least 4 enemies on level 1")
	_assert(logic.items.size() >= 5, "Expected items on level 1")
	_assert(logic.state == DungeonLogic.State.PLAYING, "Initial state should be PLAYING")
	_assert(not logic.has_key, "Player should start without key")


func _test_all_levels_reachable() -> void:
	var logic := DungeonLogic.new()
	for lvl in range(logic.total_levels()):
		logic.reset(lvl)
		_assert(logic.width == 13 and logic.height == 19, "Level %d should be 13x19" % (lvl + 1))
		var key_pos := Vector2i(-1, -1)
		for item in logic.items:
			if item["kind"] == "key":
				key_pos = item["pos"]
				break
		_assert(key_pos != Vector2i(-1, -1), "Level %d must contain a key" % (lvl + 1))
		var visited: Dictionary = _bfs_walkable(logic, logic.player_pos)
		_assert(visited.has(key_pos), "Level %d key must be reachable from player start" % (lvl + 1))
		_assert(visited.has(logic.exit_pos), "Level %d exit must be reachable from player start" % (lvl + 1))


func _bfs_walkable(logic: DungeonLogic, start: Vector2i) -> Dictionary:
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var nxt: Vector2i = cur + d
			if not visited.has(nxt) and not logic.is_wall(nxt):
				visited[nxt] = true
				queue.append(nxt)
	return visited


func _test_movement_and_walls() -> void:
	var logic := DungeonLogic.new()
	var start: Vector2i = logic.player_pos
	_assert(logic.step_move(Vector2i.LEFT), "Should move left from start")
	_assert(logic.player_pos == start + Vector2i.LEFT, "Player pos should update")
	_assert(logic.turns == 1, "Turn counter should increment")

	logic.player_pos = Vector2i(1, 1)
	var prev_turns: int = logic.turns
	_assert(not logic.step_move(Vector2i.UP), "Should not move into top wall")
	_assert(logic.turns == prev_turns, "Failed wall bump should not consume turn")
	_assert(logic.turn_events.size() == 1 and logic.turn_events[0]["type"] == "wall_bump", "Wall bump should emit wall_bump event")


func _test_combat_and_combo() -> void:
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
		"reward": 3,
	})
	_assert(logic.step_move(Vector2i.RIGHT), "Bump attack should succeed")
	_assert(logic.enemies.size() == 1 and logic.enemies[0]["hp"] == 2, "Slime should have 2 HP left")
	_assert(logic.player_hp == 11, "Slime should retaliate for 1 HP")

	_assert(logic.step_move(Vector2i.RIGHT), "Second bump attack should kill slime")
	_assert(logic.enemies.is_empty(), "Slime should be removed after death")
	_assert(logic.coins == 3, "Killing first slime should award 3 coins")
	_assert(logic.combo == 1, "Combo should be 1 after first kill")

	# Second kill quickly -> combo x2 (+1 bonus gold)
	logic.enemies.append({
		"id": 100,
		"kind": "slime",
		"pos": Vector2i(7, 16),
		"hp": 2,
		"max_hp": 4,
		"atk": 1,
		"reward": 3,
	})
	_assert(logic.step_move(Vector2i.RIGHT), "Should kill second slime")
	_assert(logic.combo == 2, "Combo should reach 2")
	_assert(logic.coins == 7, "Combo x2 kill should award 3 + 1 = 4 bonus coins (total 7)")


func _test_weapons_mechanics() -> void:
	var logic := DungeonLogic.new()
	logic.enemies.clear()
	logic.items.clear()

	# 1. Spear: range 2 + pierce hits two enemies in a line
	logic.player_pos = Vector2i(4, 17)
	logic.items.append({"kind": "spear", "pos": Vector2i(5, 17)})
	_assert(logic.step_move(Vector2i.RIGHT), "Should pick up spear")
	_assert(logic.equipped_weapon == "spear" and logic.player_atk == 3, "Spear should equip with ATK 3")

	logic.enemies.append({"id": 1, "kind": "slime", "pos": Vector2i(6, 17), "hp": 4, "max_hp": 4, "atk": 1, "reward": 3})
	logic.enemies.append({"id": 2, "kind": "slime", "pos": Vector2i(7, 17), "hp": 4, "max_hp": 4, "atk": 1, "reward": 3})
	_assert(logic.step_move(Vector2i.RIGHT), "Spear should thrust and hit both enemies")
	_assert(logic.enemies[0]["hp"] == 1 and logic.enemies[1]["hp"] == 1, "Spear pierce should deal 3 dmg to both enemies")

	# 2. Axe: cleave hits front + flanking enemy
	logic.enemies.clear()
	logic.player_pos = Vector2i(5, 4)
	logic.items.append({"kind": "axe", "pos": Vector2i(6, 4)})
	_assert(logic.step_move(Vector2i.RIGHT), "Should pick up axe")
	_assert(logic.equipped_weapon == "axe" and logic.player_atk == 4, "Axe should equip with ATK 4")
	logic.enemies.append({"id": 3, "kind": "skeleton", "pos": Vector2i(7, 4), "hp": 7, "max_hp": 7, "atk": 2, "reward": 8})
	logic.enemies.append({"id": 4, "kind": "skeleton", "pos": Vector2i(7, 3), "hp": 7, "max_hp": 7, "atk": 2, "reward": 8})
	_assert(logic.step_move(Vector2i.RIGHT), "Axe should cleave front and flanking enemy")
	_assert(logic.enemies[0]["hp"] == 3 and logic.enemies[1]["hp"] == 3, "Axe cleave should deal 4 dmg to both enemies")

	# 3. Staff: ranged bolt hits enemy 3 tiles away
	logic.enemies.clear()
	logic.player_pos = Vector2i(3, 1)
	logic.items.append({"kind": "staff", "pos": Vector2i(4, 1)})
	_assert(logic.step_move(Vector2i.RIGHT), "Should pick up staff")
	_assert(logic.equipped_weapon == "staff" and logic.player_atk == 3, "Staff should equip with ATK 3")
	logic.enemies.append({"id": 5, "kind": "slime", "pos": Vector2i(7, 1), "hp": 4, "max_hp": 4, "atk": 1, "reward": 3})
	_assert(logic.step_move(Vector2i.RIGHT), "Staff should hit enemy 3 tiles away")
	_assert(logic.enemies.is_empty() or logic.enemies[0]["hp"] <= 1, "Staff bolt should damage distant enemy")

	# 4. Weapon cycling (0 turns)
	var turns_before: int = logic.turns
	var prev_w: String = logic.equipped_weapon
	_assert(logic.cycle_weapon(), "Should cycle between unlocked weapons")
	_assert(logic.equipped_weapon != prev_w, "Equipped weapon should change")
	_assert(logic.turns == turns_before, "Cycling weapon should cost 0 turns")


func _test_pickups_and_potion() -> void:
	var logic := DungeonLogic.new()
	logic.enemies.clear()
	logic.items.clear()
	logic.player_pos = Vector2i(6, 16)
	logic.items.append({"kind": "sword", "pos": Vector2i(7, 16)})
	_assert(logic.step_move(Vector2i.RIGHT), "Should step onto sword upgrade")
	_assert(logic.player_atk == 3, "Duplicate sword should upgrade ATK to 3")

	logic.player_hp = 5
	logic.potions = 1
	_assert(logic.use_potion(), "Should use potion when injured")
	_assert(logic.player_hp == 11, "Potion should heal +6 HP")
	_assert(logic.potions == 0, "Potion count should decrease")
	_assert(not logic.use_potion(), "Should fail when out of potions")


func _test_multi_level_progression_and_win() -> void:
	var logic := DungeonLogic.new()
	logic.enemies.clear()
	# Stepping on exit without key should NOT clear level
	logic.player_pos = logic.exit_pos + Vector2i.DOWN
	_assert(logic.step_move(Vector2i.UP), "Should step onto locked exit")
	_assert(logic.state == DungeonLogic.State.PLAYING, "Cannot clear level without key")

	# Pick up key, step on exit -> LEVEL_CLEAR on level 1
	logic.items.clear()
	logic.player_pos = logic.exit_pos + Vector2i(0, 2)
	logic.items.append({"kind": "key", "pos": logic.exit_pos + Vector2i.DOWN})
	_assert(logic.step_move(Vector2i.UP), "Should pick up key")
	_assert(logic.has_key, "Player should now have key")
	_assert(logic.tiles[logic.exit_pos.y][logic.exit_pos.x] == DungeonLogic.Tile.EXIT_OPEN, "Exit tile should unlock")
	_assert(logic.step_move(Vector2i.UP), "Should step onto open exit")
	_assert(logic.state == DungeonLogic.State.LEVEL_CLEAR, "Level 1 should enter LEVEL_CLEAR")

	# Advance to Level 2
	var prev_max_hp: int = logic.player_max_hp
	_assert(logic.next_level(), "Should advance to level 2")
	_assert(logic.current_level == 1, "Current level index should be 1 (Level 2)")
	_assert(logic.player_max_hp == prev_max_hp + 2, "Advancing floor should grant +2 max HP")
	_assert(not logic.has_key, "Key should reset on new level")

	# Final level (Level 5) exit with key -> WON
	logic.reset(logic.total_levels() - 1)
	logic.enemies.clear()
	logic.items.clear()
	logic.player_pos = logic.exit_pos + Vector2i(0, 2)
	logic.items.append({"kind": "key", "pos": logic.exit_pos + Vector2i.DOWN})
	logic.step_move(Vector2i.UP)
	logic.step_move(Vector2i.UP)
	_assert(logic.state == DungeonLogic.State.WON, "Clearing final level should set state to WON")


func _test_sprites_audio_and_scene_load() -> void:
	var sprites: Dictionary = PixelSprites.build_all()
	var required_sprites: Array[String] = [
		"hero", "wall", "floor", "slime", "skeleton", "bat", "knight", "boss",
		"coin", "potion", "sword", "dagger", "spear", "axe", "staff",
		"key", "exit_locked", "exit_open",
	]
	for key in required_sprites:
		_assert(sprites.has(key), "Missing sprite: " + key)

	# Validate all sprite patterns are strictly 16x16
	for key in PixelSprites.PATTERNS.keys():
		var rows: Array = PixelSprites.PATTERNS[key]
		_assert(rows.size() == 16, "Sprite '%s' must have 16 rows" % key)
		for r in rows:
			_assert(r.length() == 16, "Sprite '%s' row must have 16 chars" % key)

	var packed: PackedScene = load("res://scenes/main.tscn")
	_assert(packed != null, "scenes/main.tscn should load cleanly")
	var instance := packed.instantiate()
	_assert(instance != null, "scenes/main.tscn should instantiate cleanly")
	get_root().add_child(instance)
	_assert(instance.logic != null, "Main scene should initialize DungeonLogic in _ready()")
	_assert(instance.sfx != null, "Main scene should initialize SfxManager in _ready()")
	_assert(instance.board != null and instance.board.logic == instance.logic, "DungeonBoard should bind to logic")

	# Exercise audio playback & mute toggle headlessly
	instance.sfx.play("attack_axe")
	instance.sfx.play("level_clear")
	_assert(instance.sfx.toggle_mute() == true, "Mute toggle should return true")
	_assert(instance.sfx.toggle_mute() == false, "Second mute toggle should return false")

	# Exercise a turn & VFX consumption
	instance._on_move(Vector2i.LEFT)
	instance.board._process(0.016)

	get_root().remove_child(instance)
	instance.free()

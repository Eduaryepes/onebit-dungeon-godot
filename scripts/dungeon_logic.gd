class_name DungeonLogic
extends RefCounted

## Pure turn-based roguelike state & rules for OneBit Dungeon (1 level).
## Decoupled from Godot UI/rendering so it can be unit-tested headlessly.

enum Tile {
	FLOOR,
	WALL,
	EXIT_LOCKED,
	EXIT_OPEN,
}

enum State {
	PLAYING,
	WON,
	LOST,
}

const LEVEL_MAP: Array[String] = [
	"#############",
	"#.....E.....#",
	"#.###...###.#",
	"#.#c..S..c#.#",
	"#.#.......#.#",
	"#.###.#.###.#",
	"#...#.#.#...#",
	"#p.s..#..s.K#",
	"#...#.#.#...#",
	"###.#...#.###",
	"#c..#...#..W#",
	"#.#...s...#.#",
	"#.#.#####.#.#",
	"#...#...#...#",
	"#.s.#.c.#.p.#",
	"#...#...#...#",
	"###...P...###",
	"#....c.c....#",
	"#############",
]

var width: int = 0
var height: int = 0
var tiles: Array = [] # 2D Array[Array[int]] indexed as tiles[y][x]

var player_pos: Vector2i = Vector2i.ZERO
var player_hp: int = 12
var player_max_hp: int = 12
var player_atk: int = 2
var coins: int = 0
var potions: int = 1
var has_key: bool = false
var turns: int = 0
var state: int = State.PLAYING

# Each enemy: { "id": int, "kind": "slime"|"skeleton", "pos": Vector2i, "hp": int, "max_hp": int, "atk": int }
var enemies: Array[Dictionary] = []
# Each item: { "kind": "coin"|"potion"|"key"|"sword", "pos": Vector2i }
var items: Array[Dictionary] = []

var exit_pos: Vector2i = Vector2i.ZERO
var last_message: String = "¡Encuentra la llave y escapa!"

# Events emitted during the latest turn for animations / floating text.
# Examples:
# { "type": "damage", "pos": Vector2i, "amount": int, "target": "player"|"enemy" }
# { "type": "pickup", "pos": Vector2i, "text": String, "color": Color }
# { "type": "heal", "pos": Vector2i, "amount": int }
# { "type": "enemy_died", "pos": Vector2i, "kind": String }
var turn_events: Array[Dictionary] = []

var _next_enemy_id: int = 1


func _init() -> void:
	reset()


func reset() -> void:
	height = LEVEL_MAP.size()
	width = LEVEL_MAP[0].length()
	tiles.clear()
	enemies.clear()
	items.clear()
	turn_events.clear()
	_next_enemy_id = 1

	player_hp = 12
	player_max_hp = 12
	player_atk = 2
	coins = 0
	potions = 1
	has_key = false
	turns = 0
	state = State.PLAYING
	last_message = "Encuentra la Llave (K) y sube las escaleras."

	for y in range(height):
		var row: Array[int] = []
		var line: String = LEVEL_MAP[y]
		for x in range(width):
			var ch: String = line[x]
			var pos := Vector2i(x, y)
			match ch:
				"#":
					row.append(Tile.WALL)
				"E":
					row.append(Tile.EXIT_LOCKED)
					exit_pos = pos
				"P":
					row.append(Tile.FLOOR)
					player_pos = pos
				"s":
					row.append(Tile.FLOOR)
					enemies.append({
						"id": _next_enemy_id,
						"kind": "slime",
						"pos": pos,
						"hp": 4,
						"max_hp": 4,
						"atk": 1,
					})
					_next_enemy_id += 1
				"S":
					row.append(Tile.FLOOR)
					enemies.append({
						"id": _next_enemy_id,
						"kind": "skeleton",
						"pos": pos,
						"hp": 7,
						"max_hp": 7,
						"atk": 2,
					})
					_next_enemy_id += 1
				"c":
					row.append(Tile.FLOOR)
					items.append({"kind": "coin", "pos": pos})
				"p":
					row.append(Tile.FLOOR)
					items.append({"kind": "potion", "pos": pos})
				"K":
					row.append(Tile.FLOOR)
					items.append({"kind": "key", "pos": pos})
				"W":
					row.append(Tile.FLOOR)
					items.append({"kind": "sword", "pos": pos})
				_:
					row.append(Tile.FLOOR)
		tiles.append(row)


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func is_wall(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return true
	return tiles[pos.y][pos.x] == Tile.WALL


func get_enemy_at(pos: Vector2i) -> int:
	for i in range(enemies.size()):
		if enemies[i]["pos"] == pos:
			return i
	return -1


func get_item_at(pos: Vector2i) -> int:
	for i in range(items.size()):
		if items[i]["pos"] == pos:
			return i
	return -1


func step_move(dir: Vector2i) -> bool:
	turn_events.clear()
	if state != State.PLAYING:
		return false
	if dir == Vector2i.ZERO:
		return step_wait()

	var target: Vector2i = player_pos + dir
	if is_wall(target):
		last_message = "Hay un muro."
		return false

	var enemy_idx: int = get_enemy_at(target)
	if enemy_idx != -1:
		_player_attack(enemy_idx)
	else:
		player_pos = target
		_check_pickups()
		_check_exit()

	turns += 1
	if state == State.PLAYING:
		_process_enemies()
	return true


func step_wait() -> bool:
	turn_events.clear()
	if state != State.PLAYING:
		return false
	turns += 1
	last_message = "Esperas un turno..."
	_process_enemies()
	return true


func use_potion() -> bool:
	turn_events.clear()
	if state != State.PLAYING:
		return false
	if potions <= 0:
		last_message = "No tienes pociones."
		return false
	if player_hp >= player_max_hp:
		last_message = "Tu vida ya está al máximo."
		return false

	potions -= 1
	var heal_amount: int = mini(5, player_max_hp - player_hp)
	player_hp += heal_amount
	last_message = "Bebes una poción (+%d HP)." % heal_amount
	turn_events.append({
		"type": "heal",
		"pos": player_pos,
		"amount": heal_amount,
	})
	turns += 1
	_process_enemies()
	return true


func _player_attack(enemy_idx: int) -> void:
	var enemy: Dictionary = enemies[enemy_idx]
	enemy["hp"] -= player_atk
	var enemy_name: String = "Slime" if enemy["kind"] == "slime" else "Esqueleto"
	turn_events.append({
		"type": "damage",
		"pos": enemy["pos"],
		"amount": player_atk,
		"target": "enemy",
	})

	if enemy["hp"] <= 0:
		var reward: int = 3 if enemy["kind"] == "slime" else 8
		coins += reward
		last_message = "¡Derrotaste al %s! (+%d oro)" % [enemy_name, reward]
		turn_events.append({
			"type": "enemy_died",
			"pos": enemy["pos"],
			"kind": enemy["kind"],
		})
		enemies.remove_at(enemy_idx)
	else:
		last_message = "Golpeas al %s (-%d HP, queda %d)." % [enemy_name, player_atk, enemy["hp"]]


func _check_pickups() -> void:
	var idx: int = get_item_at(player_pos)
	if idx == -1:
		return
	var item: Dictionary = items[idx]
	items.remove_at(idx)
	match item["kind"]:
		"coin":
			coins += 5
			last_message = "Recoges +5 de oro."
			turn_events.append({
				"type": "pickup",
				"pos": player_pos,
				"text": "+5 ORO",
				"color": Color(0.95, 0.78, 0.25),
			})
		"potion":
			potions += 1
			last_message = "Recoges una Poción."
			turn_events.append({
				"type": "pickup",
				"pos": player_pos,
				"text": "+1 POCIÓN",
				"color": Color(0.35, 0.85, 0.95),
			})
		"sword":
			player_atk += 1
			last_message = "¡Espada mejorada! (+1 ATK)"
			turn_events.append({
				"type": "pickup",
				"pos": player_pos,
				"text": "+1 ATK!",
				"color": Color(0.95, 0.95, 0.9),
			})
		"key":
			has_key = true
			tiles[exit_pos.y][exit_pos.x] = Tile.EXIT_OPEN
			last_message = "¡Llave obtenida! La salida se abrió."
			turn_events.append({
				"type": "pickup",
				"pos": player_pos,
				"text": "¡LLAVE!",
				"color": Color(0.95, 0.78, 0.25),
			})


func _check_exit() -> void:
	if player_pos == exit_pos:
		if has_key:
			state = State.WON
			last_message = "¡Nivel completado! Escapaste de la mazmorra."
		else:
			last_message = "Salida cerrada. Necesitas la Llave."


func _process_enemies() -> void:
	for enemy in enemies:
		if state != State.PLAYING:
			return
		var epos: Vector2i = enemy["pos"]
		var diff: Vector2i = player_pos - epos
		var dist: int = absi(diff.x) + absi(diff.y)

		if dist == 1:
			# Adjacent: attack player
			var dmg: int = enemy["atk"]
			player_hp = maxi(0, player_hp - dmg)
			var enemy_name: String = "Slime" if enemy["kind"] == "slime" else "Esqueleto"
			last_message = "%s te golpea (-%d HP)." % [enemy_name, dmg]
			turn_events.append({
				"type": "damage",
				"pos": player_pos,
				"amount": dmg,
				"target": "player",
			})
			if player_hp <= 0:
				state = State.LOST
				last_message = "Has caído en la mazmorra..."
				return
		elif dist <= 5:
			# Move one step closer toward player along dominant axis, fallback to other axis
			var candidates: Array[Vector2i] = []
			var step_x := Vector2i(signi(diff.x), 0)
			var step_y := Vector2i(0, signi(diff.y))
			if absi(diff.x) >= absi(diff.y):
				if step_x != Vector2i.ZERO:
					candidates.append(epos + step_x)
				if step_y != Vector2i.ZERO:
					candidates.append(epos + step_y)
			else:
				if step_y != Vector2i.ZERO:
					candidates.append(epos + step_y)
				if step_x != Vector2i.ZERO:
					candidates.append(epos + step_x)

			for next_pos in candidates:
				if _can_enemy_enter(next_pos):
					enemy["pos"] = next_pos
					break


func _can_enemy_enter(pos: Vector2i) -> bool:
	if is_wall(pos):
		return false
	if pos == player_pos:
		return false
	if get_enemy_at(pos) != -1:
		return false
	return true

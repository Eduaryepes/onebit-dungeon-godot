class_name DungeonLogic
extends RefCounted

## Pure turn-based roguelike state & rules for OneBit Dungeon (5 levels, 5 weapon types).
## Decoupled from Godot UI/rendering so it can be unit-tested headlessly.

enum Tile {
	FLOOR,
	WALL,
	EXIT_LOCKED,
	EXIT_OPEN,
}

enum State {
	PLAYING,
	LEVEL_CLEAR,
	WON,
	LOST,
}

const WEAPONS: Dictionary = {
	"sword": {
		"name": "Espada",
		"short": "ESPADA",
		"base_atk": 2,
		"range": 1,
		"pierce": false,
		"cleave": false,
		"crit_chance": 0.0,
		"desc": "Equilibrada",
		"color": Color(0.95, 0.95, 0.95),
	},
	"dagger": {
		"name": "Daga",
		"short": "DAGA",
		"base_atk": 2,
		"range": 1,
		"pierce": false,
		"cleave": false,
		"crit_chance": 0.35,
		"desc": "35% Crítico x2",
		"color": Color(0.55, 0.95, 0.98),
	},
	"spear": {
		"name": "Lanza",
		"short": "LANZA",
		"base_atk": 3,
		"range": 2,
		"pierce": true,
		"cleave": false,
		"crit_chance": 0.0,
		"desc": "Alcance 2 + Empala",
		"color": Color(0.96, 0.86, 0.45),
	},
	"axe": {
		"name": "Hacha",
		"short": "HACHA",
		"base_atk": 4,
		"range": 1,
		"pierce": false,
		"cleave": true,
		"crit_chance": 0.0,
		"desc": "Tajo en área",
		"color": Color(0.98, 0.56, 0.32),
	},
	"staff": {
		"name": "Báculo",
		"short": "BÁCULO",
		"base_atk": 3,
		"range": 3,
		"pierce": false,
		"cleave": false,
		"crit_chance": 0.15,
		"desc": "Rayo alcance 3",
		"color": Color(0.78, 0.52, 0.98),
	},
}

const ENEMY_DEFS: Dictionary = {
	"slime": {"name": "Slime", "hp": 4, "atk": 1, "reward": 3, "aggro": 5},
	"skeleton": {"name": "Esqueleto", "hp": 7, "atk": 2, "reward": 8, "aggro": 5},
	"bat": {"name": "Murciélago", "hp": 3, "atk": 2, "reward": 5, "aggro": 7},
	"knight": {"name": "Caballero", "hp": 12, "atk": 3, "reward": 14, "aggro": 5},
	"boss": {"name": "Rey Esqueleto", "hp": 24, "atk": 4, "reward": 50, "aggro": 7},
}

# Map legend:
# # = wall, . = floor, P = player, E = exit, K = key, c = coin, p = potion
# Weapons: W = sword, d = dagger, L = spear, A = axe, M = staff
# Enemies: s = slime, S = skeleton, b = bat, N = knight, B = boss
const LEVELS: Array[Dictionary] = [
	{
		"name": "Catacumbas",
		"theme": {
			"bg": Color(0.051, 0.051, 0.063, 1.0),
			"wall": Color(0.92, 0.92, 0.87, 1.0),
			"floor": Color(0.20, 0.20, 0.25, 1.0),
			"mote": Color(0.75, 0.78, 0.88, 0.45),
		},
		"map": [
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
			"#.s.#.d.#.p.#",
			"#...#...#...#",
			"###...P...###",
			"#....c.c....#",
			"#############",
		],
	},
	{
		"name": "Cripta Esmeralda",
		"theme": {
			"bg": Color(0.035, 0.063, 0.058, 1.0),
			"wall": Color(0.72, 0.95, 0.82, 1.0),
			"floor": Color(0.14, 0.25, 0.22, 1.0),
			"mote": Color(0.45, 0.95, 0.72, 0.45),
		},
		"map": [
			"#############",
			"#..c..E..c..#",
			"#.####.####.#",
			"#.#..b.b..#.#",
			"#.#.##.##.#.#",
			"#...#...#...#",
			"###.#.S.#.###",
			"#K..#...#..p#",
			"#.###.#.###.#",
			"#..s..#..s..#",
			"#.###.#.###.#",
			"#...#...#...#",
			"#.#.#.L.#.#.#",
			"#.#...b...#.#",
			"#c###...###c#",
			"#...#...#...#",
			"#.s...P...s.#",
			"#..p.....c..#",
			"#############",
		],
	},
	{
		"name": "Forja Carmesí",
		"theme": {
			"bg": Color(0.075, 0.038, 0.038, 1.0),
			"wall": Color(0.96, 0.76, 0.68, 1.0),
			"floor": Color(0.28, 0.16, 0.16, 1.0),
			"mote": Color(0.98, 0.56, 0.28, 0.55),
		},
		"map": [
			"#############",
			"#.....E.....#",
			"#.###.#.###.#",
			"#.#c..N..c#.#",
			"#.#.#...#.#.#",
			"#...#...#...#",
			"#.###...###.#",
			"#p..b...b..K#",
			"###.##.##.###",
			"#A..#...#..W#",
			"#.#...S...#.#",
			"#.#.#####.#.#",
			"#..s..#..s..#",
			"###.#.#.#.###",
			"#c..#...#..c#",
			"#.#...S...#.#",
			"#...#.P.#...#",
			"#..p..c..p..#",
			"#############",
		],
	},
	{
		"name": "Santuario Arcano",
		"theme": {
			"bg": Color(0.055, 0.039, 0.082, 1.0),
			"wall": Color(0.84, 0.76, 0.98, 1.0),
			"floor": Color(0.22, 0.17, 0.30, 1.0),
			"mote": Color(0.76, 0.54, 0.98, 0.55),
		},
		"map": [
			"#############",
			"#..c..E..c..#",
			"#.##.###.##.#",
			"#..N..b..N..#",
			"####.....####",
			"#K...###...p#",
			"#.###...###.#",
			"#.#..c.c..#.#",
			"#.#.#####.#.#",
			"#..b..M..b..#",
			"#.###.#.###.#",
			"#...#.#.#...#",
			"#c#...S...#c#",
			"#.#.#####.#.#",
			"#..L..#..p..#",
			"###.#...#.###",
			"#..s..P..s..#",
			"#....c.c....#",
			"#############",
		],
	},
	{
		"name": "Trono del Abismo",
		"theme": {
			"bg": Color(0.063, 0.051, 0.035, 1.0),
			"wall": Color(0.98, 0.86, 0.56, 1.0),
			"floor": Color(0.24, 0.20, 0.14, 1.0),
			"mote": Color(0.98, 0.80, 0.32, 0.60),
		},
		"map": [
			"#############",
			"#.....E.....#",
			"#.###...###.#",
			"#.#c..B..c#.#",
			"#.#.......#.#",
			"#.#..#.#..#.#",
			"#..N.....N..#",
			"###.##.##.###",
			"#K..#...#..p#",
			"#.#...S...#.#",
			"#.#.##.##.#.#",
			"#A..#...#..M#",
			"###.#...#.###",
			"#c..b...b..c#",
			"#.###...###.#",
			"#..p..d..p..#",
			"###...P...###",
			"#....c.c....#",
			"#############",
		],
	},
]

var current_level: int = 0
var width: int = 0
var height: int = 0
var tiles: Array = [] # 2D Array[Array[int]] indexed as tiles[y][x]

var player_pos: Vector2i = Vector2i.ZERO
var player_facing: Vector2i = Vector2i.UP
var player_hp: int = 12
var player_max_hp: int = 12
var player_atk: int = 2
var coins: int = 0
var potions: int = 1
var has_key: bool = false
var turns: int = 0
var kills: int = 0
var combo: int = 0
var combo_timer: int = 0
var state: int = State.PLAYING

var unlocked_weapons: Array[String] = ["sword"]
var weapon_upgrades: Dictionary = {"sword": 0}
var equipped_weapon: String = "sword"

# Each enemy: { "id": int, "kind": String, "pos": Vector2i, "hp": int, "max_hp": int, "atk": int, "reward": int }
var enemies: Array[Dictionary] = []
# Each item: { "kind": String, "pos": Vector2i }
var items: Array[Dictionary] = []

var exit_pos: Vector2i = Vector2i.ZERO
var last_message: String = "¡Encuentra la llave y escapa!"
var turn_events: Array[Dictionary] = []

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_enemy_id: int = 1


func _init() -> void:
	rng.randomize()
	reset(0)


func total_levels() -> int:
	return LEVELS.size()


func get_level_name() -> String:
	return LEVELS[current_level]["name"]


func get_level_theme() -> Dictionary:
	return LEVELS[current_level]["theme"]


func get_weapon_info(kind: String = "") -> Dictionary:
	var k: String = equipped_weapon if kind.is_empty() else kind
	return WEAPONS.get(k, WEAPONS["sword"])


func get_weapon_upgrade(kind: String = "") -> int:
	var k: String = equipped_weapon if kind.is_empty() else kind
	return int(weapon_upgrades.get(k, 0))


func get_weapon_display_name(kind: String = "") -> String:
	var k: String = equipped_weapon if kind.is_empty() else kind
	var info: Dictionary = get_weapon_info(k)
	var upg: int = get_weapon_upgrade(k)
	if upg > 0:
		return "%s +%d" % [info["short"], upg]
	return info["short"]


func reset(level_idx: int = 0) -> void:
	current_level = clampi(level_idx, 0, LEVELS.size() - 1)
	player_max_hp = 12 + current_level * 2
	player_hp = player_max_hp
	coins = 0
	potions = 1
	turns = 0
	kills = 0
	combo = 0
	combo_timer = 0
	unlocked_weapons = ["sword"]
	weapon_upgrades = {"sword": 0}
	equipped_weapon = "sword"
	_recalc_atk()
	_load_level(current_level)


func next_level() -> bool:
	if current_level + 1 >= LEVELS.size():
		return false
	current_level += 1
	player_max_hp += 2
	player_hp = mini(player_max_hp, player_hp + 4)
	combo = 0
	combo_timer = 0
	_load_level(current_level)
	last_message = "Nivel %d: %s (+4 HP, +2 Max HP)" % [current_level + 1, get_level_name()]
	return true


func _load_level(level_idx: int) -> void:
	var level_data: Dictionary = LEVELS[level_idx]
	var level_map: Array = level_data["map"]
	height = level_map.size()
	width = level_map[0].length()
	tiles.clear()
	enemies.clear()
	items.clear()
	turn_events.clear()
	_next_enemy_id = 1
	has_key = false
	state = State.PLAYING
	player_facing = Vector2i.UP
	last_message = "Nivel %d: %s — Busca la Llave (K)." % [level_idx + 1, level_data["name"]]

	for y in range(height):
		var row: Array[int] = []
		var line: String = level_map[y]
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
					_spawn_enemy("slime", pos)
				"S":
					row.append(Tile.FLOOR)
					_spawn_enemy("skeleton", pos)
				"b":
					row.append(Tile.FLOOR)
					_spawn_enemy("bat", pos)
				"N":
					row.append(Tile.FLOOR)
					_spawn_enemy("knight", pos)
				"B":
					row.append(Tile.FLOOR)
					_spawn_enemy("boss", pos)
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
				"d":
					row.append(Tile.FLOOR)
					items.append({"kind": "dagger", "pos": pos})
				"L":
					row.append(Tile.FLOOR)
					items.append({"kind": "spear", "pos": pos})
				"A":
					row.append(Tile.FLOOR)
					items.append({"kind": "axe", "pos": pos})
				"M":
					row.append(Tile.FLOOR)
					items.append({"kind": "staff", "pos": pos})
				_:
					row.append(Tile.FLOOR)
		tiles.append(row)


func _spawn_enemy(kind: String, pos: Vector2i) -> void:
	var def: Dictionary = ENEMY_DEFS[kind]
	enemies.append({
		"id": _next_enemy_id,
		"kind": kind,
		"pos": pos,
		"hp": def["hp"],
		"max_hp": def["hp"],
		"atk": def["atk"],
		"reward": def["reward"],
	})
	_next_enemy_id += 1


func _recalc_atk() -> void:
	var info: Dictionary = get_weapon_info()
	player_atk = int(info["base_atk"]) + get_weapon_upgrade()


func equip_weapon(kind: String) -> bool:
	if not unlocked_weapons.has(kind):
		return false
	equipped_weapon = kind
	_recalc_atk()
	return true


func cycle_weapon() -> bool:
	turn_events.clear()
	if state != State.PLAYING or unlocked_weapons.size() <= 1:
		return false
	var idx: int = unlocked_weapons.find(equipped_weapon)
	var next_idx: int = (idx + 1) % unlocked_weapons.size()
	equipped_weapon = unlocked_weapons[next_idx]
	_recalc_atk()
	var info: Dictionary = get_weapon_info()
	last_message = "Equipas %s (ATK %d — %s)." % [get_weapon_display_name(), player_atk, info["desc"]]
	turn_events.append({
		"type": "weapon_swap",
		"pos": player_pos,
		"weapon": equipped_weapon,
		"text": get_weapon_display_name(),
		"color": info["color"],
	})
	return true


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

	player_facing = dir
	var target: Vector2i = player_pos + dir
	var killed_this_turn: bool = false

	# 1. Check weapon attack targets along dir (including ranged spear/staff)
	var targets: Array[int] = _find_attack_targets(dir)
	if not targets.is_empty():
		killed_this_turn = _execute_weapon_attack(dir, targets)
	else:
		if is_wall(target):
			last_message = "Hay un muro."
			turn_events.append({
				"type": "wall_bump",
				"pos": player_pos,
				"dir": dir,
			})
			return false
		var old_pos: Vector2i = player_pos
		player_pos = target
		turn_events.append({
			"type": "move",
			"from": old_pos,
			"to": player_pos,
			"dir": dir,
		})
		_check_pickups()
		_check_exit()

	_update_combo(killed_this_turn)
	turns += 1
	if state == State.PLAYING:
		_process_enemies()
	return true


func _find_attack_targets(dir: Vector2i) -> Array[int]:
	var info: Dictionary = get_weapon_info()
	var w_range: int = int(info["range"])
	var pierce: bool = bool(info["pierce"])
	var cleave: bool = bool(info["cleave"])
	var result: Array[int] = []

	if cleave:
		# Axe: must have an enemy directly in front to swing, then cleaves flanking tiles too
		var front_idx: int = get_enemy_at(player_pos + dir)
		if front_idx == -1:
			return result
		result.append(front_idx)
		var perp := Vector2i(-dir.y, dir.x)
		var cleave_cells: Array[Vector2i] = [
			player_pos + dir + perp,
			player_pos + dir - perp,
			player_pos + perp,
			player_pos - perp,
		]
		for cell in cleave_cells:
			var idx: int = get_enemy_at(cell)
			if idx != -1 and not result.has(idx):
				result.append(idx)
		return result

	# Line scan for sword, dagger, spear (pierce), staff (ranged)
	for step in range(1, w_range + 1):
		var cell: Vector2i = player_pos + dir * step
		if is_wall(cell):
			break
		var idx: int = get_enemy_at(cell)
		if idx != -1:
			result.append(idx)
			if not pierce:
				break
	return result


func _execute_weapon_attack(dir: Vector2i, target_indices: Array[int]) -> bool:
	var info: Dictionary = get_weapon_info()
	var crit_chance: float = float(info["crit_chance"])
	var is_crit: bool = crit_chance > 0.0 and rng.randf() < crit_chance
	var dmg: int = player_atk * (2 if is_crit else 1)

	# Snapshot enemy IDs and positions before removals
	var target_ids: Array[int] = []
	var target_positions: Array[Vector2i] = []
	for idx in target_indices:
		target_ids.append(int(enemies[idx]["id"]))
		target_positions.append(enemies[idx]["pos"])

	var main_target_pos: Vector2i = target_positions[target_positions.size() - 1]
	turn_events.append({
		"type": "player_attack",
		"from": player_pos,
		"to": main_target_pos,
		"dir": dir,
		"weapon": equipped_weapon,
		"targets": target_positions,
		"crit": is_crit,
	})

	var any_killed: bool = false
	var killed_names: Array[String] = []
	var total_reward: int = 0
	var last_hit_msg: String = ""

	for eid in target_ids:
		var idx: int = _find_enemy_by_id(eid)
		if idx == -1:
			continue
		var enemy: Dictionary = enemies[idx]
		enemy["hp"] -= dmg
		var enemy_name: String = ENEMY_DEFS[enemy["kind"]]["name"]
		turn_events.append({
			"type": "damage",
			"pos": enemy["pos"],
			"amount": dmg,
			"target": "enemy",
			"crit": is_crit,
			"dir": dir,
			"enemy_id": eid,
		})

		if enemy["hp"] <= 0:
			any_killed = true
			kills += 1
			combo += 1
			combo_timer = 4
			var base_reward: int = int(enemy["reward"])
			var combo_bonus: int = maxi(0, combo - 1)
			var reward: int = base_reward + combo_bonus
			coins += reward
			total_reward += reward
			killed_names.append(enemy_name)
			turn_events.append({
				"type": "enemy_died",
				"pos": enemy["pos"],
				"kind": enemy["kind"],
				"combo": combo,
				"reward": reward,
			})
			enemies.remove_at(idx)
		else:
			var crit_tag: String = "¡CRÍTICO! " if is_crit else ""
			last_hit_msg = "%sGolpeas al %s (-%d HP, queda %d)." % [crit_tag, enemy_name, dmg, enemy["hp"]]

	if any_killed:
		var combo_str: String = " [COMBO x%d!]" % combo if combo >= 2 else ""
		if killed_names.size() > 1:
			last_message = "¡Derrotaste a %d enemigos! (+%d oro)%s" % [killed_names.size(), total_reward, combo_str]
		else:
			last_message = "¡Derrotaste al %s! (+%d oro)%s" % [killed_names[0], total_reward, combo_str]
	elif target_ids.size() > 1:
		last_message = "¡Golpeas a %d enemigos (-%d HP)!" % [target_ids.size(), dmg]
	else:
		last_message = last_hit_msg

	return any_killed


func _find_enemy_by_id(eid: int) -> int:
	for i in range(enemies.size()):
		if int(enemies[i]["id"]) == eid:
			return i
	return -1


func _update_combo(killed_this_turn: bool) -> void:
	if killed_this_turn:
		return
	if combo_timer > 0:
		combo_timer -= 1
		if combo_timer <= 0:
			combo = 0


func step_wait() -> bool:
	turn_events.clear()
	if state != State.PLAYING:
		return false
	_update_combo(false)
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
	var heal_amount: int = mini(6, player_max_hp - player_hp)
	player_hp += heal_amount
	last_message = "Bebes una poción (+%d HP)." % heal_amount
	turn_events.append({
		"type": "heal",
		"pos": player_pos,
		"amount": heal_amount,
	})
	_update_combo(false)
	turns += 1
	_process_enemies()
	return true


func _check_pickups() -> void:
	var idx: int = get_item_at(player_pos)
	if idx == -1:
		return
	var item: Dictionary = items[idx]
	items.remove_at(idx)
	var kind: String = item["kind"]

	if WEAPONS.has(kind):
		var info: Dictionary = WEAPONS[kind]
		if unlocked_weapons.has(kind):
			weapon_upgrades[kind] = int(weapon_upgrades.get(kind, 0)) + 1
			equipped_weapon = kind
			_recalc_atk()
			last_message = "¡%s mejorada! (%s, ATK %d)" % [info["name"], get_weapon_display_name(kind), player_atk]
			turn_events.append({
				"type": "pickup",
				"kind": kind,
				"pos": player_pos,
				"text": "%s +1!" % info["short"],
				"color": info["color"],
			})
		else:
			unlocked_weapons.append(kind)
			weapon_upgrades[kind] = 0
			equipped_weapon = kind
			_recalc_atk()
			last_message = "¡Nueva arma: %s! (ATK %d — %s)" % [info["name"], player_atk, info["desc"]]
			turn_events.append({
				"type": "pickup",
				"kind": kind,
				"pos": player_pos,
				"text": "¡%s!" % info["short"],
				"color": info["color"],
			})
		return

	match kind:
		"coin":
			coins += 5
			last_message = "Recoges +5 de oro."
			turn_events.append({
				"type": "pickup",
				"kind": "coin",
				"pos": player_pos,
				"text": "+5 ORO",
				"color": Color(0.95, 0.78, 0.25),
			})
		"potion":
			potions += 1
			last_message = "Recoges una Poción."
			turn_events.append({
				"type": "pickup",
				"kind": "potion",
				"pos": player_pos,
				"text": "+1 POCIÓN",
				"color": Color(0.35, 0.85, 0.95),
			})
		"key":
			has_key = true
			tiles[exit_pos.y][exit_pos.x] = Tile.EXIT_OPEN
			last_message = "¡Llave obtenida! La salida se abrió."
			turn_events.append({
				"type": "pickup",
				"kind": "key",
				"pos": player_pos,
				"text": "¡LLAVE!",
				"color": Color(0.98, 0.82, 0.25),
			})


func _check_exit() -> void:
	if player_pos == exit_pos:
		if has_key:
			var is_final: bool = (current_level + 1 >= LEVELS.size())
			if is_final:
				state = State.WON
				last_message = "¡MAZMORRA CONQUISTADA! Eres una leyenda."
			else:
				state = State.LEVEL_CLEAR
				last_message = "¡Nivel %d completado! Avanza a las profundidades." % (current_level + 1)
			turn_events.append({
				"type": "level_clear",
				"pos": exit_pos,
				"level": current_level + 1,
				"is_final": is_final,
			})
		else:
			last_message = "Salida cerrada. Necesitas la Llave."


func _process_enemies() -> void:
	for enemy in enemies:
		if state != State.PLAYING:
			return
		var epos: Vector2i = enemy["pos"]
		var diff: Vector2i = player_pos - epos
		var dist: int = absi(diff.x) + absi(diff.y)
		var def: Dictionary = ENEMY_DEFS[enemy["kind"]]
		var aggro: int = int(def["aggro"])

		if dist == 1:
			var dmg: int = int(enemy["atk"])
			player_hp = maxi(0, player_hp - dmg)
			var enemy_name: String = def["name"]
			last_message = "%s te golpea (-%d HP)." % [enemy_name, dmg]
			turn_events.append({
				"type": "enemy_attack",
				"id": int(enemy["id"]),
				"from": epos,
				"to": player_pos,
				"kind": enemy["kind"],
			})
			turn_events.append({
				"type": "damage",
				"pos": player_pos,
				"amount": dmg,
				"target": "player",
				"crit": false,
				"dir": diff,
				"enemy_id": int(enemy["id"]),
			})
			if player_hp <= 0:
				state = State.LOST
				last_message = "Has caído en la mazmorra..."
				turn_events.append({
					"type": "player_died",
					"pos": player_pos,
				})
				return
		elif dist <= aggro:
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
					var old_pos: Vector2i = epos
					enemy["pos"] = next_pos
					turn_events.append({
						"type": "enemy_move",
						"id": int(enemy["id"]),
						"from": old_pos,
						"to": next_pos,
					})
					break


func _can_enemy_enter(pos: Vector2i) -> bool:
	if is_wall(pos):
		return false
	if pos == player_pos:
		return false
	if get_enemy_at(pos) != -1:
		return false
	return true

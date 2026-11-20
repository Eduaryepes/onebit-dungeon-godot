class_name DungeonBoard
extends Control

## Renders the 1-bit dungeon grid, animated entities, camera follow,
## screen shake, floating combat/pickup text, and handles touch swipe gestures.

signal swipe_direction(dir: Vector2i)

const TILE_SIZE: float = 40.0
const COLOR_BG := Color(0.051, 0.051, 0.063, 1.0)
const COLOR_WALL := Color(0.92, 0.92, 0.87, 1.0)
const COLOR_FLOOR := Color(0.20, 0.20, 0.25, 1.0)
const COLOR_HERO := Color(0.96, 0.96, 0.92, 1.0)
const COLOR_SLIME := Color(0.45, 0.92, 0.55, 1.0)
const COLOR_SKELETON := Color(0.95, 0.35, 0.35, 1.0)
const COLOR_COIN := Color(0.96, 0.78, 0.24, 1.0)
const COLOR_POTION := Color(0.35, 0.85, 0.96, 1.0)
const COLOR_SWORD := Color(0.95, 0.95, 0.95, 1.0)
const COLOR_KEY := Color(0.98, 0.82, 0.25, 1.0)
const COLOR_EXIT_LOCKED := Color(0.55, 0.55, 0.60, 1.0)
const COLOR_EXIT_OPEN := Color(0.98, 0.82, 0.25, 1.0)
const COLOR_DAMAGE := Color(0.98, 0.30, 0.30, 1.0)
const COLOR_HEAL := Color(0.35, 0.95, 0.55, 1.0)

var logic: DungeonLogic
var sprites: Dictionary = {}

var _cam_pos: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _shake_strength: float = 0.0
var _hero_flash: float = 0.0
var _floating_texts: Array[Dictionary] = []

# Swipe tracking
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
const SWIPE_THRESHOLD: float = 28.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	sprites = PixelSprites.build_all()


func bind_logic(p_logic: DungeonLogic) -> void:
	logic = p_logic
	snap_camera()
	_floating_texts.clear()
	_shake_strength = 0.0
	_hero_flash = 0.0
	queue_redraw()


func snap_camera() -> void:
	if logic == null:
		return
	_cam_pos = _tile_center(logic.player_pos)


func consume_turn_events() -> void:
	if logic == null:
		return
	for ev in logic.turn_events:
		var pos: Vector2 = _tile_center(ev["pos"])
		match ev["type"]:
			"damage":
				var amt: int = ev["amount"]
				_spawn_float_text(pos, "-%d" % amt, COLOR_DAMAGE)
				if ev["target"] == "player":
					_shake_strength = 7.0
					_hero_flash = 0.22
				else:
					_shake_strength = maxf(_shake_strength, 3.5)
			"heal":
				_spawn_float_text(pos, "+%d HP" % ev["amount"], COLOR_HEAL)
			"pickup":
				_spawn_float_text(pos, ev["text"], ev["color"])
			"enemy_died":
				_spawn_float_text(pos + Vector2(0, -10), "KO!", COLOR_COIN)
	queue_redraw()


func _spawn_float_text(world_pos: Vector2, text: String, color: Color) -> void:
	_floating_texts.append({
		"pos": world_pos + Vector2(0, -TILE_SIZE * 0.35),
		"text": text,
		"color": color,
		"life": 0.85,
		"max_life": 0.85,
	})


func _process(delta: float) -> void:
	_time += delta
	if logic != null:
		var target_cam: Vector2 = _tile_center(logic.player_pos)
		_cam_pos = _cam_pos.lerp(target_cam, minf(1.0, delta * 12.0))

	if _shake_strength > 0.0:
		_shake_strength = maxf(0.0, _shake_strength - delta * 28.0)
	if _hero_flash > 0.0:
		_hero_flash = maxf(0.0, _hero_flash - delta)

	for i in range(_floating_texts.size() - 1, -1, -1):
		var ft: Dictionary = _floating_texts[i]
		ft["life"] -= delta
		ft["pos"] += Vector2(0, -28.0 * delta)
		if ft["life"] <= 0.0:
			_floating_texts.remove_at(i)

	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
		else:
			if _dragging:
				_finish_swipe(event.position)
				_dragging = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
		else:
			if _dragging:
				_finish_swipe(event.position)
				_dragging = false


func _finish_swipe(end_pos: Vector2) -> void:
	var delta: Vector2 = end_pos - _drag_start
	if delta.length() < SWIPE_THRESHOLD:
		return
	if absf(delta.x) >= absf(delta.y):
		swipe_direction.emit(Vector2i(1 if delta.x > 0.0 else -1, 0))
	else:
		swipe_direction.emit(Vector2i(0, 1 if delta.y > 0.0 else -1))


func _tile_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	if logic == null or sprites.is_empty():
		return

	var shake_offset := Vector2.ZERO
	if _shake_strength > 0.0:
		shake_offset = Vector2(
			sin(_time * 65.0) * _shake_strength,
			cos(_time * 57.0) * _shake_strength
		)

	var origin: Vector2 = size * 0.5 - _cam_pos + shake_offset

	# 1. Draw tiles
	for y in range(logic.height):
		for x in range(logic.width):
			var rect := Rect2(origin + Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			if rect.end.x < 0 or rect.position.x > size.x or rect.end.y < 0 or rect.position.y > size.y:
				continue
			var tile: int = logic.tiles[y][x]
			match tile:
				DungeonLogic.Tile.WALL:
					draw_texture_rect(sprites["wall"], rect, false, COLOR_WALL)
				DungeonLogic.Tile.FLOOR:
					draw_texture_rect(sprites["floor"], rect, false, COLOR_FLOOR)
				DungeonLogic.Tile.EXIT_LOCKED:
					draw_texture_rect(sprites["exit_locked"], rect, false, COLOR_EXIT_LOCKED)
				DungeonLogic.Tile.EXIT_OPEN:
					var pulse: float = 0.82 + 0.18 * sin(_time * 5.0)
					draw_texture_rect(sprites["exit_open"], rect, false, COLOR_EXIT_OPEN * Color(pulse, pulse, pulse, 1.0))

	# 2. Draw items (gentle bob)
	var item_bob: float = sin(_time * 4.0) * 2.0
	for item in logic.items:
		var pos: Vector2i = item["pos"]
		var rect := Rect2(origin + Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE + item_bob), Vector2(TILE_SIZE, TILE_SIZE))
		var color: Color = COLOR_COIN
		match item["kind"]:
			"coin":
				color = COLOR_COIN
			"potion":
				color = COLOR_POTION
			"sword":
				color = COLOR_SWORD
			"key":
				color = COLOR_KEY
		draw_texture_rect(sprites[item["kind"]], rect, false, color)

	# 3. Draw enemies + mini HP bar
	var enemy_bob: float = sin(_time * 6.0) * 1.5
	for enemy in logic.enemies:
		var pos: Vector2i = enemy["pos"]
		var base := origin + Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)
		var rect := Rect2(base + Vector2(0, enemy_bob), Vector2(TILE_SIZE, TILE_SIZE))
		var col: Color = COLOR_SLIME if enemy["kind"] == "slime" else COLOR_SKELETON
		draw_texture_rect(sprites[enemy["kind"]], rect, false, col)

		if enemy["hp"] < enemy["max_hp"]:
			var ratio: float = float(enemy["hp"]) / float(enemy["max_hp"])
			var bar_w: float = TILE_SIZE - 8.0
			draw_rect(Rect2(base + Vector2(4, 2), Vector2(bar_w, 4)), Color(0.15, 0.15, 0.18), true)
			draw_rect(Rect2(base + Vector2(4, 2), Vector2(bar_w * ratio, 4)), COLOR_DAMAGE, true)

	# 4. Draw hero
	var hero_bob: float = sin(_time * 5.0) * 1.0
	var hero_rect := Rect2(
		origin + Vector2(logic.player_pos.x * TILE_SIZE, logic.player_pos.y * TILE_SIZE + hero_bob),
		Vector2(TILE_SIZE, TILE_SIZE)
	)
	var hero_col: Color = COLOR_DAMAGE if _hero_flash > 0.0 else COLOR_HERO
	draw_texture_rect(sprites["hero"], hero_rect, false, hero_col)

	# 5. Draw floating combat / pickup texts
	var font: Font = ThemeDB.fallback_font
	for ft in _floating_texts:
		var alpha: float = clampf(ft["life"] / ft["max_life"], 0.0, 1.0)
		var col: Color = ft["color"]
		col.a = alpha
		var screen_pos: Vector2 = origin + ft["pos"]
		draw_string(font, screen_pos + Vector2(-18, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 40.0, 14, col)

	# 6. Subtle 1-bit frame border around viewport
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(0.92, 0.92, 0.87, 0.35), false, 2.0)

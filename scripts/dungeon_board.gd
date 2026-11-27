class_name DungeonBoard
extends Control

## Renders the 1-bit dungeon grid with rich game feel:
## smooth hop interpolation, squash & stretch, directional lunges, hitstop,
## camera zoom punch & trauma shake, weapon-specific slash/bolt VFX,
## procedural pixel particles, shockwave rings, torchlight falloff, and touch swipes.

signal swipe_direction(dir: Vector2i)

const TILE_SIZE: float = 40.0
const COLOR_HERO := Color(0.97, 0.97, 0.93, 1.0)
const COLOR_SLIME := Color(0.45, 0.94, 0.55, 1.0)
const COLOR_SKELETON := Color(0.95, 0.36, 0.36, 1.0)
const COLOR_BAT := Color(0.76, 0.48, 0.98, 1.0)
const COLOR_KNIGHT := Color(0.42, 0.72, 0.98, 1.0)
const COLOR_BOSS := Color(0.99, 0.74, 0.22, 1.0)
const COLOR_COIN := Color(0.96, 0.78, 0.24, 1.0)
const COLOR_POTION := Color(0.35, 0.85, 0.96, 1.0)
const COLOR_KEY := Color(0.98, 0.82, 0.25, 1.0)
const COLOR_EXIT_LOCKED := Color(0.55, 0.55, 0.60, 1.0)
const COLOR_EXIT_OPEN := Color(0.98, 0.82, 0.25, 1.0)
const COLOR_DAMAGE := Color(0.98, 0.30, 0.30, 1.0)
const COLOR_CRIT := Color(1.0, 0.88, 0.28, 1.0)
const COLOR_HEAL := Color(0.35, 0.95, 0.55, 1.0)
const COLOR_WHITE := Color(1.0, 1.0, 1.0, 1.0)

var logic: DungeonLogic
var sprites: Dictionary = {}

# Camera & juice state
var _cam_pos: Vector2 = Vector2.ZERO
var _cam_zoom: float = 1.0
var _time: float = 0.0
var _hitstop: float = 0.0
var _shake_trauma: float = 0.0
var _screen_flash: float = 0.0
var _screen_flash_color: Color = Color(1, 1, 1, 0)
var _damage_vignette: float = 0.0

# Hero animation state
var _hero_vis_pos: Vector2 = Vector2.ZERO
var _hero_hop: float = 0.0
var _hero_scale: Vector2 = Vector2.ONE
var _hero_lunge: Vector2 = Vector2.ZERO
var _hero_flash: float = 0.0

# Enemy animation state keyed by enemy id
var _enemy_vis_pos: Dictionary = {}
var _enemy_hop: Dictionary = {}
var _enemy_scale: Dictionary = {}
var _enemy_lunge: Dictionary = {}
var _enemy_flash: Dictionary = {}

# VFX pools
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _weapon_vfx: Array[Dictionary] = []
var _floating_texts: Array[Dictionary] = []
var _ambient_motes: Array[Dictionary] = []

# Floor banner
var _banner_text: String = ""
var _banner_sub: String = ""
var _banner_timer: float = 0.0
var _banner_max: float = 1.8

# Exit sparkle accumulator
var _exit_sparkle_accum: float = 0.0

# Swipe tracking
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
const SWIPE_THRESHOLD: float = 26.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	sprites = PixelSprites.build_all()


func bind_logic(p_logic: DungeonLogic, show_banner: bool = true) -> void:
	logic = p_logic
	_floating_texts.clear()
	_particles.clear()
	_rings.clear()
	_weapon_vfx.clear()
	_enemy_vis_pos.clear()
	_enemy_hop.clear()
	_enemy_scale.clear()
	_enemy_lunge.clear()
	_enemy_flash.clear()
	_shake_trauma = 0.0
	_hitstop = 0.0
	_cam_zoom = 1.0
	_hero_flash = 0.0
	_hero_hop = 0.0
	_hero_scale = Vector2.ONE
	_hero_lunge = Vector2.ZERO
	_damage_vignette = 0.0
	_screen_flash = 0.35
	_screen_flash_color = Color(0.95, 0.95, 0.90, 0.25)

	snap_camera()
	_sync_entities_immediate()
	_init_ambient_motes()

	if show_banner and logic != null:
		show_floor_banner(
			"NIVEL %d / %d" % [logic.current_level + 1, logic.total_levels()],
			logic.get_level_name().to_upper()
		)
	queue_redraw()


func show_floor_banner(title: String, subtitle: String) -> void:
	_banner_text = title
	_banner_sub = subtitle
	_banner_max = 2.0
	_banner_timer = _banner_max


func snap_camera() -> void:
	if logic == null:
		return
	_hero_vis_pos = _tile_center(logic.player_pos)
	_cam_pos = _hero_vis_pos


func _sync_entities_immediate() -> void:
	if logic == null:
		return
	_hero_vis_pos = _tile_center(logic.player_pos)
	for enemy in logic.enemies:
		var eid: int = int(enemy["id"])
		_enemy_vis_pos[eid] = _tile_center(enemy["pos"])
		_enemy_hop[eid] = 0.0
		_enemy_scale[eid] = Vector2.ONE
		_enemy_lunge[eid] = Vector2.ZERO
		_enemy_flash[eid] = 0.0


func _init_ambient_motes() -> void:
	_ambient_motes.clear()
	if logic == null:
		return
	var map_w: float = logic.width * TILE_SIZE
	var map_h: float = logic.height * TILE_SIZE
	for i in range(26):
		_ambient_motes.append({
			"pos": Vector2(_rng.randf_range(TILE_SIZE, map_w - TILE_SIZE), _rng.randf_range(TILE_SIZE, map_h - TILE_SIZE)),
			"vel": Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-14.0, -4.0)),
			"size": _rng.randf_range(2.0, 3.5),
			"phase": _rng.randf_range(0.0, TAU),
		})


func consume_turn_events() -> void:
	if logic == null:
		return
	for ev in logic.turn_events:
		match ev["type"]:
			"move":
				var from_w: Vector2 = _tile_center(ev["from"])
				var dir: Vector2i = ev["dir"]
				_hero_hop = 1.0
				_hero_scale = Vector2(0.84, 1.18)
				_spawn_dust(from_w + Vector2(0, TILE_SIZE * 0.28), Vector2(-dir.x, -dir.y), 4)

			"wall_bump":
				var dir: Vector2i = ev["dir"]
				_hero_lunge = Vector2(dir.x, dir.y) * 9.0
				_hero_scale = Vector2(1.16, 0.86)
				_add_trauma(0.18)
				var wall_edge: Vector2 = _tile_center(ev["pos"]) + Vector2(dir.x, dir.y) * (TILE_SIZE * 0.45)
				_spawn_dust(wall_edge, Vector2(-dir.x, -dir.y), 5)

			"player_attack":
				var dir: Vector2i = ev["dir"]
				var weapon: String = ev["weapon"]
				var from_w: Vector2 = _tile_center(ev["from"])
				var to_w: Vector2 = _tile_center(ev["to"])
				var is_crit: bool = bool(ev.get("crit", false))
				var w_info: Dictionary = logic.get_weapon_info(weapon)
				var w_color: Color = COLOR_CRIT if is_crit else w_info["color"]

				_hero_lunge = Vector2(dir.x, dir.y) * (15.0 if weapon != "staff" else 7.0)
				_hero_scale = Vector2(1.22, 0.82)

				_weapon_vfx.append({
					"weapon": weapon,
					"from": from_w,
					"to": to_w,
					"dir": Vector2(dir.x, dir.y),
					"targets": ev["targets"],
					"color": w_color,
					"crit": is_crit,
					"life": 0.22 if weapon != "axe" else 0.28,
					"max_life": 0.22 if weapon != "axe" else 0.28,
				})

				if weapon == "axe":
					_add_trauma(0.45)
					_cam_zoom = maxf(_cam_zoom, 1.04)
				elif weapon == "staff":
					_spawn_ring(to_w, w_color, 4.0, TILE_SIZE * 0.72, 0.26)
					_spawn_burst(to_w, w_color, 10, 85.0, 0.35)
				if is_crit:
					_hitstop = maxf(_hitstop, 0.065)
					_add_trauma(0.62)
					_cam_zoom = maxf(_cam_zoom, 1.06)
					_screen_flash = maxf(_screen_flash, 0.22)
					_screen_flash_color = Color(1.0, 0.92, 0.45, 0.22)
					_spawn_ring(to_w, COLOR_CRIT, 6.0, TILE_SIZE * 0.95, 0.30)

			"enemy_move":
				var eid: int = int(ev["id"])
				_enemy_hop[eid] = 1.0
				_enemy_scale[eid] = Vector2(0.86, 1.15)

			"enemy_attack":
				var eid: int = int(ev["id"])
				var diff: Vector2i = ev["to"] - ev["from"]
				_enemy_lunge[eid] = Vector2(diff.x, diff.y) * 14.0
				_enemy_scale[eid] = Vector2(1.2, 0.84)

			"damage":
				var pos: Vector2 = _tile_center(ev["pos"])
				var amt: int = int(ev["amount"])
				var is_crit: bool = bool(ev.get("crit", false))
				var hit_dir: Vector2i = ev.get("dir", Vector2i.UP)
				if ev["target"] == "player":
					_spawn_float_text(pos, "-%d" % amt, COLOR_DAMAGE, 16)
					_add_trauma(0.65)
					_hitstop = maxf(_hitstop, 0.045)
					_hero_flash = 0.25
					_damage_vignette = 0.85
					_hero_scale = Vector2(1.25, 0.78)
					_spawn_burst(pos, COLOR_DAMAGE, 12, 110.0, 0.42, Vector2(hit_dir.x, hit_dir.y))
				else:
					var label: String = "CRIT -%d!" % amt if is_crit else "-%d" % amt
					_spawn_float_text(pos, label, COLOR_CRIT if is_crit else COLOR_DAMAGE, 17 if is_crit else 14)
					_add_trauma(0.32 if not is_crit else 0.55)
					_hitstop = maxf(_hitstop, 0.035)
					var eid: int = int(ev.get("enemy_id", -1))
					if eid != -1:
						_enemy_flash[eid] = 0.16
						_enemy_lunge[eid] = Vector2(hit_dir.x, hit_dir.y) * 8.0
						_enemy_scale[eid] = Vector2(1.24, 0.78)
					var spark_col: Color = COLOR_CRIT if is_crit else Color(1.0, 0.92, 0.78)
					_spawn_burst(pos, spark_col, 14 if is_crit else 8, 125.0, 0.36, Vector2(hit_dir.x, hit_dir.y))

			"enemy_died":
				var pos: Vector2 = _tile_center(ev["pos"])
				var kind: String = ev["kind"]
				var combo_val: int = int(ev.get("combo", 1))
				var col: Color = _enemy_color(kind)
				var is_boss: bool = (kind == "boss")

				_hitstop = maxf(_hitstop, 0.12 if is_boss else 0.055)
				_add_trauma(0.95 if is_boss else 0.48)
				_cam_zoom = maxf(_cam_zoom, 1.09 if is_boss else 1.045)

				var burst_count: int = 38 if is_boss else 18
				_spawn_burst(pos, col, burst_count, 165.0 if is_boss else 125.0, 0.65 if is_boss else 0.48)
				_spawn_burst(pos, COLOR_WHITE, 12 if is_boss else 6, 95.0, 0.32)
				_spawn_ring(pos, col, 4.0, TILE_SIZE * (1.8 if is_boss else 0.95), 0.36 if is_boss else 0.26)

				if is_boss:
					_screen_flash = 0.55
					_screen_flash_color = Color(1.0, 0.88, 0.45, 0.42)
					_spawn_float_text(pos + Vector2(0, -14), "¡JEFE DERROTADO!", COLOR_CRIT, 16)
				elif combo_val >= 2:
					_spawn_float_text(pos + Vector2(0, -14), "COMBO x%d!" % combo_val, COLOR_CRIT, 15)
				else:
					_spawn_float_text(pos + Vector2(0, -10), "KO!", COLOR_COIN, 14)

			"heal":
				var pos: Vector2 = _tile_center(ev["pos"])
				_spawn_float_text(pos, "+%d HP" % ev["amount"], COLOR_HEAL, 15)
				_hero_scale = Vector2(0.85, 1.2)
				_spawn_ring(pos, COLOR_HEAL, 4.0, TILE_SIZE * 0.9, 0.38)
				_spawn_rising_sparkles(pos, COLOR_HEAL, 12)

			"pickup":
				var pos: Vector2 = _tile_center(ev["pos"])
				var col: Color = ev["color"]
				var kind: String = ev.get("kind", "")
				_spawn_float_text(pos, ev["text"], col, 15 if kind == "key" else 14)
				_hero_scale = Vector2(0.86, 1.18)
				_spawn_ring(pos, col, 4.0, TILE_SIZE * (1.15 if kind == "key" else 0.75), 0.32)
				_spawn_rising_sparkles(pos, col, 16 if kind == "key" else 9)
				if kind == "key":
					_add_trauma(0.32)
					_cam_zoom = maxf(_cam_zoom, 1.04)
					_screen_flash = 0.25
					_screen_flash_color = Color(1.0, 0.90, 0.40, 0.22)
					# Also pulse the unlocked exit!
					var exit_w: Vector2 = _tile_center(logic.exit_pos)
					_spawn_ring(exit_w, COLOR_EXIT_OPEN, 6.0, TILE_SIZE * 1.4, 0.55)
					_spawn_rising_sparkles(exit_w, COLOR_EXIT_OPEN, 16)

			"weapon_swap":
				var pos: Vector2 = _tile_center(ev["pos"])
				var col: Color = ev["color"]
				_spawn_float_text(pos, ev["text"], col, 13)
				_hero_scale = Vector2(1.14, 0.88)
				_spawn_ring(pos, col, 3.0, TILE_SIZE * 0.6, 0.20)

			"level_clear":
				var pos: Vector2 = _tile_center(ev["pos"])
				_screen_flash = 0.45
				_screen_flash_color = Color(1.0, 0.92, 0.55, 0.35)
				_spawn_ring(pos, COLOR_EXIT_OPEN, 6.0, TILE_SIZE * 1.9, 0.50)
				_spawn_burst(pos, COLOR_EXIT_OPEN, 28, 160.0, 0.70)

			"player_died":
				var pos: Vector2 = _tile_center(ev["pos"])
				_add_trauma(1.0)
				_hitstop = 0.10
				_damage_vignette = 1.0
				_spawn_burst(pos, COLOR_DAMAGE, 28, 140.0, 0.75)
				_spawn_ring(pos, COLOR_DAMAGE, 4.0, TILE_SIZE * 1.5, 0.45)

	queue_redraw()


func _add_trauma(amount: float) -> void:
	_shake_trauma = minf(1.0, _shake_trauma + amount)


func _enemy_color(kind: String) -> Color:
	match kind:
		"slime":
			return COLOR_SLIME
		"skeleton":
			return COLOR_SKELETON
		"bat":
			return COLOR_BAT
		"knight":
			return COLOR_KNIGHT
		"boss":
			return COLOR_BOSS
		_:
			return COLOR_SKELETON


func _item_color(kind: String) -> Color:
	if DungeonLogic.WEAPONS.has(kind):
		return DungeonLogic.WEAPONS[kind]["color"]
	match kind:
		"coin":
			return COLOR_COIN
		"potion":
			return COLOR_POTION
		"key":
			return COLOR_KEY
		_:
			return COLOR_WHITE


func _spawn_float_text(world_pos: Vector2, text: String, color: Color, font_size: int = 14) -> void:
	_floating_texts.append({
		"pos": world_pos + Vector2(_rng.randf_range(-4.0, 4.0), -TILE_SIZE * 0.35),
		"text": text,
		"color": color,
		"size": font_size,
		"life": 0.90,
		"max_life": 0.90,
	})


func _spawn_dust(world_pos: Vector2, dir: Vector2, count: int) -> void:
	for i in range(count):
		var spread := Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-20.0, 12.0))
		_particles.append({
			"pos": world_pos + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-3.0, 3.0)),
			"vel": dir * _rng.randf_range(16.0, 42.0) + spread,
			"color": Color(0.85, 0.85, 0.82, 0.75),
			"size": _rng.randf_range(2.5, 4.5),
			"life": _rng.randf_range(0.18, 0.32),
			"max_life": 0.32,
			"gravity": 35.0,
			"drag": 4.5,
		})


func _spawn_burst(world_pos: Vector2, color: Color, count: int, speed: float, duration: float, bias: Vector2 = Vector2.ZERO) -> void:
	for i in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var spd: float = _rng.randf_range(speed * 0.35, speed)
		var vel: Vector2 = Vector2(cos(angle), sin(angle)) * spd + bias * (speed * 0.45)
		var life: float = _rng.randf_range(duration * 0.65, duration)
		_particles.append({
			"pos": world_pos + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0)),
			"vel": vel,
			"color": color,
			"size": _rng.randf_range(3.0, 6.0),
			"life": life,
			"max_life": life,
			"gravity": 170.0,
			"drag": 2.8,
		})


func _spawn_rising_sparkles(world_pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var life: float = _rng.randf_range(0.35, 0.65)
		_particles.append({
			"pos": world_pos + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-8.0, 12.0)),
			"vel": Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-68.0, -28.0)),
			"color": color,
			"size": _rng.randf_range(2.5, 4.5),
			"life": life,
			"max_life": life,
			"gravity": -12.0,
			"drag": 1.6,
		})


func _spawn_ring(world_pos: Vector2, color: Color, start_r: float, end_r: float, duration: float) -> void:
	_rings.append({
		"pos": world_pos,
		"color": color,
		"start_r": start_r,
		"end_r": end_r,
		"life": duration,
		"max_life": duration,
	})


func _process(delta: float) -> void:
	_time += delta

	# Screen flash & banner always tick smoothly
	if _screen_flash > 0.0:
		_screen_flash = maxf(0.0, _screen_flash - delta * 2.2)
	if _damage_vignette > 0.0:
		_damage_vignette = maxf(0.0, _damage_vignette - delta * 2.4)
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)

	# Hitstop freezes entity/camera motion briefly for crunchy impact
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - delta)
		queue_redraw()
		return

	if logic != null:
		var hero_target: Vector2 = _tile_center(logic.player_pos)
		_hero_vis_pos = _hero_vis_pos.lerp(hero_target, minf(1.0, delta * 22.0))
		var look_ahead := Vector2(logic.player_facing.x, logic.player_facing.y) * 10.0
		_cam_pos = _cam_pos.lerp(hero_target + look_ahead, minf(1.0, delta * 10.5))

		# Sync active enemies
		var active_ids: Dictionary = {}
		for enemy in logic.enemies:
			var eid: int = int(enemy["id"])
			active_ids[eid] = true
			var target_p: Vector2 = _tile_center(enemy["pos"])
			if not _enemy_vis_pos.has(eid):
				_enemy_vis_pos[eid] = target_p
				_enemy_hop[eid] = 0.0
				_enemy_scale[eid] = Vector2.ONE
				_enemy_lunge[eid] = Vector2.ZERO
				_enemy_flash[eid] = 0.0
			else:
				_enemy_vis_pos[eid] = _enemy_vis_pos[eid].lerp(target_p, minf(1.0, delta * 19.0))
				_enemy_hop[eid] = maxf(0.0, float(_enemy_hop[eid]) - delta * 5.8)
				_enemy_scale[eid] = _enemy_scale[eid].lerp(Vector2.ONE, minf(1.0, delta * 16.0))
				_enemy_lunge[eid] = _enemy_lunge[eid].lerp(Vector2.ZERO, minf(1.0, delta * 20.0))
				_enemy_flash[eid] = maxf(0.0, float(_enemy_flash[eid]) - delta)

		# Prune dead enemy anim entries
		for eid in _enemy_vis_pos.keys():
			if not active_ids.has(eid):
				_enemy_vis_pos.erase(eid)
				_enemy_hop.erase(eid)
				_enemy_scale.erase(eid)
				_enemy_lunge.erase(eid)
				_enemy_flash.erase(eid)

		# Exit sparkles when unlocked
		if logic.has_key:
			_exit_sparkle_accum += delta
			if _exit_sparkle_accum >= 0.18:
				_exit_sparkle_accum = 0.0
				_spawn_rising_sparkles(_tile_center(logic.exit_pos), COLOR_EXIT_OPEN, 1)

		# Ambient floating dungeon motes
		var map_w: float = logic.width * TILE_SIZE
		var map_h: float = logic.height * TILE_SIZE
		for mote in _ambient_motes:
			mote["pos"] += mote["vel"] * delta
			var mp: Vector2 = mote["pos"]
			if mp.y < TILE_SIZE * 0.5:
				mp.y = map_h - TILE_SIZE * 0.5
				mp.x = _rng.randf_range(TILE_SIZE, map_w - TILE_SIZE)
			if mp.x < TILE_SIZE * 0.5:
				mp.x = map_w - TILE_SIZE * 0.5
			elif mp.x > map_w - TILE_SIZE * 0.5:
				mp.x = TILE_SIZE * 0.5
			mote["pos"] = mp

	# Decay hero & camera springs
	_hero_hop = maxf(0.0, _hero_hop - delta * 6.0)
	_hero_scale = _hero_scale.lerp(Vector2.ONE, minf(1.0, delta * 16.0))
	_hero_lunge = _hero_lunge.lerp(Vector2.ZERO, minf(1.0, delta * 22.0))
	_hero_flash = maxf(0.0, _hero_flash - delta)
	_cam_zoom = lerpf(_cam_zoom, 1.0, minf(1.0, delta * 12.0))
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.5)

	# Update particles
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove_at(i)
			continue
		var v: Vector2 = p["vel"]
		v.y += float(p["gravity"]) * delta
		v = v.lerp(Vector2.ZERO, minf(1.0, float(p["drag"]) * delta))
		p["vel"] = v
		p["pos"] += v * delta

	# Update rings
	for i in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[i]
		r["life"] -= delta
		if r["life"] <= 0.0:
			_rings.remove_at(i)

	# Update weapon VFX
	for i in range(_weapon_vfx.size() - 1, -1, -1):
		var vfx: Dictionary = _weapon_vfx[i]
		vfx["life"] -= delta
		if vfx["life"] <= 0.0:
			_weapon_vfx.remove_at(i)

	# Update floating texts
	for i in range(_floating_texts.size() - 1, -1, -1):
		var ft: Dictionary = _floating_texts[i]
		ft["life"] -= delta
		ft["pos"] += Vector2(0, -30.0 * delta)
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


func _world_to_screen(world_pos: Vector2, cam_origin: Vector2) -> Vector2:
	return size * 0.5 + (world_pos - _cam_pos) * _cam_zoom + cam_origin


func _draw_sprite_centered(tex: Texture2D, center: Vector2, draw_size: Vector2, color: Color) -> void:
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	draw_texture_rect(tex, rect, false, color)


func _torch_factor(cell: Vector2i) -> float:
	if logic == null:
		return 1.0
	var d: float = Vector2(cell - logic.player_pos).length()
	var flicker: float = sin(_time * 8.5 + cell.x * 0.7 + cell.y * 0.5) * 0.03
	var falloff: float = clampf(1.06 - d * 0.075, 0.54, 1.0)
	return clampf(falloff + flicker, 0.50, 1.0)


func _draw() -> void:
	var theme: Dictionary = logic.get_level_theme() if logic != null else {
		"bg": Color(0.051, 0.051, 0.063, 1.0),
		"wall": Color(0.92, 0.92, 0.87, 1.0),
		"floor": Color(0.20, 0.20, 0.25, 1.0),
		"mote": Color(0.8, 0.8, 0.8, 0.4),
	}
	draw_rect(Rect2(Vector2.ZERO, size), theme["bg"], true)
	if logic == null or sprites.is_empty():
		return

	var shake_mag: float = _shake_trauma * _shake_trauma * 13.0
	var shake_offset := Vector2.ZERO
	if shake_mag > 0.05:
		shake_offset = Vector2(
			sin(_time * 78.0) * shake_mag,
			cos(_time * 67.0) * shake_mag
		)

	var tile_px: float = TILE_SIZE * _cam_zoom

	# 1. Draw tiles with subtle torchlight falloff
	for y in range(logic.height):
		for x in range(logic.width):
			var cell := Vector2i(x, y)
			var screen_center: Vector2 = _world_to_screen(_tile_center(cell), shake_offset)
			var rect := Rect2(screen_center - Vector2(tile_px, tile_px) * 0.5, Vector2(tile_px + 0.5, tile_px + 0.5))
			if rect.end.x < -8 or rect.position.x > size.x + 8 or rect.end.y < -8 or rect.position.y > size.y + 8:
				continue
			var light: float = _torch_factor(cell)
			var tile: int = logic.tiles[y][x]
			match tile:
				DungeonLogic.Tile.WALL:
					var wc: Color = theme["wall"]
					draw_texture_rect(sprites["wall"], rect, false, Color(wc.r * light, wc.g * light, wc.b * light, 1.0))
				DungeonLogic.Tile.FLOOR:
					var fc: Color = theme["floor"]
					draw_texture_rect(sprites["floor"], rect, false, Color(fc.r * light, fc.g * light, fc.b * light, 1.0))
				DungeonLogic.Tile.EXIT_LOCKED:
					draw_texture_rect(sprites["exit_locked"], rect, false, COLOR_EXIT_LOCKED * Color(light, light, light, 1.0))
				DungeonLogic.Tile.EXIT_OPEN:
					var pulse: float = 0.82 + 0.18 * sin(_time * 6.0)
					draw_texture_rect(sprites["exit_open"], rect, false, COLOR_EXIT_OPEN * Color(pulse, pulse, pulse, 1.0))

	# 2. Draw ambient dungeon motes
	var mote_col: Color = theme["mote"]
	for mote in _ambient_motes:
		var sp: Vector2 = _world_to_screen(mote["pos"], shake_offset)
		if sp.x < 0 or sp.x > size.x or sp.y < 0 or sp.y > size.y:
			continue
		var pulse_a: float = 0.55 + 0.45 * sin(_time * 2.5 + float(mote["phase"]))
		var c := Color(mote_col.r, mote_col.g, mote_col.b, mote_col.a * pulse_a)
		var sz: float = float(mote["size"]) * _cam_zoom
		draw_rect(Rect2(sp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c, true)

	# 3. Draw items with gentle bob & subtle glow
	var item_bob: float = sin(_time * 4.5) * 2.4
	for item in logic.items:
		var pos: Vector2i = item["pos"]
		var kind: String = item["kind"]
		var col: Color = _item_color(kind)
		var sp: Vector2 = _world_to_screen(_tile_center(pos) + Vector2(0, item_bob), shake_offset)
		if sprites.has(kind):
			var glow_r: float = (10.0 + 2.5 * sin(_time * 5.0 + pos.x)) * _cam_zoom
			draw_circle(sp, glow_r, Color(col.r, col.g, col.b, 0.12))
			_draw_sprite_centered(sprites[kind], sp, Vector2(tile_px, tile_px), col)

	# 4. Draw enemies with smooth hop, squash/stretch, hit-flash & HP bar
	for enemy in logic.enemies:
		var eid: int = int(enemy["id"])
		var kind: String = enemy["kind"]
		var vis_p: Vector2 = _enemy_vis_pos.get(eid, _tile_center(enemy["pos"]))
		var hop_t: float = float(_enemy_hop.get(eid, 0.0))
		var hop_y: float = -sin(hop_t * PI) * 7.5
		var idle_bob: float = sin(_time * (10.0 if kind == "bat" else 5.5) + eid) * (2.6 if kind == "bat" else 1.4)
		var lunge: Vector2 = _enemy_lunge.get(eid, Vector2.ZERO)
		var sc: Vector2 = _enemy_scale.get(eid, Vector2.ONE)
		var flash_t: float = float(_enemy_flash.get(eid, 0.0))

		var sp: Vector2 = _world_to_screen(vis_p + lunge + Vector2(0, hop_y + idle_bob), shake_offset)
		var size_mul: float = 1.16 if kind == "boss" else 1.0
		var draw_sz := Vector2(tile_px * sc.x * size_mul, tile_px * sc.y * size_mul)

		# Ground shadow
		var shadow_sp: Vector2 = _world_to_screen(vis_p + Vector2(0, TILE_SIZE * 0.36), shake_offset)
		draw_rect(Rect2(shadow_sp - Vector2(tile_px * 0.28, 2.0), Vector2(tile_px * 0.56, 4.0)), Color(0, 0, 0, 0.38), true)

		var col: Color = COLOR_WHITE if flash_t > 0.0 else _enemy_color(kind)
		_draw_sprite_centered(sprites[kind], sp, draw_sz, col)

		if enemy["hp"] < enemy["max_hp"] or kind == "boss":
			var ratio: float = clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
			var bar_w: float = (tile_px - 4.0) if kind == "boss" else (tile_px - 8.0)
			var bar_pos: Vector2 = sp + Vector2(-bar_w * 0.5, -tile_px * 0.54)
			draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2, 6)), Color(0.05, 0.05, 0.07, 0.9), true)
			draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, 4)), COLOR_BOSS if kind == "boss" else COLOR_DAMAGE, true)

	# 5. Draw hero with hop, squash/stretch, lunge & equipped weapon tint indicator
	var hero_hop_y: float = -sin(_hero_hop * PI) * 8.0
	var hero_bob: float = sin(_time * 5.0) * 1.1
	var hero_sp: Vector2 = _world_to_screen(_hero_vis_pos + _hero_lunge + Vector2(0, hero_hop_y + hero_bob), shake_offset)
	var hero_shadow: Vector2 = _world_to_screen(_hero_vis_pos + Vector2(0, TILE_SIZE * 0.36), shake_offset)
	draw_rect(Rect2(hero_shadow - Vector2(tile_px * 0.28, 2.0), Vector2(tile_px * 0.56, 4.0)), Color(0, 0, 0, 0.42), true)

	# Subtle torchlight aura around hero
	draw_circle(hero_sp, tile_px * 1.25, Color(1.0, 0.95, 0.80, 0.055))
	var hero_col: Color = COLOR_DAMAGE if _hero_flash > 0.0 else COLOR_HERO
	_draw_sprite_centered(sprites["hero"], hero_sp, Vector2(tile_px * _hero_scale.x, tile_px * _hero_scale.y), hero_col)

	# 6. Draw shockwave rings
	for r in _rings:
		var t: float = 1.0 - clampf(float(r["life"]) / float(r["max_life"]), 0.0, 1.0)
		var rad: float = lerpf(float(r["start_r"]), float(r["end_r"]), 1.0 - pow(1.0 - t, 2.0)) * _cam_zoom
		var col: Color = r["color"]
		col.a = (1.0 - t) * 0.85
		draw_arc(_world_to_screen(r["pos"], shake_offset), rad, 0.0, TAU, 24, col, maxf(1.5, (1.0 - t) * 3.5))

	# 7. Draw weapon-specific slash / thrust / cleave / bolt VFX
	for vfx in _weapon_vfx:
		_draw_weapon_vfx(vfx, shake_offset)

	# 8. Draw pixel particles
	for p in _particles:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= alpha
		var sz: float = float(p["size"]) * (0.45 + 0.55 * alpha) * _cam_zoom
		var sp: Vector2 = _world_to_screen(p["pos"], shake_offset)
		draw_rect(Rect2(sp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col, true)

	# 9. Draw floating combat / pickup texts with crisp shadow
	var font: Font = ThemeDB.fallback_font
	for ft in _floating_texts:
		var t: float = clampf(float(ft["life"]) / float(ft["max_life"]), 0.0, 1.0)
		var col: Color = ft["color"]
		col.a = minf(1.0, t * 1.4)
		var fsize: int = int(ft["size"])
		var sp: Vector2 = _world_to_screen(ft["pos"], shake_offset)
		var shadow_col := Color(0.02, 0.02, 0.03, col.a * 0.9)
		draw_string(font, sp + Vector2(-59, 1), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 120.0, fsize, shadow_col)
		draw_string(font, sp + Vector2(-60, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 120.0, fsize, col)

	# 10. Low-HP pulsing red edge warning + hit vignette
	var low_hp_pulse: float = 0.0
	if logic.player_hp > 0 and float(logic.player_hp) / float(logic.player_max_hp) <= 0.30:
		low_hp_pulse = 0.16 + 0.14 * (0.5 + 0.5 * sin(_time * 6.5))
	var vig_a: float = maxf(_damage_vignette * 0.38, low_hp_pulse)
	if vig_a > 0.01:
		var edge: float = 8.0
		var vc := Color(0.95, 0.15, 0.18, vig_a)
		draw_rect(Rect2(0, 0, size.x, edge), vc, true)
		draw_rect(Rect2(0, size.y - edge, size.x, edge), vc, true)
		draw_rect(Rect2(0, edge, edge, size.y - edge * 2.0), vc, true)
		draw_rect(Rect2(size.x - edge, edge, edge, size.y - edge * 2.0), vc, true)

	# 11. Screen flash overlay
	if _screen_flash > 0.01:
		var fc := _screen_flash_color
		fc.a *= _screen_flash
		draw_rect(Rect2(Vector2.ZERO, size), fc, true)

	# 12. Floor entry banner
	if _banner_timer > 0.0:
		var progress: float = 1.0 - (_banner_timer / _banner_max)
		var alpha: float = 1.0
		if progress < 0.15:
			alpha = progress / 0.15
		elif progress > 0.72:
			alpha = (1.0 - progress) / 0.28
		alpha = clampf(alpha, 0.0, 1.0)
		var banner_h: float = 48.0
		var banner_y: float = 12.0 + (1.0 - alpha) * -8.0
		draw_rect(Rect2(14.0, banner_y, size.x - 28.0, banner_h), Color(0.05, 0.05, 0.07, 0.85 * alpha), true)
		draw_rect(Rect2(14.0, banner_y, size.x - 28.0, banner_h), Color(theme["wall"].r, theme["wall"].g, theme["wall"].b, 0.85 * alpha), false, 2.0)
		draw_string(font, Vector2(14.0, banner_y + 20.0), _banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 28.0, 13, Color(0.98, 0.85, 0.35, alpha))
		draw_string(font, Vector2(14.0, banner_y + 39.0), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, size.x - 28.0, 14, Color(0.96, 0.96, 0.92, alpha))

	# 13. Crisp 1-bit frame border around viewport
	var border_col: Color = theme["wall"]
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(border_col.r, border_col.g, border_col.b, 0.40), false, 2.0)


func _draw_weapon_vfx(vfx: Dictionary, shake_offset: Vector2) -> void:
	var t: float = 1.0 - clampf(float(vfx["life"]) / float(vfx["max_life"]), 0.0, 1.0)
	var alpha: float = 1.0 - t
	var col: Color = vfx["color"]
	col.a = alpha
	var from_s: Vector2 = _world_to_screen(vfx["from"], shake_offset)
	var to_s: Vector2 = _world_to_screen(vfx["to"], shake_offset)
	var dir: Vector2 = vfx["dir"]
	var angle: float = atan2(dir.y, dir.x)
	var weapon: String = vfx["weapon"]

	match weapon:
		"sword":
			draw_arc(from_s, TILE_SIZE * 0.95 * _cam_zoom, angle - 0.85, angle + 0.85, 12, col, 4.5 * alpha)
			draw_arc(from_s, TILE_SIZE * 0.78 * _cam_zoom, angle - 0.65, angle + 0.65, 10, Color(1, 1, 1, alpha * 0.85), 2.5 * alpha)
		"dagger":
			var r: float = TILE_SIZE * 0.42 * _cam_zoom
			draw_line(to_s + Vector2(-r, -r), to_s + Vector2(r, r), col, 3.5 * alpha)
			draw_line(to_s + Vector2(r, -r), to_s + Vector2(-r, r), Color(1, 1, 1, alpha), 3.0 * alpha)
		"spear":
			var tip: Vector2 = from_s.lerp(to_s + dir * (TILE_SIZE * 0.35 * _cam_zoom), minf(1.0, t * 2.5 + 0.4))
			draw_line(from_s, tip, col, 5.0 * alpha)
			draw_line(from_s, tip, Color(1, 1, 1, alpha), 2.2 * alpha)
		"axe":
			draw_arc(from_s, TILE_SIZE * 1.18 * _cam_zoom, angle - 1.55, angle + 1.55, 18, col, 7.0 * alpha)
			draw_arc(from_s, TILE_SIZE * 0.96 * _cam_zoom, angle - 1.35, angle + 1.35, 16, Color(1, 1, 1, alpha * 0.9), 3.0 * alpha)
		"staff":
			var bolt_pos: Vector2 = from_s.lerp(to_s, minf(1.0, t * 2.2))
			draw_line(from_s, to_s, Color(col.r, col.g, col.b, alpha * 0.55), 3.0 * alpha)
			draw_circle(bolt_pos, (7.0 * alpha + 2.0) * _cam_zoom, col)
			draw_circle(bolt_pos, (3.5 * alpha + 1.0) * _cam_zoom, Color(1, 1, 1, alpha))

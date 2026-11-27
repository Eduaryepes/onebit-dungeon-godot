extends Control

## Main scene controller for OneBit Dungeon.
## Connects HUD, D-Pad buttons, swipe gestures, keyboard input, weapon cycling,
## multi-level progression, procedural 8-bit audio, and Win/Game Over overlay.

@onready var title_label: Label = %TitleLabel
@onready var mute_btn: Button = %MuteButton
@onready var hp_label: Label = %HpLabel
@onready var atk_label: Label = %AtkLabel
@onready var coin_label: Label = %CoinLabel
@onready var key_label: Label = %KeyLabel
@onready var log_label: Label = %LogLabel
@onready var weapon_btn: Button = %WeaponButton
@onready var potion_btn: Button = %PotionButton
@onready var board: DungeonBoard = %DungeonBoard
@onready var overlay: PanelContainer = %EndOverlay
@onready var overlay_title: Label = %EndTitle
@onready var overlay_stats: Label = %EndStats
@onready var next_level_btn: Button = %NextLevelButton

var logic: DungeonLogic
var sfx: SfxManager


func _ready() -> void:
	sfx = SfxManager.new()
	add_child(sfx)

	logic = DungeonLogic.new()
	board.bind_logic(logic)
	board.swipe_direction.connect(_on_move)

	%UpButton.pressed.connect(_on_move.bind(Vector2i.UP))
	%DownButton.pressed.connect(_on_move.bind(Vector2i.DOWN))
	%LeftButton.pressed.connect(_on_move.bind(Vector2i.LEFT))
	%RightButton.pressed.connect(_on_move.bind(Vector2i.RIGHT))
	%WaitButton.pressed.connect(_on_wait)
	weapon_btn.pressed.connect(_on_cycle_weapon)
	potion_btn.pressed.connect(_on_potion)
	next_level_btn.pressed.connect(_on_next_level)
	%RestartButton.pressed.connect(_on_restart)
	%TopRestartButton.pressed.connect(_on_restart)
	mute_btn.pressed.connect(_on_toggle_mute)

	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if logic.state == DungeonLogic.State.LEVEL_CLEAR:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_next_level()
			return
	match event.keycode:
		KEY_UP, KEY_W:
			_on_move(Vector2i.UP)
		KEY_DOWN, KEY_S:
			_on_move(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			_on_move(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			_on_move(Vector2i.RIGHT)
		KEY_SPACE:
			_on_wait()
		KEY_Q, KEY_TAB:
			_on_cycle_weapon()
		KEY_H:
			_on_potion()
		KEY_M:
			_on_toggle_mute()
		KEY_R:
			_on_restart()


func _on_move(dir: Vector2i) -> void:
	var acted: bool = logic.step_move(dir)
	if acted or not logic.turn_events.is_empty():
		board.consume_turn_events()
		_play_events_sfx()
	_refresh_ui()


func _on_wait() -> void:
	if logic.step_wait():
		board.consume_turn_events()
		_play_events_sfx()
	_refresh_ui()


func _on_cycle_weapon() -> void:
	if logic.cycle_weapon():
		board.consume_turn_events()
		_play_events_sfx()
		_pulse_control(weapon_btn)
	else:
		sfx.play("wall_bump", 1.3, -10.0)
	_refresh_ui()


func _on_potion() -> void:
	if logic.use_potion():
		board.consume_turn_events()
		_play_events_sfx()
		_pulse_control(hp_label)
	else:
		sfx.play("wall_bump", 1.2, -10.0)
	_refresh_ui()


func _on_next_level() -> void:
	if logic.next_level():
		sfx.play("ui_click")
		board.bind_logic(logic, true)
	_refresh_ui()


func _on_restart() -> void:
	sfx.play("ui_click")
	logic.reset(0)
	board.bind_logic(logic, true)
	_refresh_ui()


func _on_toggle_mute() -> void:
	var is_muted: bool = sfx.toggle_mute()
	mute_btn.text = "OFF" if is_muted else "SFX"
	mute_btn.modulate = Color(0.65, 0.65, 0.70) if is_muted else Color(0.95, 0.95, 0.90)


func _play_events_sfx() -> void:
	if sfx == null:
		return
	var rng_pitch: float = randf_range(0.94, 1.07)
	for ev in logic.turn_events:
		match ev["type"]:
			"move":
				sfx.play("step", rng_pitch, -9.0)
			"wall_bump":
				sfx.play("wall_bump", rng_pitch, -8.0)
			"player_attack":
				var weapon: String = ev["weapon"]
				sfx.play("attack_" + weapon, rng_pitch, -4.0)
				if bool(ev.get("crit", false)):
					sfx.play("crit", 1.0, -2.0)
			"damage":
				if ev["target"] == "player":
					sfx.play("player_hurt", rng_pitch, -2.0)
					_pulse_control(hp_label)
				else:
					sfx.play("hit_enemy", rng_pitch, -5.0)
			"enemy_died":
				var kind: String = ev["kind"]
				var combo_val: int = int(ev.get("combo", 1))
				if kind == "boss":
					sfx.play("boss_die", 1.0, -1.0)
				else:
					var combo_pitch: float = minf(1.55, 1.0 + (combo_val - 1) * 0.12)
					sfx.play("enemy_die", combo_pitch, -3.0)
			"pickup":
				var kind: String = ev.get("kind", "")
				if DungeonLogic.WEAPONS.has(kind):
					sfx.play("pickup_weapon", 1.0, -3.0)
					_pulse_control(weapon_btn)
				elif kind == "key":
					sfx.play("pickup_key", 1.0, -2.0)
					_pulse_control(key_label)
				elif kind == "potion":
					sfx.play("pickup_potion", 1.0, -4.0)
					_pulse_control(potion_btn)
				else:
					sfx.play("pickup_coin", rng_pitch, -5.0)
					_pulse_control(coin_label)
			"heal":
				sfx.play("heal", 1.0, -3.0)
			"weapon_swap":
				sfx.play("weapon_swap", rng_pitch, -6.0)
			"level_clear":
				sfx.play("level_clear", 1.0, -2.0)
			"player_died":
				sfx.play("game_over", 1.0, -2.0)


func _pulse_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.14, 1.14), 0.06)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.12)


func _refresh_ui() -> void:
	title_label.text = "NV %d/%d • %s" % [
		logic.current_level + 1,
		logic.total_levels(),
		logic.get_level_name().to_upper(),
	]
	hp_label.text = "HP %d/%d" % [logic.player_hp, logic.player_max_hp]
	atk_label.text = "ATK %d" % logic.player_atk
	if logic.combo >= 2:
		coin_label.text = "ORO %d x%d" % [logic.coins, logic.combo]
	else:
		coin_label.text = "ORO %d" % logic.coins
	key_label.text = "LLAVE: SI" if logic.has_key else "LLAVE: NO"
	key_label.modulate = Color(0.98, 0.82, 0.25) if logic.has_key else Color(0.65, 0.65, 0.70)

	var w_info: Dictionary = logic.get_weapon_info()
	var arsenal_suffix: String = " [%d]" % logic.unlocked_weapons.size() if logic.unlocked_weapons.size() > 1 else ""
	weapon_btn.text = "%s (%d)%s" % [logic.get_weapon_display_name(), logic.player_atk, arsenal_suffix]
	weapon_btn.add_theme_color_override("font_color", w_info["color"])
	weapon_btn.disabled = logic.state != DungeonLogic.State.PLAYING

	potion_btn.text = "POCIÓN (%d)" % logic.potions
	potion_btn.disabled = logic.potions <= 0 or logic.state != DungeonLogic.State.PLAYING
	log_label.text = logic.last_message

	if logic.state == DungeonLogic.State.LEVEL_CLEAR:
		overlay.visible = true
		next_level_btn.visible = true
		overlay_title.text = "¡NIVEL %d COMPLETADO!" % (logic.current_level + 1)
		overlay_title.modulate = Color(0.98, 0.85, 0.30)
		overlay_stats.text = "Turnos: %d  |  Oro: %d\nEnemigos: %d  |  HP: %d/%d" % [
			logic.turns, logic.coins, logic.kills, logic.player_hp, logic.player_max_hp
		]
	elif logic.state == DungeonLogic.State.WON:
		overlay.visible = true
		next_level_btn.visible = false
		overlay_title.text = "¡MAZMORRA CONQUISTADA!"
		overlay_title.modulate = Color(0.98, 0.85, 0.30)
		overlay_stats.text = "5/5 Niveles  |  Turnos: %d\nOro: %d  |  Enemigos: %d" % [
			logic.turns, logic.coins, logic.kills
		]
	elif logic.state == DungeonLogic.State.LOST:
		overlay.visible = true
		next_level_btn.visible = false
		overlay_title.text = "HAS CAÍDO"
		overlay_title.modulate = Color(0.95, 0.35, 0.35)
		overlay_stats.text = "Nivel %d/%d  |  Turnos: %d\nOro: %d  |  Enemigos: %d" % [
			logic.current_level + 1, logic.total_levels(), logic.turns, logic.coins, logic.kills
		]
	else:
		overlay.visible = false
		next_level_btn.visible = false

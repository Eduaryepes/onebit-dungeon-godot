extends Control

## Main scene controller for OneBit Dungeon.
## Connects HUD, D-Pad buttons, swipe gestures, keyboard input, and Win/Game Over overlay.

@onready var hp_label: Label = %HpLabel
@onready var atk_label: Label = %AtkLabel
@onready var coin_label: Label = %CoinLabel
@onready var key_label: Label = %KeyLabel
@onready var log_label: Label = %LogLabel
@onready var potion_btn: Button = %PotionButton
@onready var board: DungeonBoard = %DungeonBoard
@onready var overlay: PanelContainer = %EndOverlay
@onready var overlay_title: Label = %EndTitle
@onready var overlay_stats: Label = %EndStats

var logic: DungeonLogic


func _ready() -> void:
	logic = DungeonLogic.new()
	board.bind_logic(logic)
	board.swipe_direction.connect(_on_move)

	%UpButton.pressed.connect(_on_move.bind(Vector2i.UP))
	%DownButton.pressed.connect(_on_move.bind(Vector2i.DOWN))
	%LeftButton.pressed.connect(_on_move.bind(Vector2i.LEFT))
	%RightButton.pressed.connect(_on_move.bind(Vector2i.RIGHT))
	%WaitButton.pressed.connect(_on_wait)
	potion_btn.pressed.connect(_on_potion)
	%RestartButton.pressed.connect(_on_restart)
	%TopRestartButton.pressed.connect(_on_restart)

	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
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
		KEY_H:
			_on_potion()
		KEY_R:
			_on_restart()


func _on_move(dir: Vector2i) -> void:
	if logic.step_move(dir):
		board.consume_turn_events()
	_refresh_ui()


func _on_wait() -> void:
	if logic.step_wait():
		board.consume_turn_events()
	_refresh_ui()


func _on_potion() -> void:
	if logic.use_potion():
		board.consume_turn_events()
	_refresh_ui()


func _on_restart() -> void:
	logic.reset()
	board.bind_logic(logic)
	_refresh_ui()


func _refresh_ui() -> void:
	hp_label.text = "HP %d/%d" % [logic.player_hp, logic.player_max_hp]
	atk_label.text = "ATK %d" % logic.player_atk
	coin_label.text = "ORO %d" % logic.coins
	key_label.text = "LLAVE: SI" if logic.has_key else "LLAVE: NO"
	key_label.modulate = Color(0.98, 0.82, 0.25) if logic.has_key else Color(0.65, 0.65, 0.70)
	potion_btn.text = "POCIÓN (%d)" % logic.potions
	potion_btn.disabled = logic.potions <= 0 or logic.state != DungeonLogic.State.PLAYING
	log_label.text = logic.last_message

	if logic.state == DungeonLogic.State.WON:
		overlay.visible = true
		overlay_title.text = "¡NIVEL COMPLETADO!"
		overlay_title.modulate = Color(0.98, 0.82, 0.25)
		overlay_stats.text = "Turnos: %d  |  Oro: %d\nHP restante: %d/%d" % [
			logic.turns, logic.coins, logic.player_hp, logic.player_max_hp
		]
	elif logic.state == DungeonLogic.State.LOST:
		overlay.visible = true
		overlay_title.text = "HAS CAÍDO"
		overlay_title.modulate = Color(0.95, 0.35, 0.35)
		overlay_stats.text = "Turnos: %d  |  Oro: %d\n¡Inténtalo de nuevo!" % [
			logic.turns, logic.coins
		]
	else:
		overlay.visible = false

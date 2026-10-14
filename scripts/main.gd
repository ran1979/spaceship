extends Node2D

# Fixed playfield, centered in the viewport. HUD bar sits above it.
# Flow: PLAYING -> LEVEL_DONE (press Space) -> next level, or GAME_OVER (press Space) -> level 1.
enum State { PLAYING, LEVEL_DONE, GAME_OVER }

const FIELD_SIZE := Vector2(960, 540)
const FIELD_BG := Color(0.03, 0.03, 0.10)
const CLAIM_COLOR := Color(0.10, 0.34, 0.40)
const CLAIM_EDGE_COLOR := Color(0.55, 1.0, 0.95)
const BORDER_COLOR := Color(0.3, 0.9, 1.0)
const BORDER_WIDTH := 3.0
const TARGET_PERCENT := 75.0
const STARTING_LIVES := 3
const CRASH_INVULN := 1.0  # seconds of immunity after a crash

@onready var _player: Node2D = $Player
@onready var _hazards: Node2D = $Hazards
@onready var _hud: CanvasLayer = $HUD

var level := 1
var _state := State.PLAYING
var _claimed: Array[PackedVector2Array] = []
var _claimed_area := 0.0
var _invuln := 0.0


func _ready() -> void:
	_player.territory_claimed.connect(_on_territory_claimed)
	_start_game()


func _process(delta: float) -> void:
	if _state == State.PLAYING:
		_play(delta)
	elif Input.is_action_just_pressed("cut"):
		if _state == State.LEVEL_DONE:
			_start_level(level + 1)
		else:
			_start_game()
	_hud.update_stats(_coverage_percent(), TARGET_PERCENT, _player.lives, level)


func _draw() -> void:
	draw_rect(_field_rect(), FIELD_BG, true)
	for poly in _claimed:
		draw_colored_polygon(poly, CLAIM_COLOR)
		_draw_loop(poly, CLAIM_EDGE_COLOR)
	_draw_loop(_player.perimeter(), BORDER_COLOR)


func _play(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	_hazards.step(delta, _player.perimeter(), _player.cut_path(), _player.position)
	if _invuln <= 0.0 and _hazards.hit_test(_player.cut_path(), _player.position):
		_player.crash()
		_invuln = CRASH_INVULN
	if _player.lives <= 0:
		_game_over()


func _on_territory_claimed(poly: PackedVector2Array, area: float) -> void:
	_claimed.append(poly)
	_claimed_area += area
	_hazards.respawn_inside(poly, _player.perimeter(), _player.position)
	queue_redraw()
	if _coverage_percent() >= TARGET_PERCENT:
		_level_done()


func _start_game() -> void:
	_player.lives = STARTING_LIVES
	_start_level(1)


func _start_level(n: int) -> void:
	level = n
	_state = State.PLAYING
	_claimed.clear()
	_claimed_area = 0.0
	_invuln = 0.0
	_player.restart(_perimeter_points())
	_player.set_process(true)
	_hazards.clear()
	var cfg := _level_config(n)
	_hazards.spawn(_player.perimeter(), _player.position, cfg.stars, cfg.aliens, cfg.speed)
	_hud.hide_message()
	queue_redraw()


func _level_done() -> void:
	_state = State.LEVEL_DONE
	_player.set_process(false)
	_hud.show_message("LEVEL %d COMPLETE\n\nPress Space to continue" % level)


func _game_over() -> void:
	_state = State.GAME_OVER
	_player.set_process(false)
	_hud.show_message("GAME OVER\n\nReached level %d\n\nPress Space to restart" % level)


# Harder each level: more hazards, faster movement, one more alien every second level.
func _level_config(n: int) -> Dictionary:
	return {
		"stars": 6 + 2 * (n - 1),
		"aliens": 1 + (n - 1) / 2,
		"speed": 1.0 + 0.12 * (n - 1),
	}


func _coverage_percent() -> float:
	return _claimed_area / (FIELD_SIZE.x * FIELD_SIZE.y) * 100.0


func _draw_loop(poly: PackedVector2Array, color: Color) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, Color(color, 0.25), BORDER_WIDTH * 3.0)
	draw_polyline(closed, color, BORDER_WIDTH)


func _field_rect() -> Rect2:
	var origin := (get_viewport_rect().size - FIELD_SIZE) / 2.0
	return Rect2(origin, FIELD_SIZE)


# Clockwise corners of the field, starting top-left.
func _perimeter_points() -> PackedVector2Array:
	var r := _field_rect()
	return PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])

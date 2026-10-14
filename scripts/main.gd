extends Node2D

# Fixed playfield, centered in the viewport. HUD bar sits above it.
# Flow: PLAYING -> LEVEL_DONE (press Space) -> next level, or GAME_OVER (press Space) -> level 1.
enum State { PLAYING, LEVEL_DONE, GAME_OVER }

const FIELD_SIZE := Vector2(960, 540)
const FIELD_BG := Color(0.03, 0.03, 0.10)
const BORDER_COLOR := Color(0.3, 0.9, 1.0)
const BORDER_WIDTH := 3.0
const TARGET_BASE := 60.0  # coverage target on level 1
const TARGET_STEP := 5.0  # added per level
const TARGET_MAX := 75.0
const STARTING_LIVES := 3
const CRASH_INVULN := 1.0  # seconds of immunity after a crash
const SHIP_RADIUS := 11.0
const POWERUP_TIME := 5.0
const SPEED_MULT := 1.6
const SLOW_FACTOR := 0.5  # hazards move at this fraction of normal speed during a slow present

@onready var _player: Node2D = $Player
@onready var _hazards: Node2D = $Hazards
@onready var _presents: Node2D = $Presents
@onready var _hud: CanvasLayer = $HUD
@onready var _sfx: Node = $Sfx

var level := 1
var _state := State.PLAYING
var _claimed: Array[PackedVector2Array] = []
var _claimed_area := 0.0
var _invuln := 0.0  # crash immunity
var _shield_left := 0.0  # shield present
var _speed_left := 0.0  # speed present
var _slow_left := 0.0  # slow present


func _ready() -> void:
	_player.territory_claimed.connect(_on_territory_claimed)
	_player.cut_started.connect(_sfx.draw_start)
	_player.cut_ended.connect(_sfx.draw_stop)
	_player.crashed.connect(_sfx.crash)
	_presents.collected.connect(_on_present)
	_start_game()


func _process(delta: float) -> void:
	if _state == State.PLAYING:
		_play(delta)
	elif Input.is_action_just_pressed("cut"):
		if _state == State.LEVEL_DONE:
			_start_level(level + 1)
		else:
			_start_game()
	_hud.update_stats(_coverage_percent(), _target_percent(level), _player.lives, level, _status_text())


func _draw() -> void:
	draw_rect(_field_rect(), FIELD_BG, true)
	for poly in _claimed:
		draw_colored_polygon(poly, _claim_fill())
		_draw_loop(poly, _claim_edge())
	_draw_loop(_player.perimeter(), BORDER_COLOR)


func _play(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	_shield_left = maxf(_shield_left - delta, 0.0)
	_speed_left = maxf(_speed_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	_player.speed_mult = SPEED_MULT if _speed_left > 0.0 else 1.0
	var hazard_dt := delta * (SLOW_FACTOR if _slow_left > 0.0 else 1.0)

	_hazards.step(hazard_dt, _player.perimeter(), _player.cut_path(), _player.position)
	_presents.update(delta, _player.perimeter(), _player.position, SHIP_RADIUS)

	var can_be_hit := _invuln <= 0.0 and _shield_left <= 0.0
	if can_be_hit and _hazards.hit_test(_player.cut_path(), _player.position):
		_player.crash()
		_invuln = CRASH_INVULN
	if _player.lives <= 0:
		_game_over()


func _on_territory_claimed(poly: PackedVector2Array, area: float) -> void:
	_sfx.claim()
	_claimed.append(poly)
	_claimed_area += area
	_hazards.respawn_inside(poly, _player.perimeter(), _player.position)
	queue_redraw()
	if _coverage_percent() >= _target_percent(level):
		_level_done()


func _on_present(kind: String) -> void:
	match kind:
		"life":
			_player.lives += 1
		"shield":
			_shield_left = POWERUP_TIME
		"speed":
			_speed_left = POWERUP_TIME
		"slow":
			_slow_left = POWERUP_TIME


func _start_game() -> void:
	_player.lives = STARTING_LIVES
	_start_level(1)


func _start_level(n: int) -> void:
	level = n
	_state = State.PLAYING
	_claimed.clear()
	_claimed_area = 0.0
	_invuln = 0.0
	_shield_left = 0.0
	_speed_left = 0.0
	_slow_left = 0.0
	_player.restart(_perimeter_points())
	_player.set_process(true)
	_hazards.clear()
	_presents.clear()
	var cfg := _level_config(n)
	_hazards.spawn(_player.perimeter(), _player.position, cfg.stars, cfg.aliens, cfg.speed)
	_hud.hide_message()
	queue_redraw()


func _level_done() -> void:
	_state = State.LEVEL_DONE
	_player.set_process(false)
	_sfx.level_passed()
	_hud.show_message("LEVEL %d COMPLETE\n\nPress Space to continue" % level)


func _game_over() -> void:
	_state = State.GAME_OVER
	_player.set_process(false)
	_hud.show_message("GAME OVER\n\nReached level %d\n\nPress Space to restart" % level)


# Level 1 starts easy and each level adds hazards and speed.
func _level_config(n: int) -> Dictionary:
	return {
		"stars": 3 + 2 * (n - 1),
		"aliens": n / 2,
		"speed": 1.0 + 0.12 * (n - 1),
	}


# Each level claims in its own hue, so progress is easy to tell apart.
func _claim_hue() -> float:
	return fposmod(0.02 + (level - 1) * 0.17, 1.0)


func _claim_fill() -> Color:
	return Color.from_hsv(_claim_hue(), 0.7, 0.4)


func _claim_edge() -> Color:
	return Color.from_hsv(_claim_hue(), 0.45, 1.0)


func _target_percent(n: int) -> float:
	return minf(TARGET_BASE + TARGET_STEP * (n - 1), TARGET_MAX)


func _status_text() -> String:
	var parts := PackedStringArray()
	if _shield_left > 0.0:
		parts.append("SHIELD %ds" % ceili(_shield_left))
	if _speed_left > 0.0:
		parts.append("SPEED %ds" % ceili(_speed_left))
	if _slow_left > 0.0:
		parts.append("SLOW %ds" % ceili(_slow_left))
	return "  ".join(parts)


func _coverage_percent() -> float:
	return _claimed_area / (FIELD_SIZE.x * FIELD_SIZE.y) * 100.0


func _draw_loop(poly: PackedVector2Array, color: Color) -> void:
	if poly.is_empty():
		return
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

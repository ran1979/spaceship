extends Node2D

# Fixed playfield, centered in the viewport. HUD bar sits above it.
# Flow: MENU -> PLAYING -> LEVEL_DONE (Space) -> next level, or GAME_OVER (Space) -> MENU.
enum State { MENU, PLAYING, LEVEL_DONE, GAME_OVER }

const Scores := preload("res://scripts/scores.gd")

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
const EXTRA_LIFE_MARGIN := 5.0  # percentage points above target that earn a bonus life
const FREEZE_TIME := 5.0  # seconds all hazards stop moving after a freeze present
const POINTS_PER_PERCENT := 10  # score per percent of field claimed, times level
const LEVEL_BONUS := 1000  # times level

@onready var _player: Node2D = $Player
@onready var _hazards: Node2D = $Hazards
@onready var _presents: Node2D = $Presents
@onready var _hud: CanvasLayer = $HUD
@onready var _sfx: Node = $Sfx
@onready var _menu: CanvasLayer = $Menu

var level := 1
var _state := State.MENU
var _claimed: Array[PackedVector2Array] = []
var _claimed_area := 0.0
var _score := 0
var _score_path := Scores.SAVE_PATH  # tests point this elsewhere
var _invuln := 0.0  # crash immunity
var _shield_left := 0.0  # shield present
var _speed_left := 0.0  # speed present
var _slow_left := 0.0  # slow present
var _freeze_left := 0.0  # freeze present
var _smash_left := 0.0  # smash present


func _ready() -> void:
	_player.territory_claimed.connect(_on_territory_claimed)
	_player.cut_started.connect(_sfx.draw_start)
	_player.cut_ended.connect(_sfx.draw_stop)
	_player.crashed.connect(_sfx.crash)
	_presents.collected.connect(_on_present)
	_menu.play_pressed.connect(_start_game)
	_show_menu()


func _process(delta: float) -> void:
	if _state == State.PLAYING:
		_play(delta)
	elif Input.is_action_just_pressed("cut") or Input.is_action_just_pressed("ui_accept"):
		match _state:
			State.MENU:
				_start_game()
			State.LEVEL_DONE:
				_start_level(level + 1)
			State.GAME_OVER:
				_show_menu()
	_hud.update_stats(_coverage_percent(), _target_percent(level), _player.lives, level, _status_text(), _score)


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
	_freeze_left = maxf(_freeze_left - delta, 0.0)
	_smash_left = maxf(_smash_left - delta, 0.0)
	_player.speed_mult = SPEED_MULT if _speed_left > 0.0 else 1.0
	var hazard_dt := delta * (SLOW_FACTOR if _slow_left > 0.0 else 1.0)
	if _freeze_left > 0.0:
		hazard_dt = 0.0

	_hazards.step(hazard_dt, _player.perimeter(), _player.cut_path(), _player.position)
	_presents.update(delta, _player.perimeter(), _player.position, SHIP_RADIUS)
	if _smash_left > 0.0 and _hazards.smash_touching(_player.cut_path(), _player.position) > 0:
		_sfx.explode()

	var can_be_hit := _invuln <= 0.0 and _shield_left <= 0.0 and _smash_left <= 0.0
	if can_be_hit and _hazards.hit_test(_player.cut_path(), _player.position):
		_player.crash()
		_invuln = CRASH_INVULN
	if _player.lives <= 0:
		_game_over()


func _on_territory_claimed(poly: PackedVector2Array, area: float) -> void:
	_sfx.claim()
	_claimed.append(poly)
	_claimed_area += area
	var percent := area / (FIELD_SIZE.x * FIELD_SIZE.y) * 100.0
	_score += roundi(percent * POINTS_PER_PERCENT) * level
	if _hazards.respawn_inside(poly, _player.perimeter(), _player.position) > 0:
		_sfx.explode()
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
		"freeze":
			_freeze_left = FREEZE_TIME
		"smash":
			_smash_left = POWERUP_TIME


func _show_menu() -> void:
	_state = State.MENU
	_player.set_process(false)
	_reset_field()
	_hud.visible = false
	_menu.show_scores(Scores.load_top(_score_path))
	_menu.visible = true


func _start_game() -> void:
	_menu.visible = false
	_hud.visible = true
	_score = 0
	_player.lives = STARTING_LIVES
	_start_level(1)


func _start_level(n: int) -> void:
	level = n
	_state = State.PLAYING
	_reset_field()
	_player.set_process(true)
	var cfg := _level_config(n)
	_hazards.spawn(_player.perimeter(), _player.position, cfg.stars, cfg.aliens, cfg.speed, cfg.ghosts)
	queue_redraw()


# Clears the field back to a full border with no hazards, presents or effects.
func _reset_field() -> void:
	_claimed.clear()
	_claimed_area = 0.0
	_invuln = 0.0
	_shield_left = 0.0
	_speed_left = 0.0
	_slow_left = 0.0
	_freeze_left = 0.0
	_smash_left = 0.0
	_player.restart(_perimeter_points())
	_hazards.clear()
	_presents.clear()
	_hud.hide_message()


func _level_done() -> void:
	_state = State.LEVEL_DONE
	_player.set_process(false)
	_score += LEVEL_BONUS * level
	var bonus_life := _coverage_percent() >= _target_percent(level) + EXTRA_LIFE_MARGIN
	var msg := "LEVEL %d COMPLETE\n\nScore %d\n\nPress Space to continue" % [level, _score]
	if bonus_life:
		_player.lives += 1
		_sfx.extra_life()
		msg = "LEVEL %d COMPLETE\n\nEXTRA LIFE!\n\nScore %d\n\nPress Space to continue" % [level, _score]
	else:
		_sfx.level_passed()
	_hud.show_message(msg)


func _game_over() -> void:
	_state = State.GAME_OVER
	_player.set_process(false)
	Scores.submit(_score, level, _score_path)
	_hud.show_message("GAME OVER\n\nScore %d\nReached level %d\n\nPress Space for the menu" % [_score, level])


# Level 1 starts easy and each level adds hazards and speed.
func _level_config(n: int) -> Dictionary:
	var cfg := {
		"stars": mini(3 + 2 * (n - 1), 5),
		"aliens": n / 2,
		"ghosts": (n - 1) / 2,
		"speed": 1.0 + 0.12 * (n - 1),
	}
	# Hand-set mixes for levels 2-4; level 5 on keeps the scaling above, stars capped at 5.
	match n:
		2:
			cfg.stars = 4
			cfg.aliens = 1
			cfg.ghosts = 0
		3:
			cfg.stars = 0
			cfg.aliens = 3
			cfg.ghosts = 0
		4:
			cfg.stars = 5
			cfg.aliens = 1
			cfg.ghosts = 1
	return cfg


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
	if _freeze_left > 0.0:
		parts.append("FREEZE %ds" % ceili(_freeze_left))
	if _smash_left > 0.0:
		parts.append("SMASH %ds" % ceili(_smash_left))
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

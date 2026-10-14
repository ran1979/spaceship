extends Node2D

# Fixed playfield, centered in the viewport. HUD bar sits above it.
const FIELD_SIZE := Vector2(960, 540)
const FIELD_BG := Color(0.03, 0.03, 0.10)
const CLAIM_COLOR := Color(0.10, 0.34, 0.40)
const BORDER_COLOR := Color(0.3, 0.9, 1.0)
const BORDER_WIDTH := 3.0
const TARGET_PERCENT := 75.0
const STAR_COUNT := 6
const ALIEN_COUNT := 1
const CRASH_INVULN := 1.0  # seconds of immunity after a crash

@onready var _player: Node2D = $Player
@onready var _hazards: Node2D = $Hazards
@onready var _hud: CanvasLayer = $HUD

var level := 1
var _claimed: Array[PackedVector2Array] = []
var _claimed_area := 0.0
var _invuln := 0.0


func _ready() -> void:
	_player.territory_claimed.connect(_on_territory_claimed)
	_player.setup(_perimeter_points())
	_hazards.spawn(_player.perimeter(), _player.position, STAR_COUNT, ALIEN_COUNT)


func _process(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	_hazards.step(delta, _player.perimeter(), _player.cut_path(), _player.position)
	if _invuln <= 0.0 and _hazards.hit_test(_player.cut_path(), _player.position):
		_player.crash()
		_invuln = CRASH_INVULN
	_hud.update_stats(_coverage_percent(), TARGET_PERCENT, _player.lives, level)


func _draw() -> void:
	draw_rect(_field_rect(), FIELD_BG, true)
	for poly in _claimed:
		draw_colored_polygon(poly, CLAIM_COLOR)
		_draw_loop(poly)
	_draw_loop(_player.perimeter())


func _on_territory_claimed(poly: PackedVector2Array, area: float) -> void:
	_claimed.append(poly)
	_claimed_area += area
	_hazards.respawn_inside(poly, _player.perimeter(), _player.position)
	queue_redraw()
	if _coverage_percent() >= TARGET_PERCENT:
		_win()


func _win() -> void:
	_player.set_process(false)
	set_process(false)
	_hud.show_message("LEVEL %d COMPLETE" % level)


func _coverage_percent() -> float:
	return _claimed_area / (FIELD_SIZE.x * FIELD_SIZE.y) * 100.0


func _draw_loop(poly: PackedVector2Array) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, BORDER_COLOR, BORDER_WIDTH)


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

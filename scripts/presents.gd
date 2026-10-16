extends Node2D

# Gift boxes that appear at random spots in the uncleared field. Touching one collects it.

signal collected(kind: String)

const Hazards := preload("res://scripts/hazards.gd")

const KINDS := {
	"life": Color(1.0, 0.35, 0.45),
	"shield": Color(0.4, 0.8, 1.0),
	"speed": Color(1.0, 0.85, 0.3),
	"slow": Color(0.7, 0.5, 1.0),
	"freeze": Color(0.8, 1.0, 1.0),
	"smash": Color(1.0, 0.4, 1.0),
}
const RADIUS := 10.0
const LIFETIME := 12.0
const BLINK_TIME := 3.0  # blink during the last seconds before a present vanishes
const MAX_ON_FIELD := 2
const SPAWN_MIN := 8.0
const SPAWN_MAX := 14.0

var _items: Array = []  # each: {pos, kind, age}
var _timer := 0.0


func clear() -> void:
	_items.clear()
	_timer = randf_range(SPAWN_MIN, SPAWN_MAX)


func add(pos: Vector2, kind: String) -> void:
	_items.append({"pos": pos, "kind": kind, "age": 0.0})


func update(delta: float, region: PackedVector2Array, ship_pos: Vector2, ship_radius: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(SPAWN_MIN, SPAWN_MAX)
		if _items.size() < MAX_ON_FIELD:
			add(Hazards.random_point_in(region, ship_pos), KINDS.keys().pick_random())
	for i in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[i]
		item.age += delta
		if item.age >= LIFETIME:
			_items.remove_at(i)
		elif item.pos.distance_to(ship_pos) < RADIUS + ship_radius:
			_items.remove_at(i)
			collected.emit(item.kind)
	queue_redraw()


func _draw() -> void:
	for item in _items:
		var shown: bool = item.age < LIFETIME - BLINK_TIME or int(item.age * 6.0) % 2 == 0
		if not shown:
			continue
		var c: Color = KINDS[item.kind]
		var pos: Vector2 = item.pos
		draw_rect(Rect2(pos - Vector2.ONE * RADIUS, Vector2.ONE * RADIUS * 2.0), c)
		# Ribbon cross
		draw_rect(Rect2(pos - Vector2(2, RADIUS), Vector2(4, RADIUS * 2.0)), Color.WHITE)
		draw_rect(Rect2(pos - Vector2(RADIUS, 2), Vector2(RADIUS * 2.0, 4)), Color.WHITE)

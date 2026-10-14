extends Node2D

# Stars/asteroids and a chaser alien bouncing inside the uncleared field.
# Touching the active cut or the ship is a crash; main and player handle the consequences.

const SHIP_RADIUS := 11.0
const STAR_RADII := [6.0, 10.0, 15.0]
const STAR_SPEED_MIN := 70.0
const STAR_SPEED_MAX := 130.0
const ALIEN_RADIUS := 13.0
const ALIEN_SPEED := 90.0
const ALIEN_CHASE_SPEED := 150.0
const ALIEN_STEER_RATE := 1.5  # blend toward desired velocity per second
const SPAWN_CLEARANCE := 120.0  # keep spawns this far from the ship

var _items: Array = []  # each: {pos, vel, r, chaser}
var _speed_scale := 1.0


func spawn(region: PackedVector2Array, ship_pos: Vector2, star_count: int, alien_count: int, speed_scale: float) -> void:
	_speed_scale = speed_scale
	for i in star_count:
		var speed := randf_range(STAR_SPEED_MIN, STAR_SPEED_MAX) * speed_scale
		add(_random_point_in(region, ship_pos), _random_dir() * speed, STAR_RADII.pick_random(), false)
	for i in alien_count:
		add(_random_point_in(region, ship_pos), _random_dir() * ALIEN_SPEED * speed_scale, ALIEN_RADIUS, true)


func clear() -> void:
	_items.clear()


func add(pos: Vector2, vel: Vector2, r: float, chaser: bool) -> void:
	_items.append({"pos": pos, "vel": vel, "r": r, "chaser": chaser})


func step(delta: float, region: PackedVector2Array, path: PackedVector2Array, _ship_pos: Vector2) -> void:
	for h in _items:
		if h.chaser:
			_steer_alien(h, delta, path)
		var prev: Vector2 = h.pos
		h.pos = h.pos + h.vel * delta
		_bounce(h, region, prev)
	queue_redraw()


# True if any hazard touches the cut path or the ship.
func hit_test(path: PackedVector2Array, ship_pos: Vector2) -> bool:
	for h in _items:
		if h.pos.distance_to(ship_pos) < h.r + SHIP_RADIUS:
			return true
		for i in range(path.size() - 1):
			if Geometry2D.get_closest_point_to_segment(h.pos, path[i], path[i + 1]).distance_to(h.pos) < h.r:
				return true
	return false


# Hazards whose center lies inside a newly claimed zone are moved to fresh open space.
func respawn_inside(claimed: PackedVector2Array, region: PackedVector2Array, ship_pos: Vector2) -> void:
	for h in _items:
		if Geometry2D.is_point_in_polygon(h.pos, claimed):
			h.pos = _random_point_in(region, ship_pos)
			h.vel = _random_dir() * h.vel.length()


func _steer_alien(h: Dictionary, delta: float, path: PackedVector2Array) -> void:
	if path.size() < 2:
		h.vel = h.vel.normalized() * ALIEN_SPEED * _speed_scale
		return
	var target := _closest_on_path(h.pos, path)
	var desired: Vector2 = (target - h.pos).normalized() * ALIEN_CHASE_SPEED * _speed_scale
	h.vel = h.vel.lerp(desired, minf(1.0, ALIEN_STEER_RATE * delta))


func _closest_on_path(p: Vector2, path: PackedVector2Array) -> Vector2:
	var best := path[0]
	var best_d := INF
	for i in range(path.size() - 1):
		var c := Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
		var d := c.distance_to(p)
		if d < best_d:
			best_d = d
			best = c
	return best


# Reflects off the nearest field edge. The normal faces the side the hazard came from,
# so a hazard that already crossed an edge in one step is pushed back inside.
func _bounce(h: Dictionary, region: PackedVector2Array, prev: Vector2) -> void:
	for k in region.size():
		var a := region[k]
		var b := region[(k + 1) % region.size()]
		var c := Geometry2D.get_closest_point_to_segment(h.pos, a, b)
		var d: Vector2 = h.pos - c
		if d.length() >= h.r:
			continue
		var n: Vector2
		if d.length() > 0.001:
			n = d.normalized()
		else:
			n = (b - a).orthogonal().normalized()
		if n.dot(prev - c) < 0.0:
			n = -n
		if h.vel.dot(n) < 0.0:
			h.vel = h.vel.bounce(n)
		h.pos = c + n * h.r


func _random_point_in(region: PackedVector2Array, avoid: Vector2) -> Vector2:
	var lo := region[0]
	var hi := region[0]
	for p in region:
		lo = lo.min(p)
		hi = hi.max(p)
	for i in 200:
		var p := Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))
		if Geometry2D.is_point_in_polygon(p, region) and p.distance_to(avoid) > SPAWN_CLEARANCE:
			return p
	return _centroid(region)


func _centroid(region: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in region:
		sum += p
	return sum / region.size()


func _random_dir() -> Vector2:
	return Vector2.from_angle(randf() * TAU)


func _draw() -> void:
	for h in _items:
		if h.chaser:
			draw_circle(h.pos, h.r, Color(0.5, 0.95, 0.4))
			draw_circle(h.pos + Vector2(0, -4), h.r * 0.5, Color(0.8, 1.0, 0.75))
		elif h.r > 12.0:
			# Asteroid
			draw_circle(h.pos, h.r, Color(0.5, 0.46, 0.42))
		else:
			# Star with glow
			draw_circle(h.pos, h.r * 1.8, Color(1.0, 1.0, 0.8, 0.15))
			draw_circle(h.pos, h.r * 0.5, Color(1.0, 1.0, 0.9))

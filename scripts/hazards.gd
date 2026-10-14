extends Node2D

# Rocks (stars/asteroids), a chaser invader and Pac-Man style ghosts bouncing inside the uncleared field.
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
const GHOST_RADIUS := 12.0
const GHOST_SPEED := 80.0  # wandering speed
const GHOST_CHASE_SPEED := 130.0
const GHOST_SHY_DISTANCE := 140.0  # clyde flees when the ship gets this close
const GHOST_KINDS := ["blinky", "pinky", "clyde"]
const GHOST_COLORS := {
	"blinky": Color(1.0, 0.2, 0.2),
	"pinky": Color(1.0, 0.6, 0.85),
	"clyde": Color(1.0, 0.7, 0.2),
}

var _items: Array = []  # each: {pos, vel, r, chaser, ghost, t, rot, spin, shape, turn, dead, boom}

# Classic arcade looks: Asteroids-style vector rocks and a Space Invaders pixel crab.
const ROCK_COLOR := Color(0.85, 0.95, 0.85)
const ALIEN_COLOR := Color(0.4, 1.0, 0.4)
const INVADER_FRAMES := [
	[
		"..X.....X..",
		"...X...X...",
		"..XXXXXXX..",
		".XX.XXX.XX.",
		"XXXXXXXXXXX",
		"X.XXXXXXX.X",
		"X.X.....X.X",
		"...XX.XX...",
	],
	[
		"..X.....X..",
		"X..X...X..X",
		"X.XXXXXXX.X",
		"XXX.XXX.XXX",
		"XXXXXXXXXXX",
		".XXXXXXXXX.",
		"..X.....X..",
		".X.........X",
	],
]
const INVADER_FRAME_TIME := 0.4
const RESPAWN_TIME := 3.0  # enemies caught in a claim come back after this
const BOOM_TIME := 0.5  # explosion flash length
var _speed_scale := 1.0


func spawn(region: PackedVector2Array, ship_pos: Vector2, star_count: int, alien_count: int, speed_scale: float, ghost_count := 0) -> void:
	_speed_scale = speed_scale
	for i in star_count:
		var speed := randf_range(STAR_SPEED_MIN, STAR_SPEED_MAX) * speed_scale
		add(random_point_in(region, ship_pos), _random_dir() * speed, STAR_RADII.pick_random(), false)
	for i in alien_count:
		add(random_point_in(region, ship_pos), _random_dir() * ALIEN_SPEED * speed_scale, ALIEN_RADIUS, true)
	for i in ghost_count:
		var kind: String = GHOST_KINDS[i % GHOST_KINDS.size()]
		add(random_point_in(region, ship_pos), _random_dir() * GHOST_SPEED * speed_scale, GHOST_RADIUS, false, kind)


func clear() -> void:
	_items.clear()


func add(pos: Vector2, vel: Vector2, r: float, chaser: bool, ghost := "") -> void:
	var shape := PackedVector2Array()
	if not chaser and ghost == "":
		shape = _rock_shape(r)
	_items.append({"pos": pos, "vel": vel, "r": r, "chaser": chaser, "ghost": ghost, "t": 0.0,
		"rot": randf() * TAU, "spin": randf_range(-1.2, 1.2), "shape": shape, "turn": 0.0,
		"dead": 0.0, "boom": 0.0})


# Jagged outline with 10 corners, like an Asteroids rock.
func _rock_shape(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(Vector2.from_angle(TAU * i / 10.0) * r * randf_range(0.75, 1.0))
	return pts




func step(delta: float, region: PackedVector2Array, path: PackedVector2Array, ship_pos: Vector2) -> void:
	for h in _items:
		h.boom = maxf(h.boom - delta, 0.0)
		if h.dead > 0.0:
			h.dead -= delta
			if h.dead <= 0.0:
				h.pos = random_point_in(region, ship_pos)
				h.vel = _random_dir() * h.vel.length()
			continue
		if h.chaser:
			_steer_alien(h, delta, path)
		elif h.ghost != "":
			_steer_ghost(h, delta, path, ship_pos)
		h.t += delta
		h.rot += h.spin * delta
		var prev: Vector2 = h.pos
		h.pos = h.pos + h.vel * delta
		_bounce(h, region, prev)
	queue_redraw()


# True if any hazard touches the cut path or the ship.
func hit_test(path: PackedVector2Array, ship_pos: Vector2) -> bool:
	for h in _items:
		if h.dead > 0.0:
			continue
		if h.pos.distance_to(ship_pos) < h.r + SHIP_RADIUS:
			return true
		for i in range(path.size() - 1):
			if Geometry2D.get_closest_point_to_segment(h.pos, path[i], path[i + 1]).distance_to(h.pos) < h.r:
				return true
	return false


# Enemies whose center lies inside a newly claimed zone explode, then come back after RESPAWN_TIME.
# Returns how many were caught.
func respawn_inside(claimed: PackedVector2Array, _region: PackedVector2Array, _ship_pos: Vector2) -> int:
	var caught := 0
	for h in _items:
		if h.dead <= 0.0 and Geometry2D.is_point_in_polygon(h.pos, claimed):
			h.dead = RESPAWN_TIME
			h.boom = BOOM_TIME
			caught += 1
	return caught


func _steer_alien(h: Dictionary, delta: float, path: PackedVector2Array) -> void:
	if path.size() < 2:
		h.vel = h.vel.normalized() * ALIEN_SPEED * _speed_scale
		return
	var target := _closest_on_path(h.pos, path)
	var desired: Vector2 = (target - h.pos).normalized() * ALIEN_CHASE_SPEED * _speed_scale
	h.vel = h.vel.lerp(desired, minf(1.0, ALIEN_STEER_RATE * delta))


# Blinky chases the cut, Pinky goes for the ship, Clyde wanders and flees when the ship is close.
func _steer_ghost(h: Dictionary, delta: float, path: PackedVector2Array, ship_pos: Vector2) -> void:
	var speed := GHOST_CHASE_SPEED * _speed_scale
	match h.ghost:
		"blinky":
			if path.size() >= 2:
				_steer_toward(h, delta, _closest_on_path(h.pos, path), speed)
				return
		"pinky":
			if path.size() >= 2:
				_steer_toward(h, delta, ship_pos, speed)
				return
		"clyde":
			if h.pos.distance_to(ship_pos) < GHOST_SHY_DISTANCE:
				_steer_toward(h, delta, h.pos + (h.pos - ship_pos), GHOST_SPEED * _speed_scale)
				return
	_wander(h, delta)


func _steer_toward(h: Dictionary, delta: float, target: Vector2, speed: float) -> void:
	var desired: Vector2 = (target - h.pos).normalized() * speed
	h.vel = h.vel.lerp(desired, minf(1.0, ALIEN_STEER_RATE * delta))


func _wander(h: Dictionary, delta: float) -> void:
	h.turn -= delta
	if h.turn <= 0.0:
		h.turn = randf_range(1.0, 2.5)
		h.vel = _random_dir() * GHOST_SPEED * _speed_scale
	else:
		h.vel = h.vel.normalized() * GHOST_SPEED * _speed_scale


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


static func random_point_in(region: PackedVector2Array, avoid: Vector2) -> Vector2:
	var lo := region[0]
	var hi := region[0]
	for p in region:
		lo = lo.min(p)
		hi = hi.max(p)
	for i in 200:
		var p := Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))
		if Geometry2D.is_point_in_polygon(p, region) and p.distance_to(avoid) > SPAWN_CLEARANCE:
			return p
	return centroid(region)


static func centroid(region: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in region:
		sum += p
	return sum / region.size()


func _random_dir() -> Vector2:
	return Vector2.from_angle(randf() * TAU)


func _draw() -> void:
	for h in _items:
		if h.boom > 0.0:
			_draw_boom(h)
		if h.dead > 0.0:
			continue
		if h.chaser:
			_draw_invader(h)
		elif h.ghost != "":
			_draw_ghost(h)
		else:
			_draw_rock(h)


func _draw_boom(h: Dictionary) -> void:
	var k: float = 1.0 - h.boom / BOOM_TIME
	draw_arc(h.pos, h.r + 24.0 * k, 0.0, TAU, 24, Color(1.0, 0.8, 0.3, 1.0 - k), 3.0)
	draw_circle(h.pos, h.r * (1.0 - k) + 4.0, Color(1.0, 0.6, 0.2, 1.0 - k))


func _draw_ghost(h: Dictionary) -> void:
	var r: float = h.r
	var c: Color = GHOST_COLORS[h.ghost]
	var top: Vector2 = h.pos + Vector2(0, -r * 0.2)
	draw_circle(top, r, c)
	draw_rect(Rect2(h.pos.x - r, top.y, r * 2.0, r), c)
	# Scalloped skirt
	for i in 3:
		draw_circle(Vector2(h.pos.x + (-0.67 + i * 0.67) * r, h.pos.y + 0.8 * r), r * 0.33, c)
	# Eyes look where the ghost is heading
	var look: Vector2 = h.vel.normalized() if h.vel.length() > 0.01 else Vector2.DOWN
	for sx in [-0.4, 0.4]:
		var eye: Vector2 = h.pos + Vector2(sx * r, -0.3 * r)
		draw_circle(eye, r * 0.28, Color.WHITE)
		draw_circle(eye + look * r * 0.12, r * 0.14, Color(0.1, 0.1, 0.5))


func _draw_rock(h: Dictionary) -> void:
	var pts := PackedVector2Array()
	for p in h.shape:
		pts.append(h.pos + p.rotated(h.rot))
	pts.append(pts[0])
	draw_polyline(pts, ROCK_COLOR, 2.0)


func _draw_invader(h: Dictionary) -> void:
	var frame: Array = INVADER_FRAMES[int(h.t / INVADER_FRAME_TIME) % INVADER_FRAMES.size()]
	var px: float = h.r * 2.0 / 11.0
	var origin: Vector2 = h.pos - Vector2(5.5, 4.0) * px
	for y in frame.size():
		var row: String = frame[y]
		for x in row.length():
			if row[x] == "X":
				draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), ALIEN_COLOR)

extends Node2D

# Rides a closed perimeter polygon and cuts new lines through the uncleared field.
# Perimeter position = (edge index, distance along that edge), so the same logic
# works for any polygon the cuts produce.

signal territory_claimed(polygon: PackedVector2Array, area: float)
signal cut_started
signal cut_ended
signal crashed

const SPEED := 160.0
const SNAP := 0.001  # edge-fraction tolerance for perimeter movement
const EPS := 0.5  # pixel tolerance for cut geometry
const TURN_THRESHOLD := 0.5
const TRAIL_COLOR := Color(1.0, 0.6, 0.2)

var lives := 3
var speed_mult := 1.0  # set by main while a speed present is active

var _points := PackedVector2Array()
var _edge := 0  # edge runs from _points[_edge] to _points[_edge + 1]
var _dist := 0.0  # distance travelled along that edge

var _drawing := false
var _trail := PackedVector2Array()  # cut path: start, interior corners, current position
var _start := Vector2.ZERO
var _start_edge := 0
var _start_dist := 0.0
var _needs_release := false  # after a cancel or claim, cut key must be released before restarting
var _particles: CPUParticles2D


func _ready() -> void:
	_add_key_action("move_left", [KEY_LEFT, KEY_A])
	_add_key_action("move_right", [KEY_RIGHT, KEY_D])
	_add_key_action("move_up", [KEY_UP, KEY_W])
	_add_key_action("move_down", [KEY_DOWN, KEY_S])
	_add_key_action("cut", [KEY_SPACE])
	_particles = CPUParticles2D.new()
	_particles.local_coords = false
	_particles.emitting = false
	_particles.amount = 30
	_particles.lifetime = 0.5
	_particles.spread = 180.0
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 40.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.0
	_particles.color = TRAIL_COLOR
	add_child(_particles)


func restart(points: PackedVector2Array) -> void:
	setup(points)
	_drawing = false
	_trail.clear()
	_needs_release = true


func setup(points: PackedVector2Array) -> void:
	_points = points
	_edge = 0
	_dist = 0.0
	position = points[0]


func perimeter() -> PackedVector2Array:
	return _points


func cut_path() -> PackedVector2Array:
	return _trail.duplicate() if _drawing else PackedVector2Array()


# Hit by a hazard: a cut in progress is destroyed, otherwise the ship respawns at the first corner.
func crash() -> void:
	if _drawing:
		_cancel_cut(true)
	else:
		lives = maxi(lives - 1, 0)
		_edge = 0
		_dist = 0.0
		position = _points[0]
	crashed.emit()


func step(input: Vector2, delta: float, cutting := false) -> void:
	if not _drawing:
		if not cutting:
			_needs_release = false
		elif not _needs_release and input != Vector2.ZERO and _is_inward(input):
			_begin_cut()
	if _drawing:
		_step_draw(input, delta, cutting)
		return

	if input == Vector2.ZERO:
		return
	if _seg_len(_edge) - _dist <= SNAP:
		_turn(input, _vertex(_edge + 1))
	elif _dist <= SNAP:
		_turn(input, _vertex(_edge))
	var along := input.dot(_edge_dir())
	if absf(along) > TURN_THRESHOLD:
		_dist = clampf(_dist + signf(along) * SPEED * speed_mult * delta, 0.0, _seg_len(_edge))
	position = _points[_edge].lerp(_points[_vertex(_edge + 1)], _dist / _seg_len(_edge))


func _process(delta: float) -> void:
	_particles.emitting = _drawing
	step(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta, Input.is_action_pressed("cut"))
	queue_redraw()


func _draw() -> void:
	# Saucer: disc with a dome on top.
	draw_circle(Vector2.ZERO, 11.0, Color(0.55, 0.85, 0.5))
	draw_circle(Vector2(0, -4), 6.0, Color(0.7, 1.0, 0.8))
	if _drawing:
		var local := PackedVector2Array()
		for p in _trail:
			local.append(p - position)
		local.append(Vector2.ZERO)
		draw_polyline(local, Color(TRAIL_COLOR, 0.25), 8.0)
		draw_polyline(local, TRAIL_COLOR, 2.0)


# At a vertex: switch to whichever edge touching it best matches the input.
func _turn(input: Vector2, v: int) -> void:
	var prev := _vertex(v - 1)
	var dir := input.normalized()
	var best := TURN_THRESHOLD
	var outgoing := (_points[_vertex(v + 1)] - _points[v]).normalized()
	var incoming := (_points[prev] - _points[v]).normalized()
	if dir.dot(outgoing) > best:
		best = dir.dot(outgoing)
		_edge = v
		_dist = 0.0
	if dir.dot(incoming) > best:
		_edge = prev
		_dist = _seg_len(prev)


func _vertex(i: int) -> int:
	return posmod(i, _points.size())


func _seg_len(e: int) -> float:
	return _points[e].distance_to(_points[_vertex(e + 1)])


func _edge_dir() -> Vector2:
	return (_points[_vertex(_edge + 1)] - _points[_edge]).normalized()


func _begin_cut() -> void:
	_drawing = true
	cut_started.emit()
	_start = position
	_start_edge = _edge
	_start_dist = _dist
	_trail = PackedVector2Array([position])


func _is_inward(input: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(position + input.normalized() * 2.0, _points)


func _step_draw(input: Vector2, delta: float, cutting: bool) -> void:
	if not cutting:
		_cancel_cut(false)
		return
	if input == Vector2.ZERO:
		return
	var to := position + input.normalized() * SPEED * speed_mult * delta
	if _retrace(to):
		return
	if _hits_own_trail(to):
		_cancel_cut(false)
		return
	var hit := _boundary_hit(to)
	if not hit.is_empty():
		_finish_cut(hit.point, hit.edge, hit.dist)
		return
	_trail.append(to)
	position = to


# Moving back over the last cut segment pops corners instead of cutting through itself.
func _retrace(to: Vector2) -> bool:
	if _trail.size() < 2 or not _on_segment(to, _trail[-2], _trail[-1]):
		return false
	if to.distance_to(_trail[-2]) >= _trail[-1].distance_to(_trail[-2]):
		return false
	while _trail.size() >= 2 and _on_segment(to, _trail[-2], _trail[-1]) \
			and to.distance_to(_trail[-2]) < _trail[-1].distance_to(_trail[-2]):
		_trail.remove_at(_trail.size() - 1)
	if not _trail[-1].is_equal_approx(to):
		_trail.append(to)
	position = to
	return true


# The last segment touches the ship, so it is never a hit.
func _hits_own_trail(to: Vector2) -> bool:
	for i in range(_trail.size() - 2):
		if Geometry2D.segment_intersects_segment(position, to, _trail[i], _trail[i + 1]) != null:
			return true
	return false


# First field edge the next step reaches: a crossing, or a close pass once the cut has an interior point.
func _boundary_hit(to: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for k in _points.size():
		var a := _points[k]
		var b := _points[_vertex(k + 1)]
		var hit: Variant = Geometry2D.segment_intersects_segment(position, to, a, b)
		var p := Vector2.INF
		if hit != null and hit.distance_to(position) > EPS:
			p = hit
		elif _trail.size() >= 2:
			p = Geometry2D.get_closest_point_to_segment(to, a, b)
			if p.distance_to(to) > EPS:
				continue
		else:
			continue
		var d := position.distance_to(p)
		if d < best_d:
			best_d = d
			best = {"point": p, "edge": k, "dist": a.distance_to(p)}
	return best


func _finish_cut(e: Vector2, e_edge: int, e_dist: float) -> void:
	if _trail.size() < 2 or e.is_equal_approx(_start):
		_cancel_cut(false)
		return
	var loops := _split_region(e, e_edge, e_dist)
	var small := 0 if _area(loops[0]) < _area(loops[1]) else 1
	_points = loops[1 - small]
	_edge = _index_of(_points, e)
	_dist = 0.0
	position = e
	_drawing = false
	_trail.clear()
	_needs_release = true
	cut_ended.emit()
	territory_claimed.emit(loops[small], _area(loops[small]))


# Splits the field along the cut into two loops. Each loop is a boundary arc closed by the cut.
func _split_region(e: Vector2, e_edge: int, e_dist: float) -> Array:
	var cuts := [[_start_edge, _start_dist, _start], [e_edge, e_dist, e]]
	var poly := PackedVector2Array()
	for k in _points.size():
		poly.append(_points[k])
		var here := []
		for c in cuts:
			if c[0] == k:
				here.append(c)
		if here.size() == 2 and here[0][1] > here[1][1]:
			here.reverse()
		for c in here:
			poly.append(c[2])
	poly = _dedupe(poly)
	var s_idx := _index_of(poly, _start)
	var e_idx := _index_of(poly, e)
	var interior := _trail.slice(1)
	var back := interior.duplicate()
	back.reverse()
	var loop_a := _arc(poly, s_idx, e_idx)
	loop_a.append_array(back)
	var loop_b := _arc(poly, e_idx, s_idx)
	loop_b.append_array(interior)
	return [_dedupe(loop_a), _dedupe(loop_b)]


func _cancel_cut(lose_life: bool) -> void:
	_drawing = false
	cut_ended.emit()
	_trail.clear()
	position = _start
	_edge = _start_edge
	_dist = _start_dist
	_needs_release = true
	if lose_life:
		lives = maxi(lives - 1, 0)


func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < EPS


func _arc(poly: PackedVector2Array, a: int, b: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := a
	while true:
		out.append(poly[i])
		if i == b:
			break
		i = posmod(i + 1, poly.size())
	return out


func _dedupe(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		if out.is_empty() or not out[-1].is_equal_approx(p):
			out.append(p)
	while out.size() > 1 and out[-1].is_equal_approx(out[0]):
		out.remove_at(out.size() - 1)
	return out


func _index_of(poly: PackedVector2Array, p: Vector2) -> int:
	for i in poly.size():
		if poly[i].is_equal_approx(p):
			return i
	return -1


func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		sum += poly[i].cross(poly[posmod(i + 1, poly.size())])
	return absf(sum) * 0.5


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.keycode = key
		InputMap.action_add_event(action, ev)

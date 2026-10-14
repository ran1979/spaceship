extends SceneTree

# Headless checks: perimeter walking, cutting, claiming, self-collision, retrace, release.
# Run: ./run.sh --headless -s res://tests/test_perimeter.gd

var _failures := 0
var _square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])


var _ran := false


# Runs on the first frame, once the scene tree is live.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_test_perimeter_walk()
	_test_claim_split()
	_test_self_collision()
	_test_retrace()
	_test_release_cancels()
	_test_level_win()
	_test_hazards()
	print("cut tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
	return true


func _new_ship() -> Node2D:
	var ship: Node2D = preload("res://scripts/player.gd").new()
	ship.setup(_square)
	return ship


# Ship parked on the top edge at x=50, ready to cut downward.
func _ship_at_top_mid() -> Node2D:
	var ship := _new_ship()
	ship.step(Vector2.RIGHT, 0.3125)
	return ship


func _test_perimeter_walk() -> void:
	var ship := _new_ship()
	ship.step(Vector2.RIGHT, 0.5)
	_check(ship, Vector2(80, 0), "moves along top edge")
	ship.step(Vector2.RIGHT, 1.0)
	_check(ship, Vector2(100, 0), "clamps at top-right corner")
	ship.step(Vector2.DOWN, 0.5)
	_check(ship, Vector2(100, 80), "turns down at corner and moves same frame")
	ship.step(Vector2.DOWN, 1.0)
	_check(ship, Vector2(100, 100), "clamps at bottom-right corner")
	ship.step(Vector2.LEFT, 0.5)
	_check(ship, Vector2(20, 100), "turns left at corner and moves")
	ship.step(Vector2.UP, 0.5)
	_check(ship, Vector2(20, 100), "ignores perpendicular input mid-edge")
	ship.step(Vector2.LEFT, 1.0)
	_check(ship, Vector2(0, 100), "clamps at bottom-left corner")
	ship.step(Vector2.UP, 0.5)
	_check(ship, Vector2(0, 20), "turns up at bottom-left corner and moves")
	ship.free()


# Straight cut top-mid to bottom-mid splits the square into two equal halves.
func _test_claim_split() -> void:
	var ship := _ship_at_top_mid()
	var claimed := []
	ship.territory_claimed.connect(func(poly, area): claimed.append([poly, area]))
	ship.step(Vector2.DOWN, 0.1, true)
	ship.step(Vector2.DOWN, 0.5, true)
	ship.step(Vector2.DOWN, 0.1, true)
	_check(ship, Vector2(50, 100), "cut reconnects on bottom edge")
	_check_bool(claimed.size() == 1 and claimed[0][0].size() == 6, "claims one 6-point piece")
	_check_bool(claimed.size() == 1 and is_equal_approx(claimed[0][1], 5000.0), "claimed area is half the square")
	_check_bool(ship.perimeter().size() == 6, "remaining field has 6 points")
	# Ship now walks the new vertical edge (50,100)->(50,96)->(50,16).
	ship.step(Vector2.UP, 1.0)
	_check(ship, Vector2(50, 96), "walks to end of new short edge")
	ship.step(Vector2.UP, 0.1)
	_check(ship, Vector2(50, 80), "turns onto new edge")
	ship.free()


# Trail loops back across its first segment: cancel, lose a life, return to start.
func _test_self_collision() -> void:
	var ship := _ship_at_top_mid()
	ship.step(Vector2.DOWN, 0.1, true)
	ship.step(Vector2.LEFT, 0.2, true)
	ship.step(Vector2(42, -8), 0.27, true)
	_check(ship, Vector2(50, 0), "self-hit returns ship to start")
	_check_bool(ship.lives == 2, "self-hit costs one life")
	ship.free()


# Moving back over the last cut segment retraces instead of colliding.
func _test_retrace() -> void:
	var ship := _ship_at_top_mid()
	ship.step(Vector2.DOWN, 0.1, true)
	ship.step(Vector2.DOWN, 0.1, true)
	ship.step(Vector2.UP, 0.1, true)
	_check(ship, Vector2(50, 16), "retrace pops back to previous corner")
	_check_bool(ship.lives == 3, "retrace costs no life")
	ship.free()


# Releasing the cut key mid-air cancels without life loss and needs a fresh press.
func _test_release_cancels() -> void:
	var ship := _ship_at_top_mid()
	ship.step(Vector2.DOWN, 0.1, true)
	ship.step(Vector2.DOWN, 0.1, false)
	_check(ship, Vector2(50, 0), "release cancels to start")
	_check_bool(ship.lives == 3, "release costs no life")
	ship.step(Vector2.DOWN, 0.1, true)
	_check(ship, Vector2(50, 0), "held key does not restart without release")
	ship.step(Vector2.DOWN, 0.1, false)
	ship.step(Vector2.DOWN, 0.1, true)
	_check(ship, Vector2(50, 16), "fresh press starts a new cut")
	ship.free()


# Coverage below 75% keeps playing; reaching 75% ends the level.
func _test_level_win() -> void:
	var main: Node2D = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	var field_area: float = 960.0 * 540.0
	main._on_territory_claimed(poly, field_area * 0.5)
	_check_bool(main._player.is_processing(), "50% coverage keeps playing")
	main._on_territory_claimed(poly, field_area * 0.3)
	_check_bool(not main._player.is_processing(), "80% coverage ends the level")
	root.remove_child(main)
	main.free()


# Hazards: bounce off an edge they crossed, respawn when enclosed, hit tests, crash.
func _test_hazards() -> void:
	var haz: Node2D = preload("res://scripts/hazards.gd").new()
	haz.add(Vector2(99, 50), Vector2(200, 0), 6.0, false)
	haz.step(0.02, _square, PackedVector2Array(), Vector2.ZERO)
	var h: Dictionary = haz._items[0]
	_check_bool(h.pos.is_equal_approx(Vector2(94, 50)) and h.vel.is_equal_approx(Vector2(-200, 0)), "star bounces back inside right wall")

	var right := PackedVector2Array([Vector2(50, 0), Vector2(100, 0), Vector2(100, 100), Vector2(50, 100)])
	var left := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(50, 100), Vector2(0, 100)])
	haz._items.clear()
	haz.add(Vector2(20, 50), Vector2(90, 0), 6.0, false)
	haz.respawn_inside(left, right, Vector2(90, 90))
	h = haz._items[0]
	_check_bool(Geometry2D.is_point_in_polygon(h.pos, right), "enclosed hazard respawns in remaining field")

	haz._items.clear()
	haz.add(Vector2(50, 50), Vector2.ZERO, 6.0, false)
	_check_bool(haz.hit_test(PackedVector2Array(), Vector2(60, 50)), "hazard touching ship is a hit")
	_check_bool(not haz.hit_test(PackedVector2Array(), Vector2(80, 50)), "distant ship is not a hit")
	_check_bool(haz.hit_test(PackedVector2Array([Vector2(0, 53), Vector2(100, 53)]), Vector2(0, 0)), "hazard touching cut line is a hit")
	haz.free()

	var ship := _ship_at_top_mid()
	ship.step(Vector2.DOWN, 0.1, true)
	ship.crash()
	_check(ship, Vector2(50, 0), "crash during cut returns to cut start")
	_check_bool(ship.lives == 2, "crash during cut costs one life")
	ship.free()

	ship = _new_ship()
	ship.step(Vector2.RIGHT, 0.5)
	ship.crash()
	_check(ship, Vector2(0, 0), "crash on perimeter respawns at first corner")
	_check_bool(ship.lives == 2, "crash on perimeter costs one life")
	ship.free()


func _check(ship: Node2D, expected: Vector2, label: String) -> void:
	if not ship.position.is_equal_approx(expected):
		_failures += 1
		print("FAIL %s: got %s, want %s" % [label, ship.position, expected])


func _check_bool(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL %s" % label)

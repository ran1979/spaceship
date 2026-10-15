extends Control

# On-screen controls for phones and tablets. Touch the left half to drag a floating
# stick (drives the move_* actions); hold the right half to cut (drives the cut action).
# The gameplay code reads touch and keyboard input the same way. Zones are whole halves
# so a thumb never has to hit a small target, which matters on letterboxed phones.

const PAD_RADIUS := 90.0
const PAD_MARGIN := Vector2(150, 150)  # where the idle stick hint sits
const CUT_RADIUS := 75.0
const CUT_MARGIN := Vector2(150, 150)
const KNOB_RADIUS := 34.0
const DEAD_ZONE := 0.15

var _active := false  # shown once the device reports touch
var _pad_touch := -1  # touch index owning the stick, -1 if none
var _cut_touch := -1  # touch index holding the cut zone, -1 if none
var _pad_origin := Vector2.ZERO  # where the stick was grabbed, follows the thumb start
var _knob := Vector2.ZERO  # stick offset, each axis in -1..1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_active = DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_active = true
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag and event.index == _pad_touch:
		_update_pad(event.position)
	queue_redraw()


func _on_press(index: int, pos: Vector2) -> void:
	if _pad_touch == -1 and pos.x < size.x * 0.5:
		_pad_touch = index
		_pad_origin = pos
		_update_pad(pos)
	elif _cut_touch == -1 and pos.x >= size.x * 0.5:
		_cut_touch = index
		Input.action_press("cut")


func _on_release(index: int) -> void:
	if index == _pad_touch:
		_pad_touch = -1
		_knob = Vector2.ZERO
		_set_axis("move_left", "move_right", 0.0)
		_set_axis("move_up", "move_down", 0.0)
	if index == _cut_touch:
		_cut_touch = -1
		Input.action_release("cut")


func _update_pad(pos: Vector2) -> void:
	var v := ((pos - _pad_origin) / PAD_RADIUS).limit_length(1.0)
	_knob = v
	_set_axis("move_left", "move_right", v.x if absf(v.x) > DEAD_ZONE else 0.0)
	_set_axis("move_up", "move_down", v.y if absf(v.y) > DEAD_ZONE else 0.0)


func _set_axis(negative: String, positive: String, value: float) -> void:
	_set_action(negative, maxf(-value, 0.0))
	_set_action(positive, maxf(value, 0.0))


func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _pad_center() -> Vector2:
	return _pad_origin if _pad_touch != -1 else Vector2(PAD_MARGIN.x, size.y - PAD_MARGIN.y)


func _cut_center() -> Vector2:
	return Vector2(size.x - CUT_MARGIN.x, size.y - CUT_MARGIN.y)


func _draw() -> void:
	if not _active:
		return
	var pc := _pad_center()
	var grabbed := _pad_touch != -1
	draw_circle(pc, PAD_RADIUS, Color(1, 1, 1, 0.16 if grabbed else 0.10))
	draw_arc(pc, PAD_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(pc + _knob * PAD_RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.35))

	var cc := _cut_center()
	var held := _cut_touch != -1
	draw_circle(cc, CUT_RADIUS, Color(1.0, 0.6, 0.2, 0.5 if held else 0.18))
	draw_arc(cc, CUT_RADIUS, 0.0, TAU, 48, Color(1.0, 0.7, 0.3, 0.6), 3.0)

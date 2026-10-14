extends CanvasLayer

# Top bar (coverage, target, lives, level) plus a centered message for level end.

const BAR_HEIGHT := 40.0
const BAR_BG := Color(0.02, 0.02, 0.06, 0.9)
const TEXT_COLOR := Color(0.85, 0.95, 1.0)

var _coverage: Label
var _target: Label
var _lives: Label
var _level: Label
var _message: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BAR_BG
	bg.anchor_right = 1.0
	bg.offset_bottom = BAR_HEIGHT
	add_child(bg)

	var row := HBoxContainer.new()
	row.anchor_right = 1.0
	row.offset_bottom = BAR_HEIGHT
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	add_child(row)
	_coverage = _label(row)
	_target = _label(row)
	_lives = _label(row)
	_level = _label(row)

	_message = Label.new()
	_message.anchor_right = 1.0
	_message.anchor_bottom = 1.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 48)
	_message.add_theme_color_override("font_color", TEXT_COLOR)
	_message.visible = false
	add_child(_message)


func update_stats(coverage: float, target: float, lives: int, level: int) -> void:
	_coverage.text = "COVERAGE  %.1f%%" % coverage
	_target.text = "TARGET  %d%%" % int(target)
	_lives.text = "LIVES  %d" % lives
	_level.text = "LEVEL  %d" % level


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func _label(parent: Node) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label

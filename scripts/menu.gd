extends CanvasLayer

# Start screen: title, PLAY button and the high-score board.
signal play_pressed

const TEXT_COLOR := Color(0.85, 0.95, 1.0)
const ACCENT_COLOR := Color(0.3, 0.9, 1.0)
const PANEL_BG := Color(0.02, 0.02, 0.07, 0.88)

var _board: VBoxContainer
var _play: Button


func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var col := VBoxContainer.new()
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	add_child(col)

	col.add_child(_label("SPACESHIP", 72, ACCENT_COLOR))
	col.add_child(_label("Claim the sky. Dodge the rocks.", 22, TEXT_COLOR))

	_play = Button.new()
	_play.text = "PLAY"
	_play.custom_minimum_size = Vector2(260, 64)
	_play.add_theme_font_size_override("font_size", 36)
	_play.pressed.connect(func(): play_pressed.emit())
	col.add_child(_play)
	col.add_child(_label("Press Space / Enter, or tap PLAY", 18, TEXT_COLOR))

	col.add_child(_label("HIGH SCORES", 32, ACCENT_COLOR))
	_board = VBoxContainer.new()
	_board.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_board)


func show_scores(top: Array) -> void:
	for row in _board.get_children():
		row.queue_free()
	if top.is_empty():
		_board.add_child(_label("no scores yet", 22, TEXT_COLOR))
	for i in top.size():
		var entry: Dictionary = top[i]
		_board.add_child(_label("%d.   %d   (level %d)" % [i + 1, int(entry.score), int(entry.level)], 24, TEXT_COLOR))
	_play.grab_focus()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

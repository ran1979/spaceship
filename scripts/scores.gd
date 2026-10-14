extends RefCounted

# Top scores kept on the device (user:// storage). Each entry: {score, level}.

const SAVE_PATH := "user://highscores.json"
const MAX_ENTRIES := 5


static func load_top(path := SAVE_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Array else []


static func submit(score: int, level: int, path := SAVE_PATH) -> void:
	var top := load_top(path)
	top.append({"score": score, "level": level})
	top.sort_custom(func(a, b): return int(a.score) > int(b.score))
	if top.size() > MAX_ENTRIES:
		top.resize(MAX_ENTRIES)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(top))

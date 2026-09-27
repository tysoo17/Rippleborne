class_name SaveManager
extends RefCounted
## Saves and loads the game as JSON. Only data is saved (world, economy,
## player...), never the scene tree; scenes rebuild themselves from the data.

## Where the save lives. Tests point this at another file.
static var save_path: String = "user://savegame.json"
## Bump this when the save format changes, so old saves are recognised.
const SAVE_VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func save_game() -> bool:
	var data := Game.to_dict()
	data["version"] = SAVE_VERSION
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Returns "" on success, otherwise a message for the player.
static func load_game() -> String:
	if not has_save():
		return "No saved game yet."
	var text := FileAccess.get_file_as_string(save_path)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return "The save file is damaged."
	if int(data.get("version", 0)) != SAVE_VERSION:
		return "The save file is from another version of the game."
	Game.from_dict(data)
	return ""

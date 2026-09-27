extends GamePanel
## Esc menu: save, load, help, quit.

const TITLE_SCENE := "res://game/ui/title_screen.tscn"
const MAIN_SCENE := "res://game/main.tscn"

var _status: Label
var _music_button: Button
var _sound_button: Button


func build() -> void:
	custom_minimum_size = Vector2(220, 0)
	set_title("Paused")
	body.add_child(button("Resume", close))
	body.add_child(button("Save game", _save))
	body.add_child(button("Load last save", _load))
	body.add_child(button("How to play", func(): EventBus.open_panel.emit(&"help", {})))
	_music_button = button("Music", func():
		Sfx.set_music_on(not Sfx.music_on)
		refresh())
	body.add_child(_music_button)
	_sound_button = button("Sound", func():
		Sfx.set_sound_on(not Sfx.sound_on)
		refresh())
	body.add_child(_sound_button)
	body.add_child(button("Quit to title", _quit))
	_status = label("", 0.0, Color(0.7, 0.85, 0.7))
	body.add_child(_status)


func refresh() -> void:
	_status.text = "Day %d  -  %s" % [GameClock.day, Game.location]
	_music_button.text = "Music: %s" % ("on" if Sfx.music_on else "off")
	_sound_button.text = "Sound: %s" % ("on" if Sfx.sound_on else "off")


func _save() -> void:
	_status.text = "Game saved." if SaveManager.save_game() else "Could not save!"


func _load() -> void:
	var problem := SaveManager.load_game()
	if problem != "":
		_status.text = problem
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)


func _quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)

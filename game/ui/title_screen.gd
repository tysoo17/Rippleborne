extends Control
## First screen: start a new game or continue the saved one.

const MAIN_SCENE := "res://game/main.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var message: Label = %Message


func _ready() -> void:
	get_tree().paused = false
	Sfx.play_music(&"town")
	%NewGameButton.pressed.connect(_new_game)
	continue_button.pressed.connect(_continue)
	%QuitButton.pressed.connect(get_tree().quit)
	continue_button.disabled = not SaveManager.has_save()
	%NewGameButton.grab_focus()


func _new_game() -> void:
	Game.new_game()
	Game.show_intro = true
	get_tree().change_scene_to_file(MAIN_SCENE)


func _continue() -> void:
	var problem := SaveManager.load_game()
	if problem != "":
		message.text = problem
		return
	get_tree().change_scene_to_file(MAIN_SCENE)

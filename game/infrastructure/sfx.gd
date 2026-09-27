extends Node
## Short sound effects (autoload "Sfx"). Usage: Sfx.play(&"hit")

const SOUNDS := {
	&"swing": "res://assets/sfx/swing.wav",
	&"hit": "res://assets/sfx/hit.wav",
	&"hurt": "res://assets/sfx/hurt.wav",
	&"pickup": "res://assets/sfx/pickup.wav",
	&"coin": "res://assets/sfx/coin.wav",
	&"dash": "res://assets/sfx/dash.wav",
	&"upgrade": "res://assets/sfx/upgrade.wav",
	&"news": "res://assets/sfx/news.wav",
	&"click": "res://assets/sfx/click.wav",
}
const VOICES := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in SOUNDS:
		if ResourceLoader.exists(SOUNDS[sound]):
			_streams[sound] = load(SOUNDS[sound])
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Plays a sound with a little random pitch so repeats don't sound robotic.
func play(sound: StringName, volume_db: float = -6.0, pitch_spread: float = 0.08) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	player.play()

extends Node
## Sound effects and music (autoload "Sfx").
##   Sfx.play(&"hit")             short sound effect
##   Sfx.play_music(&"town")      background music, crossfades from the current track
## The on/off switches are remembered in user://settings.cfg.

const SOUNDS := {
	&"swing": "res://assets/sfx/swing.wav",
	&"hit": "res://assets/sfx/hit.wav",
	&"heavy_hit": "res://assets/sfx/heavy_hit.wav",
	&"block": "res://assets/sfx/block.wav",
	&"hurt": "res://assets/sfx/hurt.wav",
	&"pickup": "res://assets/sfx/pickup.wav",
	&"coin": "res://assets/sfx/coin.wav",
	&"dash": "res://assets/sfx/dash.wav",
	&"upgrade": "res://assets/sfx/upgrade.wav",
	&"news": "res://assets/sfx/news.wav",
	&"click": "res://assets/sfx/click.wav",
}
const MUSIC := {
	&"town": "res://assets/music/town.wav",
	&"field": "res://assets/music/field.wav",
	&"mine": "res://assets/music/mine.wav",
}
## Which track plays in which location.
const LOCATION_MUSIC := {
	"Town": &"town", "Mining Village": &"town", "Road": &"field", "Forest": &"field", "Mine": &"mine",
}
const VOICES := 8
const MUSIC_VOLUME_DB := -14.0
const FADE_SECONDS := 1.5
const SETTINGS_PATH := "user://settings.cfg"

var music_on: bool = true
var sound_on: bool = true

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in SOUNDS:
		if ResourceLoader.exists(SOUNDS[sound]):
			_streams[sound] = load(SOUNDS[sound])
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music_a = _new_music_player()
	_music_b = _new_music_player()
	_load_settings()
	EventBus.location_changed.connect(func(location_name: String):
		if LOCATION_MUSIC.has(location_name):
			play_music(LOCATION_MUSIC[location_name]))


## Plays a sound with a little random pitch so repeats don't sound robotic.
func play(sound: StringName, volume_db: float = -6.0, pitch_spread: float = 0.08) -> void:
	if not sound_on or not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	player.play()


## Crossfade to another music track. Playing the same track again does nothing.
func play_music(track: StringName) -> void:
	if track == _current_track or not MUSIC.has(track) or not ResourceLoader.exists(MUSIC[track]):
		return
	_current_track = track
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = load(MUSIC[track])
	_music_a.volume_db = -60.0
	if music_on:
		_music_a.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_music_a, "volume_db", MUSIC_VOLUME_DB, FADE_SECONDS)
	tween.tween_property(_music_b, "volume_db", -60.0, FADE_SECONDS)
	tween.chain().tween_callback(_music_b.stop)


func set_music_on(value: bool) -> void:
	music_on = value
	if music_on and _current_track != &"":
		_music_a.volume_db = MUSIC_VOLUME_DB
		_music_a.play()
	elif not music_on:
		_music_a.stop()
		_music_b.stop()
	_save_settings()


func set_sound_on(value: bool) -> void:
	sound_on = value
	_save_settings()


func _new_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	# Loop: when a track ends, start it again (only the active player).
	player.finished.connect(func():
		if player == _music_a and music_on:
			player.play())
	return player


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_on = config.get_value("audio", "music_on", true)
		sound_on = config.get_value("audio", "sound_on", true)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_on", music_on)
	config.set_value("audio", "sound_on", sound_on)
	config.save(SETTINGS_PATH)

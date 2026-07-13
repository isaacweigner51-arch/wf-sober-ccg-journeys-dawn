extends Node

const HOME_TRACK := "res://assets/audio/home_recovery_theme_fixed.ogg"
const HOME_TRACK_FALLBACK := "res://assets/audio/home_recovery_theme_v2.wav"

var music_player: AudioStreamPlayer
var current_track := ""
var target_volume_db := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_music_player()

func _ensure_music_player() -> void:
    if music_player != null and is_instance_valid(music_player):
        return
    music_player = AudioStreamPlayer.new()
    music_player.name = "PersistentMusicPlayer"
    music_player.process_mode = Node.PROCESS_MODE_ALWAYS
    music_player.bus = "Master"
    add_child(music_player)

func _ensure_master_audio() -> void:
    var master_index: int = AudioServer.get_bus_index("Master")
    if master_index >= 0:
        AudioServer.set_bus_mute(master_index, false)
        if AudioServer.get_bus_volume_db(master_index) < -30.0:
            AudioServer.set_bus_volume_db(master_index, 0.0)

func play_home_music() -> void:
    _ensure_music_player()
    _ensure_master_audio()
    await get_tree().process_frame
    var selected_path: String = HOME_TRACK
    var stream: AudioStream = load(selected_path) as AudioStream
    if stream == null:
        selected_path = HOME_TRACK_FALLBACK
        stream = load(selected_path) as AudioStream
    if stream == null:
        push_error("Home music could not be loaded from either audio resource.")
        return
    _play_loaded_stream(selected_path, stream, target_volume_db)

func _play_loaded_stream(path: String, stream: AudioStream, volume_db: float) -> void:
    _ensure_music_player()
    _ensure_master_audio()
    if music_player == null or not is_instance_valid(music_player):
        return
    if current_track == path and music_player.playing:
        music_player.stream_paused = false
        music_player.volume_db = volume_db
        return
    if stream is AudioStreamOggVorbis:
        stream.loop = true
    elif stream is AudioStreamWAV:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    current_track = path
    music_player.stop()
    music_player.stream = stream
    music_player.stream_paused = false
    music_player.volume_db = volume_db
    music_player.play(0.0)

func play_music(path: String, volume_db: float = -1.0) -> void:
    _ensure_music_player()
    _ensure_master_audio()
    var stream: AudioStream = load(path) as AudioStream
    if stream == null:
        push_error("Music track could not be loaded: %s" % path)
        return
    _play_loaded_stream(path, stream, volume_db)

func stop_music(fade_seconds: float = 0.6) -> void:
    if music_player == null or not is_instance_valid(music_player) or not music_player.playing:
        current_track = ""
        return
    var tween := create_tween()
    tween.tween_property(music_player, "volume_db", -35.0, fade_seconds)
    await tween.finished
    music_player.stop()
    current_track = ""

func set_music_volume(linear_value: float) -> void:
    linear_value = clampf(linear_value, 0.0, 1.0)
    target_volume_db = -80.0 if linear_value <= 0.001 else linear_to_db(linear_value)
    if music_player != null and is_instance_valid(music_player):
        music_player.volume_db = target_volume_db

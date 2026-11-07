class_name SoundPlaybackComponent
extends Node

## Non-spatial playback keyed by file path. Each sound can run several voices at once,
## depending on its playback mode.

signal sound_started(path: String)
signal sound_stopped(path: String)

## overlap: every trigger adds a voice. restart: a trigger replaces running voices.
## toggle: a trigger stops running voices, otherwise starts one.
const MODE_IDS: Array[StringName] = [&"overlap", &"restart", &"toggle"]
const DEFAULT_MODE := &"overlap"

@export var bus: StringName = &"Master"
@export_range(1, 32, 1) var max_voices_per_sound: int = 8

var _voices: Dictionary[String, Array] = {}


## Triggers a sound. Returns true if a voice started.
func trigger(path: String, volume: float = 1.0, mode: StringName = DEFAULT_MODE) -> bool:
  if mode == &"toggle" and is_playing(path):
    stop(path)
    return false
  if mode == &"restart":
    _stop_voices(path)

  var stream := AudioFileLoader.load_stream(path)
  if stream == null:
    return false
  var voices: Array = _voices.get(path, [])
  var started := voices.is_empty()
  if voices.size() >= max_voices_per_sound:
    _free_voice(voices.pop_front())

  var player := AudioStreamPlayer.new()
  player.bus = bus
  player.stream = stream
  player.volume_linear = volume
  player.finished.connect(_on_voice_finished.bind(path, player))
  add_child(player)
  player.play()
  voices.append(player)
  _voices[path] = voices
  if started:
    sound_started.emit(path)
  return true


func stop(path: String) -> void:
  if _stop_voices(path):
    sound_stopped.emit(path)


func stop_all() -> void:
  for path in _voices.keys():
    stop(path)


func is_playing(path: String) -> bool:
  return not (_voices.get(path, []) as Array).is_empty()


func get_playing_paths() -> Array[String]:
  var paths: Array[String] = []
  paths.assign(_voices.keys())
  return paths


## Applies a volume change to all running voices of a sound.
func set_volume(path: String, volume: float) -> void:
  for player: AudioStreamPlayer in _voices.get(path, []):
    player.volume_linear = volume


## Playback position of the newest voice in seconds, or 0 when silent.
func get_position(path: String) -> float:
  var voices: Array = _voices.get(path, [])
  return (voices.back() as AudioStreamPlayer).get_playback_position() if not voices.is_empty() else 0.0


func _stop_voices(path: String) -> bool:
  if not _voices.has(path):
    return false
  for player in _voices[path]:
    _free_voice(player)
  _voices.erase(path)
  return true


func _free_voice(player: AudioStreamPlayer) -> void:
  player.stop()
  player.queue_free()


func _on_voice_finished(path: String, player: AudioStreamPlayer) -> void:
  player.queue_free()
  var voices: Array = _voices.get(path, [])
  voices.erase(player)
  if voices.is_empty() and _voices.has(path):
    _voices.erase(path)
    sound_stopped.emit(path)

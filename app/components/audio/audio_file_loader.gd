class_name AudioFileLoader
extends RefCounted

## Loads raw audio files from absolute or user:// paths at runtime, without a Godot import.

const SUPPORTED_EXTENSIONS: Array[StringName] = [&"mp3", &"ogg", &"wav"]

static var _stream_cache: Dictionary[String, AudioStream] = {}


static func is_supported(path: String) -> bool:
  return StringName(path.get_extension().to_lower()) in SUPPORTED_EXTENSIONS


## Returns a cached stream, or null when the file is missing, unsupported, or undecodable.
static func load_stream(path: String) -> AudioStream:
  var key := normalize_path(path)
  if _stream_cache.has(key):
    return _stream_cache[key]
  if not is_supported(key) or not FileAccess.file_exists(key):
    return null

  var stream: AudioStream
  match key.get_extension().to_lower():
    "mp3":
      stream = AudioStreamMP3.load_from_file(key)
    "ogg":
      stream = AudioStreamOggVorbis.load_from_file(key)
    "wav":
      stream = AudioStreamWAV.load_from_file(key)
  if stream == null:
    push_warning("AudioFileLoader: could not decode '%s'" % key)
    return null
  _stream_cache[key] = stream
  return stream


static func normalize_path(path: String) -> String:
  if path.begins_with("user://"):
    return ProjectSettings.globalize_path(path).simplify_path()
  return path.simplify_path()


## Drops cached streams so files replaced on disk are decoded again.
static func clear_cache() -> void:
  _stream_cache.clear()

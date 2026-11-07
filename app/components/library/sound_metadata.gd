class_name SoundMetadata
extends RefCounted

## Per-sound notes and volumes stored as YAML inside the sound directory.
## Only values that differ from the defaults are written. Entries of files that are currently
## missing are kept, so a temporarily moved file does not lose its note.

const FILE_NAME := ".soundboard.yml"
const FORMAT_VERSION := 1
const DEFAULT_VOLUME := 1.0
const MAX_VOLUME := 2.0

var file_path: String
var _sounds: Dictionary[String, Dictionary] = {}
var _last_error: String = ""


func _init(directory: String = "") -> void:
  if not directory.is_empty():
    file_path = directory.path_join(FILE_NAME)


## Loads the file if present. A missing file is a valid empty state.
func load_file() -> bool:
  _sounds.clear()
  _last_error = ""
  if not FileAccess.file_exists(file_path):
    return true

  var result = YAML.parse(FileAccess.get_file_as_string(file_path))
  if result.has_error():
    return _fail("YAML error in '%s': %s" % [file_path, result.get_error()])
  var data: Variant = result.get_data()
  if data == null:
    return true
  if not data is Dictionary:
    return _fail("top level of '%s' must be a mapping" % file_path)
  var sounds: Variant = (data as Dictionary).get("sounds", {})
  if not sounds is Dictionary:
    return _fail("'sounds' in '%s' must be a mapping" % file_path)

  for key in sounds:
    var raw: Variant = sounds[key]
    if not key is String or not raw is Dictionary:
      continue
    var values := {}
    var note: Variant = raw.get("note")
    if note is String and not (note as String).is_empty():
      values.note = note
    var volume: Variant = raw.get("volume")
    if volume is float or volume is int:
      values.volume = clampf(float(volume), 0.0, MAX_VOLUME)
    if not values.is_empty():
      _sounds[key] = values
  return true


func save_file() -> bool:
  _last_error = ""
  var sounds := {}
  var keys := _sounds.keys()
  keys.sort()
  for key: String in keys:
    sounds[key] = _sounds[key]
  var result = YAML.stringify({"version": FORMAT_VERSION, "sounds": sounds})
  if result.has_error():
    return _fail("could not serialize notes: %s" % result.get_error())

  var file := FileAccess.open(file_path, FileAccess.WRITE)
  if file == null:
    return _fail(
      "could not write '%s': %s" % [file_path, error_string(FileAccess.get_open_error())]
    )
  file.store_string(result.get_data())
  return true


func get_last_error() -> String:
  return _last_error


func get_note(relative_path: String) -> String:
  return _sounds.get(relative_path, {}).get("note", "")


func get_volume(relative_path: String) -> float:
  return _sounds.get(relative_path, {}).get("volume", DEFAULT_VOLUME)


func set_note(relative_path: String, note: String) -> void:
  _set_value(relative_path, "note", note.strip_edges(), "")


func set_volume(relative_path: String, volume: float) -> void:
  _set_value(relative_path, "volume", snappedf(clampf(volume, 0.0, MAX_VOLUME), 0.01), DEFAULT_VOLUME)


func _set_value(relative_path: String, key: String, value: Variant, default: Variant) -> void:
  var values: Dictionary = _sounds.get(relative_path, {})
  if value == default:
    values.erase(key)
  else:
    values[key] = value
  if values.is_empty():
    _sounds.erase(relative_path)
  else:
    _sounds[relative_path] = values


func _fail(message: String) -> bool:
  _last_error = message
  push_warning("SoundMetadata: " + message)
  return false

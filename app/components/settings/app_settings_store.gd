class_name AppSettingsStore
extends Node

## Persists application preferences and the recently used directories in a ConfigFile.
## The store only reads and writes values; callers decide what each value means.

const RECENT_SECTION := "recent"
const RECENT_KEY := "directories"

## Suspends every store, so automated tests never touch the user's saved preferences.
static var suspended := false

@export var file_path: String = "user://settings.cfg"
@export_range(1, 50, 1) var max_recent_directories: int = 10

var _file: ConfigFile


func is_active() -> bool:
  return not suspended and not file_path.is_empty()


func get_value(section: String, key: String, default: Variant = null) -> Variant:
  return _get_file().get_value(section, key, default)


## Stores several values per section in one write: {section: {key: value}}.
func store_values(values: Dictionary) -> void:
  var file := _get_file()
  for section: String in values:
    var section_values: Dictionary = values[section]
    for key: String in section_values:
      file.set_value(section, key, section_values[key])
  _save()


## Most recent first.
func get_recent_directories() -> PackedStringArray:
  return get_value(RECENT_SECTION, RECENT_KEY, PackedStringArray())


func remember_directory(path: String) -> void:
  var recent := get_recent_directories()
  var index := recent.find(path)
  if index >= 0:
    recent.remove_at(index)
  recent.insert(0, path)
  recent.resize(mini(recent.size(), max_recent_directories))
  store_values({RECENT_SECTION: {RECENT_KEY: recent}})


func forget_directory(path: String) -> void:
  var recent := get_recent_directories()
  var index := recent.find(path)
  if index >= 0:
    recent.remove_at(index)
    store_values({RECENT_SECTION: {RECENT_KEY: recent}})


func _save() -> void:
  if not is_active():
    return
  var error := _file.save(file_path)
  if error != OK:
    push_warning("%s could not save %s: %s" % [name, file_path, error_string(error)])


func _get_file() -> ConfigFile:
  if _file == null:
    _file = ConfigFile.new()
    if is_active() and FileAccess.file_exists(file_path):
      var error := _file.load(file_path)
      if error != OK:
        push_warning("%s ignores unreadable %s: %s" % [name, file_path, error_string(error)])
        _file = ConfigFile.new()
  return _file

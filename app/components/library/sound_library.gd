class_name SoundLibrary
extends Node

## Owns the open sound directory: its scanned entries and its metadata file.
## Metadata edits are written back after a short debounce and when the node leaves the tree.

signal directory_opened(directory: String)
signal entries_changed
signal metadata_save_failed(message: String)

@export_range(0.1, 10.0, 0.1, "suffix:s") var autosave_delay: float = 1.0

var directory: String = ""
var recursive: bool = false:
  set(value):
    if recursive == value:
      return
    recursive = value
    if has_directory():
      rescan()
var entries: Array[SoundEntry] = []
var metadata := SoundMetadata.new()

var _save_timer: Timer


func _ready() -> void:
  _save_timer = Timer.new()
  _save_timer.one_shot = true
  _save_timer.wait_time = autosave_delay
  _save_timer.timeout.connect(flush)
  add_child(_save_timer)


func _exit_tree() -> void:
  flush()


func has_directory() -> bool:
  return not directory.is_empty()


## Opens a directory and loads its metadata. Returns false if the directory is unavailable.
func open_directory(path: String) -> bool:
  var normalized := AudioFileLoader.normalize_path(path)
  if not DirAccess.dir_exists_absolute(normalized):
    return false
  flush()
  directory = normalized
  metadata = SoundMetadata.new(directory)
  if not metadata.load_file():
    metadata_save_failed.emit(metadata.get_last_error())
  directory_opened.emit(directory)
  rescan()
  return true


func rescan() -> void:
  AudioFileLoader.clear_cache()
  entries = SoundDirectoryScanner.scan(directory, recursive) if has_directory() else []
  entries_changed.emit()


func set_note(entry: SoundEntry, note: String) -> void:
  metadata.set_note(entry.relative_path, note)
  _schedule_save()


func set_volume(entry: SoundEntry, volume: float) -> void:
  metadata.set_volume(entry.relative_path, volume)
  _schedule_save()


## Writes pending metadata changes immediately.
func flush() -> void:
  if _save_timer == null or _save_timer.is_stopped():
    return
  _save_timer.stop()
  if not metadata.save_file():
    metadata_save_failed.emit(metadata.get_last_error())


func _schedule_save() -> void:
  if has_directory():
    _save_timer.start(autosave_delay)

class_name SoundEntry
extends RefCounted

## One playable file found below a sound directory.

## Absolute filesystem path used for loading and playback identity.
var path: String
## Path relative to the sound directory, always with forward slashes. Metadata key.
var relative_path: String
## Relative sub-directory, empty for files directly in the sound directory.
var group: String
## File name without extension.
var title: String


func _init(root: String, file_path: String) -> void:
  path = file_path
  relative_path = file_path.trim_prefix(root).trim_prefix("/")
  group = relative_path.get_base_dir()
  title = relative_path.get_file().get_basename()

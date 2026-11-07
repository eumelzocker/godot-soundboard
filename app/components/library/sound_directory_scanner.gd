class_name SoundDirectoryScanner
extends RefCounted

## Finds supported audio files in a directory, optionally including sub-directories.
## Hidden files and directories are skipped. Results are sorted by group, then by file name.


static func scan(root: String, recursive: bool) -> Array[SoundEntry]:
  var entries: Array[SoundEntry] = []
  var normalized_root := AudioFileLoader.normalize_path(root)
  _scan_into(entries, normalized_root, normalized_root, recursive)
  entries.sort_custom(_compare)
  return entries


static func _scan_into(
  entries: Array[SoundEntry],
  root: String,
  directory_path: String,
  recursive: bool,
) -> void:
  var directory := DirAccess.open(directory_path)
  if directory == null:
    return
  for file_name in directory.get_files():
    if file_name.begins_with(".") or not AudioFileLoader.is_supported(file_name):
      continue
    entries.append(SoundEntry.new(root, directory_path.path_join(file_name)))
  if not recursive:
    return
  for child_name in directory.get_directories():
    if not child_name.begins_with("."):
      _scan_into(entries, root, directory_path.path_join(child_name), true)


static func _compare(a: SoundEntry, b: SoundEntry) -> bool:
  if a.group != b.group:
    return a.group.naturalnocasecmp_to(b.group) < 0
  return a.relative_path.naturalnocasecmp_to(b.relative_path) < 0

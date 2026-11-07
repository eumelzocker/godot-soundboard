extends SceneTree

## Headless contract and composition tests.
## Run: godot --headless --path . -s res://tests/composition_test.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const DOC_ROOTS: Array[String] = ["res://docs/architecture", "res://docs/systems"]

var _failures: int = 0
var _checks: int = 0
var _sound_dir: String


func _initialize() -> void:
  AppSettingsStore.suspended = true
  _sound_dir = ProjectSettings.globalize_path("user://test_sounds")
  _create_fixture(_sound_dir)
  _run.call_deferred()


func _run() -> void:
  _test_loader()
  _test_scanner()
  _test_metadata()
  _test_settings()
  _test_playback()
  await _test_library()
  await _test_main_scene()
  _test_documentation_paths()
  _remove_recursive(_sound_dir)
  print("%d checks, %d failures" % [_checks, _failures])
  quit(1 if _failures > 0 else 0)


func _test_loader() -> void:
  _check(AudioFileLoader.is_supported("a/b.MP3"), "loader accepts upper-case extensions")
  _check(not AudioFileLoader.is_supported("a/b.flac"), "loader rejects unsupported formats")
  _check(AudioFileLoader.load_stream(_sound_dir.path_join("alpha.wav")) is AudioStreamWAV, "loader decodes WAV")
  _check(AudioFileLoader.load_stream(_sound_dir.path_join("missing.wav")) == null, "loader returns null for missing files")


func _test_scanner() -> void:
  var flat := SoundDirectoryScanner.scan(_sound_dir, false)
  _check(_relative_paths(flat) == ["alpha.wav", "beta.wav"], "flat scan skips hidden, unsupported, and nested files")
  var nested := SoundDirectoryScanner.scan(_sound_dir, true)
  _check(_relative_paths(nested) == ["alpha.wav", "beta.wav", "group/gamma.wav"], "recursive scan sorts by group")
  _check(nested[2].group == "group" and nested[2].title == "gamma", "entry derives group and title")


func _test_metadata() -> void:
  var metadata := SoundMetadata.new(_sound_dir)
  _check(metadata.load_file(), "missing metadata file is a valid empty state")
  metadata.set_note("alpha.wav", "  intro  ")
  metadata.set_volume("alpha.wav", 0.5)
  metadata.set_mode("beta.wav", &"toggle")
  metadata.set_volume("beta.wav", SoundMetadata.DEFAULT_VOLUME)
  _check(metadata.save_file(), "metadata saves")

  var text := FileAccess.get_file_as_string(metadata.file_path)
  _check(not text.contains("1.0"), "default values are not written")
  var reloaded := SoundMetadata.new(_sound_dir)
  _check(reloaded.load_file(), "metadata reloads")
  _check(reloaded.get_note("alpha.wav") == "intro", "note round-trips trimmed")
  _check(is_equal_approx(reloaded.get_volume("alpha.wav"), 0.5), "volume round-trips")
  _check(reloaded.get_mode("beta.wav") == &"toggle", "mode round-trips")
  _check(reloaded.get_mode("alpha.wav") == SoundPlaybackComponent.DEFAULT_MODE, "unset mode uses default")

  var file := FileAccess.open(metadata.file_path, FileAccess.WRITE)
  file.store_string("sounds:\n  alpha.wav: {mode: bogus, volume: 9}\n")
  file.close()
  reloaded.load_file()
  _check(reloaded.get_mode("alpha.wav") == SoundPlaybackComponent.DEFAULT_MODE, "unknown mode is ignored")
  _check(reloaded.get_volume("alpha.wav") == SoundMetadata.MAX_VOLUME, "volume is clamped")
  DirAccess.remove_absolute(metadata.file_path)


func _test_settings() -> void:
  var store := AppSettingsStore.new()
  store.max_recent_directories = 2
  store.remember_directory("/a")
  store.remember_directory("/b")
  store.remember_directory("/a")
  store.remember_directory("/c")
  _check(store.get_recent_directories() == PackedStringArray(["/c", "/a"]), "recent directories are unique, newest first, capped")
  store.forget_directory("/c")
  _check(store.get_recent_directories() == PackedStringArray(["/a"]), "recent directory can be forgotten")
  store.free()


func _test_playback() -> void:
  var playback := SoundPlaybackComponent.new()
  root.add_child(playback)
  var path := _sound_dir.path_join("alpha.wav")
  var started: Array[String] = []
  playback.sound_started.connect(func(p: String) -> void: started.append(p))

  _check(playback.trigger(path), "overlap trigger starts")
  _check(playback.trigger(path), "overlap trigger adds a voice")
  _check(started.size() == 1, "started is emitted once per sound")
  _check(playback.get_child_count() == 2, "overlap keeps both voices")
  _check(playback.trigger(path, 1.0, &"restart") and playback.get_child_count() == 1 + _queued(playback), "restart replaces voices")
  _check(not playback.trigger(path, 1.0, &"toggle") and not playback.is_playing(path), "toggle stops a playing sound")
  _check(playback.trigger(path, 1.0, &"toggle") and playback.is_playing(path), "toggle starts a silent sound")
  _check(not playback.trigger(_sound_dir.path_join("missing.wav")), "missing file does not start")
  playback.stop_all()
  _check(playback.get_playing_paths().is_empty(), "stop all silences everything")
  playback.free()


func _test_library() -> void:
  var library := SoundLibrary.new()
  root.add_child(library)
  _check(not library.open_directory(_sound_dir.path_join("nope")), "unavailable directory is rejected")
  _check(library.open_directory(_sound_dir), "directory opens")
  _check(library.entries.size() == 2, "library scans flat by default")
  library.recursive = true
  _check(library.entries.size() == 3, "toggling recursion rescans")
  library.set_note(library.entries[0], "hello")
  library.flush()
  _check(FileAccess.file_exists(_sound_dir.path_join(SoundMetadata.FILE_NAME)), "flush writes metadata into the sound directory")
  library.free()
  DirAccess.remove_absolute(_sound_dir.path_join(SoundMetadata.FILE_NAME))
  await process_frame


func _test_main_scene() -> void:
  var app := (load(MAIN_SCENE) as PackedScene).instantiate() as SoundboardApp
  app.restore_last_directory = false
  root.add_child(app)
  await process_frame
  _check(app.settings != null and app.library != null and app.playback != null, "main scene wires its components")
  _check(app.open_directory(_sound_dir), "app opens a directory")
  _check(app.get_visible_card_count() == app.library.entries.size(), "app shows one card per sound")
  var card := app.get_card(app.library.entries[0].path)
  _check(card != null, "cards are addressable by path")
  card.triggered.emit()
  _check(app.playback.is_playing(card.entry.path), "card trigger plays its sound")
  app._search_edit.text = "beta"
  app._search_edit.text_changed.emit("beta")
  _check(app.get_visible_card_count() == 1, "search filters cards")
  app.playback.stop_all()
  await process_frame
  app.free()
  await process_frame


func _test_documentation_paths() -> void:
  var pattern := RegEx.create_from_string("`(res://[^`]+)`")
  for doc_root in DOC_ROOTS:
    for file_name in DirAccess.get_files_at(doc_root):
      if not file_name.ends_with(".md"):
        continue
      var text := FileAccess.get_file_as_string(doc_root.path_join(file_name))
      for match in pattern.search_all(text):
        var path := match.get_string(1)
        _check(
          FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path),
          "%s references existing %s" % [file_name, path]
        )


func _check(condition: bool, description: String) -> void:
  _checks += 1
  if not condition:
    _failures += 1
    printerr("FAIL: " + description)


func _queued(node: Node) -> int:
  return node.get_children().filter(func(child: Node) -> bool: return child.is_queued_for_deletion()).size()


func _relative_paths(entries: Array[SoundEntry]) -> Array:
  return entries.map(func(entry: SoundEntry) -> String: return entry.relative_path)


func _create_fixture(directory: String) -> void:
  _remove_recursive(directory)
  DirAccess.make_dir_recursive_absolute(directory.path_join("group"))
  DirAccess.make_dir_recursive_absolute(directory.path_join(".hidden"))
  var stream := AudioStreamWAV.new()
  stream.format = AudioStreamWAV.FORMAT_16_BITS
  stream.mix_rate = 8000
  var data := PackedByteArray()
  data.resize(8000)
  stream.data = data
  for relative in ["alpha.wav", "beta.wav", "group/gamma.wav", ".hidden.wav", ".hidden/delta.wav"]:
    stream.save_to_wav(directory.path_join(relative))
  FileAccess.open(directory.path_join("readme.txt"), FileAccess.WRITE).store_string("not audio")


func _remove_recursive(directory: String) -> void:
  if not DirAccess.dir_exists_absolute(directory):
    return
  for child in DirAccess.get_directories_at(directory):
    _remove_recursive(directory.path_join(child))
  for file_name in DirAccess.get_files_at(directory):
    DirAccess.remove_absolute(directory.path_join(file_name))
  DirAccess.remove_absolute(directory)

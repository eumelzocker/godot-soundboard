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
  metadata.set_note("alpha.wav", "  intro\nsecond line  ")
  metadata.set_volume("alpha.wav", 0.5)
  metadata.set_note("beta.wav", "outro")
  metadata.set_volume("beta.wav", SoundMetadata.DEFAULT_VOLUME)
  _check(metadata.save_file(), "metadata saves")

  var text := FileAccess.get_file_as_string(metadata.file_path)
  _check(not text.contains("1.0"), "default values are not written")
  var reloaded := SoundMetadata.new(_sound_dir)
  _check(reloaded.load_file(), "metadata reloads")
  _check(reloaded.get_note("alpha.wav") == "intro\nsecond line", "multi-line note round-trips trimmed")
  _check(is_equal_approx(reloaded.get_volume("alpha.wav"), 0.5), "volume round-trips")
  _check(is_equal_approx(reloaded.get_volume("beta.wav"), SoundMetadata.DEFAULT_VOLUME), "unset volume uses default")

  var file := FileAccess.open(metadata.file_path, FileAccess.WRITE)
  file.store_string("sounds:\n  alpha.wav: {mode: legacy, volume: 9}\n")
  file.close()
  reloaded.load_file()
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
  var metadata_path := _sound_dir.path_join(SoundMetadata.FILE_NAME)
  library.autosave_delay = 0.05
  library.set_note(library.entries[0], "autosaved")
  _check(library.has_unsaved_changes(), "an edit marks the library dirty")
  await create_timer(0.3).timeout
  _check(not library.has_unsaved_changes(), "the autosave timer clears pending changes")
  _check(FileAccess.get_file_as_string(metadata_path).contains("autosaved"), "the autosave timer writes metadata into the sound directory")
  library.set_note(library.entries[0], "hello")
  library.flush()
  _check(FileAccess.get_file_as_string(metadata_path).contains("hello"), "flush writes pending metadata immediately")
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
  app._mode_picker.select(SoundPlaybackComponent.MODE_IDS.find(&"toggle"))
  app._mode_picker.item_selected.emit(app._mode_picker.selected)
  _check(app.playback_mode == &"toggle", "toolbar sets the global playback mode")
  card.triggered.emit()
  _check(not app.playback.is_playing(card.entry.path), "global toggle mode stops a playing card")
  card.volume_changed.emit(0.5)
  _check(is_equal_approx(app.library.metadata.get_volume(card.entry.relative_path), 0.5), "card volume reaches metadata")
  if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
    card.copy_requested.emit(false)
    _check(DisplayServer.clipboard_get() == card.entry.relative_path.get_file(), "copy icon copies the file name")
    card.copy_requested.emit(true)
    _check(DisplayServer.clipboard_get() == card.entry.path, "Ctrl+click on the copy icon copies the full path")
  card.note_edit_requested.emit()
  _check(app._note_editor.is_open(), "note button opens the editor")
  app._note_editor._text_edit.text = "first\nsecond\nthird"
  app._note_editor.save()
  _check(not app._note_editor.is_open(), "saving closes the editor")
  _check(card.note == "first\nsecond\nthird", "saved note reaches the card")
  _check(app.library.metadata.get_note(card.entry.relative_path) == card.note, "saved note reaches metadata")
  _check(card._note_button.text == "first  (+2)", "card shows the first line and the hidden line count")
  app._search_edit.text = "beta"
  app._search_edit.text_changed.emit("beta")
  _check(app.get_visible_card_count() == 1, "search filters cards")
  app.playback.stop_all()
  await _test_settings_dialog(app)
  await process_frame
  app.free()
  await process_frame


func _test_settings_dialog(app: SoundboardApp) -> void:
  var dialog := app.settings_dialog
  var original_preset := GoUi.preset().id
  dialog.open_dialog()
  await process_frame
  _check(dialog.is_dialog_open(), "settings dialog opens")
  for page_id: StringName in [&"appearance", &"playback", &"recent_folders", &"shortcuts", &"about"]:
    _check(dialog.select_page(page_id), "settings dialog has page '%s'" % page_id)

  var playback_page := dialog.get_node("PlaybackPageProvider") as PlaybackPageProvider
  dialog.select_page(&"playback")
  playback_page._mode_select.select(SoundPlaybackComponent.MODE_IDS.find(&"restart"))
  playback_page._mode_select.item_selected.emit(playback_page._mode_select.selected)
  _check(app.playback_mode == &"restart" and app._mode_picker.selected == playback_page._mode_select.selected, "playback page sets the mode and syncs the toolbar")
  playback_page._volume_slider.value = 0.3
  _check(is_equal_approx(app.master_volume, 0.3) and is_equal_approx(app._master_slider.value, 0.3), "playback page sets the master volume and syncs the toolbar")
  var recursive := app.library.recursive
  playback_page._recursive_toggle.button_pressed = not recursive
  _check(app.library.recursive != recursive and app._recursive_toggle.button_pressed == app.library.recursive, "playback page toggles subfolders and syncs the toolbar")
  app._mode_picker.select(SoundPlaybackComponent.MODE_IDS.find(&"overlap"))
  app._mode_picker.item_selected.emit(app._mode_picker.selected)
  dialog.select_page(&"playback")
  _check(playback_page._mode_select.selected == app._mode_picker.selected, "playback page reflects toolbar changes")

  var missing_dir := _sound_dir.path_join("gone")
  app.settings.remember_directory(missing_dir)
  dialog.select_page(&"appearance")
  var recent_page := dialog.get_node("RecentFoldersPageProvider") as RecentFoldersPageProvider
  recent_page._remove(missing_dir)
  await process_frame
  _check(not app.settings.get_recent_directories().has(missing_dir), "recent page removes a folder")
  _check(dialog.is_dialog_open() and dialog.get_selected_page_id() == &"appearance", "removing a folder keeps the dialog on its page")
  recent_page._open(_sound_dir)
  await process_frame
  _check(not dialog.is_dialog_open(), "opening a recent folder closes the dialog")
  dialog.open_dialog()
  await process_frame
  dialog._page_filter.set_text("version")
  dialog._on_page_filter_changed("version")
  _check(dialog.get_selected_page_id() == &"about", "page filter narrows to matching pages")
  dialog._on_page_filter_changed("")

  var appearance := dialog.get_node("AppearancePageProvider") as AppearancePageProvider
  var old_ui := app._ui_root
  var target_light := not String(original_preset).ends_with("_light")
  appearance.apply_preset(AppearancePageProvider.family_of(original_preset), target_light)
  await process_frame
  await process_frame
  _check(GoUi.preset().id != original_preset, "appearance switches the GoHUD preset")
  _check(not is_instance_valid(old_ui) or old_ui.is_queued_for_deletion(), "theme change rebuilds the app UI")
  _check(app.get_visible_card_count() > 0, "rebuilt UI restores the sound cards")
  _check(dialog.is_dialog_open() and dialog.get_selected_page_id() == &"about", "dialog stays open on its page after a theme change")
  _check(
    app.settings.get_value(AppearancePageProvider.APPEARANCE_SECTION, AppearancePageProvider.THEME_PRESET_KEY, "") == String(GoUi.preset().id),
    "chosen preset is stored in the settings"
  )

  var f1 := InputEventAction.new()
  f1.action = &"toggle_settings_dialog"
  f1.pressed = true
  Input.parse_input_event(f1)
  await process_frame
  await process_frame
  _check(not dialog.is_dialog_open(), "F1 closes the settings dialog")
  GoUi.use_preset(original_preset)
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

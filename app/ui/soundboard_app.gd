class_name SoundboardApp
extends Control

## Composition root of the soundboard window. Connects library, playback, and settings with the
## GoHUD-based toolbar and the grid of sound cards. The visible UI is rebuilt from current state
## whenever the GoHUD theme changes.

const APP_SECTION := "app"
const MASTER_VOLUME_KEY := "master_volume"
const RECURSIVE_KEY := "recursive"
const PLAYBACK_MODE_KEY := "playback_mode"
const SLIM_LAYOUT_KEY := "slim_layout"
const ROOT_GROUP_TITLE := "(folder root)"
const COPY_NOTICE_SECONDS := 1.5
const MIN_SEARCH_WIDTH := 220.0
const MIN_WINDOW_HEIGHT := 480
const MODE_TITLES: Dictionary[StringName, String] = {
  &"overlap": "Overlap",
  &"restart": "Restart",
  &"toggle": "Toggle",
}

@export var settings: AppSettingsStore
@export var library: SoundLibrary
@export var playback: SoundPlaybackComponent
@export var settings_dialog: SettingsDialogComponent
@export var length_scanner: SoundLengthScanner
@export var default_master_volume: float = 0.8
## Minimum card width in the slim layout; the wide layout doubles it.
@export var min_card_width: float = 240.0
## Reopens the most recent directory on startup.
@export var restore_last_directory: bool = true

## Playback mode applied to every sound card.
var playback_mode: StringName = SoundPlaybackComponent.DEFAULT_MODE
var master_volume: float
## Narrow cards (true) or double-width cards for long file names (false).
var slim_layout: bool = true
var _cards: Dictionary[String, SoundCard] = {}
## Known lengths by path; survives UI rebuilds and is reset when the library rescans.
var _lengths: Dictionary[String, float] = {}
var _ui_root: Control
var _mode_picker: OptionButton
var _search_edit: LineEdit
var _recent_button: MenuButton
var _rescan_button: Button
var _recursive_toggle: CheckButton
var _master_slider: HSlider
var _status_label: Label
var _content: VBoxContainer
var _file_dialog: FileDialog
var _snackbar: GoSnackbar
var _note_editor: NoteEditor


func _ready() -> void:
  assert(
    settings != null and library != null and playback != null and settings_dialog != null
      and length_scanner != null,
    "SoundboardApp needs its components"
  )
  library.recursive = settings.get_value(APP_SECTION, RECURSIVE_KEY, false)
  master_volume = settings.get_value(APP_SECTION, MASTER_VOLUME_KEY, default_master_volume)
  set_master_volume(master_volume)
  slim_layout = settings.get_value(APP_SECTION, SLIM_LAYOUT_KEY, true)
  var saved_mode := StringName(settings.get_value(APP_SECTION, PLAYBACK_MODE_KEY, String(playback_mode)))
  if SoundPlaybackComponent.MODE_IDS.has(saved_mode):
    playback_mode = saved_mode
  _build_services()
  _build_ui()

  library.entries_changed.connect(_on_entries_changed)
  length_scanner.length_ready.connect(_on_length_ready)
  library.metadata_save_failed.connect(_show_error)
  playback.sound_started.connect(_on_sound_started)
  playback.sound_stopped.connect(_on_sound_stopped)
  get_window().files_dropped.connect(_on_files_dropped)
  GoUi.watch(_rebuild_ui)
  set_process(false)

  var recent := settings.get_recent_directories()
  if restore_last_directory and not recent.is_empty() and DirAccess.dir_exists_absolute(recent[0]):
    open_directory(recent[0])
  else:
    _rebuild_cards()


func _exit_tree() -> void:
  GoUi.unwatch(_rebuild_ui)
  settings.store_values({
    APP_SECTION: {
      MASTER_VOLUME_KEY: master_volume,
      RECURSIVE_KEY: library.recursive,
      PLAYBACK_MODE_KEY: String(playback_mode),
      SLIM_LAYOUT_KEY: slim_layout,
    },
  })


func _input(event: InputEvent) -> void:
  if _note_editor.is_open() or settings_dialog.is_dialog_open():
    return
  if event.is_action_pressed(&"stop_all"):
    playback.stop_all()
  elif event.is_action_pressed(&"focus_search"):
    _search_edit.grab_focus()
    _search_edit.select_all()
  elif event.is_action_pressed(&"open_directory"):
    show_directory_dialog()
  elif event.is_action_pressed(&"rescan_directory"):
    library.rescan()
  else:
    return
  get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
  for path in playback.get_playing_paths():
    if _cards.has(path):
      _cards[path].set_playback_position(playback.get_position(path))


func open_directory(path: String) -> bool:
  playback.stop_all()
  if not library.open_directory(path):
    settings.forget_directory(path)
    _show_error("Folder not available: %s" % path)
    return false
  settings.remember_directory(library.directory)
  return true


func show_directory_dialog() -> void:
  _file_dialog.current_dir = (
    library.directory if library.has_directory() else OS.get_environment("HOME")
  )
  _file_dialog.popup_centered_ratio(0.7)


func get_card(path: String) -> SoundCard:
  return _cards.get(path)


func get_visible_card_count() -> int:
  return _cards.values().filter(func(card: SoundCard) -> bool: return card.visible).size()


## Theme-independent helpers that survive UI rebuilds.
func _build_services() -> void:
  _file_dialog = FileDialog.new()
  _file_dialog.title = "Choose sound folder"
  _file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
  _file_dialog.access = FileDialog.ACCESS_FILESYSTEM
  _file_dialog.use_native_dialog = true
  _file_dialog.dir_selected.connect(open_directory)
  add_child(_file_dialog)

  _note_editor = NoteEditor.new()
  add_child(_note_editor)


## Replaces the visible UI after a theme change, keeping search text and loaded cards. Runs
## synchronously: GoHUD notifies from the settings dialog's deferred rebuild, and an immediate
## swap removes old controls before any popup tries to give focus back to them.
func _rebuild_ui() -> void:
  if not is_inside_tree():
    return
  var search_text := _search_edit.text
  remove_child(_ui_root)
  _ui_root.queue_free()
  _build_ui()
  _search_edit.text = search_text
  _rebuild_cards()


func _build_ui() -> void:
  theme = GoUi.theme()
  _ui_root = Control.new()
  _ui_root.name = "UI"
  _ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(_ui_root)
  move_child(_ui_root, 0)

  var background := ColorRect.new()
  background.color = GoUi.color(GoTheme.BACKGROUND)
  background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _ui_root.add_child(background)

  var frame := GoStyle.padding(GoUi.metric(GoTheme.GAP))
  frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _ui_root.add_child(frame)
  var layout := GoStyle.column(GoUi.metric(GoTheme.GAP))
  frame.add_child(layout)

  # The toolbar wraps its three groups onto more lines in narrow windows instead of forcing the
  # whole layout wider than the window.
  var toolbar := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
  layout.add_child(toolbar)

  var folder_group := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  folder_group.name = "FolderGroup"
  folder_group.add_child(GoStyle.button("Open folder…", show_directory_dialog, GoStyle.Tone.PRIMARY))
  _recent_button = MenuButton.new()
  _recent_button.text = "Recent"
  _recent_button.flat = false
  GoStyle.style_button(_recent_button)
  _recent_button.about_to_popup.connect(_fill_recent_menu)
  _recent_button.get_popup().index_pressed.connect(_on_recent_selected)
  folder_group.add_child(_recent_button)
  _rescan_button = GoStyle.icon_button(GoIconSet.REFRESH, library.rescan)
  _rescan_button.tooltip_text = "Rescan folder (F5)"
  folder_group.add_child(_rescan_button)
  _recursive_toggle = GoStyle.toggle("Subfolders", false)
  _recursive_toggle.set_pressed_no_signal(library.recursive)
  _recursive_toggle.tooltip_text = "Include sub-folders as groups"
  _recursive_toggle.toggled.connect(set_recursive)
  folder_group.add_child(_recursive_toggle)
  toolbar.add_child(folder_group)

  _search_edit = GoStyle.line_edit("Search name or note (Ctrl+F)")
  _search_edit.clear_button_enabled = true
  _search_edit.custom_minimum_size.x = MIN_SEARCH_WIDTH
  _search_edit.text_changed.connect(func(_text: String) -> void: _apply_filter())
  toolbar.add_child(_search_edit)
  _search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

  var playback_group := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  playback_group.name = "PlaybackGroup"
  _mode_picker = GoStyle.picker()
  for mode_id in SoundPlaybackComponent.MODE_IDS:
    _mode_picker.add_item(MODE_TITLES[mode_id])
  _mode_picker.select(SoundPlaybackComponent.MODE_IDS.find(playback_mode))
  _mode_picker.tooltip_text = "Click behavior for all sounds\nOverlap: every click adds a voice\nRestart: a click restarts the sound\nToggle: a click starts or stops the sound"
  _mode_picker.item_selected.connect(
    func(index: int) -> void: set_playback_mode(SoundPlaybackComponent.MODE_IDS[index])
  )
  playback_group.add_child(_mode_picker)
  var volume_icon := GoStyle.icon_button(GoIconSet.VOLUME_HIGH)
  volume_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  playback_group.add_child(volume_icon)
  _master_slider = GoStyle.slider(0.0, 1.0, 0.01)
  _master_slider.custom_minimum_size.x = 140
  _master_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  _master_slider.tooltip_text = "Master volume"
  _master_slider.value = master_volume
  _master_slider.value_changed.connect(set_master_volume)
  playback_group.add_child(_master_slider)
  playback_group.add_child(GoStyle.button("Stop all (Esc)", playback.stop_all, GoStyle.Tone.DANGER))
  var settings_button := GoStyle.icon_button(GoIconSet.SETTINGS, settings_dialog.open_dialog)
  settings_button.tooltip_text = "Settings (F1)"
  playback_group.add_child(settings_button)
  toolbar.add_child(playback_group)
  _limit_window_size.call_deferred([folder_group, _search_edit, playback_group])

  _status_label = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
  layout.add_child(_status_label)

  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  layout.add_child(scroll)
  _content = GoStyle.column(GoUi.metric(GoTheme.GAP))
  _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  scroll.add_child(_content)

  _snackbar = GoSnackbar.new()
  _ui_root.add_child(_snackbar)


func _rebuild_cards() -> void:
  for child in _content.get_children():
    _content.remove_child(child)
    child.queue_free()
  _cards.clear()
  _rescan_button.disabled = not library.has_directory()

  if not library.has_directory():
    _content.add_child(_build_empty_state("Open a folder or drop one onto this window."))
  elif library.entries.is_empty():
    _content.add_child(_build_empty_state("No MP3, OGG, or WAV files in this folder."))

  var show_groups := library.recursive and library.entries.any(
    func(entry: SoundEntry) -> bool: return not entry.group.is_empty()
  )
  var grid: GridContainer = null
  var group := ""
  for entry in library.entries:
    if grid == null or entry.group != group:
      group = entry.group
      var section := VBoxContainer.new()
      section.name = "Group"
      section.set_meta(&"sound_group", group)
      if show_groups:
        section.add_child(GoStyle.section(group if not group.is_empty() else ROOT_GROUP_TITLE, false))
      grid = GoStyle.responsive_grid(card_width())
      section.add_child(grid)
      _content.add_child(section)
    grid.add_child(_create_card(entry))
  _apply_filter()
  var unknown: Array[String] = []
  for entry in library.entries:
    if not _lengths.has(entry.path):
      unknown.append(entry.path)
  length_scanner.scan(unknown)


func _on_entries_changed() -> void:
  _lengths.clear()
  _rebuild_cards()


func _on_length_ready(path: String, seconds: float) -> void:
  _lengths[path] = seconds
  if _cards.has(path):
    _cards[path].set_length(seconds)


func _create_card(entry: SoundEntry) -> SoundCard:
  var metadata := library.metadata
  var card := SoundCard.new()
  card.setup(
    entry,
    metadata.get_note(entry.relative_path),
    metadata.get_volume(entry.relative_path),
  )
  card.triggered.connect(func() -> void:
    if not playback.trigger(
      entry.path, metadata.get_volume(entry.relative_path), playback_mode
    ) and not FileAccess.file_exists(entry.path):
      _show_error("File missing: %s" % entry.relative_path)
  )
  card.note_edit_requested.connect(func() -> void:
    _note_editor.open(entry.title, card.note, func(note: String) -> void:
      card.set_note(note)
      library.set_note(entry, note)
      _apply_filter()
    )
  )
  card.copy_requested.connect(func(full_path: bool) -> void:
    copy_to_clipboard(entry.path if full_path else entry.relative_path.get_file())
  )
  card.volume_changed.connect(func(volume: float) -> void:
    library.set_volume(entry, volume)
    playback.set_volume(entry.path, volume)
  )
  card.set_length(_lengths.get(entry.path, -1.0))
  card.set_playing(playback.is_playing(entry.path))
  _cards[entry.path] = card
  return card


func _build_empty_state(message: String) -> Control:
  var column := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  column.name = "EmptyState"
  column.add_child(GoStyle.label(message, GoTheme.ROLE_SUBTITLE))
  var recent := settings.get_recent_directories()
  if not recent.is_empty():
    column.add_child(GoStyle.section("Recent folders", false))
    for path in recent:
      if path != library.directory:
        column.add_child(GoStyle.list_button(GoIconSet.BOOK, path, open_directory.bind(path), Color.TRANSPARENT, "", false))
  return column


func _apply_filter() -> void:
  var words := _search_edit.text.to_lower().split(" ", false)
  for section in _content.get_children():
    if not section.has_meta(&"sound_group"):
      continue
    var grid := section.get_child(section.get_child_count() - 1)
    var any_visible := false
    for card: SoundCard in grid.get_children():
      card.visible = card.matches(words)
      any_visible = any_visible or card.visible
    section.visible = any_visible
  _update_status()


func _update_status() -> void:
  if not library.has_directory():
    _status_label.text = "No folder open"
    return
  var parts := PackedStringArray([library.directory, "%d sounds" % library.entries.size()])
  var shown := get_visible_card_count()
  if shown != library.entries.size():
    parts.append("%d shown" % shown)
  var playing := playback.get_playing_paths().size()
  if playing > 0:
    parts.append("%d playing" % playing)
  _status_label.text = "  ·  ".join(parts)


func _fill_recent_menu() -> void:
  var popup := _recent_button.get_popup()
  popup.clear()
  for path in settings.get_recent_directories():
    popup.add_item(path)
  if popup.item_count == 0:
    popup.add_item("No recent folders")
    popup.set_item_disabled(0, true)


func _on_recent_selected(index: int) -> void:
  var recent := settings.get_recent_directories()
  if index < recent.size():
    open_directory(recent[index])


func _on_files_dropped(files: PackedStringArray) -> void:
  if files.is_empty():
    return
  var path := files[0]
  open_directory(path if DirAccess.dir_exists_absolute(path) else path.get_base_dir())


func _on_sound_started(path: String) -> void:
  if not _lengths.has(path):
    var stream := AudioFileLoader.load_stream(path)
    if stream != null:
      _on_length_ready(path, stream.get_length())
  if _cards.has(path):
    _cards[path].set_playing(true)
  set_process(true)
  _update_status()


func _on_sound_stopped(path: String) -> void:
  if _cards.has(path):
    _cards[path].set_playing(false)
  set_process(not playback.get_playing_paths().is_empty())
  _update_status()


## Setters shared by the toolbar and the settings dialog; each keeps the toolbar in sync.
func set_playback_mode(mode: StringName) -> void:
  var index := SoundPlaybackComponent.MODE_IDS.find(mode)
  if index < 0:
    return
  playback_mode = mode
  if _mode_picker != null:
    _mode_picker.select(index)


func set_master_volume(volume: float) -> void:
  master_volume = clampf(volume, 0.0, 1.0)
  AudioServer.set_bus_volume_linear(0, master_volume)
  if _master_slider != null:
    _master_slider.set_value_no_signal(master_volume)


func set_recursive(on: bool) -> void:
  library.recursive = on
  if _recursive_toggle != null:
    _recursive_toggle.set_pressed_no_signal(on)


func copy_to_clipboard(text: String) -> void:
  DisplayServer.clipboard_set(text)
  _snackbar.show_text("Copied: %s" % text, GoTheme.TEXT, COPY_NOTICE_SECONDS)


func _show_error(message: String) -> void:
  _snackbar.show_text(message, GoTheme.DANGER)


## Keeps the window at least as wide as the widest toolbar group (plus frame and scrollbar), so
## nothing is pushed out of view. Recomputed after theme changes, which can change font sizes.
func _limit_window_size(toolbar_items: Array) -> void:
  var widest := card_width()
  for item: Control in toolbar_items:
    if is_instance_valid(item):
      widest = maxf(widest, item.get_combined_minimum_size().x)
  var margins := 2.0 * GoUi.metric(GoTheme.GAP) + GoUi.metric(GoTheme.GAP_SMALL)
  get_window().min_size = Vector2i(ceili(widest + margins), MIN_WINDOW_HEIGHT)


func set_slim_layout(on: bool) -> void:
  if slim_layout == on:
    return
  slim_layout = on
  _rebuild_ui()


func card_width() -> float:
  return min_card_width if slim_layout else min_card_width * 2.0

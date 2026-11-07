class_name SoundboardApp
extends Control

## Composition root of the soundboard window. Connects library, playback, and settings with the
## GoHUD-based toolbar and the grid of sound cards.

const APP_SECTION := "app"
const MASTER_VOLUME_KEY := "master_volume"
const RECURSIVE_KEY := "recursive"
const ROOT_GROUP_TITLE := "(folder root)"

@export var settings: AppSettingsStore
@export var library: SoundLibrary
@export var playback: SoundPlaybackComponent
@export var default_master_volume: float = 0.8
@export var min_card_width: float = 280.0
## Reopens the most recent directory on startup.
@export var restore_last_directory: bool = true

var _cards: Dictionary[String, SoundCard] = {}
var _search_edit: LineEdit
var _recent_button: MenuButton
var _rescan_button: Button
var _recursive_toggle: CheckButton
var _master_slider: HSlider
var _status_label: Label
var _content: VBoxContainer
var _file_dialog: FileDialog
var _snackbar: GoSnackbar


func _ready() -> void:
  assert(settings != null and library != null and playback != null, "SoundboardApp needs its components")
  _build_ui()
  library.recursive = settings.get_value(APP_SECTION, RECURSIVE_KEY, false)
  _recursive_toggle.set_pressed_no_signal(library.recursive)
  _master_slider.value = settings.get_value(APP_SECTION, MASTER_VOLUME_KEY, default_master_volume)
  _apply_master_volume(_master_slider.value)

  library.entries_changed.connect(_rebuild_cards)
  library.metadata_save_failed.connect(_show_error)
  playback.sound_started.connect(_on_sound_started)
  playback.sound_stopped.connect(_on_sound_stopped)
  get_window().files_dropped.connect(_on_files_dropped)
  set_process(false)

  var recent := settings.get_recent_directories()
  if restore_last_directory and not recent.is_empty() and DirAccess.dir_exists_absolute(recent[0]):
    open_directory(recent[0])
  else:
    _rebuild_cards()


func _exit_tree() -> void:
  settings.store_values({
    APP_SECTION: {MASTER_VOLUME_KEY: _master_slider.value, RECURSIVE_KEY: library.recursive},
  })


func _input(event: InputEvent) -> void:
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
      _cards[path].set_progress(playback.get_progress(path))


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


func _build_ui() -> void:
  theme = GoUi.theme()
  var background := ColorRect.new()
  background.color = GoUi.color(GoTheme.BACKGROUND)
  background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  add_child(background)

  var frame := GoStyle.padding(GoUi.metric(GoTheme.GAP))
  frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  add_child(frame)
  var layout := GoStyle.column(GoUi.metric(GoTheme.GAP))
  frame.add_child(layout)

  var toolbar := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  layout.add_child(toolbar)
  toolbar.add_child(GoStyle.button("Open folder…", show_directory_dialog, GoStyle.Tone.PRIMARY))
  _recent_button = MenuButton.new()
  _recent_button.text = "Recent"
  _recent_button.flat = false
  GoStyle.style_button(_recent_button)
  _recent_button.about_to_popup.connect(_fill_recent_menu)
  _recent_button.get_popup().index_pressed.connect(_on_recent_selected)
  toolbar.add_child(_recent_button)
  _rescan_button = GoStyle.icon_button(GoIconSet.REFRESH, library.rescan)
  _rescan_button.tooltip_text = "Rescan folder (F5)"
  toolbar.add_child(_rescan_button)
  _recursive_toggle = GoStyle.toggle("Subfolders", false)
  _recursive_toggle.tooltip_text = "Include sub-folders as groups"
  _recursive_toggle.toggled.connect(func(on: bool) -> void: library.recursive = on)
  toolbar.add_child(_recursive_toggle)
  _search_edit = GoStyle.line_edit("Search name or note (Ctrl+F)")
  _search_edit.clear_button_enabled = true
  _search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _search_edit.text_changed.connect(func(_text: String) -> void: _apply_filter())
  toolbar.add_child(_search_edit)
  var volume_icon := GoStyle.icon_button(GoIconSet.VOLUME_HIGH)
  volume_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  toolbar.add_child(volume_icon)
  _master_slider = GoStyle.slider(0.0, 1.0, 0.01)
  _master_slider.custom_minimum_size.x = 140
  _master_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  _master_slider.tooltip_text = "Master volume"
  _master_slider.value_changed.connect(_apply_master_volume)
  toolbar.add_child(_master_slider)
  toolbar.add_child(GoStyle.button("Stop all (Esc)", playback.stop_all, GoStyle.Tone.DANGER))
  for control: Control in toolbar.get_children():
    if control != _search_edit and control != _master_slider:
      GoStyle.natural_width(control)

  _status_label = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
  layout.add_child(_status_label)

  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  layout.add_child(scroll)
  _content = GoStyle.column(GoUi.metric(GoTheme.GAP))
  _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  scroll.add_child(_content)

  _file_dialog = FileDialog.new()
  _file_dialog.title = "Choose sound folder"
  _file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
  _file_dialog.access = FileDialog.ACCESS_FILESYSTEM
  _file_dialog.use_native_dialog = true
  _file_dialog.dir_selected.connect(open_directory)
  add_child(_file_dialog)

  _snackbar = GoSnackbar.new()
  add_child(_snackbar)


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
      grid = GoStyle.responsive_grid(min_card_width)
      section.add_child(grid)
      _content.add_child(section)
    grid.add_child(_create_card(entry))
  _apply_filter()


func _create_card(entry: SoundEntry) -> SoundCard:
  var metadata := library.metadata
  var card := SoundCard.new()
  card.setup(
    entry,
    metadata.get_note(entry.relative_path),
    metadata.get_volume(entry.relative_path),
    metadata.get_mode(entry.relative_path),
  )
  card.triggered.connect(func() -> void:
    if not playback.trigger(
      entry.path,
      metadata.get_volume(entry.relative_path),
      metadata.get_mode(entry.relative_path),
    ) and not FileAccess.file_exists(entry.path):
      _show_error("File missing: %s" % entry.relative_path)
  )
  card.stop_requested.connect(playback.stop.bind(entry.path))
  card.note_changed.connect(func(note: String) -> void: library.set_note(entry, note))
  card.volume_changed.connect(func(volume: float) -> void:
    library.set_volume(entry, volume)
    playback.set_volume(entry.path, volume)
  )
  card.mode_changed.connect(func(mode: StringName) -> void: library.set_mode(entry, mode))
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
  if _cards.has(path):
    _cards[path].set_playing(true)
  set_process(true)
  _update_status()


func _on_sound_stopped(path: String) -> void:
  if _cards.has(path):
    _cards[path].set_playing(false)
  set_process(not playback.get_playing_paths().is_empty())
  _update_status()


func _apply_master_volume(volume: float) -> void:
  AudioServer.set_bus_volume_linear(0, volume)


func _show_error(message: String) -> void:
  _snackbar.show_text(message, GoTheme.DANGER)

class_name SoundCard
extends PanelContainer

## Presents one sound: trigger button, volume, playback progress, and note.
## The card only reports edits; the app decides how to store and play them.

signal triggered
## The note button was pressed; the owner opens an editor and calls set_note() with the result.
signal note_edit_requested
signal volume_changed(volume: float)
## The copy icon was clicked; [param full_path] is true with Ctrl held.
signal copy_requested(full_path: bool)

const VOLUME_STEPS: Array[float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
const COPY_ICON_SIZE := 20

var entry: SoundEntry
## Full note text, possibly multi-line.
var note: String = ""
## Length in seconds, or -1 while unknown.
var length: float = -1.0

var _play_button: Button
var _copy_button: Button
var _volume_button: MenuButton
var _volumes: Array[float] = []
var _progress: ProgressBar
var _time_label: Label
var _playing: bool = false
var _note_button: Button


func setup(sound: SoundEntry, initial_note: String, volume: float) -> void:
  entry = sound
  name = "SoundCard"
  GoStyle.style_panel(self, GoStyle.surface(GoTheme.BOX_CARD))

  var column := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
  add_child(column)

  var header := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  column.add_child(header)
  _play_button = GoStyle.button(sound.title, triggered.emit, GoStyle.Tone.PRIMARY)
  _play_button.set_meta(&"go_no_wrap", true)
  _play_button.autowrap_mode = TextServer.AUTOWRAP_OFF
  _play_button.clip_text = true
  _play_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  _play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  header.add_child(_play_button)

  _copy_button = GoStyle.icon_button(
    GoIconSet.COPY,
    func() -> void: copy_requested.emit(Input.is_key_pressed(KEY_CTRL)),
    COPY_ICON_SIZE,
  )
  _copy_button.tooltip_text = "Copy file name\nCtrl+click: copy full path"
  header.add_child(_copy_button)

  _volumes.assign(VOLUME_STEPS)
  if not _volumes.has(volume):
    _volumes.append(volume)
    _volumes.sort()
  _volume_button = MenuButton.new()
  _volume_button.flat = false
  _volume_button.tooltip_text = "Volume"
  GoStyle.style_button(_volume_button, GoStyle.Tone.OUTLINED)
  GoStyle.natural_width(_volume_button)
  var menu := _volume_button.get_popup()
  for step in _volumes:
    menu.add_radio_check_item(_volume_text(step))
  menu.index_pressed.connect(_on_volume_selected)
  header.add_child(_volume_button)
  _show_volume(volume)

  var progress_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  column.add_child(progress_row)
  _progress = GoStyle.progress(GoUi.color(GoTheme.ACCENT_FILL))
  _progress.max_value = 1.0
  _progress.step = 0.0
  _progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  progress_row.add_child(_progress)
  _time_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.SECONDARY))
  _time_label.name = "TimeLabel"
  _time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
  _time_label.size_flags_horizontal = Control.SIZE_SHRINK_END
  _time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  _time_label.tooltip_text = "Length; counts the position while playing"
  _time_label.mouse_filter = Control.MOUSE_FILTER_PASS
  progress_row.add_child(_time_label)

  _note_button = GoStyle.button("", note_edit_requested.emit, GoStyle.Tone.BARE)
  _note_button.set_meta(&"go_no_wrap", true)
  _note_button.autowrap_mode = TextServer.AUTOWRAP_OFF
  _note_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
  _note_button.clip_text = true
  _note_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  _note_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  column.add_child(_note_button)

  set_note(initial_note)


func set_note(text: String) -> void:
  note = text.strip_edges()
  var lines := note.split("\n", false)
  if lines.is_empty():
    _note_button.text = "Add note…"
    _note_button.add_theme_color_override(&"font_color", GoUi.color(GoTheme.MUTED))
  else:
    _note_button.text = lines[0] + ("  (+%d)" % (lines.size() - 1) if lines.size() > 1 else "")
    _note_button.remove_theme_color_override(&"font_color")
  _note_button.tooltip_text = note if not note.is_empty() else "Click to add a note"
  _play_button.tooltip_text = entry.relative_path + ("\n\n" + note if not note.is_empty() else "")


func set_playing(playing: bool) -> void:
  _playing = playing
  if not playing:
    _progress.value = 0.0
    _time_label.text = format_time(length) if length > 0.0 else ""


## Shows the length while silent. Negative means unknown.
func set_length(seconds: float) -> void:
  length = seconds
  # Reserve the width of the longest text, so the bar does not jump while the position counts.
  var font := _time_label.get_theme_font(&"font")
  var font_size := _time_label.get_theme_font_size(&"font_size")
  _time_label.custom_minimum_size.x = ceilf(
    font.get_string_size(format_time(maxf(length, 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
  ) if length > 0.0 else 0.0
  if not _playing:
    _time_label.text = format_time(length) if length > 0.0 else ""


## Updates progress bar and time label while playing.
func set_playback_position(seconds: float) -> void:
  _progress.value = clampf(seconds / length, 0.0, 1.0) if length > 0.0 else 0.0
  _time_label.text = format_time(seconds)


## m:ss.ttt with minutes only when needed, e.g. 3.250 or 1:05.250.
static func format_time(seconds: float) -> String:
  var total_ms := roundi(maxf(seconds, 0.0) * 1000.0)
  var minutes := total_ms / 60000
  var secs := (total_ms / 1000) % 60
  var millis := total_ms % 1000
  if minutes > 0:
    return "%d:%02d.%03d" % [minutes, secs, millis]
  return "%d.%03d" % [secs, millis]


## True if every word occurs in the relative path or note.
func matches(words: PackedStringArray) -> bool:
  var haystack := ("%s %s" % [entry.relative_path, note]).to_lower()
  for word in words:
    if not haystack.contains(word):
      return false
  return true


func _on_volume_selected(index: int) -> void:
  _show_volume(_volumes[index])
  volume_changed.emit(_volumes[index])


func _show_volume(volume: float) -> void:
  _volume_button.text = _volume_text(volume)
  var menu := _volume_button.get_popup()
  for index in menu.item_count:
    menu.set_item_checked(index, is_equal_approx(_volumes[index], volume))


func _volume_text(volume: float) -> String:
  return "%d%%" % roundi(volume * 100.0)

class_name SoundCard
extends PanelContainer

## Presents one sound: trigger button, volume, playback progress, and note.
## The card only reports edits; the app decides how to store and play them.

signal triggered
signal note_changed(note: String)
signal volume_changed(volume: float)

const VOLUME_STEPS: Array[float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

var entry: SoundEntry

var _play_button: Button
var _volume_button: MenuButton
var _volumes: Array[float] = []
var _progress: ProgressBar
var _note_edit: LineEdit


func setup(sound: SoundEntry, note: String, volume: float) -> void:
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

  _progress = GoStyle.progress(GoUi.color(GoTheme.ACCENT_FILL))
  _progress.max_value = 1.0
  _progress.step = 0.0
  column.add_child(_progress)

  _note_edit = GoStyle.line_edit("Note")
  _note_edit.text = note
  _note_edit.text_changed.connect(_on_note_changed)
  column.add_child(_note_edit)

  _update_tooltip()


func set_playing(playing: bool) -> void:
  if not playing:
    _progress.value = 0.0


func set_progress(progress: float) -> void:
  _progress.value = progress


## True if every word occurs in the relative path or note.
func matches(words: PackedStringArray) -> bool:
  var haystack := ("%s %s" % [entry.relative_path, _note_edit.text]).to_lower()
  for word in words:
    if not haystack.contains(word):
      return false
  return true


func _on_note_changed(note: String) -> void:
  _update_tooltip()
  note_changed.emit(note)


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


func _update_tooltip() -> void:
  var note := _note_edit.text.strip_edges()
  _play_button.tooltip_text = entry.relative_path + ("\n\n" + note if not note.is_empty() else "")

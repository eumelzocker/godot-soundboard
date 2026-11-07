class_name SoundCard
extends PanelContainer

## Presents one sound: trigger and stop buttons, playback progress, note, mode, and volume.
## The card only reports edits; the app decides how to store and play them.

signal triggered
signal stop_requested
signal note_changed(note: String)
signal volume_changed(volume: float)
signal mode_changed(mode: StringName)

const MODE_TITLES: Dictionary[StringName, String] = {
  &"overlap": "Overlap",
  &"restart": "Restart",
  &"toggle": "Toggle",
}

var entry: SoundEntry

var _play_button: Button
var _stop_button: Button
var _progress: ProgressBar
var _note_edit: LineEdit
var _mode_picker: OptionButton
var _volume_slider: HSlider
var _volume_label: Label


func setup(sound: SoundEntry, note: String, volume: float, mode: StringName) -> void:
  entry = sound
  name = "SoundCard"
  GoStyle.style_panel(self, GoStyle.surface(GoTheme.BOX_CARD))

  var column := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  add_child(column)

  var header := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  column.add_child(header)
  _play_button = GoStyle.button(sound.title, triggered.emit, GoStyle.Tone.PRIMARY)
  _play_button.clip_text = true
  _play_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  _play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  header.add_child(_play_button)
  _stop_button = GoStyle.icon_button(GoIconSet.STOP, stop_requested.emit)
  _stop_button.tooltip_text = "Stop"
  header.add_child(_stop_button)

  _progress = GoStyle.progress(GoUi.color(GoTheme.ACCENT_FILL))
  _progress.max_value = 1.0
  _progress.step = 0.0
  column.add_child(_progress)

  _note_edit = GoStyle.line_edit("Note")
  _note_edit.text = note
  _note_edit.text_changed.connect(_on_note_changed)
  column.add_child(_note_edit)

  var controls := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  column.add_child(controls)
  _mode_picker = GoStyle.picker()
  for mode_id in SoundPlaybackComponent.MODE_IDS:
    _mode_picker.add_item(MODE_TITLES[mode_id])
  _mode_picker.select(maxi(SoundPlaybackComponent.MODE_IDS.find(mode), 0))
  _mode_picker.tooltip_text = "Overlap: every click adds a voice\nRestart: a click restarts the sound\nToggle: a click starts or stops the sound"
  _mode_picker.item_selected.connect(
    func(index: int) -> void: mode_changed.emit(SoundPlaybackComponent.MODE_IDS[index])
  )
  controls.add_child(_mode_picker)
  _volume_slider = GoStyle.slider(0.0, SoundMetadata.MAX_VOLUME, 0.05)
  _volume_slider.value = volume
  _volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  _volume_slider.value_changed.connect(_on_volume_changed)
  controls.add_child(_volume_slider)
  _volume_label = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
  _volume_label.size_flags_horizontal = Control.SIZE_SHRINK_END
  _volume_label.custom_minimum_size.x = 44
  _volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  controls.add_child(_volume_label)

  _update_volume_label(volume)
  _update_tooltip()
  set_playing(false)


func set_playing(playing: bool) -> void:
  _stop_button.disabled = not playing
  if not playing:
    _progress.value = 0.0


func set_progress(progress: float) -> void:
  _progress.value = progress


## True if every word occurs in the title, relative path, or note.
func matches(words: PackedStringArray) -> bool:
  var haystack := ("%s %s" % [entry.relative_path, _note_edit.text]).to_lower()
  for word in words:
    if not haystack.contains(word):
      return false
  return true


func _on_note_changed(note: String) -> void:
  _update_tooltip()
  note_changed.emit(note)


func _on_volume_changed(volume: float) -> void:
  _update_volume_label(volume)
  volume_changed.emit(volume)


func _update_volume_label(volume: float) -> void:
  _volume_label.text = "%d%%" % roundi(volume * 100.0)


func _update_tooltip() -> void:
  var note := _note_edit.text.strip_edges()
  _play_button.tooltip_text = entry.relative_path + ("\n\n" + note if not note.is_empty() else "")

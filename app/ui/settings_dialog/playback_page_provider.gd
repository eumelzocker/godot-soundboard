class_name PlaybackPageProvider
extends SettingsPageProvider

## The toolbar settings in one page: playback mode, master volume, and sub-folder scanning.
## Values go through the app's setters, so toolbar and dialog stay in sync.

@export var app: SoundboardApp

var _mode_select: OptionButton
var _volume_slider: HSlider
var _volume_value: Label
var _recursive_toggle: CheckButton


func _init() -> void:
  page_id = &"playback"
  page_title = "Playback"
  category_title = "Settings"
  navigation_order = 10


func build_page() -> Control:
  var content := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  content.add_child(GoStyle.label(
    "The same settings as in the toolbar.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)
  ))

  content.add_child(GoStyle.label("Click behavior"))
  var titles: Array[String] = []
  for mode_id in SoundPlaybackComponent.MODE_IDS:
    titles.append(SoundboardApp.MODE_TITLES[mode_id])
  _mode_select = GoStyle.select(titles)
  _mode_select.name = "PlaybackModeSelect"
  _mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _mode_select.item_selected.connect(
    func(index: int) -> void: app.set_playback_mode(SoundPlaybackComponent.MODE_IDS[index])
  )
  content.add_child(_mode_select)
  content.add_child(GoStyle.label(
    "Overlap: every click adds a voice. Restart: a click restarts the sound. Toggle: a click starts or stops the sound.",
    GoTheme.ROLE_CAPTION,
    GoUi.color(GoTheme.MUTED),
  ))

  content.add_child(GoStyle.label("Master volume"))
  var volume_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  _volume_slider = GoStyle.slider(0.0, 1.0, 0.01)
  _volume_slider.name = "MasterVolumeSlider"
  _volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  _volume_slider.value_changed.connect(_on_volume_changed)
  volume_row.add_child(_volume_slider)
  _volume_value = GoStyle.label("")
  _volume_value.custom_minimum_size.x = 52.0
  _volume_value.size_flags_horizontal = Control.SIZE_SHRINK_END
  _volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  volume_row.add_child(_volume_value)
  content.add_child(volume_row)

  _recursive_toggle = GoStyle.toggle("Include subfolders", false)
  _recursive_toggle.name = "RecursiveToggle"
  _recursive_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _recursive_toggle.toggled.connect(func(on: bool) -> void: app.set_recursive(on))
  content.add_child(_recursive_toggle)
  content.add_child(GoStyle.label(
    "Sub-folders are scanned too and shown as groups.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)
  ))
  return scroll_page("PlaybackPage", content)


func get_search_text() -> String:
  return "click behavior mode overlap restart toggle master volume subfolders recursive groups"


func sync() -> void:
  if _mode_select == null or app == null:
    return
  _mode_select.select(SoundPlaybackComponent.MODE_IDS.find(app.playback_mode))
  _volume_slider.set_value_no_signal(app.master_volume)
  _volume_value.text = _percent(app.master_volume)
  _recursive_toggle.set_pressed_no_signal(app.library.recursive)


func _on_volume_changed(volume: float) -> void:
  app.set_master_volume(volume)
  _volume_value.text = _percent(volume)


func _percent(volume: float) -> String:
  return "%d%%" % roundi(volume * 100.0)

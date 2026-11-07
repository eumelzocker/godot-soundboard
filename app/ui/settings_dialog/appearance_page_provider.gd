class_name AppearancePageProvider
extends SettingsPageProvider

## GoHUD theme selection as family plus light/dark mode. The chosen preset is persisted and
## applied in _ready, before the app builds its UI.

const APPEARANCE_SECTION := "appearance"
const THEME_PRESET_KEY := "theme_preset"

@export var settings_store: AppSettingsStore

var _family_select: OptionButton
var _light_toggle: CheckButton
var _families: Array[StringName] = []


func _init() -> void:
  page_id = &"appearance"
  page_title = "Appearance"
  category_title = "Settings"
  navigation_order = 0
  default_page = true


func _ready() -> void:
  if settings_store == null:
    return
  var saved := StringName(str(settings_store.get_value(APPEARANCE_SECTION, THEME_PRESET_KEY, "")))
  if GoThemePresets.find(saved) != null and saved != current_preset_id():
    GoUi.use_preset(saved)


func build_page() -> Control:
  var content := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  content.add_child(GoStyle.label(
    "Choose the interface theme and color mode.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)
  ))

  _families = available_families()
  var titles: Array[String] = []
  for family in _families:
    titles.append(_family_title(family))
  content.add_child(GoStyle.label("Theme"))
  _family_select = GoStyle.select(titles)
  _family_select.name = "ThemeFamilySelect"
  _family_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _family_select.item_selected.connect(_on_family_selected)
  content.add_child(_family_select)

  _light_toggle = GoStyle.toggle("Light mode", false)
  _light_toggle.name = "LightThemeToggle"
  _light_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _light_toggle.toggled.connect(_on_light_toggled)
  content.add_child(_light_toggle)
  return scroll_page("AppearancePage", content)


func get_search_text() -> String:
  return "theme style look family light dark mode colors gohud"


func sync() -> void:
  if _family_select == null:
    return
  var preset_id := current_preset_id()
  _family_select.select(maxi(_families.find(family_of(preset_id)), 0))
  _light_toggle.set_pressed_no_signal(String(preset_id).ends_with("_light"))


func current_preset_id() -> StringName:
  var current := GoUi.preset()
  return current.id if current != null else GoThemePresets.DEFAULT_DARK


## Switches the GoHUD preset, rebuilding the dialog, and persists the choice.
func apply_preset(family: StringName, light: bool) -> void:
  var preset_id := _resolve_preset(family, light)
  if preset_id.is_empty() or preset_id == current_preset_id():
    sync()
    return
  rebuild_requested.emit(GoUi.use_preset.bind(preset_id))
  if settings_store != null:
    settings_store.store_values({APPEARANCE_SECTION: {THEME_PRESET_KEY: String(preset_id)}})


static func family_of(preset_id: StringName) -> StringName:
  var value := String(preset_id)
  for suffix in ["_dark", "_light"]:
    if value.ends_with(suffix):
      return StringName(value.trim_suffix(suffix))
  return preset_id


static func available_families() -> Array[StringName]:
  var families: Array[StringName] = []
  for preset_id in GoThemePresets.names():
    var family := family_of(preset_id)
    if family != preset_id and not families.has(family):
      families.append(family)
  return families


func _on_family_selected(index: int) -> void:
  apply_preset(_families[index], _light_toggle.button_pressed)


func _on_light_toggled(light: bool) -> void:
  apply_preset(_families[maxi(_family_select.selected, 0)], light)


func _family_title(family: StringName) -> String:
  return "Sci-fi" if family == &"scifi" else String(family).capitalize()


func _resolve_preset(family: StringName, light: bool) -> StringName:
  var wanted := StringName("%s_%s" % [family, "light" if light else "dark"])
  if GoThemePresets.find(wanted) != null:
    return wanted
  var other := StringName("%s_%s" % [family, "dark" if light else "light"])
  return other if GoThemePresets.find(other) != null else &""

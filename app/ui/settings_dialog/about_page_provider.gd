class_name AboutPageProvider
extends SettingsPageProvider

## Project identity from the definition: icon, name, version, purpose, and description.

var _definition: SettingsDialogDefinition


func _init() -> void:
  page_id = &"about"
  page_title = "About"
  category_title = "Reference"
  navigation_order = 200


func configure(definition: SettingsDialogDefinition) -> void:
  _definition = definition


func build_page() -> Control:
  var content := GoStyle.column(GoUi.metric(GoTheme.GAP))
  content.alignment = BoxContainer.ALIGNMENT_CENTER
  if _definition == null:
    return scroll_page("AboutPage", content)

  var icon := TextureRect.new()
  icon.name = "ProjectIcon"
  icon.texture = _definition.project_icon
  icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(96.0, 96.0)
  icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  content.add_child(icon)

  for line in [
    [_definition.project_name, GoTheme.ROLE_TITLE, Color.TRANSPARENT],
    ["Version %s" % _definition.read_version(), GoTheme.ROLE_COMPACT, Color.TRANSPARENT],
    [_definition.purpose, GoTheme.ROLE_SUBTITLE, Color.TRANSPARENT],
    [_definition.description, GoTheme.ROLE_BODY, GoUi.color(GoTheme.SECONDARY)],
  ]:
    var label := GoStyle.label(line[0], line[1], line[2])
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(label)
  return scroll_page("AboutPage", content)


func get_search_text() -> String:
  if _definition == null:
    return "version"
  return "version %s %s %s" % [_definition.project_name, _definition.purpose, _definition.description]

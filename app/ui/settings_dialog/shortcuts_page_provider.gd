class_name ShortcutsPageProvider
extends SettingsPageProvider

## Keyboard reference built from the definition's shortcut list.

var _definition: SettingsDialogDefinition


func _init() -> void:
  page_id = &"shortcuts"
  page_title = "Shortcuts"
  category_title = "Reference"
  navigation_order = 100


func configure(definition: SettingsDialogDefinition) -> void:
  _definition = definition


func build_page() -> Control:
  var content := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  var current_section := ""
  for shortcut in _definition.shortcuts if _definition != null else []:
    if shortcut.section != current_section:
      current_section = shortcut.section
      content.add_child(GoStyle.section(current_section, false))
    content.add_child(_shortcut_row(shortcut))
  return scroll_page("ShortcutsPage", content)


func get_search_text() -> String:
  var parts: PackedStringArray = ["keys keyboard hotkeys"]
  for shortcut in _definition.shortcuts if _definition != null else []:
    parts.append_array([shortcut.section, shortcut.title, shortcut.detail, shortcut.fallback_key])
  return " ".join(parts)


func _shortcut_row(shortcut: DialogShortcut) -> PanelContainer:
  var row := GoStyle.edge_card_panel(GoUi.color(GoTheme.SECONDARY))
  row.name = "%sShortcut" % shortcut.title.to_pascal_case()
  var layout := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  var copy := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
  copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  copy.add_child(GoStyle.label(shortcut.title, GoTheme.ROLE_BUTTON))
  copy.add_child(GoStyle.label(shortcut.detail, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
  layout.add_child(copy)
  var shows_binding := not shortcut.action.is_empty() and DisplayServer.get_name() != "headless"
  layout.add_child(GoKbd.for_action(shortcut.action) if shows_binding else GoKbd.make(shortcut.fallback_key))
  row.add_child(layout)
  return row

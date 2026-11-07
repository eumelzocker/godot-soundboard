class_name RecentFoldersPageProvider
extends SettingsPageProvider

## Manages the recently used folders: open one, remove single entries, or clear the list.
## Folders that no longer exist are marked.

@export var app: SoundboardApp
@export var settings_store: AppSettingsStore


func _init() -> void:
  page_id = &"recent_folders"
  page_title = "Recent folders"
  category_title = "Folders"
  navigation_order = 50


func build_page() -> Control:
  var content := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  var recent := settings_store.get_recent_directories() if settings_store != null else PackedStringArray()
  content.add_child(GoStyle.label(
    "Folders you opened recently, newest first. The newest one reopens on startup.",
    GoTheme.ROLE_CAPTION,
    GoUi.color(GoTheme.SECONDARY),
  ))
  if recent.is_empty():
    content.add_child(GoStyle.label("No recent folders.", GoTheme.ROLE_BODY, GoUi.color(GoTheme.MUTED)))
    return scroll_page("RecentFoldersPage", content)

  for path in recent:
    content.add_child(_folder_row(path))
  var clear := GoStyle.button("Clear list", _clear, GoStyle.Tone.DANGER)
  clear.name = "ClearRecentButton"
  GoStyle.natural_width(clear)
  content.add_child(clear)
  return scroll_page("RecentFoldersPage", content)


func get_search_text() -> String:
  var recent := settings_store.get_recent_directories() if settings_store != null else PackedStringArray()
  return "recent folders history directories open remove clear %s" % " ".join(recent)


func _folder_row(path: String) -> PanelContainer:
  var available := DirAccess.dir_exists_absolute(path)
  var is_open := app != null and app.library.directory == path
  var accent := GoTheme.ACCENT if is_open else (GoTheme.SECONDARY if available else GoTheme.DANGER)
  var row := GoStyle.edge_card_panel(GoUi.color(accent))
  var layout := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  var copy := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
  copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var name_label := GoStyle.label(path.get_file() if not path.get_file().is_empty() else path, GoTheme.ROLE_BUTTON)
  copy.add_child(name_label)
  var detail := path
  if is_open:
    detail += "  ·  open"
  elif not available:
    detail += "  ·  not found"
  var path_label := GoStyle.label(detail, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
  path_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
  copy.add_child(path_label)
  layout.add_child(copy)

  var open := GoStyle.button("Open", _open.bind(path))
  open.disabled = not available or is_open
  GoStyle.natural_width(open)
  open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  layout.add_child(open)
  var remove := GoStyle.icon_button(GoIconSet.TRASH, _remove.bind(path))
  remove.tooltip_text = "Remove from list"
  remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  layout.add_child(remove)
  row.add_child(layout)
  return row


func _open(path: String) -> void:
  if app.open_directory(path):
    close_requested.emit()


func _remove(path: String) -> void:
  rebuild_requested.emit(settings_store.forget_directory.bind(path))


func _clear() -> void:
  rebuild_requested.emit(settings_store.clear_recent_directories)

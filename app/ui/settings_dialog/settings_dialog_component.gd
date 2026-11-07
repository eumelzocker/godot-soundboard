class_name SettingsDialogComponent
extends Node

## Modal settings shell opened with F1. Content comes from child page providers and a definition
## resource. A searchable category tree selects one subpage at a time; the title bar drags the
## dialog, and the last visited page is remembered in the settings store.

signal popup_opened
signal popup_closed

const NAVIGATION_SECTION := "navigation"
const LAST_PAGE_KEY := "last_page"

@export var definition: SettingsDialogDefinition
@export var toggle_action: StringName = &"toggle_settings_dialog"
@export var settings_store: AppSettingsStore
## Opacity of the dialog background. Negative uses the GoHUD theme value (80% by default).
@export_range(-1.0, 1.0, 0.01) var background_alpha: float = 0.97

var _dialog_layer: CanvasLayer
var _surface: GoSurface
var _subpages: Array[SettingsPageProvider.Subpage] = []
var _pages_by_id: Dictionary[StringName, Control] = {}
var _tree_items_by_page_id: Dictionary[StringName, TreeItem] = {}
var _category_tree: Tree
var _page_filter: GoSearchBar
var _page_stack: Control
var _subpage_title: Label
var _empty_state: Label
var _selected_page_id: StringName
var _is_dragging_dialog: bool = false
var _changing_tree_selection: bool = false


func _ready() -> void:
  if not InputMap.has_action(toggle_action):
    push_warning("%s cannot toggle because action '%s' is unavailable" % [name, toggle_action])
  for provider in _page_providers():
    provider.configure(definition)
    provider.rebuild_requested.connect(_on_provider_rebuild_requested)


func _unhandled_input(event: InputEvent) -> void:
  if not event.is_action_pressed(toggle_action, false, true):
    return
  if is_dialog_open():
    if _surface == null or _surface.is_top():
      close_dialog()
  else:
    open_dialog()
  get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
  if not is_dialog_open():
    _is_dragging_dialog = false
    return
  var mouse_button := event as InputEventMouseButton
  if mouse_button != null:
    if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
      _is_dragging_dialog = false
    return
  var mouse_motion := event as InputEventMouseMotion
  if mouse_motion != null and _is_dragging_dialog:
    if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
      _is_dragging_dialog = false
      return
    if _surface != null and _surface.card != null:
      _surface.card.position += mouse_motion.relative
      _clamp_dialog_position()
      get_viewport().set_input_as_handled()


func is_dialog_open() -> bool:
  return is_instance_valid(_dialog_layer)


func open_dialog() -> void:
  if is_dialog_open():
    return
  _dialog_layer = CanvasLayer.new()
  _dialog_layer.name = "SettingsDialogLayer"
  _dialog_layer.layer = 210
  add_child(_dialog_layer)
  _build_dialog_surface()
  popup_opened.emit()


func close_dialog() -> void:
  if not is_dialog_open():
    return
  _dialog_layer.queue_free()
  _dialog_layer = null
  _is_dragging_dialog = false
  _surface = null
  _clear_workspace_references()
  popup_closed.emit()


func select_page(page_id: StringName) -> bool:
  if not _pages_by_id.has(page_id):
    return false
  _selected_page_id = page_id
  _remember_page(page_id)
  for candidate in _pages_by_id:
    _pages_by_id[candidate].visible = candidate == page_id
  _empty_state.visible = false
  var subpage := _subpage_for_id(page_id)
  _subpage_title.text = subpage.page_title if subpage != null else ""
  var item: TreeItem = _tree_items_by_page_id.get(page_id)
  if item != null and _category_tree.get_selected() != item:
    _changing_tree_selection = true
    item.select(0)
    _category_tree.scroll_to_item(item, true)
    _changing_tree_selection = false
  _sync_providers()
  return true


func get_selected_page_id() -> StringName:
  return _selected_page_id


func _build_dialog_surface(selected_page_id: StringName = &"", filter_text: String = "") -> void:
  _surface = GoSurface.new()
  _surface.name = "SettingsDialog"
  _surface.max_width = 900.0
  _surface.height_ratio = 0.72
  _surface.max_height_ratio = 0.88
  _surface.fit_content = false
  _surface.scroll_body = false
  _surface.dismiss_on_scrim = true
  _surface.alpha = background_alpha
  _surface.set_title(definition.dialog_title if definition != null else "Settings")
  _surface.close_requested.connect(close_dialog)
  _dialog_layer.add_child(_surface)
  _surface.title_label.mouse_filter = Control.MOUSE_FILTER_STOP
  _surface.title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
  _surface.title_label.tooltip_text = "Drag to move this dialog"
  _surface.title_label.gui_input.connect(_on_title_gui_input)

  var workspace := GoStyle.row(GoUi.metric(GoTheme.GAP))
  workspace.name = "Workspace"
  workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
  _surface.body.add_child(workspace)

  var navigation := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  navigation.name = "NavigationPane"
  navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  navigation.size_flags_vertical = Control.SIZE_EXPAND_FILL
  navigation.size_flags_stretch_ratio = 0.3
  navigation.custom_minimum_size.x = GoUi.metric(GoTheme.TOUCH) * 4.0
  workspace.add_child(navigation)

  _page_filter = GoSearchBar.make("Filter pages")
  _page_filter.name = "PageFilter"
  _page_filter.set_text(filter_text)
  _page_filter.text_changed.connect(_on_page_filter_changed)
  navigation.add_child(_page_filter)

  _category_tree = Tree.new()
  _category_tree.name = "CategoryTree"
  var tree_ink := GoUi.theme_color(&"font_color", GoTheme.VAR_LIST_BUTTON, GoUi.color(GoTheme.TEXT))
  var tree_active_ink := GoUi.theme_color(&"font_hover_color", GoTheme.VAR_LIST_BUTTON, tree_ink)
  GoStyle.font_role(_category_tree, GoTheme.ROLE_BODY, tree_ink)
  _category_tree.add_theme_color_override(&"font_hovered_color", tree_active_ink)
  _category_tree.add_theme_color_override(&"font_selected_color", tree_active_ink)
  _category_tree.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
  _category_tree.hide_root = true
  _category_tree.allow_reselect = true
  _category_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _category_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
  _category_tree.item_selected.connect(_on_category_tree_item_selected)
  navigation.add_child(_category_tree)

  var separator := VSeparator.new()
  separator.theme = GoUi.theme()
  workspace.add_child(separator)

  var content := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
  content.name = "ContentPane"
  content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  content.size_flags_vertical = Control.SIZE_EXPAND_FILL
  content.size_flags_stretch_ratio = 0.7
  workspace.add_child(content)

  _subpage_title = GoStyle.label("", GoTheme.ROLE_TITLE)
  _subpage_title.name = "SubpageTitle"
  content.add_child(_subpage_title)

  _page_stack = Control.new()
  _page_stack.name = "PageStack"
  _page_stack.clip_contents = true
  _page_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _page_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
  content.add_child(_page_stack)

  for provider in _page_providers():
    provider.configure(definition)
    _subpages.append_array(provider.build_subpages())
  _subpages.sort_custom(
    func(left: SettingsPageProvider.Subpage, right: SettingsPageProvider.Subpage) -> bool:
      if left.navigation_order == right.navigation_order:
        return left.page_title.naturalnocasecmp_to(right.page_title) < 0
      return left.navigation_order < right.navigation_order
  )
  for subpage in _subpages:
    if subpage.page_id.is_empty() or subpage.content == null or _pages_by_id.has(subpage.page_id):
      push_warning("%s ignored invalid or duplicate page id '%s'" % [name, subpage.page_id])
      continue
    subpage.content.visible = false
    _page_stack.add_child(subpage.content)
    subpage.content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pages_by_id[subpage.page_id] = subpage.content

  _empty_state = GoStyle.label(
    "No pages match this filter.", GoTheme.ROLE_BODY, GoUi.color(GoTheme.SECONDARY)
  )
  _empty_state.name = "EmptyState"
  _empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  _empty_state.visible = false
  _page_stack.add_child(_empty_state)
  _empty_state.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

  var initial_page_id := selected_page_id
  if initial_page_id.is_empty():
    initial_page_id = _stored_page_id()
  if not _pages_by_id.has(initial_page_id):
    initial_page_id = _default_page_id()
  _rebuild_category_tree(filter_text, initial_page_id)


## Rebuilds the open dialog after [param change] ran, keeping page, filter, and position.
func _on_provider_rebuild_requested(change: Callable) -> void:
  if not is_dialog_open():
    change.call()
    return
  var selected_page_id := _selected_page_id
  var filter_text := _page_filter.get_text()
  var card_position := _surface.card.position
  change.call()
  _dialog_layer.remove_child(_surface)
  _surface.queue_free()
  _surface = null
  _clear_workspace_references()
  _build_dialog_surface(selected_page_id, filter_text)
  _restore_dialog_position.call_deferred(card_position)


func _on_page_filter_changed(query: String) -> void:
  _rebuild_category_tree(query, _selected_page_id)


func _on_category_tree_item_selected() -> void:
  if _changing_tree_selection:
    return
  var item := _category_tree.get_selected()
  if item != null:
    select_page(StringName(str(item.get_metadata(0))))


func _rebuild_category_tree(query: String, preferred_page_id: StringName) -> void:
  _category_tree.clear()
  _tree_items_by_page_id.clear()
  var root_item := _category_tree.create_item()
  var category_items: Dictionary[String, TreeItem] = {}
  var first_page_id: StringName
  for subpage in _subpages:
    if not _pages_by_id.has(subpage.page_id) or not subpage.matches_filter(query):
      continue
    var category_item: TreeItem = category_items.get(subpage.category_title)
    if category_item == null:
      category_item = _category_tree.create_item(root_item)
      category_item.set_text(0, subpage.category_title.to_upper())
      category_item.set_selectable(0, false)
      category_item.set_custom_color(0, GoUi.color(GoTheme.SECONDARY))
      category_items[subpage.category_title] = category_item
    var page_item := _category_tree.create_item(category_item)
    page_item.set_text(0, subpage.page_title)
    page_item.set_metadata(0, subpage.page_id)
    _tree_items_by_page_id[subpage.page_id] = page_item
    if first_page_id.is_empty():
      first_page_id = subpage.page_id

  var page_to_select := preferred_page_id
  if not _tree_items_by_page_id.has(page_to_select):
    page_to_select = first_page_id
  if page_to_select.is_empty():
    _show_empty_state()
  else:
    select_page(page_to_select)


func _show_empty_state() -> void:
  _selected_page_id = &""
  for page in _pages_by_id.values():
    page.visible = false
  _subpage_title.text = "No results"
  _empty_state.visible = true


func _sync_providers() -> void:
  for provider in _page_providers():
    provider.sync()


func _page_providers() -> Array[SettingsPageProvider]:
  var providers: Array[SettingsPageProvider] = []
  for child in get_children():
    if child is SettingsPageProvider:
      providers.append(child)
  return providers


func _default_page_id() -> StringName:
  for subpage in _subpages:
    if subpage.default_page and _pages_by_id.has(subpage.page_id):
      return subpage.page_id
  return _subpages[0].page_id if not _subpages.is_empty() else &""


func _subpage_for_id(page_id: StringName) -> SettingsPageProvider.Subpage:
  for subpage in _subpages:
    if subpage.page_id == page_id:
      return subpage
  return null


func _stored_page_id() -> StringName:
  if settings_store == null:
    return &""
  return StringName(str(settings_store.get_value(NAVIGATION_SECTION, LAST_PAGE_KEY, "")))


func _remember_page(page_id: StringName) -> void:
  if settings_store != null and _stored_page_id() != page_id:
    settings_store.store_values({NAVIGATION_SECTION: {LAST_PAGE_KEY: String(page_id)}})


func _clear_workspace_references() -> void:
  _subpages.clear()
  _pages_by_id.clear()
  _tree_items_by_page_id.clear()
  _category_tree = null
  _page_filter = null
  _page_stack = null
  _subpage_title = null
  _empty_state = null
  _selected_page_id = &""
  _changing_tree_selection = false


func _on_title_gui_input(event: InputEvent) -> void:
  var mouse_button := event as InputEventMouseButton
  if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
    return
  _is_dragging_dialog = mouse_button.pressed
  _surface.title_label.accept_event()


func _clamp_dialog_position() -> void:
  if _surface == null or _surface.card == null:
    return
  var viewport_rect := get_viewport().get_visible_rect()
  var maximum := (viewport_rect.end - _surface.card.size).max(viewport_rect.position)
  _surface.card.position = _surface.card.position.clamp(viewport_rect.position, maximum)


func _restore_dialog_position(card_position: Vector2) -> void:
  if _surface == null or _surface.card == null:
    return
  _surface.card.position = card_position
  _clamp_dialog_position()

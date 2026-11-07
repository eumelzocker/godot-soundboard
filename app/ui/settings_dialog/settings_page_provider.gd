class_name SettingsPageProvider
extends Node

## Contract for one or more subpages of the settings dialog. Providers are children of
## SettingsDialogComponent; they build fresh controls on every open.

class Subpage extends RefCounted:
  var page_id: StringName
  var page_title: String
  var category_title: String
  var navigation_order: int
  var default_page: bool
  var search_text: String
  var content: Control

  func _init(
    id: StringName,
    title: String,
    category: String,
    order: int,
    selected_by_default: bool,
    page_content: Control,
    searchable_text: String,
  ) -> void:
    page_id = id
    page_title = title
    category_title = category
    navigation_order = order
    default_page = selected_by_default
    content = page_content
    search_text = "%s %s %s" % [category, title, searchable_text]

  func matches_filter(query: String) -> bool:
    var searchable := search_text.to_lower()
    for word in query.strip_edges().to_lower().split(" ", false):
      if not searchable.contains(word):
        return false
    return true

## Requests a dialog rebuild. The dialog invokes [param change] after capturing its UI state.
signal rebuild_requested(change: Callable)
## Asks the dialog to close, e.g. after an action that hands control back to the app.
signal close_requested

@export var page_id: StringName = &"page"
@export var page_title: String = "Page"
@export var category_title: String = "General"
@export var navigation_order: int = 0
@export var default_page: bool = false


func configure(_definition: SettingsDialogDefinition) -> void:
  pass


func build_page() -> Control:
  return Control.new()


## Providers can override this to contribute several related subpages.
func build_subpages() -> Array[Subpage]:
  var pages: Array[Subpage] = [
    Subpage.new(
      page_id, page_title, category_title, navigation_order, default_page,
      build_page(), get_search_text()
    ),
  ]
  return pages


## Updates controls from current state after a page is shown.
func sync() -> void:
  pass


## Search material for the dialog's page filter.
func get_search_text() -> String:
  return ""


## Wraps a content column in a scrollable, slightly inset page, the common page layout.
func scroll_page(node_name: String, content: Control) -> GoScroll:
  var page := GoScroll.new()
  page.name = node_name
  var inset := GoStyle.padding(GoUi.metric(GoTheme.GAP_TINY), 0)
  inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  inset.add_child(content)
  page.add_child(inset)
  return page

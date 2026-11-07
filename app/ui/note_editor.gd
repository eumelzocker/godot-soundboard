class_name NoteEditor
extends Node

## Modal multi-line note editor on a GoHUD surface. One editor serves all cards; the caller
## passes a callback that receives the edited text when the user saves.

@export var editor_height: float = 220.0

var _surface: GoSurface
var _text_edit: TextEdit
var _on_save: Callable


func is_open() -> bool:
  return _surface != null


func open(title: String, text: String, on_save: Callable) -> void:
  close()
  _on_save = on_save
  _surface = GoSurface.new()
  _surface.set_title(title)
  _surface.close_requested.connect(close)

  _text_edit = TextEdit.new()
  _text_edit.theme = GoUi.theme()
  _text_edit.text = text
  _text_edit.placeholder_text = "Note"
  _text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
  _text_edit.custom_minimum_size.y = editor_height
  _text_edit.gui_input.connect(_on_text_input)
  _surface.body.add_child(_text_edit)
  _surface.initial_focus = _text_edit

  var actions := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
  actions.alignment = BoxContainer.ALIGNMENT_END
  actions.add_child(GoStyle.button("Cancel", close))
  actions.add_child(GoStyle.button("Save (Ctrl+Enter)", save, GoStyle.Tone.PRIMARY))
  for button in actions.get_children():
    GoStyle.natural_width(button)
  _surface.footer.add_child(actions)
  _surface.footer.visible = true

  add_child(_surface)
  _text_edit.set_caret_line(_text_edit.get_line_count() - 1)
  _text_edit.set_caret_column(_text_edit.get_line(_text_edit.get_line_count() - 1).length())
  _text_edit.grab_focus.call_deferred()


func save() -> void:
  if not is_open():
    return
  var callback := _on_save
  var text := _text_edit.text
  close()
  callback.call(text)


func close() -> void:
  if _surface == null:
    return
  _surface.queue_free()
  _surface = null
  _text_edit = null
  _on_save = Callable()


func _on_text_input(event: InputEvent) -> void:
  var key := event as InputEventKey
  if key != null and key.pressed and key.ctrl_pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
    _text_edit.accept_event()
    save()

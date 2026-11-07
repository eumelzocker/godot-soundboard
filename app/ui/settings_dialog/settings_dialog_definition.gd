class_name SettingsDialogDefinition
extends Resource

## Project-owned copy for the settings dialog: title, shortcut reference, and About content.

@export var dialog_title: String = "Settings"
@export var shortcuts: Array[DialogShortcut] = []

@export_group("About")
@export var project_name: String
@export var project_icon: Texture2D
@export_file var version_path: String
@export var purpose: String
@export_multiline var description: String


func read_version() -> String:
  var version := FileAccess.get_file_as_string(version_path).strip_edges() if not version_path.is_empty() else ""
  return version if not version.is_empty() else "development"

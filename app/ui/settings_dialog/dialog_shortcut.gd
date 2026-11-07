class_name DialogShortcut
extends Resource

## One entry of the shortcut reference page.

@export var section: String = "PLAYBACK"
## Input action whose binding is shown. Leave empty for keys handled outside the input map.
@export var action: StringName
@export var fallback_key: String
@export var title: String
@export_multiline var detail: String

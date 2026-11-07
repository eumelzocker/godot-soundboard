# Settings Dialog

## Responsibility

`res://app/ui/settings_dialog/settings_dialog_component.gd` owns the modal F1 dialog: open and
close, a searchable category tree on the left, one visible subpage on the right, dragging by the
title bar, and remembering the last visited page. It knows no page content.

Content comes from child page providers extending
`res://app/ui/settings_dialog/settings_page_provider.gd`:

| Provider | Category | Content |
| --- | --- | --- |
| `res://app/ui/settings_dialog/appearance_page_provider.gd` | Settings | GoHUD theme family and light mode |
| `res://app/ui/settings_dialog/playback_page_provider.gd` | Settings | Click behavior, master volume, subfolders (same as the toolbar) |
| `res://app/ui/settings_dialog/recent_folders_page_provider.gd` | Folders | Open, remove, or clear recent folders |
| `res://app/ui/settings_dialog/shortcuts_page_provider.gd` | Reference | Keyboard reference |
| `res://app/ui/settings_dialog/about_page_provider.gd` | Reference | Name, version, purpose, description |

Copy, shortcut entries, and About data live in the definition resource
`res://app/ui/settings_dialog/soundboard_dialog.tres`.

## Theme changes

- The appearance provider switches the preset with `GoUi.use_preset()` through its
  `rebuild_requested` signal, so the dialog rebuilds itself and keeps page, filter, and position.
- `res://app/ui/soundboard_app.gd` watches GoHUD and rebuilds its UI from current state once per
  change; loaded cards, search text, and playback continue.
- The preset is stored as `appearance/theme_preset` and applied in the provider's `_ready`, which
  runs before the app builds its UI.

## Extension points and invariants

- Add a page by adding a provider node below `SettingsDialog` in `res://scenes/main.tscn`.
  Page IDs must be unique; `navigation_order` sorts pages.
- Providers build fresh controls on every open and update them in `sync()`.
- Pages that change app state call the public setters of `res://app/ui/soundboard_app.gd`
  (`set_playback_mode`, `set_master_volume`, `set_recursive`), which keep the toolbar in sync.
- A provider can emit `close_requested` to close the dialog, e.g. after opening a folder.
- While the dialog or the note editor is open, the app ignores its own shortcuts, so Esc only
  closes the popup.

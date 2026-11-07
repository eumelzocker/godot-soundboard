# Settings

## Responsibility

`res://app/components/settings/app_settings_store.gd` persists app-wide preferences in
`user://settings.cfg` as a `ConfigFile`.

## Contents

| Section | Key | Meaning |
| --- | --- | --- |
| `recent` | `directories` | Recently opened directories, newest first, capped at `max_recent_directories` |
| `app` | `master_volume` | Master bus volume `0..1` |
| `app` | `recursive` | Sub-folder scanning |
| `app` | `playback_mode` | Global playback mode: `overlap`, `restart`, or `toggle` |
| `appearance` | `theme_preset` | GoHUD preset chosen in the settings dialog |
| `navigation` | `last_page` | Last visited settings dialog page |

## Invariants

- An unavailable directory is removed from the recent list when opening it fails.
- `AppSettingsStore.suspended` disables file access, so tests never touch user preferences.
- Per-sound data belongs in the sound directory's metadata file, not here.

# App Composition

## Summary

The soundboard follows the Godot-native, component-based architecture of `../gamedev-lab/`.
`res://scenes/main.tscn` is the composition root. Its root node runs
`res://app/ui/soundboard_app.gd` and holds three child components wired through typed exported
references:

| Node | Script | Responsibility |
| --- | --- | --- |
| `Settings` | `res://app/components/settings/app_settings_store.gd` | App preferences and recent directories |
| `Library` | `res://app/components/library/sound_library.gd` | Open directory, scanned entries, metadata autosave |
| `Playback` | `res://app/components/audio/sound_playback_component.gd` | Voices per sound, modes, progress |

## Data flow

1. The app asks the library to open a directory, from the folder dialog, the recent menu, a drop,
   or the last directory at startup.
2. The library scans the directory, loads its metadata file, and emits `entries_changed`.
3. The app builds one `res://app/ui/sound_card.gd` per entry. Cards only emit edits and triggers.
4. The app routes triggers to playback and edits to the library, which saves them after a debounce.
5. Playback emits `sound_started` and `sound_stopped`; the app updates cards and polls progress
   only while something plays.

## Rules

- Components do not reference UI classes. UI classes do not load files or play audio.
- Audio files are loaded lazily on first trigger through
  `res://app/components/audio/audio_file_loader.gd` and cached until the next rescan.
- UI is built in code with GoHUD helpers so it follows the configured theme preset
  (`gohud/theme/preset` in `res://project.godot`).
- New behavior receives coverage in `res://tests/composition_test.gd`.

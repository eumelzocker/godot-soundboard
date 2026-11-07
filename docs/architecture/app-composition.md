# App Composition

## Summary

The soundboard uses a **Godot-native, component-based architecture**. Scenes are composition
roots: a host node owns focused child components, and typed exported node references make
dependencies visible in the editor. Signals carry reactions that should remain loosely coupled.

This is not an Entity Component System (ECS). Godot nodes remain the actors, components contain
both state and behavior, and the SceneTree owns their lifecycle.

`res://scenes/main.tscn` is the composition root. Its root node runs
`res://app/ui/soundboard_app.gd` and holds three child components:

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
   Note edits go through one shared `res://app/ui/note_editor.gd` popup owned by the app.
4. The app routes triggers to playback and edits to the library, which saves them after a debounce.
5. Playback emits `sound_started` and `sound_stopped`; the app updates cards and polls progress
   only while something plays.

## Choosing a coupling mechanism

| Need | Prefer |
| --- | --- |
| Known collaborator in a statically authored scene | Typed exported node reference |
| One component announces an event without owning the reaction | Signal |
| Stateless helper without lifecycle (loading, scanning, parsing) | Static functions on a `RefCounted` class |
| Optional capability shared through a small protocol | Focused method contract plus validation |

Avoid inheritance for assembling capabilities; it is still appropriate for a narrow
implementation contract.

## Ownership boundaries

- `res://app/components` contains non-UI components. They never reference UI classes.
- `res://app/ui` contains presentation. UI classes do not load files or play audio.
- `res://scenes` contains scenes; `res://tests` contains headless tests.
- `res://addons` contains vendored third-party add-ons and is not modified in place.

## Rules

- Audio files are loaded lazily on first trigger through
  `res://app/components/audio/audio_file_loader.gd` and cached until the next rescan.
- UI is built in code with GoHUD helpers so it follows the configured theme preset
  (`gohud/theme/preset` in `res://project.godot`).

## Extension rules

Before adding a component, verify that the capability can be configured, removed, replaced, or
reused independently. Otherwise, extending an existing component is usually clearer.

New behavior should:

1. own one coherent responsibility;
2. expose only dependencies it actually uses;
3. validate required references at startup and degrade safely for optional references;
4. keep presentation separate from loading, persistence, and playback policy; and
5. receive coverage in `res://tests/composition_test.gd`.

# Playback

## Responsibility

`res://app/components/audio/sound_playback_component.gd` plays sounds identified by absolute
path on non-spatial `AudioStreamPlayer` voices. It knows nothing about cards or metadata; callers
pass volume and mode with each trigger. The app applies one global mode, chosen in the toolbar
and persisted as `app/playback_mode` in the settings.

## Modes

| Mode | Trigger while playing | Trigger while silent |
| --- | --- | --- |
| `overlap` (default) | Adds a voice | Starts |
| `restart` | Replaces running voices | Starts |
| `toggle` | Stops | Starts |

## Invariants

- At most `max_voices_per_sound` voices run per sound; the oldest is dropped first.
- `sound_started` fires when a sound goes from silent to playing, `sound_stopped` when its last
  voice ends or is stopped.
- `get_position()` reports the newest voice's position in seconds; cards derive progress from it.
- Master volume is the `Master` bus volume, controlled by the app.

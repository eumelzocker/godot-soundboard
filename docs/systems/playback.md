# Playback

## Responsibility

`res://app/components/audio/sound_playback_component.gd` plays sounds identified by absolute
path on non-spatial `AudioStreamPlayer` voices. It knows nothing about cards or metadata; callers
pass volume and mode with each trigger.

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
- `get_progress()` reports the newest voice's position in `0..1`.
- Master volume is the `Master` bus volume, controlled by the app.

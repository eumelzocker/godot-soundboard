# Sound Library

## Responsibility

`res://app/components/library/sound_library.gd` owns the open directory, its scanned entries,
and its metadata. `res://app/components/library/sound_directory_scanner.gd` finds files and
`res://app/components/library/sound_metadata.gd` reads and writes the metadata file.

## Scanning

- Supported formats are MP3, OGG Vorbis, and WAV, the formats Godot decodes at runtime without an
  import. The list lives in `res://app/components/audio/audio_file_loader.gd`.
- Hidden files and hidden directories are skipped.
- With `recursive` enabled, sub-directories are included and each entry's `group` is its relative
  directory. Results are sorted naturally by group, then path.
- Rescanning clears the decoded-stream cache so replaced files are reloaded.

## Metadata file

Notes and volumes live in `.soundboard.yml` inside the sound directory, keyed by the path
relative to that directory:

```yaml
version: 1
sounds:
  airhorn.mp3:
    note: |-
      Use after a bad joke
      Not during the intro
    volume: 0.8
  sub/bell.ogg:
    note: Round start
```

- Only non-default values are written; an entry without values is removed.
- Entries for files that are currently missing are kept.
- Unknown keys and malformed values are ignored; volume is clamped to `0..2`.
- Edits are saved after `autosave_delay` and when the library leaves the tree.
- A failed load or save is reported through `metadata_save_failed`; the app shows it in a snackbar.

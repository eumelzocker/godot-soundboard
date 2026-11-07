# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Changes are grouped as
`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`. Empty groups are
omitted. Add ongoing work under `Unreleased`; released sections are immutable.

## [Unreleased]

## [0.1.0] - 2026-11-07

### Added

- Initial soundboard: choose a directory through a native folder dialog, the recent-folders menu,
  or drag and drop, and get one card per MP3, OGG, or WAV file.
- Optional sub-folder scan that groups cards by relative directory.
- Per-sound multi-line notes and volume (dropdown beside the play button), stored as
  `.soundboard.yml` inside the sound directory with debounced autosave.
- Cards show only the first note line plus a hidden-line count; clicking it opens a modal
  editor (Ctrl+Enter saves, Esc cancels without stopping sounds).
- Search across file names, paths, and notes.
- Global playback mode (overlap, restart, toggle) in the toolbar.
- Playback progress per card, global stop (Esc), rescan (F5), and master volume.
- Recently used directories and app preferences persisted in `user://settings.cfg`; the most
  recent directory reopens on startup.
- F1 settings dialog with a searchable page tree: GoHUD theme family and light mode (persisted,
  applied live by rebuilding the UI), a shortcut reference, and an About page. A gear button in
  the toolbar opens it too. The dialog and the note editor use a nearly opaque background
  (`background_alpha`, 97%) instead of the 80% theme default.
- Tooltips and menus open as native subwindows, which avoids Godot 4.7.2 errors when embedded
  tooltips close.
- Linux export preset writing to `.bin/soundboard.x86_64`, plus `.bin/soundboard.sh`, which
  starts the export on NixOS in the tracked flake runtime shell with matching display and audio
  libraries.
- Headless composition tests and documentation path checks.

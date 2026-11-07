# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Changes are grouped as
`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`. Empty groups are
omitted. Add ongoing work under `Unreleased`; released sections are immutable.

## [Unreleased]

### Added

- Initial soundboard: choose a directory through a native folder dialog, the recent-folders menu,
  or drag and drop, and get one card per MP3, OGG, or WAV file.
- Optional sub-folder scan that groups cards by relative directory.
- Per-sound notes, volume, and playback mode (overlap, restart, toggle), stored as
  `.soundboard.yml` inside the sound directory with debounced autosave.
- Search across file names, paths, and notes.
- Playback progress per card, per-sound stop, global stop (Esc), rescan (F5), and master volume.
- Recently used directories and app preferences persisted in `user://settings.cfg`; the most
  recent directory reopens on startup.
- Headless composition tests and documentation path checks.
- Linux export preset writing to `.bin/soundboard.x86_64`; the Nix runtime shell in `.bin/` is
  now tracked.

### Changed

- The project is self-contained: documentation describes its architecture rules directly instead
  of referring to an external lab project.

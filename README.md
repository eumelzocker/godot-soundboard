# Soundboard

A small desktop soundboard. Pick a folder and every MP3, OGG, or WAV file in it becomes a play
button. Notes and per-sound volumes are saved in a file inside that folder, so they travel with
your sounds.

## Running

The Linux build lives in `.bin/`. Keep `soundboard.x86_64` and `libgdyaml.linux.release.x86_64.so`
in the same directory.

- **NixOS:** start `.bin/soundboard.sh`. It runs the app inside the Nix shell from
  `.bin/flake.nix`, which provides the display and audio libraries. The first start takes a moment.
- **Other Linux distributions:** run `.bin/soundboard.x86_64` directly.

## Using it

- **Open a folder** with *Open folder…* (Ctrl+O), the *Recent* menu, or by dropping a folder onto
  the window. The last folder reopens on the next start.
- **Click a sound** to play it. The toolbar sets what a click does for all sounds:
  *Overlap* adds another voice, *Restart* starts over, *Toggle* starts or stops.
- **Per sound:** choose a volume from the percentage button, click the note line to write a
  (multi-line) note, and use the copy icon to copy the file name (Ctrl+click: full path).
- **Search** file names and notes with Ctrl+F. **Stop all** sounds with Esc.
- **Subfolders** in the toolbar includes sub-folders and shows them as groups. F5 rescans.
- **Settings** (F1 or the gear icon): theme and light mode, playback options, the recent-folders
  list, a shortcut reference, and version information.

## Where data is stored

| What | Where |
| --- | --- |
| Notes and volumes | `.soundboard.yml` in the sound folder (a hidden file) |
| App settings and recent folders | `~/.local/share/godot/app_userdata/Soundboard/settings.cfg` |

Notes are saved automatically about a second after each change. If the sound folder is
read-only, the app shows an error and the notes cannot be saved there.

## Building from source

Requires Godot 4.7. Open the project in the editor, or export from the command line:

```sh
godot --headless --path . --export-release "Linux" .bin/soundboard.x86_64
```

Developer documentation starts at [docs/README.md](docs/README.md); changes are listed in
[CHANGES.md](CHANGES.md).

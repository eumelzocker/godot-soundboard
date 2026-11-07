# Repository Instructions

A desktop soundboard built with Godot 4.7. It scans a local directory for audio files, shows a
play button per file, and stores notes and playback preferences in a YAML file inside that
directory. Concepts, workflows, and architecture decisions follow `../gamedev-lab/` and extend
them where needed.

Chat to the user in german, but keep application code, identifiers, comments, UI text, logs,
diagnostics, and new project documentation in English.


## Architecture

- Favor composition over inheritance. The main scene is the composition root; components are child
  nodes wired through typed exported references.
- Avoid code duplication and boilerplate.
- No superfluous unused fields.
- Keep loading, scanning, persistence, and playback free of UI code. UI classes only present state
  and report edits.
- Build UI with the GoHUD add-on (`GoStyle`, `GoUi`, theme tokens) instead of hand-made styles.


## Directory ownership

- `app/components/` contains reusable non-UI components (audio, library, settings).
- `app/ui/` contains GoHUD-based presentation and the composition-root script.
- `scenes/` contains scenes. `tests/` contains headless tests.
- `addons/` contains third-party add-ons copied from `../gamedev-lab/`. Do not modify them in
  place; update them by copying a newer version.


## Godot workflow

- Use Godot AI for live editor state, scene hierarchy, scene changes, runtime inspection, logs,
  and smoke tests.
- Use repository files and headless Godot commands for source inspection and automated tests.
- If no Godot AI session is connected, report it and continue with filesystem or headless checks.
- Run the tests with `godot --headless --path . -s res://tests/composition_test.gd`. On NixOS,
  unset `LD_LIBRARY_PATH` if Godot fails with a glibc error.


## Documentation

- Use `docs/README.md` as the documentation entry point and `docs/systems/README.md` as the
  catalog of implemented systems.
- Keep current architecture in `docs/architecture/`, implemented behavior in `docs/systems/`, and
  future proposals in `docs/plans/`.
- Reference repository files and directories with exact, backticked `res://` paths so the
  composition test can validate them.
- Document responsibilities and invariants instead of duplicating complete implementation APIs.


## Versioning and changelog

- Version number is stored in file `./version.txt`.
- Backward compatibility is not required while the project version is below `1.0.0`.
- Record user-visible or otherwise material changes under `Unreleased` in `CHANGES.md` before
  every non-release commit.
- Treat every dated version section in `CHANGES.md` as immutable after its release commit.
- Do not choose or increment a version during ordinary implementation work. Keep accumulating
  changes under `Unreleased` until the user explicitly requests a release.
- In a release commit, choose the next semantic patch version, rename `Unreleased` to that version
  and the release date, and create a new empty `Unreleased` section above it.

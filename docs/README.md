# Project Documentation

This directory separates current design from future work:

- [Architecture](architecture/app-composition.md) explains the composition root and the design
  rules shared by all components.
- [Systems](systems/README.md) is the maintained catalog of implemented systems.
- [Plans](plans/) contains proposals. Plans are not authoritative descriptions of current behavior.

## Maintenance rules

1. Update the relevant architecture or system document when a system boundary, lifecycle,
   configuration contract, or extension point changes.
2. Keep implementation detail in code. Documentation explains responsibilities, data flow,
   configuration, extension points, and invariants.
3. Write repository references as exact, backticked `res://` paths. The composition test validates
   these paths in architecture and system documentation.

---
name: Godot projects in this environment
description: How to validate a Godot game project when there's no registered "Godot" artifact type.
---

Godot is not one of the supported artifact kinds (expo/react-vite/slides/video-js/openscad/data-visualization),
so a Godot project must be handled as a plain file/git project, not registered via the artifacts skill.

There is still a real engine available: `installSystemDependencies({ packages: ["godot_4"] })` installs a
headless-capable Godot 4 binary (`godot4` on PATH). Use it to actually validate changes instead of relying on
static reading alone:
- `godot4 --headless --path <project> --import` reimports all assets and surfaces asset-level errors (e.g.
  malformed WAV headers that fail "Format not supported for WAVE file").
- `godot4 --headless --path <project> --check-only` surfaces GDScript parse errors.
- `godot4 --headless --path <project> --quit-after <frames>` boots the main scene headlessly to catch
  startup-time script errors.
None of these can simulate UI interaction/gameplay, so deep runtime logic (combat, animations) still needs
careful static code review, not just these checks.

**Why:** without running the real importer, WAV/resource format bugs and script errors are invisible to pure
source review — several "silent" bugs only surfaced as ERROR lines during `--import`.

**How to apply:** for any Godot stabilization/bugfix task, install `godot_4` early and run the three checks above
before and after edits, in addition to reading the source.

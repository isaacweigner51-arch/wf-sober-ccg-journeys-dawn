---
name: Godot headless syntax check method
description: How to actually get a clean syntax check in this repo without false-positive errors from autoloads/custom classes.
---

Running `godot4 --headless --check-only --script <file>.gd` on a single script
in this project reports false errors (`Identifier not found: AudioManager`,
`Could not find type "CardView"`) because autoloads and custom class_name
scripts aren't registered outside full project context.

**Why:** the project relies on autoload singletons (AudioManager, AccessManager)
and custom classes (CardView) declared elsewhere; single-file checks don't see them.

**How to apply:** to validate GDScript changes, run
`godot4 --headless --quit --path .` from the project root and grep the output
for `SCRIPT ERROR`/`Parse Error`. Pre-existing `No loader found for resource`
warnings about missing audio/art assets are expected noise, not regressions.

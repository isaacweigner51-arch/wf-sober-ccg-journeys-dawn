---
name: wf-sober-ccg-journeys-dawn duplicate project copies
description: This repo contains two nearly-identical copies of the Godot project (root and wf_v084/); only the root one is what players actually run.
---

The GitHub repo `isaacweigner51-arch/wf-sober-ccg-journeys-dawn` contains the entire Godot project twice:
- At the repo root (`project.godot`, `menu.gd`, `card_view.gd`, `main.gd`, `assets/`, `data/`, etc.) — this is the one the repo's own README tells users to open ("Open project.godot with Godot 4 and press F5"), so **this is the copy that actually runs in-game**.
- Under `wf_v084/` — a mirror with the same file layout.

**Why this matters:** a fix applied only under `wf_v084/` (e.g. editing `wf_v084/menu.gd` or regenerating `wf_v084/assets/cards/full/*.jpg`) compiles fine and looks complete, but has zero effect on what the player sees, because the root copy — the one Godot actually opens — is untouched. This caused a real incident: a card-art fix and full art regeneration were pushed and verified only in `wf_v084/`, while the root copy kept showing old/generic art, and it took a full session of "it's still broken" round-trips to discover the duplicate-copy structure.

**How to apply:** before declaring a fix to this project done, diff the root-level files against the matching `wf_v084/` files for anything touched (`diff -rq . wf_v084` scoped to the relevant paths). If they differ, sync the fix to both copies (or at minimum confirm which copy is canonical) before pushing. When in doubt, check `project.godot`'s location referenced by the repo README/instructions — that's the canonical copy.

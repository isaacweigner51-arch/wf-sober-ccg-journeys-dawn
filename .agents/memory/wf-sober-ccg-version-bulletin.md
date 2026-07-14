---
name: wf-sober-ccg in-game bulletin/version bump workflow
description: User wants every change (bug fixes, features, new cards) reflected in the in-game "What's New" bulletin with a bumped version number, on every change going forward — not just on request.
---

The player-facing "What's New" popup is driven by `data/version_manifest.json`
(read by `update_manager.gd`, shown by `menu.gd`'s `maybe_show_whats_new()`).
It only pops up when `version` differs from the last version the player saw,
so bumping the version is what actually surfaces new bulletin content.

**Standing instruction (confirmed 2026-07-14):** update this manifest and bump
the version *every time a change is made* to the game — bug fixes, features,
and new cards all belong in the `fixes` array, in plain player-facing
language (not commit-message/dev language). Do this proactively, without
being asked each time.

**How to apply, each change:**
1. Bump `version` / `version_name` / `version_code` in `data/version_manifest.json`
   (patch bump for fixes/small features, e.g. 0.8.6 -> 0.8.7).
2. Update `notes` (one-line summary) and append to `fixes` (player-readable
   bullets) — cards added/removed should update `card_count` too.
3. Mirror the same version bump in `export_presets.cfg`
   (`version/code` +1, `version/name` to match) and the fallback
   `current_version` default in `update_manager.gd`.
4. Sync all of the above into the `wf_v084/` mirror copy (see
   `wf-sober-ccg-duplicate-copies.md`) — this project has two copies of
   everything and both must match.
5. Headless syntax check both copies, commit, push to `main`, then merge
   `--no-ff` into `replit-stabilization` and push that too.

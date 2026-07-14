---
name: Godot assets missing .import sidecar files
description: Why card art / other assets can render fine in headless dev checks but fall back to placeholders on real device or exported builds.
---

This environment previously only ever ran `godot4 --headless --quit --path .`
for syntax checks, which never triggers Godot's editor asset-import scan. Any
asset added without ever opening a real editor context has no `.import`
sidecar file, so it isn't tracked in Godot's resource database.

Menu/card art code has a manual `FileAccess` raw-bytes fallback that loads
even un-imported images fine in a live headless run — so the art bug was
invisible in local headless testing. But on export (device build), Godot only
bundles resources it recognizes from the import database, so any asset
without a `.import` file silently gets left out, and code falls back to the
generic placeholder pool at runtime on the real device.

**Why:** the export pipeline and a bare headless script run use different
asset-loading paths; passing one does not prove the other works.

**How to apply:** after adding new binary assets (images/audio) to a Godot
project in this kind of environment, run a real editor-context pass —
`godot4 --headless --editor --quit-after 200 --path .` — to force-generate
`.import`/`.uid` sidecar files, then commit those sidecars (but gitignore the
regenerable `.godot/` cache dir itself). Do this for every tracked copy of the
project (e.g. this repo's `wf_v084/` mirror too).

---
name: Leader portrait layer stacking + derived layers
description: Rules for leader_view.gd layered art — aura must render behind the character; hair/aux layers must be derived from the base portrait, never separately AI-generated.
---

**Rule 1:** The aura layer must be created BEFORE body/head/hair in `_setup_nodes()` so Godot draws it behind the character. Aura art is a centered orb/ring on the full canvas — drawn on top it completely covers the face ("glowing blob" bug seen in player screenshots, July 2026).

**Rule 2:** Any overlay layer that must align with the character (hair, blink) must be derived from the character's OWN base portrait (body+head recomposite via ImageMagick, gradient alpha masks), never generated as a separate AI image. Separately generated cutouts have no shared canvas origin and render as giant misaligned blobs.

**Why:** Both failure modes shipped in v0.9.3 and reached the player before being caught. A quick `magick ... -composite` stack preview of aura+body+head+hair on a dark background catches both instantly.

**How to apply:** Before shipping any leader art change, composite all layers with ImageMagick and view the result. Hair rebuild recipe: `base = body over head composite; hair = base alpha × vertical gradient (opaque to ~26%, faded by ~38%)`.

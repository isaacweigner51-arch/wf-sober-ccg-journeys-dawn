---
name: Battle Prep facing layout
description: Rule for keeping the Battle Prep "who's facing who" stage visually centered.
---

The Battle Prep stage has a left leader zone, a VS strip, and a right opponent zone.
To keep the "VS" text and the two portraits centered, the left and right zones must be
the same width.  The VS strip is then placed exactly in the middle.

**Why:** The previous layout used a 408 px left zone and a 490 px right zone, which
pushed the VS divider 41 px left of the stage center and made the whole screen look
off-balance.

**How to apply:** If the stage width changes, recompute the three zones as:
- left_zone = right_zone = (stage_width - vs_width) / 2
- vs_x = left_zone
Then update the background rectangles, portrait frames, and the `_bp_build_vs_zone`
constants so the content stays centered.

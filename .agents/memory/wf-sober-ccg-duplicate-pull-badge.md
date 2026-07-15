---
name: wf-sober-ccg duplicate pull badge
description: How duplicate-vs-new card status is surfaced in pack reveal/results, and the shared-reference pitfall it required avoiding.
---

`add_card_to_collection` (menu.gd) now returns `{"is_duplicate": bool, "vials": int}` instead of void. Callers that display a pull (`_roll_one_pack`) must `cd.duplicate()` before stamping a `_dup_info` key onto the card dict — `random_card_of_rarity` returns a direct reference into the shared master `cards` array, so mutating it in place would leak one pull's duplicate status onto every future pull of that same card.

`card_panel` renders a "DUPLICATE +N VIALS" badge whenever `cd.get("_dup_info", {})` has `is_duplicate: true`. Every other caller of `card_panel` (collection, deck builder, previews) passes plain card dicts with no `_dup_info` key, so the badge only ever appears on actual pack-opening reveals (both single and bulk).

**Why:** the reveal/bulk-results screens previously showed a duplicate pull (silently converted to Vials at copy limit) identically to a brand-new card, which read as a bug/scam to players.

**How to apply:** if adding more per-pull metadata to reveal screens, follow the same pattern — stamp it on a duplicated dict at pull time, never on the shared `cards` entries.

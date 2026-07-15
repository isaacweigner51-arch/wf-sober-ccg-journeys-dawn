---
name: wf-sober-ccg highlight/text color collision pattern
description: How "highlight looks like an empty bubble" bugs happen in this project's Godot UI, and how to find every instance.
---

The shared `style(border, radius)` StyleBoxFlat helper in `menu.gd` always hardcodes `bg_color = PANEL` (near-black) regardless of the `border` color passed in — it only ever tints the outline, never the fill. Several call sites called `style(GOLD_COLOR, N)` for what was clearly meant to be a solid, filled CTA/highlight button, then separately set a dark `font_color` override assuming a light gold background for contrast. Since the actual background stayed near-black, the dark text became nearly invisible against it, leaving only a gold outline visible — reported by the user as the highlight/border "looking like an empty bubble" or "the same color as the text."

**Why:** `style()` was written for bordered dark panels/buttons (dark fill + colored outline + light default text), not filled CTAs. Reusing it for a filled highlight silently breaks contrast because nothing errors — it just produces an unreadable button.

**How to apply:** When asked to fix "highlight same as text" / "empty bubble" bugs in this repo, grep both `menu.gd` and `main.gd` for `style(GOLD_COLOR` (or `style(accent`/`style(class_color`) followed within a few lines by a dark `font_color` override (values like `Color(0.0x, 0.0x, ...)` or `Color(0.1x, 0.1x, ...)`) — that pairing is the bug signature. Fix by using a real filled-background stylebox (a `solid_style()`-style helper that sets `bg_color = fill` instead of `PANEL`) at each such site, not by changing the border/text color alone. Known fixed sites (v0.8.19): Home screen primary nav BATTLE button + ENTER BATTLE button, Battle Setup active deck-mode button + BEGIN BATTLE button, Collection screen selected class/rarity filter tabs. Always re-grep before assuming the list above is exhaustive — new UI code can reintroduce the same pattern.

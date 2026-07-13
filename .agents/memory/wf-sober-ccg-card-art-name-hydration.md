---
name: wf-sober-ccg card art name-hydration gap
description: Why some in-battle cards kept showing recycled placeholder art even after every catalog card got unique artwork.
---

`card_view.gd`'s `_art_texture()` resolves each card's unique artwork by looking up `data.get("id")` and loading `res://assets/cards/full/{id}.jpg`. But the actual battle decks in `main.gd` are built by a hardcoded `card(name, cost, attack, health, ...)` helper that never sets an `id` field — only `name`. To recover an id, `card_view.gd`'s `_hydrate_card_data()` lowercases the card's `name` and looks it up in `data/cards.json`'s `name` field.

**Why this matters:** any hardcoded battle card whose name doesn't exactly match an entry in `data/cards.json` (finishers, tokens created at runtime like "Inspired Volunteer", or tutorial-only "Training" rarity cards) hydrates to an empty id and silently falls back to the old 16-image `art_XX.png` placeholder pool — even though every catalog card has genuine unique art. This is easy to miss because most cards *do* match by name, so spot-checks look fine; the bug only shows up for the specific handful of off-catalog cards. In this project, 14 of ~84 hardcoded battle-deck card names had no `data/cards.json` counterpart.

**How to apply:** when auditing "is every card's art actually unique," don't just check `data/cards.json`'s catalog — grep `main.gd` (or wherever the real deck-building code lives) for every `card("...")` call, collect the distinct names, and diff them against the catalog's `name` field. For any that don't match, either add them to the catalog or (simpler, since these are often not meant to be collectible) give the `card()` helper an optional explicit `id` parameter and pass a stable id at each such call site, so `_art_texture()`'s direct id lookup succeeds without depending on name hydration at all.

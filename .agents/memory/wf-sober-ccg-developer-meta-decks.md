---
name: Developer meta decks
description: How owner-only developer meta decks are built and why card changes must be added manually.
---

Owner-only "Dev Meta" decks are built by `build_developer_meta_deck(faction_name)` in
main.gd as hardcoded lists of card names and copy counts.  They do not auto-include new
or buffed cards, even if the card data in `data/cards.json` is updated.

**Why:** The deck is a curated list of the strongest cards for that class, not a generic
pool.  A card must be explicitly added to the `_append_named_cards` list or it will never
appear in the deck, regardless of changes to its cost/stats/effect.

**How to apply:** When adding or buffing a card intended for a Dev Meta deck, update the
named-card list for that class in the same commit.  Remember the class prebuilt decks
used by the AI are generated separately by `build_class_deck`, so they also need to be
checked if the card is meant for the standard prebuilt pool.

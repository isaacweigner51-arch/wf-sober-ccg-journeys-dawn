# v0.7.6 — Second Chance Card Art Fix

- Fixed blank artwork on the Second Chance opening-hand screen.
- Runtime-built cards now resolve their full Journey's Dawn art by matching card names against `data/cards.json`.
- Cards without a catalog ID use a deterministic visual fallback instead of a black rectangle.
- Card names, cost, rarity, stats, and effects remain visible.

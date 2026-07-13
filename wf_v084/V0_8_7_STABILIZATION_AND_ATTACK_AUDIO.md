# v0.8.7 Stabilization and Attack Audio

Stabilization pass on top of v0.8.6. No new features, no redesign. Second
Chance screen is unchanged.

## Fixes

- Card rendering: hand and battlefield cards now resolve their own unique
  illustrated artwork by card ID (falling back to a name match against
  `cards.json`), the same lookup Second Chance already used. Previously live
  cards were forced onto a pool of 16 recycled placeholder images regardless
  of which card was shown.
- Runtime errors: eight signature-voice WAV files (`walking_free`,
  `walking_free_attack`, `rally_the_free`, `rally_the_free_attack`,
  `inner_peace`, `inner_peace_attack`, `beacon_of_hope`,
  `beacon_of_hope_attack`) had a WAV header Godot's importer rejected
  ("Format not supported for WAVE file"), so they failed to import and threw
  errors on every asset reimport. Re-encoded to standard 44.1kHz 16-bit PCM.
- Verified evolution, evolved-follower-can-attack-followers, and battlefield
  five-slot spacing against the current code -- all already function as
  intended after the v0.8.5/v0.8.6 fixes and were left untouched.

## Attack audio replacement

Replaced the attack swing/impact sounds with cleaner layered effects and
removed the old files entirely (`attack_swoosh_new.wav`,
`attack_whoosh.wav`, `impact_heavy_new.wav`, `impact_heavy.wav`,
`impact_light_new.wav`, `impact_light.wav`):

- `attack_swing_clean.wav` -- short whoosh, plays on every attack.
- `impact_follower_clean.wav` -- standard follower-vs-follower hit.
- `impact_leader_deep.wav` -- deeper impact, used whenever the leader is hit.
- `impact_large_follower.wav` -- stronger low-end, used when the attacker or
  defender is a large follower (attack >= 5 or health >= 6).

No metallic squeal, arcade laser, or long echo in any of the four sounds.
Leader/large-follower selection lives in `attack_impact_sound()` in
`main.gd`.

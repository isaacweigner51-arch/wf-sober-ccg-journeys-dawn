---
name: wf-sober-ccg victory screen — actual root cause
description: The recurring "victory screen overlaps/undimmed board" bug in wf-sober-ccg-journeys-dawn had two real causes that earlier fixes (token-based cutoff) never touched.
---

The bug reported repeatedly ("victory/VICTORY banner overlapping live board, no
dimming, card art visible through it") was NOT fully fixed by the earlier
`victory_sequence_token` race-condition fix. That fix addressed the cinematic's
own banner bleeding into the *result* screen underneath, but two separate bugs
in the cinematic itself (`_play_victory_sequence` in `main.gd`) kept producing
the same visible symptom:

1. `_finish_match` fired the cinematic fire-and-forget, then cut it off after a
   **fixed, guessed delay** that was shorter than the cinematic's own real
   duration (its steps add up to ~2.2s+). This *always* tore the dimming
   scrim/banner layer down mid-animation.
2. A step inside the cinematic (`show_vfx`, used for the "DEFEATED" popup)
   used `await tween.finished` — the same open-ended-await hang pattern as
   [Godot await tween.finished can hang forever](godot-tween-await-hang.md).
   If that tween was ever interrupted, the whole cinematic hung *before* it
   ever built the dimming/backdrop, silently skipping it.

**Why this matters beyond this one bug:** a fire-and-forget coroutine raced
against a *guessed* fixed-delay timer in the caller is its own hang/race
category, distinct from the tween.finished-hang category — both can produce
the identical visible symptom, so fixing one does not fix the other. When a
symptom recurs after a fix, check for a second, independent code path/cause
before re-patching the one already fixed.

**How to apply:** if a coroutine's total duration is knowable and bounded
(every internal await is a fixed timer, not tween.finished), the caller should
just `await` it directly instead of firing it and racing a separately-guessed
timeout — the guess will drift out of sync the moment either duration changes.

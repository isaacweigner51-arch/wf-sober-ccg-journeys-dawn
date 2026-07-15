---
name: wf-sober-ccg victory screen — actual confirmed root cause
description: The recurring "victory screen overlaps/undimmed board" bug in wf-sober-ccg-journeys-dawn. Two rounds of plausible-looking fixes were wrong; the confirmed cause only surfaced from the engine's own error log.
---

The bug reported repeatedly ("VICTORY banner overlapping live board, no
dimming, card art visible through it, buttons unreachable") went through two
rounds of code-reading-only fixes that looked correct but did not fix it:

1. An earlier session fixed a genuine `victory_sequence_token` race between
   the cinematic banner and the result screen. Real bug, wrong one.
2. This session first fixed a fixed-delay-vs-real-duration mismatch and an
   `await tween.finished` hang risk in the cinematic. Also real, also not the
   cause of *this* symptom — user re-tested a confirmed-current build and the
   bug was identical.

**The actual cause**, found only by asking the user to paste Godot's
Output/Debugger panel text: `game_over_layer.z_index = 10000` in
`show_game_over()`. Godot's `CanvasItem.z_index` is hard-capped at 4096. Set
it higher and the engine does **not** clamp it — it fails validation, prints
`Tried to set Z index to an invalid value: N. Z index must be between -4096
and 4096`, and silently leaves the property at whatever it was before (the
default, 0). The result screen therefore never actually got a high z-index at
all and rendered underneath ordinary battlefield UI on every single win —
100% reproducible, not a race. Two more instances of the identical mistake
(`z_index = 5000`, also over the cap) existed elsewhere in the same codebase
(a card-inspection popup and a menu transition).

**Why this matters:** a wrong-looking-right visual bug that survives two
plausible, verified-clean-headless-check fixes is a strong signal to stop
theorizing from source alone and get a runtime error log — GDScript/Godot
often fails silently (print an ERROR line, keep going) rather than crashing,
so purely static reading of the "logically correct" code can miss an engine
constraint violation entirely. `godot4 --headless --quit --path .` only
catches script *parse* errors, never runtime property-validation errors like
this one — it will report a project as clean even when this bug is present.

**How to apply:** when a Godot visual/layering bug resists a source-level fix
that passed headless verification, ask for the Output/Debugger panel text
before writing another fix. Also worth a blanket grep for
`z_index = [0-9]+` values over 4096 (or negative below -4096) whenever
touching layering code in this codebase — the pattern of hand-picking "a very
big number" for "definitely on top" is what produced all three instances.

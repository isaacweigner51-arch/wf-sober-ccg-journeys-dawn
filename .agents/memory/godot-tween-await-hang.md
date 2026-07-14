---
name: Godot await tween.finished can hang forever
description: Why "await <Tween>.finished" is risky for critical-path UI sequences in this project's GDScript, and the fix pattern used.
---

`await some_tween.finished` only resolves on a clean natural completion.
If the tween's target node is ever fought over by another tween on the same
property (e.g. an infinite-looping idle animation on `scale`/`rotation` that
is never explicitly stopped), interrupted, or killed by unrelated code, the
`finished` signal may never fire — and the awaiting coroutine hangs forever.

**Why:** This caused a 100%-reproducible "victory screen hangs, no buttons
ever appear" bug in `main.gd`'s `_play_victory_sequence`, because leader
nodes run an infinite idle-bob tween on `scale` (from `start_leader_idle`)
that is never stopped, including through match end.

**How to apply:** For any UI sequence on a critical path (results screens,
modal transitions, anything the player must be able to get past), don't
await a tween's `finished` signal directly. Await a fixed `get_tree().create_timer(duration, true, false, true).timeout` matching that tween's own
duration instead — the timer always fires regardless of what happens to the
tween. This project already uses this pattern one level up (the overall
results-screen delay in `_finish_match`); the fix was to apply the same
pattern to the *inner* tween chain too, not just the outer one.

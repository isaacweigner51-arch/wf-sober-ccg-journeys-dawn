---
name: Two-button handoff soft-locks from GDScript closure capture
description: Why a "click A, then B appears" button pattern in menu.gd silently soft-locked the Academy tutorial, and the fix pattern to use.
---

Any UI flow with two sibling buttons at the same position where clicking the
first is supposed to hide it and reveal the second (a "handoff") breaks if
either button's own `func():` callback references either button variable
directly (`if is_instance_valid(end_turn_btn): ...`). GDScript closures
snapshot outer locals **by value at creation time**, not by reference — so a
callback created before its own variable's assignment (self-reference) or
before a sibling's assignment (forward reference) permanently captures null,
and any code gated behind `is_instance_valid()` on that variable silently
never runs.

**Why:** this is the same closure-capture pitfall as `gdscript-closure-capture.md`,
but easy to miss here because a *self*-reference (a button's callback
referencing the same button it's assigned to) is just as broken as a forward
reference to a sibling — the assignment always completes after the closure
literal is built.

**How to apply:** route all cross-button/self-button lookups through a shared
`Dictionary` (`var controls := {"a": null, "b": null}`) populated with the
real nodes right after creation, and have every callback read
`controls.get("a")` at call time instead of closing over the variable
directly. This pattern was already used correctly elsewhere in menu.gd
(build_signature_lesson, build_keyword_lesson) — apply it to any new
multi-button lesson/dialog flow instead of the direct-variable pattern.
